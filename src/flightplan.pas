unit flightplan;

{ Plano de voo: pontos da rota, limites (geocerca e altitude), opções da rota,
  validação, estimativas e arquivos no formato "QGC WPL 110" (compatível com
  Mission Planner e QGroundControl).

  A rota só é enviada a drones com GPS (veja ProtocoloTemGPS em protocols.pas).
  A simulação (SimulateStep) continua disponível para treinar sem drone. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, Math;

const
  ROTA_MAX_PONTOS = 190;
  ROTA_ALT_MIN_ABSOLUTA = 2.0;     // m acima do ponto de partida
  ROTA_ALT_MAX_ABSOLUTA = 120.0;   // m (limite usual da regulamentação)
  ROTA_VEL_MIN = 0.5;              // m/s
  ROTA_VEL_MAX = 15.0;             // m/s
  ROTA_VEL_SUBIDA = 2.5;           // m/s (padrão ArduCopter)
  ROTA_VEL_DESCIDA = 1.0;          // m/s (média até o pouso)

type
  TAcaoFinal = (afVoltarPartida, afPousarUltimo, afPairarUltimo);

  { TWaypoint }

  TWaypoint = class
  private
    FLatitude: Double;
    FLongitude: Double;
    FAltitude: Double;
    FSpeed: Double;
    FStatus: string; // 'PENDING', 'ACTIVE', 'COMPLETED'
  public
    constructor Create(ALat, ALon, AAlt, ASpeed: Double);
    property Latitude: Double read FLatitude write FLatitude;
    property Longitude: Double read FLongitude write FLongitude;
    property Altitude: Double read FAltitude write FAltitude;
    property Speed: Double read FSpeed write FSpeed;
    property Status: string read FStatus write FStatus;
  end;

  TGeofencePoint = record
    Latitude: Double;
    Longitude: Double;
  end;

  { TFlightPlan }

  TFlightPlan = class
  private
    FWaypoints: TObjectList;
    FCurrentIndex: Integer;
    FGeofence: array[0..3] of TGeofencePoint;
    FGeofenceActive: Boolean;
    FMaxAltitude: Double;
    FMinAltitude: Double;
    FAltitudeActive: Boolean;

    FSimulatedDroneLat: Double;
    FSimulatedDroneLon: Double;
    FSimulatedDroneAlt: Double;
    FSimulationActive: Boolean;

    // Opções da rota
    FAltDecolagem: Double;
    FVelPadrao: Double;
    FAcaoFinal: TAcaoFinal;
    FDistMaxima: Double;

    // Ponto de partida (posição do drone ao enviar a rota)
    FHomeValido: Boolean;
    FHomeLat: Double;
    FHomeLon: Double;

    function GetWaypoint(AIndex: Integer): TWaypoint;
    function GetWaypointCount: Integer;
    function GeofenceConfigurada: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddWaypoint(ALat, ALon, AAlt, ASpeed: Double);
    procedure DeleteWaypoint(AIndex: Integer);
    procedure MoveWaypoint(AFrom, ATo: Integer);
    procedure ClearWaypoints;
    procedure ResetStatus;

    function IsWithinGeofence(ALat, ALon: Double): Boolean;
    function CheckAltitudeLimits(AAlt: Double; out AWarning: string): Boolean;

    procedure StartRoute;
    procedure UpdateRouteTracking(ADroneLat, ADroneLon: Double; out ANextWaypointMsg: string);
    procedure SimulateStep(const ATimeStepSec: Double);

    procedure SetGeofenceCorner(AIndex: Integer; ALat, ALon: Double);
    function GetGeofenceCorner(AIndex: Integer): TGeofencePoint;

    { Rota }
    procedure DefineHome(ALat, ALon: Double);
    procedure LimpaHome;
    { Comprimento do trecho que chega ao ponto AIndex (0 = da partida, se conhecida). }
    function DistanciaTrecho(AIndex: Integer): Double;
    { Distância horizontal total (inclui ida da partida e retorno, se houver). }
    function DistanciaTotal: Double;
    { Tempo estimado em segundos (decolagem, trechos, retorno e pouso). }
    function TempoEstimado: Double;
    { Verifica a rota. Erros impedem o envio; avisos só informam. }
    function Valida(AErros, AAvisos: TStrings): Boolean;
    { Texto que muda sempre que a rota ou as opções mudam. }
    function Assinatura: string;

    procedure SalvaArquivo(const ANome: string);
    function CarregaArquivo(const ANome: string; out AErro: string): Boolean;

    property Waypoints[AIndex: Integer]: TWaypoint read GetWaypoint; default;
    property WaypointCount: Integer read GetWaypointCount;
    property CurrentIndex: Integer read FCurrentIndex write FCurrentIndex;
    property GeofenceActive: Boolean read FGeofenceActive write FGeofenceActive;
    property MaxAltitude: Double read FMaxAltitude write FMaxAltitude;
    property MinAltitude: Double read FMinAltitude write FMinAltitude;
    property AltitudeActive: Boolean read FAltitudeActive write FAltitudeActive;

    property SimulatedDroneLat: Double read FSimulatedDroneLat write FSimulatedDroneLat;
    property SimulatedDroneLon: Double read FSimulatedDroneLon write FSimulatedDroneLon;
    property SimulatedDroneAlt: Double read FSimulatedDroneAlt write FSimulatedDroneAlt;
    property SimulationActive: Boolean read FSimulationActive write FSimulationActive;

    property AltitudeDecolagem: Double read FAltDecolagem write FAltDecolagem;
    property VelocidadePadrao: Double read FVelPadrao write FVelPadrao;
    property AcaoFinal: TAcaoFinal read FAcaoFinal write FAcaoFinal;
    property DistanciaMaxima: Double read FDistMaxima write FDistMaxima;
    property HomeValido: Boolean read FHomeValido;
    property HomeLat: Double read FHomeLat;
    property HomeLon: Double read FHomeLon;
  end;

{ Distância em metros entre dois pontos (haversine). }
function DistanciaMetros(ALat1, ALon1, ALat2, ALon2: Double): Double;
{ Lê número aceitando ponto ou vírgula como separador decimal. }
function LeNumero(const ATexto: string; out AValor: Double): Boolean;
{ Formata número com ponto decimal (independe da configuração regional). }
function FormataNumero(AValor: Double; ACasas: Integer): string;
function TextoTempo(ASegundos: Double): string;

var
  GlobalFlightPlan: TFlightPlan;

implementation

var
  FmtPonto: TFormatSettings;

function DistanciaMetros(ALat1, ALon1, ALat2, ALon2: Double): Double;
const
  R = 6371000.0;
var
  DLat, DLon, A: Double;
begin
  DLat := DegToRad(ALat2 - ALat1);
  DLon := DegToRad(ALon2 - ALon1);
  A := Sqr(Sin(DLat / 2)) + Cos(DegToRad(ALat1)) * Cos(DegToRad(ALat2)) * Sqr(Sin(DLon / 2));
  Result := 2 * R * ArcTan2(Sqrt(A), Sqrt(Max(0, 1 - A)));
end;

function LeNumero(const ATexto: string; out AValor: Double): Boolean;
begin
  Result := TryStrToFloat(StringReplace(Trim(ATexto), ',', '.', [rfReplaceAll]), AValor, FmtPonto);
  if Result then Result := not IsNan(AValor) and not IsInfinite(AValor);
end;

function FormataNumero(AValor: Double; ACasas: Integer): string;
begin
  Result := FloatToStrF(AValor, ffFixed, 15, ACasas, FmtPonto);
end;

function TextoTempo(ASegundos: Double): string;
var
  S: Integer;
begin
  S := Round(ASegundos);
  if S < 60 then
    Result := IntToStr(S) + ' s'
  else
    Result := Format('%d min %.2d s', [S div 60, S mod 60]);
end;

{ TWaypoint }

constructor TWaypoint.Create(ALat, ALon, AAlt, ASpeed: Double);
begin
  inherited Create;
  FLatitude := ALat;
  FLongitude := ALon;
  FAltitude := AAlt;
  FSpeed := ASpeed;
  FStatus := 'PENDING';
end;

{ TFlightPlan }

constructor TFlightPlan.Create;
var
  I: Integer;
begin
  inherited Create;
  FWaypoints := TObjectList.Create(True);
  FCurrentIndex := -1;
  FGeofenceActive := False;
  FMaxAltitude := ROTA_ALT_MAX_ABSOLUTA;
  FMinAltitude := ROTA_ALT_MIN_ABSOLUTA;
  FAltitudeActive := False;

  FSimulatedDroneLat := 0.0;
  FSimulatedDroneLon := 0.0;
  FSimulatedDroneAlt := 0.0;
  FSimulationActive := False;

  FAltDecolagem := 10.0;
  FVelPadrao := 5.0;
  FAcaoFinal := afVoltarPartida;
  FDistMaxima := 500.0;
  FHomeValido := False;

  for I := 0 to 3 do
  begin
    FGeofence[I].Latitude := 0.0;
    FGeofence[I].Longitude := 0.0;
  end;
end;

destructor TFlightPlan.Destroy;
begin
  FWaypoints.Free;
  inherited Destroy;
end;

function TFlightPlan.GetWaypoint(AIndex: Integer): TWaypoint;
begin
  if (AIndex >= 0) and (AIndex < FWaypoints.Count) then
    Result := TWaypoint(FWaypoints[AIndex])
  else
    Result := nil;
end;

function TFlightPlan.GetWaypointCount: Integer;
begin
  Result := FWaypoints.Count;
end;

procedure TFlightPlan.AddWaypoint(ALat, ALon, AAlt, ASpeed: Double);
begin
  FWaypoints.Add(TWaypoint.Create(ALat, ALon, AAlt, ASpeed));
end;

procedure TFlightPlan.DeleteWaypoint(AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < FWaypoints.Count) then
    FWaypoints.Delete(AIndex);
end;

procedure TFlightPlan.MoveWaypoint(AFrom, ATo: Integer);
begin
  if (AFrom >= 0) and (AFrom < FWaypoints.Count) and
    (ATo >= 0) and (ATo < FWaypoints.Count) and (AFrom <> ATo) then
    FWaypoints.Move(AFrom, ATo);
end;

procedure TFlightPlan.ClearWaypoints;
begin
  FWaypoints.Clear;
  FCurrentIndex := -1;
end;

procedure TFlightPlan.ResetStatus;
var
  I: Integer;
begin
  for I := 0 to FWaypoints.Count - 1 do
    TWaypoint(FWaypoints[I]).Status := 'PENDING';
  FCurrentIndex := -1;
end;

function TFlightPlan.GeofenceConfigurada: Boolean;
var
  I: Integer;
begin
  Result := FGeofenceActive;
  if Result then
    for I := 0 to 3 do
      if (Abs(FGeofence[I].Latitude) < 0.0001) and (Abs(FGeofence[I].Longitude) < 0.0001) then
        Exit(False);
end;

function TFlightPlan.IsWithinGeofence(ALat, ALon: Double): Boolean;
var
  I, J: Integer;
  Inside: Boolean;
begin
  Result := True;
  // Geocerca desligada ou com cantos não definidos: não restringe.
  if not GeofenceConfigurada then
    Exit;

  Inside := False;
  J := 3;
  for I := 0 to 3 do
  begin
    if ((FGeofence[I].Latitude > ALat) <> (FGeofence[J].Latitude > ALat)) and
       (ALon < (FGeofence[J].Longitude - FGeofence[I].Longitude) * (ALat - FGeofence[I].Latitude) /
         (FGeofence[J].Latitude - FGeofence[I].Latitude) + FGeofence[I].Longitude) then
      Inside := not Inside;
    J := I;
  end;
  Result := Inside;
end;

function TFlightPlan.CheckAltitudeLimits(AAlt: Double; out AWarning: string): Boolean;
begin
  Result := True;
  AWarning := '';

  if not FAltitudeActive then
    Exit;

  if AAlt > FMaxAltitude then
  begin
    Result := False;
    AWarning := Format('ALTITUDE CRÍTICA: %.1f m acima do máximo de %.1f m!', [AAlt, FMaxAltitude]);
  end
  else if AAlt < FMinAltitude then
  begin
    Result := False;
    AWarning := Format('ALTITUDE CRÍTICA: %.1f m abaixo do mínimo de %.1f m!', [AAlt, FMinAltitude]);
  end;
end;

procedure TFlightPlan.StartRoute;
var
  I: Integer;
begin
  if FWaypoints.Count = 0 then
  begin
    FCurrentIndex := -1;
    Exit;
  end;

  for I := 0 to FWaypoints.Count - 1 do
    TWaypoint(FWaypoints[I]).Status := 'PENDING';

  FCurrentIndex := 0;
  TWaypoint(FWaypoints[0]).Status := 'ACTIVE';

  if FSimulationActive then
  begin
    FSimulatedDroneLat := TWaypoint(FWaypoints[0]).Latitude;
    FSimulatedDroneLon := TWaypoint(FWaypoints[0]).Longitude;
    FSimulatedDroneAlt := TWaypoint(FWaypoints[0]).Altitude;
  end;
end;

procedure TFlightPlan.UpdateRouteTracking(ADroneLat, ADroneLon: Double; out ANextWaypointMsg: string);
var
  W: TWaypoint;
begin
  ANextWaypointMsg := '';
  if (FCurrentIndex < 0) or (FCurrentIndex >= FWaypoints.Count) then
    Exit;

  W := TWaypoint(FWaypoints[FCurrentIndex]);
  if DistanciaMetros(ADroneLat, ADroneLon, W.Latitude, W.Longitude) < 4.0 then
  begin
    W.Status := 'COMPLETED';
    Inc(FCurrentIndex);
    if FCurrentIndex < FWaypoints.Count then
    begin
      TWaypoint(FWaypoints[FCurrentIndex]).Status := 'ACTIVE';
      ANextWaypointMsg := Format('Ponto %d alcançado. Seguindo para o ponto %d...',
        [FCurrentIndex, FCurrentIndex + 1]);
    end
    else
    begin
      FCurrentIndex := -1;
      ANextWaypointMsg := 'ROTA CONCLUÍDA.';
    end;
  end;
end;

procedure TFlightPlan.SimulateStep(const ATimeStepSec: Double);
var
  W: TWaypoint;
  Dist, StepDist, Frac: Double;
begin
  if not FSimulationActive then
    Exit;

  if (FCurrentIndex < 0) or (FCurrentIndex >= FWaypoints.Count) then
    Exit;

  W := TWaypoint(FWaypoints[FCurrentIndex]);
  Dist := DistanciaMetros(FSimulatedDroneLat, FSimulatedDroneLon, W.Latitude, W.Longitude);

  if Dist > 0.2 then
  begin
    StepDist := W.Speed * ATimeStepSec;
    if StepDist >= Dist then
    begin
      FSimulatedDroneLat := W.Latitude;
      FSimulatedDroneLon := W.Longitude;
    end
    else
    begin
      Frac := StepDist / Dist;
      FSimulatedDroneLat := FSimulatedDroneLat + (W.Latitude - FSimulatedDroneLat) * Frac;
      FSimulatedDroneLon := FSimulatedDroneLon + (W.Longitude - FSimulatedDroneLon) * Frac;
    end;
  end;

  if Abs(FSimulatedDroneAlt - W.Altitude) > 0.1 then
  begin
    if FSimulatedDroneAlt < W.Altitude then
      FSimulatedDroneAlt := FSimulatedDroneAlt + (1.5 * ATimeStepSec)
    else
      FSimulatedDroneAlt := FSimulatedDroneAlt - (1.5 * ATimeStepSec);
  end
  else
    FSimulatedDroneAlt := W.Altitude;
end;

procedure TFlightPlan.SetGeofenceCorner(AIndex: Integer; ALat, ALon: Double);
begin
  if (AIndex >= 0) and (AIndex < 4) then
  begin
    FGeofence[AIndex].Latitude := ALat;
    FGeofence[AIndex].Longitude := ALon;
  end;
end;

function TFlightPlan.GetGeofenceCorner(AIndex: Integer): TGeofencePoint;
begin
  if (AIndex >= 0) and (AIndex < 4) then
    Result := FGeofence[AIndex]
  else
  begin
    Result.Latitude := 0.0;
    Result.Longitude := 0.0;
  end;
end;

{ Rota }

procedure TFlightPlan.DefineHome(ALat, ALon: Double);
begin
  FHomeLat := ALat;
  FHomeLon := ALon;
  FHomeValido := (ALat <> 0) or (ALon <> 0);
end;

procedure TFlightPlan.LimpaHome;
begin
  FHomeValido := False;
end;

function TFlightPlan.DistanciaTrecho(AIndex: Integer): Double;
var
  W, A: TWaypoint;
begin
  Result := 0;
  W := GetWaypoint(AIndex);
  if not Assigned(W) then
    Exit;
  if AIndex = 0 then
  begin
    if FHomeValido then
      Result := DistanciaMetros(FHomeLat, FHomeLon, W.Latitude, W.Longitude);
  end
  else
  begin
    A := GetWaypoint(AIndex - 1);
    Result := DistanciaMetros(A.Latitude, A.Longitude, W.Latitude, W.Longitude);
  end;
end;

function TFlightPlan.DistanciaTotal: Double;
var
  I: Integer;
  U: TWaypoint;
begin
  Result := 0;
  for I := 0 to FWaypoints.Count - 1 do
    Result := Result + DistanciaTrecho(I);
  if FHomeValido and (FAcaoFinal = afVoltarPartida) and (FWaypoints.Count > 0) then
  begin
    U := GetWaypoint(FWaypoints.Count - 1);
    Result := Result + DistanciaMetros(U.Latitude, U.Longitude, FHomeLat, FHomeLon);
  end;
end;

function TFlightPlan.TempoEstimado: Double;
var
  I: Integer;
  W, U: TWaypoint;
  AltAnterior, Vel: Double;
begin
  Result := 0;
  if FWaypoints.Count = 0 then
    Exit;

  // Decolagem
  Result := FAltDecolagem / ROTA_VEL_SUBIDA;
  AltAnterior := FAltDecolagem;

  for I := 0 to FWaypoints.Count - 1 do
  begin
    W := GetWaypoint(I);
    Vel := W.Speed;
    if Vel < ROTA_VEL_MIN then
      Vel := FVelPadrao;
    // Horizontal e vertical acontecem juntos: vale o mais demorado.
    if W.Altitude >= AltAnterior then
      Result := Result + Max(DistanciaTrecho(I) / Vel, (W.Altitude - AltAnterior) / ROTA_VEL_SUBIDA)
    else
      Result := Result + Max(DistanciaTrecho(I) / Vel, (AltAnterior - W.Altitude) / ROTA_VEL_DESCIDA);
    AltAnterior := W.Altitude;
  end;

  U := GetWaypoint(FWaypoints.Count - 1);
  case FAcaoFinal of
    afVoltarPartida:
      begin
        if FHomeValido then
          Result := Result + DistanciaMetros(U.Latitude, U.Longitude, FHomeLat, FHomeLon) / Max(FVelPadrao, ROTA_VEL_MIN);
        Result := Result + AltAnterior / ROTA_VEL_DESCIDA;
      end;
    afPousarUltimo:
      Result := Result + AltAnterior / ROTA_VEL_DESCIDA;
    afPairarUltimo: ;
  end;
end;

function TFlightPlan.Valida(AErros, AAvisos: TStrings): Boolean;
var
  I: Integer;
  W, A: TWaypoint;
  AltMin, AltMax, D: Double;
begin
  AErros.Clear;
  AAvisos.Clear;

  // Reject non-finite values before comparisons, distances and time estimates.
  if IsNan(FMinAltitude) or IsInfinite(FMinAltitude) or
     IsNan(FMaxAltitude) or IsInfinite(FMaxAltitude) or
     IsNan(FAltDecolagem) or IsInfinite(FAltDecolagem) or
     IsNan(FVelPadrao) or IsInfinite(FVelPadrao) or
     IsNan(FDistMaxima) or IsInfinite(FDistMaxima) or (FDistMaxima <= 0) or
     (FMinAltitude > FMaxAltitude) then
    AErros.Add('Limites da rota invalidos ou nao finitos.');
  if FHomeValido and (IsNan(FHomeLat) or IsInfinite(FHomeLat) or
     IsNan(FHomeLon) or IsInfinite(FHomeLon)) then
    AErros.Add('Coordenadas do ponto de partida nao finitas.');
  if FGeofenceActive then
    for I := 0 to High(FGeofence) do
      if IsNan(FGeofence[I].Latitude) or IsInfinite(FGeofence[I].Latitude) or
         IsNan(FGeofence[I].Longitude) or IsInfinite(FGeofence[I].Longitude) then
        AErros.Add('Coordenadas da geocerca nao finitas.');
  for I := 0 to FWaypoints.Count - 1 do
  begin
    W := GetWaypoint(I);
    if IsNan(W.Latitude) or IsInfinite(W.Latitude) or
       IsNan(W.Longitude) or IsInfinite(W.Longitude) or
       IsNan(W.Altitude) or IsInfinite(W.Altitude) or
       IsNan(W.Speed) or IsInfinite(W.Speed) then
      AErros.Add(Format('Ponto %d: valores nao finitos.', [I + 1]));
  end;
  if AErros.Count > 0 then Exit(False);

  AltMin := Max(FMinAltitude, ROTA_ALT_MIN_ABSOLUTA);
  AltMax := Min(FMaxAltitude, ROTA_ALT_MAX_ABSOLUTA);

  if FWaypoints.Count = 0 then
    AErros.Add('A rota não tem pontos.');
  if FWaypoints.Count > ROTA_MAX_PONTOS then
    AErros.Add(Format('A rota tem %d pontos; o máximo é %d.', [FWaypoints.Count, ROTA_MAX_PONTOS]));

  if (FAltDecolagem < AltMin) or (FAltDecolagem > AltMax) then
    AErros.Add(Format('Altitude de decolagem %s m fora do limite (%s a %s m).',
      [FormataNumero(FAltDecolagem, 1), FormataNumero(AltMin, 1), FormataNumero(AltMax, 1)]));
  if (FVelPadrao < ROTA_VEL_MIN) or (FVelPadrao > ROTA_VEL_MAX) then
    AErros.Add(Format('Velocidade padrão fora do limite (%s a %s m/s).',
      [FormataNumero(ROTA_VEL_MIN, 1), FormataNumero(ROTA_VEL_MAX, 1)]));

  for I := 0 to FWaypoints.Count - 1 do
  begin
    W := GetWaypoint(I);
    if (Abs(W.Latitude) > 90) or (Abs(W.Longitude) > 180) or
      ((W.Latitude = 0) and (W.Longitude = 0)) then
      AErros.Add(Format('Ponto %d: coordenadas inválidas.', [I + 1]));
    if (W.Altitude < AltMin) or (W.Altitude > AltMax) then
      AErros.Add(Format('Ponto %d: altitude %s m fora do limite (%s a %s m).',
        [I + 1, FormataNumero(W.Altitude, 1), FormataNumero(AltMin, 1), FormataNumero(AltMax, 1)]));
    if (W.Speed < ROTA_VEL_MIN) or (W.Speed > ROTA_VEL_MAX) then
      AErros.Add(Format('Ponto %d: velocidade %s m/s fora do limite (%s a %s m/s).',
        [I + 1, FormataNumero(W.Speed, 1), FormataNumero(ROTA_VEL_MIN, 1), FormataNumero(ROTA_VEL_MAX, 1)]));
    if not IsWithinGeofence(W.Latitude, W.Longitude) then
      AErros.Add(Format('Ponto %d: fora da geocerca.', [I + 1]));
    if FHomeValido then
    begin
      D := DistanciaMetros(FHomeLat, FHomeLon, W.Latitude, W.Longitude);
      if D > FDistMaxima then
        AErros.Add(Format('Ponto %d: a %s m do ponto de partida (máximo %s m).',
          [I + 1, FormataNumero(D, 0), FormataNumero(FDistMaxima, 0)]));
    end;
    if I > 0 then
    begin
      A := GetWaypoint(I - 1);
      if DistanciaMetros(A.Latitude, A.Longitude, W.Latitude, W.Longitude) < 1.0 then
        AAvisos.Add(Format('Pontos %d e %d estão a menos de 1 m um do outro.', [I, I + 1]));
    end;
  end;

  if FHomeValido then
  begin
    if not IsWithinGeofence(FHomeLat, FHomeLon) then
      AErros.Add('O ponto de partida do drone está fora da geocerca.');
  end
  else
    AAvisos.Add('Ponto de partida desconhecido: a distância até o drone será conferida ao enviar.');

  if (FWaypoints.Count > 0) and (TempoEstimado > 15 * 60) then
    AAvisos.Add('Rota longa (' + TextoTempo(TempoEstimado) +
      '): confira se a bateria do drone aguenta, com margem.');
  if FAcaoFinal = afPairarUltimo then
    AAvisos.Add('Ao terminar, o drone vai pairar no último ponto até receber outro comando.');

  Result := AErros.Count = 0;
end;

function TFlightPlan.Assinatura: string;
var
  I: Integer;
  W: TWaypoint;
begin
  Result := Format('%s|%s|%d|%s', [FormataNumero(FAltDecolagem, 2),
    FormataNumero(FVelPadrao, 2), Ord(FAcaoFinal), FormataNumero(FDistMaxima, 0)]);
  // O ponto de partida não entra: ele oscila com o GPS e o drone usa o próprio.
  for I := 0 to FWaypoints.Count - 1 do
  begin
    W := GetWaypoint(I);
    Result := Result + '|' + FormataNumero(W.Latitude, 7) + ',' +
      FormataNumero(W.Longitude, 7) + ',' + FormataNumero(W.Altitude, 2) + ',' +
      FormataNumero(W.Speed, 2);
  end;
end;

{ Arquivo "QGC WPL 110": índice, atual, frame, comando, p1..p4, lat, lon, alt, autocontinuar }

procedure TFlightPlan.SalvaArquivo(const ANome: string);
var
  L: TStringList;
  I, N: Integer;
  W, U: TWaypoint;
  HLat, HLon, VelAtual: Double;

  procedure Linha(AFrame, ACmd: Integer; P1, P2, P3, P4, ALat, ALon, AAlt: Double);
  begin
    L.Add(Format('%d'#9'0'#9'%d'#9'%d'#9'%s'#9'%s'#9'%s'#9'%s'#9'%s'#9'%s'#9'%s'#9'1',
      [N, AFrame, ACmd, FormataNumero(P1, 6), FormataNumero(P2, 6), FormataNumero(P3, 6),
       FormataNumero(P4, 6), FormataNumero(ALat, 8), FormataNumero(ALon, 8),
       FormataNumero(AAlt, 6)]));
    Inc(N);
  end;

begin
  L := TStringList.Create;
  try
    L.Add('QGC WPL 110');
    N := 0;
    if FHomeValido then
    begin
      HLat := FHomeLat;
      HLon := FHomeLon;
    end
    else if FWaypoints.Count > 0 then
    begin
      HLat := GetWaypoint(0).Latitude;
      HLon := GetWaypoint(0).Longitude;
    end
    else
    begin
      HLat := 0;
      HLon := 0;
    end;
    // 0: ponto de partida (referência), 1: decolagem
    Linha(0, 16, 0, 0, 0, 0, HLat, HLon, 0);
    Linha(3, 22, 0, 0, 0, 0, 0, 0, FAltDecolagem);
    VelAtual := -1;
    for I := 0 to FWaypoints.Count - 1 do
    begin
      W := GetWaypoint(I);
      if Abs(W.Speed - VelAtual) > 0.01 then
      begin
        Linha(2, 178, 1, W.Speed, -1, 0, 0, 0, 0);
        VelAtual := W.Speed;
      end;
      Linha(3, 16, 0, 2, 0, 0, W.Latitude, W.Longitude, W.Altitude);
    end;
    if FWaypoints.Count > 0 then
    begin
      U := GetWaypoint(FWaypoints.Count - 1);
      case FAcaoFinal of
        afVoltarPartida: Linha(2, 20, 0, 0, 0, 0, 0, 0, 0);
        afPousarUltimo: Linha(3, 21, 0, 0, 0, 0, U.Latitude, U.Longitude, 0);
        afPairarUltimo: Linha(3, 17, 0, 0, 0, 0, U.Latitude, U.Longitude, U.Altitude);
      end;
    end;
    L.SaveToFile(ANome);
  finally
    L.Free;
  end;
end;

function TFlightPlan.CarregaArquivo(const ANome: string; out AErro: string): Boolean;
var
  L, C: TStringList;
  I, Cmd, Lidos: Integer;
  V: array[0..11] of Double;
  J: Integer;
  Vel: Double;
  NovaAcao: TAcaoFinal;
  NovaDecolagem: Double;
  Pontos: TObjectList;
begin
  Result := False;
  AErro := '';
  L := TStringList.Create;
  C := TStringList.Create;
  Pontos := TObjectList.Create(True);
  try
    try
      L.LoadFromFile(ANome);
    except
      on E: Exception do
      begin
        AErro := 'Não foi possível ler o arquivo: ' + E.Message;
        Exit;
      end;
    end;
    if (L.Count = 0) or (Pos('QGC WPL', L[0]) <> 1) then
    begin
      AErro := 'O arquivo não está no formato "QGC WPL 110" (Mission Planner / QGroundControl).';
      Exit;
    end;

    Vel := FVelPadrao;
    NovaAcao := afPairarUltimo;
    NovaDecolagem := FAltDecolagem;
    C.Delimiter := #9;
    C.StrictDelimiter := True;
    Lidos := 0;
    for I := 1 to L.Count - 1 do
    begin
      if Trim(L[I]) = '' then
        Continue;
      C.DelimitedText := StringReplace(Trim(L[I]), ' ', #9, [rfReplaceAll]);
      // Remove campos vazios causados por separadores repetidos.
      for J := C.Count - 1 downto 0 do
        if C[J] = '' then
          C.Delete(J);
      if C.Count < 12 then
      begin
        AErro := Format('Linha %d incompleta.', [I + 1]);
        Exit;
      end;
      for J := 0 to 11 do
        if not LeNumero(C[J], V[J]) then
        begin
          AErro := Format('Linha %d: valor inválido "%s".', [I + 1, C[J]]);
          Exit;
        end;
      if Round(V[0]) = 0 then
        Continue;  // ponto de partida de referência
      Cmd := Round(V[3]);
      case Cmd of
        16: // ponto da rota
          begin
            Pontos.Add(TWaypoint.Create(V[8], V[9], V[10], Vel));
            Inc(Lidos);
          end;
        22: // decolagem
          NovaDecolagem := V[10];
        178: // velocidade
          if V[5] > 0 then
            Vel := V[5];
        20:
          NovaAcao := afVoltarPartida;
        21:
          begin
            NovaAcao := afPousarUltimo;
            if (V[8] <> 0) or (V[9] <> 0) then
            begin
              Pontos.Add(TWaypoint.Create(V[8], V[9], Max(V[10], FAltDecolagem), Vel));
              Inc(Lidos);
            end;
          end;
        17:
          begin
            NovaAcao := afPairarUltimo;
            if (V[8] <> 0) or (V[9] <> 0) then
            begin
              Pontos.Add(TWaypoint.Create(V[8], V[9], V[10], Vel));
              Inc(Lidos);
            end;
          end;
      end;
    end;
    if Lidos = 0 then
    begin
      AErro := 'O arquivo não contém pontos de rota.';
      Exit;
    end;

    // Pouso/pairar no mesmo lugar do último ponto: não duplica o ponto.
    if (Pontos.Count >= 2) and (NovaAcao <> afVoltarPartida) and
      (DistanciaMetros(TWaypoint(Pontos[Pontos.Count - 1]).Latitude, TWaypoint(Pontos[Pontos.Count - 1]).Longitude,
       TWaypoint(Pontos[Pontos.Count - 2]).Latitude, TWaypoint(Pontos[Pontos.Count - 2]).Longitude) < 0.5) then
      Pontos.Delete(Pontos.Count - 1);

    FWaypoints.Clear;
    Pontos.OwnsObjects := False;
    for I := 0 to Pontos.Count - 1 do
      FWaypoints.Add(Pontos[I]);
    FCurrentIndex := -1;
    FAcaoFinal := NovaAcao;
    FAltDecolagem := NovaDecolagem;
    Result := True;
  finally
    Pontos.Free;
    C.Free;
    L.Free;
  end;
end;

initialization
  FmtPonto := DefaultFormatSettings;
  FmtPonto.DecimalSeparator := '.';
  FmtPonto.ThousandSeparator := #0;
  GlobalFlightPlan := TFlightPlan.Create;

finalization
  GlobalFlightPlan.Free;

end.
