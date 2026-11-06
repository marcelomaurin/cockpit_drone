unit mavlink_vehicle_adapter;

{ Adaptador de validacao para integracao MAVLink.
  Sem transporte, serializacao, armamento ou comandos ao equipamento. }

{$mode objfpc}{$H+}

interface

uses SysUtils, vehicle_control_contract;

type
  TMavlinkAdapterState = record
    VehicleClass: TVehicleClass;
    HeartbeatFresh: Boolean;
    ModeApproved: Boolean;
    AutopilotArmed: Boolean;
    InputFresh: Boolean;
    SimulatorOnly: Boolean;
  end;

function ValidateMavlinkDispatch(const Cmd: TVehicleCommand;
  const State: TMavlinkAdapterState; out Reason: string): Boolean;

implementation

function ValidateMavlinkDispatch(const Cmd: TVehicleCommand;
  const State: TMavlinkAdapterState; out Reason: string): Boolean;
begin
  Result := False;
  if not ValidateCommand(Cmd, Reason) then Exit;
  if Cmd.VehicleClass <> State.VehicleClass then
  begin
    Reason := 'Classe do comando difere da classe do autopiloto';
    Exit;
  end;
  if not State.SimulatorOnly then
  begin
    Reason := 'Transporte fisico desabilitado nesta etapa';
    Exit;
  end;
  if not State.HeartbeatFresh then
  begin
    Reason := 'Heartbeat ausente ou obsoleto';
    Exit;
  end;
  if not State.InputFresh then
  begin
    Reason := 'Entrada de controle obsoleta';
    Exit;
  end;
  if not State.ModeApproved then
  begin
    Reason := 'Modo do autopiloto nao aprovado';
    Exit;
  end;
  if Cmd.Armed <> State.AutopilotArmed then
  begin
    Reason := 'Armamento nao confirmado pela telemetria';
    Exit;
  end;
  Reason := '';
  Result := True;
end;

end.
