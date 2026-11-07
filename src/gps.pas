unit GPS;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, ComCtrls, Math, gpstarget, gpsskyplot, gpssignalplot, gpsportconnected,
  nmeadecode, LazSerial, AdvLed, SdpoSerial, config;

type

  { TfrmGPS }

  TfrmGPS = class(TForm)
    GPSPortConnected1: TGPSPortConnected;
    GPSSignalPlot1: TGPSSignalPlot;
    GPSSkyPlot1: TGPSSkyPlot;
    GPSTarget1: TGPSTarget;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    lblGLLTime: TLabel;
    lblGLLLong: TLabel;
    lblGLLLat: TLabel;
    Memo1: TMemo;
    NMEADecode1: TNMEADecode;
    PageControl1: TPageControl;
    pnGPS: TPanel;
    SdpoSerial1: TSdpoSerial;
    tslog: TTabSheet;
    tbSAT: TTabSheet;
    tsSignal: TTabSheet;
    tslocation: TTabSheet;

    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure GPSPortConnected1Show(Sender: TObject);
    procedure GPSSignalPlot1Click(Sender: TObject);
    procedure NMEADecode1NMEA(Sender: TObject; NMEA: TNMEADecode);
    procedure SdpoSerial1RxData(Sender: TObject);

  private
    FBuffer: string;

    // GPS Central (Base / Estação Terrena - Serial NMEA)
    FLatitude: Double;
    FLongitude: Double;
    FAltitude: Double;
    FVelocidade: Double;
    FCurso: Double;
    FHDOP: Double;
    FVDOP: Double;
    FPDOP: Double;

    FSatelites: Integer;
    FFixQuality: Integer;
    FFixStatus: Integer;
    FModoFix: string;

    FDataUTC: string;
    FHoraUTC: string;

    FTemPosicao: Boolean;
    FTemAltitude: Boolean;

    // GPS Drone (Telemetria em Voo)
    FDroneLat: Double;
    FDroneLon: Double;
    FDroneAlt: Double;
    FDroneVel: Double;
    FDroneCurso: Double;
    FDroneSatelites: Integer;
    FDroneFix: Integer;
    FDroneTemPosicao: Boolean;
    FDistanciaDroneCentral: Double;
    FAzimuteDroneCentral: Double;

    // Controles dinâmicos de interface para os 2 GPS
    FGbCentral: TGroupBox;
    FGbDrone: TGroupBox;
    FPnRelativo: TPanel;
    FLblCentralPos: TLabel;
    FLblCentralAlt: TLabel;
    FLblCentralSat: TLabel;
    FLblCentralHora: TLabel;
    FLblDronePos: TLabel;
    FLblDroneAlt: TLabel;
    FLblDroneVel: TLabel;
    FLblDroneSat: TLabel;

    procedure Log(const AMsg: string);
    procedure EnsureConfig;
    procedure ConfiguraSerial;
    procedure AbrirGPS;
    procedure FecharGPS;
    procedure ProcessaBufferNMEA;
    procedure CriaControlesLocalizacao;
    procedure RecalculaDistancia;
    procedure AtualizaUI;
    function SafeStrToFloat(const S: string; out V: Double): Boolean;
    function SafeStrToInt(const S: string; out V: Integer): Boolean;

  public
    procedure Atualiza;
    procedure AtualizaTelemetriaDrone(const ALat, ALon, AAlt, AVel, ACurso: Double;
      ASatelites, AFix: Integer; AValido: Boolean);

    // GPS Central
    property Latitude: Double read FLatitude;
    property Longitude: Double read FLongitude;
    property Altitude: Double read FAltitude;
    property Velocidade: Double read FVelocidade;
    property Curso: Double read FCurso;
    property Satelites: Integer read FSatelites;
    property HDOP: Double read FHDOP;
    property VDOP: Double read FVDOP;
    property PDOP: Double read FPDOP;
    property FixQuality: Integer read FFixQuality;
    property FixStatus: Integer read FFixStatus;
    property ModoFix: string read FModoFix;
    property DataUTC: string read FDataUTC;
    property HoraUTC: string read FHoraUTC;
    property TemPosicao: Boolean read FTemPosicao;
    property TemAltitude: Boolean read FTemAltitude;

    // Aliases explícitos
    property CentralLat: Double read FLatitude;
    property CentralLon: Double read FLongitude;
    property CentralAlt: Double read FAltitude;
    property CentralTemPosicao: Boolean read FTemPosicao;

    // GPS Drone (Telemetria)
    property DroneLat: Double read FDroneLat;
    property DroneLon: Double read FDroneLon;
    property DroneAlt: Double read FDroneAlt;
    property DroneVelocidade: Double read FDroneVel;
    property DroneCurso: Double read FDroneCurso;
    property DroneSatelites: Integer read FDroneSatelites;
    property DroneFix: Integer read FDroneFix;
    property DroneTemPosicao: Boolean read FDroneTemPosicao;
    property DistanciaDroneCentral: Double read FDistanciaDroneCentral;
    property AzimuteDroneCentral: Double read FAzimuteDroneCentral;
  end;

var
  frmGPS: TfrmGPS;

implementation

{$R *.lfm}

uses
  main;

{ TfrmGPS }

procedure TfrmGPS.Log(const AMsg: string);
begin
  if Assigned(Memo1) then
    Memo1.Lines.Append(FormatDateTime('dd/mm/yyyy hh:nn:ss', Now) + ': ' + AMsg);
end;

procedure TfrmGPS.EnsureConfig;
begin
  if not Assigned(frmconfig) then
    frmconfig := Tfrmconfig.Create(Self);
end;

function TfrmGPS.SafeStrToFloat(const S: string; out V: Double): Boolean;
var
  T: string;
begin
  T := Trim(S);
  T := StringReplace(T, ',', FormatSettings.DecimalSeparator, [rfReplaceAll]);
  T := StringReplace(T, '.', FormatSettings.DecimalSeparator, [rfReplaceAll]);
  Result := TryStrToFloat(T, V);
end;

function TfrmGPS.SafeStrToInt(const S: string; out V: Integer): Boolean;
begin
  Result := TryStrToInt(Trim(S), V);
end;

procedure TfrmGPS.ConfiguraSerial;
begin
  EnsureConfig;

  if SdpoSerial1.Active then
    SdpoSerial1.Close;

  SdpoSerial1.Device := Trim(frmconfig.cbSerialPort.Text);
  SdpoSerial1.BaudRate := TBaudRate(frmconfig.cbBaudrate.ItemIndex);
  SdpoSerial1.DataBits := TDataBits(frmconfig.cbDatabits.ItemIndex);
  SdpoSerial1.FlowControl := TFlowControl(frmconfig.rgFlowControl.ItemIndex);
  SdpoSerial1.StopBits := TStopBits(frmconfig.rgStopbit.ItemIndex);
end;

procedure TfrmGPS.AbrirGPS;
begin
  EnsureConfig;

  if not frmconfig.ckbGPS.Checked then
  begin
    Log('GPS desabilitado na configuração');
    if Assigned(frmMain) then
      frmMain.DesativaGPS;
    Exit;
  end;

  ConfiguraSerial;

  try
    if not SdpoSerial1.Active then
      SdpoSerial1.Open;

    if Assigned(GPSPortConnected1) then
    begin
      try
        GPSPortConnected1.OpenPort;
      except
      end;

      try
        GPSPortConnected1.DoShow;
      except
      end;
    end;

    Log('GPS ativo na porta ' + SdpoSerial1.Device);

    if Assigned(frmMain) then
      frmMain.AtivaGPS;

  except
    on E: Exception do
    begin
      Log('Erro ao abrir GPS: ' + E.Message);
      if Assigned(frmMain) then
        frmMain.DesativaGPS;
      FecharGPS;
    end;
  end;
end;

procedure TfrmGPS.FecharGPS;
begin
  try
    if Assigned(GPSPortConnected1) then
    begin
      try
        GPSPortConnected1.ClosePort;
      except
      end;
    end;
  except
  end;

  try
    if SdpoSerial1.Active then
      SdpoSerial1.Close;
  except
  end;

  if Assigned(frmMain) then
    frmMain.DesativaGPS;
end;

procedure TfrmGPS.ProcessaBufferNMEA;
var
  P: Integer;
  Linha: string;
begin
  repeat
    P := Pos(#13, FBuffer);
    if P = 0 then
      P := Pos(#10, FBuffer);

    if P > 0 then
    begin
      Linha := Trim(Copy(FBuffer, 1, P - 1));
      Delete(FBuffer, 1, P);

      while (Length(FBuffer) > 0) and ((FBuffer[1] = #10) or (FBuffer[1] = #13)) do
        Delete(FBuffer, 1, 1);

      if Linha <> '' then
      begin
        Log('NMEA: ' + Linha);
        try
          NMEADecode1.Sentence := Linha;
        except
          on E: Exception do
            Log('Erro ao interpretar NMEA: ' + E.Message);
        end;
      end;
    end;
  until P = 0;
end;

procedure TfrmGPS.Atualiza;
var
  dLat, dLong, dAlt, dVel, dCurso, dHDOP, dVDOP, dPDOP: Double;
  iSat, iFixQuality, iFixStatus: Integer;
begin
  FTemPosicao := False;
  FTemAltitude := False;

  { posição e hora - GLL }
  if SafeStrToFloat(NMEADecode1.GLL.LatitudeDegree, dLat) and
     SafeStrToFloat(NMEADecode1.GLL.LongitudeDegree, dLong) then
  begin
    if SameText(NMEADecode1.GLL.LatHemis, 'S') then
      dLat := -Abs(dLat)
    else
      dLat := Abs(dLat);

    if SameText(NMEADecode1.GLL.LongHemis, 'W') then
      dLong := -Abs(dLong)
    else
      dLong := Abs(dLong);

    FLatitude := dLat;
    FLongitude := dLong;
    FTemPosicao := True;
    FHoraUTC := NMEADecode1.GLL.UTCTime;
  end;

  { fallback posição / altitude / satélites / hdop / qualidade - GGA }
  if SafeStrToFloat(NMEADecode1.GGA.LatitudeDegree, dLat) and
     SafeStrToFloat(NMEADecode1.GGA.LongitudeDegree, dLong) then
  begin
    if SameText(NMEADecode1.GGA.LatHemis, 'S') then
      dLat := -Abs(dLat)
    else
      dLat := Abs(dLat);

    if SameText(NMEADecode1.GGA.LongHemis, 'W') then
      dLong := -Abs(dLong)
    else
      dLong := Abs(dLong);

    if not FTemPosicao then
    begin
      FLatitude := dLat;
      FLongitude := dLong;
      FTemPosicao := True;
    end;
  end;

  if SafeStrToFloat(NMEADecode1.GGA.Altitude, dAlt) then
  begin
    FAltitude := dAlt;
    FTemAltitude := True;
  end;

  if SafeStrToInt(NMEADecode1.GGA.SatsInUse, iSat) then
    FSatelites := iSat;

  if SafeStrToFloat(NMEADecode1.GGA.HDOP, dHDOP) then
    FHDOP := dHDOP;

  if SafeStrToInt(NMEADecode1.GGA.FixQuality, iFixQuality) then
    FFixQuality := iFixQuality;

  if NMEADecode1.GGA.UTC <> '' then
    FHoraUTC := NMEADecode1.GGA.UTC;

  { fallback posição / velocidade / curso / data / hora - RMC }
  if SafeStrToFloat(NMEADecode1.RMC.LatitudeDegree, dLat) and
     SafeStrToFloat(NMEADecode1.RMC.LongitudeDegree, dLong) then
  begin
    if SameText(NMEADecode1.RMC.LatHemis, 'S') then
      dLat := -Abs(dLat)
    else
      dLat := Abs(dLat);

    if SameText(NMEADecode1.RMC.LongHemis, 'W') then
      dLong := -Abs(dLong)
    else
      dLong := Abs(dLong);

    if not FTemPosicao then
    begin
      FLatitude := dLat;
      FLongitude := dLong;
      FTemPosicao := True;
    end;
  end;

  if SafeStrToFloat(NMEADecode1.RMC.Speed, dVel) then
    FVelocidade := dVel;

  if SafeStrToFloat(NMEADecode1.RMC.TrueCourse, dCurso) then
    FCurso := dCurso;

  if NMEADecode1.RMC.UTCDate <> '' then
    FDataUTC := NMEADecode1.RMC.UTCDate;

  if NMEADecode1.RMC.UTCTime <> '' then
    FHoraUTC := NMEADecode1.RMC.UTCTime;

  { GSA - fix e dop }
  if SafeStrToInt(NMEADecode1.GSA.FixStatus, iFixStatus) then
    FFixStatus := iFixStatus;

  FModoFix := NMEADecode1.GSA.Mode;

  if SafeStrToFloat(NMEADecode1.GSA.PDOP, dPDOP) then
    FPDOP := dPDOP;

  if SafeStrToFloat(NMEADecode1.GSA.HDOP, dHDOP) then
    FHDOP := dHDOP;

  if SafeStrToFloat(NMEADecode1.GSA.VDOP, dVDOP) then
    FVDOP := dVDOP;

  { fallback altitude - PGRMZ }
  if (not FTemAltitude) and SafeStrToFloat(NMEADecode1.PGRMZ.Altitude, dAlt) then
  begin
    FAltitude := dAlt;
    FTemAltitude := True;
  end;

  AtualizaUI;
end;

procedure TfrmGPS.CriaControlesLocalizacao;
begin
  if Assigned(FGbCentral) then Exit;

  // Esconde labels antigos da aba de localização
  if Assigned(Label3) then Label3.Visible := False;
  if Assigned(Label4) then Label4.Visible := False;
  if Assigned(Label5) then Label5.Visible := False;
  if Assigned(lblGLLLat) then lblGLLLat.Visible := False;
  if Assigned(lblGLLLong) then lblGLLLong.Visible := False;
  if Assigned(lblGLLTime) then lblGLLTime.Visible := False;

  // Painel da Central
  FGbCentral := TGroupBox.Create(tslocation);
  FGbCentral.Parent := tslocation;
  FGbCentral.Left := 8;
  FGbCentral.Top := 6;
  FGbCentral.Width := 290;
  FGbCentral.Height := 134;
  FGbCentral.Caption := ' GPS Central (Base / Serial) ';
  FGbCentral.Font.Style := [fsBold];

  FLblCentralPos := TLabel.Create(FGbCentral);
  FLblCentralPos.Parent := FGbCentral;
  FLblCentralPos.Left := 10;
  FLblCentralPos.Top := 4;
  FLblCentralPos.Font.Style := [];
  FLblCentralPos.Caption := 'Lat: -  Lon: -';

  FLblCentralAlt := TLabel.Create(FGbCentral);
  FLblCentralAlt.Parent := FGbCentral;
  FLblCentralAlt.Left := 10;
  FLblCentralAlt.Top := 26;
  FLblCentralAlt.Font.Style := [];
  FLblCentralAlt.Caption := 'Altitude: -';

  FLblCentralSat := TLabel.Create(FGbCentral);
  FLblCentralSat.Parent := FGbCentral;
  FLblCentralSat.Left := 10;
  FLblCentralSat.Top := 48;
  FLblCentralSat.Font.Style := [];
  FLblCentralSat.Caption := 'Satélites: 0  |  Sem fix';

  FLblCentralHora := TLabel.Create(FGbCentral);
  FLblCentralHora.Parent := FGbCentral;
  FLblCentralHora.Left := 10;
  FLblCentralHora.Top := 70;
  FLblCentralHora.Font.Style := [];
  FLblCentralHora.Caption := 'UTC: -';

  // Painel do Drone
  FGbDrone := TGroupBox.Create(tslocation);
  FGbDrone.Parent := tslocation;
  FGbDrone.Left := 304;
  FGbDrone.Top := 6;
  FGbDrone.Width := 290;
  FGbDrone.Height := 134;
  FGbDrone.Caption := ' GPS Drone (Telemetria em Voo) ';
  FGbDrone.Font.Style := [fsBold];

  FLblDronePos := TLabel.Create(FGbDrone);
  FLblDronePos.Parent := FGbDrone;
  FLblDronePos.Left := 10;
  FLblDronePos.Top := 4;
  FLblDronePos.Font.Style := [];
  FLblDronePos.Caption := 'Lat: -  Lon: -';

  FLblDroneAlt := TLabel.Create(FGbDrone);
  FLblDroneAlt.Parent := FGbDrone;
  FLblDroneAlt.Left := 10;
  FLblDroneAlt.Top := 26;
  FLblDroneAlt.Font.Style := [];
  FLblDroneAlt.Caption := 'Altitude: -';

  FLblDroneVel := TLabel.Create(FGbDrone);
  FLblDroneVel.Parent := FGbDrone;
  FLblDroneVel.Left := 10;
  FLblDroneVel.Top := 48;
  FLblDroneVel.Font.Style := [];
  FLblDroneVel.Caption := 'Vel: -  |  Rumo: -';

  FLblDroneSat := TLabel.Create(FGbDrone);
  FLblDroneSat.Parent := FGbDrone;
  FLblDroneSat.Left := 10;
  FLblDroneSat.Top := 70;
  FLblDroneSat.Font.Style := [];
  FLblDroneSat.Caption := 'Satélites: -  |  Sem telemetria';

  // Barra de status relativo
  FPnRelativo := TPanel.Create(tslocation);
  FPnRelativo.Parent := tslocation;
  FPnRelativo.Left := 8;
  FPnRelativo.Top := 146;
  FPnRelativo.Width := 586;
  FPnRelativo.Height := 34;
  FPnRelativo.BevelOuter := bvLowered;
  FPnRelativo.Font.Style := [fsBold];
  FPnRelativo.Caption := 'Aguardando sincronização de GPS (Central e Drone)...';
end;

procedure TfrmGPS.RecalculaDistancia;
var
  dLatRad, dLonRad, lat1Rad, lat2Rad, a, c, y, x: Double;
begin
  if FTemPosicao and FDroneTemPosicao then
  begin
    dLatRad := (FDroneLat - FLatitude) * Pi / 180.0;
    dLonRad := (FDroneLon - FLongitude) * Pi / 180.0;
    lat1Rad := FLatitude * Pi / 180.0;
    lat2Rad := FDroneLat * Pi / 180.0;
    a := Sin(dLatRad / 2.0) * Sin(dLatRad / 2.0) +
         Cos(lat1Rad) * Cos(lat2Rad) * Sin(dLonRad / 2.0) * Sin(dLonRad / 2.0);
    if a > 1.0 then a := 1.0;
    c := 2.0 * ArcTan2(Sqrt(a), Sqrt(Max(0.0, 1.0 - a)));
    FDistanciaDroneCentral := 6371000.0 * c;

    y := Sin(dLonRad) * Cos(lat2Rad);
    x := Cos(lat1Rad) * Sin(lat2Rad) - Sin(lat1Rad) * Cos(lat2Rad) * Cos(dLonRad);
    FAzimuteDroneCentral := ArcTan2(y, x) * 180.0 / Pi;
    if FAzimuteDroneCentral < 0 then
      FAzimuteDroneCentral := FAzimuteDroneCentral + 360.0;
  end
  else
  begin
    FDistanciaDroneCentral := 0;
    FAzimuteDroneCentral := 0;
  end;
end;

procedure TfrmGPS.AtualizaUI;
begin
  if not Assigned(FGbCentral) then Exit;

  // 1. Central
  if FTemPosicao then
  begin
    FLblCentralPos.Caption := Format('Lat: %.6f  Lon: %.6f', [FLatitude, FLongitude]);
    if FTemAltitude then
      FLblCentralAlt.Caption := Format('Altitude: %.1f m', [FAltitude])
    else
      FLblCentralAlt.Caption := 'Altitude: s/ info';
    FLblCentralSat.Caption := Format('Satélites: %d  |  Fix: %d (%s)', [FSatelites, FFixQuality, FModoFix]);
    FLblCentralHora.Caption := 'UTC: ' + FHoraUTC;
  end
  else
  begin
    FLblCentralPos.Caption := 'Aguardando fix NMEA na porta serial...';
    FLblCentralAlt.Caption := 'Altitude: -';
    FLblCentralSat.Caption := Format('Satélites: %d  |  Sem fix', [FSatelites]);
    FLblCentralHora.Caption := 'UTC: ' + FHoraUTC;
  end;

  // 2. Drone
  if FDroneTemPosicao then
  begin
    FLblDronePos.Caption := Format('Lat: %.6f  Lon: %.6f', [FDroneLat, FDroneLon]);
    FLblDroneAlt.Caption := Format('Altitude: %.1f m', [FDroneAlt]);
    FLblDroneVel.Caption := Format('Vel: %.1f m/s (%.0f km/h)  Rumo: %.0f°',
      [FDroneVel, FDroneVel * 3.6, FDroneCurso]);
    FLblDroneSat.Caption := Format('Satélites: %d  |  Fix: %d', [FDroneSatelites, FDroneFix]);
  end
  else
  begin
    FLblDronePos.Caption := 'Aguardando telemetria GPS do drone...';
    FLblDroneAlt.Caption := 'Altitude: -';
    FLblDroneVel.Caption := 'Velocidade: -  |  Rumo: -';
    FLblDroneSat.Caption := 'Satélites: -  |  Sem telemetria';
  end;

  // 3. Status Relativo
  RecalculaDistancia;
  if FTemPosicao and FDroneTemPosicao then
    FPnRelativo.Caption := Format('Distância Central <-> Drone: %.1f m  |  Azimute: %.0f°',
      [FDistanciaDroneCentral, FAzimuteDroneCentral])
  else if FDroneTemPosicao then
    FPnRelativo.Caption := 'Drone com sinal GPS ativo. Central aguardando fix NMEA local.'
  else if FTemPosicao then
    FPnRelativo.Caption := 'Central com sinal GPS ativo. Drone aguardando telemetria em voo.'
  else
    FPnRelativo.Caption := 'Aguardando sincronização de GPS (Central e Drone)...';
end;

procedure TfrmGPS.AtualizaTelemetriaDrone(const ALat, ALon, AAlt, AVel, ACurso: Double;
  ASatelites, AFix: Integer; AValido: Boolean);
begin
  FDroneLat := ALat;
  FDroneLon := ALon;
  FDroneAlt := AAlt;
  FDroneVel := AVel;
  FDroneCurso := ACurso;
  FDroneSatelites := ASatelites;
  FDroneFix := AFix;
  FDroneTemPosicao := AValido and (Abs(ALat) > 0.0001) and (Abs(ALon) > 0.0001);

  AtualizaUI;
end;

procedure TfrmGPS.FormCreate(Sender: TObject);
begin
  Caption := 'GPS - Central (Base) e Drone (Telemetria)';

  GPSSignalPlot1.NMEADecode := NMEADecode1;
  GPSSkyPlot1.NMEADecode := NMEADecode1;
  GPSTarget1.NMEADecode := NMEADecode1;

  FBuffer := '';
  FLatitude := 0;
  FLongitude := 0;
  FAltitude := 0;
  FVelocidade := 0;
  FCurso := 0;
  FHDOP := 0;
  FVDOP := 0;
  FPDOP := 0;
  FSatelites := 0;
  FFixQuality := 0;
  FFixStatus := 0;
  FModoFix := '';
  FDataUTC := '';
  FHoraUTC := '';
  FTemPosicao := False;
  FTemAltitude := False;

  FDroneLat := 0;
  FDroneLon := 0;
  FDroneAlt := 0;
  FDroneVel := 0;
  FDroneCurso := 0;
  FDroneSatelites := 0;
  FDroneFix := 0;
  FDroneTemPosicao := False;
  FDistanciaDroneCentral := 0;
  FAzimuteDroneCentral := 0;

  CriaControlesLocalizacao;
  AtualizaUI;
end;

procedure TfrmGPS.FormShow(Sender: TObject);
begin
  AbrirGPS;
end;

procedure TfrmGPS.FormHide(Sender: TObject);
begin
  FecharGPS;
end;

procedure TfrmGPS.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  FecharGPS;
  CloseAction := caHide;
end;

procedure TfrmGPS.GPSPortConnected1Show(Sender: TObject);
begin
  Log('GPS PORT: Connected');
end;

procedure TfrmGPS.GPSSignalPlot1Click(Sender: TObject);
begin
end;

procedure TfrmGPS.NMEADecode1NMEA(Sender: TObject; NMEA: TNMEADecode);
var
  dLat, dLong, dSpeed: Double;
begin
  case NMEA.MessageType of
    GGAMsg:
      begin
        with NMEA.GGA do
        begin
          if SafeStrToFloat(LatitudeDegree, dLat) then
          begin
          end;

          if SafeStrToFloat(LongitudeDegree, dLong) then
          begin
          end;
        end;
      end;

    GSAMsg:
      begin
      end;

    RMCMsg:
      begin
        with NMEA.RMC do
        begin
          if SafeStrToFloat(LatitudeDegree, dLat) then
          begin
          end;

          if SafeStrToFloat(LongitudeDegree, dLong) then
          begin
          end;

          if SafeStrToFloat(Speed, dSpeed) then
          begin
          end;
        end;
      end;

    WPLMsg:
      begin
      end;

    GLLMsg:
      begin
        with NMEA.GLL do
        begin
          if SafeStrToFloat(LatitudeDegree, dLat) then
            lblGLLLat.Caption := Format('%9.6f', [Abs(dLat)]) + ' (' + LatHemis + ')'
          else
            lblGLLLat.Caption := '';

          if SafeStrToFloat(LongitudeDegree, dLong) then
            lblGLLLong.Caption := Format('%9.6f', [Abs(dLong)]) + ' (' + LongHemis + ')'
          else
            lblGLLLong.Caption := '';

          lblGLLTime.Caption := UTCTime;
        end;
      end;

    PGRMMsg:
      begin
      end;

    PGRMZMsg:
      begin
      end;

    PGRMEMsg:
      begin
      end;
  end;

  Atualiza;
end;

procedure TfrmGPS.SdpoSerial1RxData(Sender: TObject);
var
  InString: string;
begin
  try
    InString := SdpoSerial1.ReadData;

    if InString = '' then
      Exit;

    FBuffer := FBuffer + InString;
    ProcessaBufferNMEA;

  except
    on E: Exception do
      Log('Erro RxData: ' + E.Message);
  end;
end;

end.
