unit rotamavlink;

{ Liga o plano de voo do cockpit (flightplan) à missão MAVLink do componente
  TAIDroneMavlink (CHATGPT, pacote openai_drone).

  A montagem da missão (partida no ArduPilot, decolagem, velocidade por
  trecho, pontos e ação final) fica no componente: TAIDroneMavlink.BuildMission.
  Aqui só se converte o plano e se atualiza o estado dos pontos. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, flightplan, aidronemavlink;

function MontaMissao(APlano: TFlightPlan; AArduPilot: Boolean): TAIMavMission;
{ Atualiza o estado (PENDING/ACTIVE/COMPLETED) dos pontos pelo item em execução. }
procedure AtualizaEstadoPontos(APlano: TFlightPlan; const AMissao: TAIMavMission;
  AItemAtual: Integer);

implementation

function MontaMissao(APlano: TFlightPlan; AArduPilot: Boolean): TAIMavMission;
var
  Pontos: array of TAIMavWaypoint;
  Acao: TAIMavFinalAction;
  I: Integer;
begin
  Result := nil;
  if (APlano.WaypointCount = 0) or not APlano.HomeValido then
    Exit;
  Pontos := nil;
  SetLength(Pontos, APlano.WaypointCount);
  for I := 0 to APlano.WaypointCount - 1 do
  begin
    Pontos[I].Lat := APlano[I].Latitude;
    Pontos[I].Lon := APlano[I].Longitude;
    Pontos[I].Alt := APlano[I].Altitude;
    Pontos[I].Speed := APlano[I].Speed;
  end;
  case APlano.AcaoFinal of
    afPousarUltimo: Acao := mfaLandAtLast;
    afPairarUltimo: Acao := mfaHoverAtLast;
  else
    Acao := mfaReturnToLaunch;
  end;
  Result := TAIDroneMavlink.BuildMission(Pontos, APlano.AltitudeDecolagem, Acao,
    APlano.HomeLat, APlano.HomeLon, AArduPilot);
end;

procedure AtualizaEstadoPontos(APlano: TFlightPlan; const AMissao: TAIMavMission;
  AItemAtual: Integer);
var
  I, Seq: Integer;
begin
  if (AItemAtual < 0) or (Length(AMissao) = 0) then
    Exit;
  for I := 0 to APlano.WaypointCount - 1 do
  begin
    Seq := TAIDroneMavlink.ItemOfWaypoint(AMissao, I);
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

end.
