unit rotamavlink;

{ Converte o plano de voo (flightplan) em itens de missão MAVLink.

  Sequência gerada:
    [ArduPilot] 0  ponto de partida (o drone substitui pela posição real)
                   decolagem vertical até a altitude de decolagem
                   para cada ponto: mudança de velocidade (se mudou) + ponto
                   ação final: voltar à partida (RTL), pousar ou pairar no
                   último ponto
  Altitudes relativas ao ponto de partida. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math, flightplan, mavlinkproto;

function MontaMissao(APlano: TFlightPlan; AArduPilot: Boolean): TMavMissao;
{ Item da missão que corresponde ao ponto AIndice da rota (-1 se não houver). }
function ItemDoPonto(const AMissao: TMavMissao; AIndice: Integer): Integer;
{ Atualiza o estado (PENDING/ACTIVE/COMPLETED) dos pontos pelo item em execução. }
procedure AtualizaEstadoPontos(APlano: TFlightPlan; const AMissao: TMavMissao;
  AItemAtual: Integer);
function DescreveItem(const AItem: TMavItemMissao): string;

implementation

const
  RAIO_ACEITACAO = 2.0; // m

function Item(ACmd: Word; AFrame: Byte; P1, P2, P3, P4: Single;
  ALat, ALon: Double; AAlt: Single; APonto: Integer): TMavItemMissao;
begin
  Result.Comando := ACmd;
  Result.Frame := AFrame;
  Result.P1 := P1;
  Result.P2 := P2;
  Result.P3 := P3;
  Result.P4 := P4;
  Result.X := Round(ALat * 1e7);
  Result.Y := Round(ALon * 1e7);
  Result.Z := AAlt;
  Result.Ponto := APonto;
end;

procedure Adiciona(var M: TMavMissao; const AItem: TMavItemMissao);
begin
  SetLength(M, Length(M) + 1);
  M[High(M)] := AItem;
end;

function MontaMissao(APlano: TFlightPlan; AArduPilot: Boolean): TMavMissao;
var
  I: Integer;
  W, U: TWaypoint;
  Vel: Double;
begin
  Result := nil;
  if (APlano.WaypointCount = 0) or not APlano.HomeValido then
    Exit;

  if AArduPilot then
    Adiciona(Result, Item(MAV_CMD_NAV_WAYPOINT, MAV_FRAME_GLOBAL, 0, 0, 0, 0,
      APlano.HomeLat, APlano.HomeLon, 0, -1));

  // Decolagem vertical sobre o ponto de partida (guinada: mantém a atual).
  Adiciona(Result, Item(MAV_CMD_NAV_TAKEOFF, MAV_FRAME_GLOBAL_RELATIVE_ALT, 0, 0, 0, NaN,
    APlano.HomeLat, APlano.HomeLon, APlano.AltitudeDecolagem, -1));

  Vel := -1;
  for I := 0 to APlano.WaypointCount - 1 do
  begin
    W := APlano[I];
    if Abs(W.Speed - Vel) > 0.01 then
    begin
      // velocidade em relação ao solo; -1 = não muda a aceleração
      Adiciona(Result, Item(MAV_CMD_DO_CHANGE_SPEED, MAV_FRAME_MISSION, 1, W.Speed, -1, 0,
        0, 0, 0, -1));
      Vel := W.Speed;
    end;
    Adiciona(Result, Item(MAV_CMD_NAV_WAYPOINT, MAV_FRAME_GLOBAL_RELATIVE_ALT, 0,
      RAIO_ACEITACAO, 0, NaN, W.Latitude, W.Longitude, W.Altitude, I));
  end;

  U := APlano[APlano.WaypointCount - 1];
  case APlano.AcaoFinal of
    afVoltarPartida:
      Adiciona(Result, Item(MAV_CMD_NAV_RETURN_TO_LAUNCH, MAV_FRAME_MISSION, 0, 0, 0, 0,
        0, 0, 0, -1));
    afPousarUltimo:
      Adiciona(Result, Item(MAV_CMD_NAV_LAND, MAV_FRAME_GLOBAL_RELATIVE_ALT, 0, 0, 0, NaN,
        U.Latitude, U.Longitude, 0, -1));
    afPairarUltimo:
      Adiciona(Result, Item(MAV_CMD_NAV_LOITER_UNLIM, MAV_FRAME_GLOBAL_RELATIVE_ALT, 0, 0, 0, NaN,
        U.Latitude, U.Longitude, U.Altitude, -1));
  end;
end;

function ItemDoPonto(const AMissao: TMavMissao; AIndice: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to High(AMissao) do
    if AMissao[I].Ponto = AIndice then
      Exit(I);
  Result := -1;
end;

procedure AtualizaEstadoPontos(APlano: TFlightPlan; const AMissao: TMavMissao;
  AItemAtual: Integer);
var
  I, Seq: Integer;
begin
  if (AItemAtual < 0) or (Length(AMissao) = 0) then
    Exit;
  for I := 0 to APlano.WaypointCount - 1 do
  begin
    Seq := ItemDoPonto(AMissao, I);
    if Seq < 0 then
      Continue;
    if Seq < AItemAtual then
      APlano[I].Status := 'COMPLETED'
    else if Seq = AItemAtual then
      APlano[I].Status := 'ACTIVE'
    else
      APlano[I].Status := 'PENDING';
  end;
  APlano.CurrentIndex := -1;
end;

function DescreveItem(const AItem: TMavItemMissao): string;
begin
  case AItem.Comando of
    MAV_CMD_NAV_WAYPOINT:
      if AItem.Ponto >= 0 then
        Result := Format('Ponto %d (%.6f, %.6f) a %.1f m',
          [AItem.Ponto + 1, AItem.X / 1e7, AItem.Y / 1e7, AItem.Z])
      else
        Result := Format('Partida (%.6f, %.6f)', [AItem.X / 1e7, AItem.Y / 1e7]);
    MAV_CMD_NAV_TAKEOFF: Result := Format('Decolar até %.1f m', [AItem.Z]);
    MAV_CMD_DO_CHANGE_SPEED: Result := Format('Velocidade %.1f m/s', [AItem.P2]);
    MAV_CMD_NAV_RETURN_TO_LAUNCH: Result := 'Voltar ao ponto de partida e pousar';
    MAV_CMD_NAV_LAND: Result := 'Pousar no último ponto';
    MAV_CMD_NAV_LOITER_UNLIM: Result := 'Pairar no último ponto';
  else
    Result := 'Comando ' + IntToStr(AItem.Comando);
  end;
end;

end.
