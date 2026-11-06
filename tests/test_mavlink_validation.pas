program test_mavlink_validation;

{$mode objfpc}{$H+}

uses
  SysUtils, vehicle_control_contract, mavlink_vehicle_adapter;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn(StdErr, 'FAIL: ', AMessage);
    Halt(1);
  end;
end;

var
  Cmd: TVehicleCommand;
  State: TMavlinkAdapterState;
  Reason: string;
begin
  NeutralCommand(Cmd, vcBoat);
  State := Default(TMavlinkAdapterState);
  State.VehicleClass := vcBoat;
  State.SimulatorOnly := True;
  State.HeartbeatFresh := True;
  State.InputFresh := True;
  State.ModeApproved := True;
  State.AutopilotArmed := False;

  Check(ValidateMavlinkDispatch(Cmd, State, Reason), 'neutral simulated boat should pass');

  State.SimulatorOnly := False;
  Check(not ValidateMavlinkDispatch(Cmd, State, Reason), 'physical transport must be blocked');
  State.SimulatorOnly := True;

  State.HeartbeatFresh := False;
  Check(not ValidateMavlinkDispatch(Cmd, State, Reason), 'stale heartbeat must fail');
  State.HeartbeatFresh := True;

  State.InputFresh := False;
  Check(not ValidateMavlinkDispatch(Cmd, State, Reason), 'stale input must fail');
  State.InputFresh := True;

  State.ModeApproved := False;
  Check(not ValidateMavlinkDispatch(Cmd, State, Reason), 'unapproved mode must fail');
  State.ModeApproved := True;

  State.VehicleClass := vcFixedWing;
  Check(not ValidateMavlinkDispatch(Cmd, State, Reason), 'vehicle mismatch must fail');
  State.VehicleClass := vcBoat;

  Cmd.Values[vaForward] := 0.5;
  Check(not ValidateMavlinkDispatch(Cmd, State, Reason), 'disarmed motion must fail');
  Cmd.Values[vaForward] := 0;

  Cmd.Enabled := Cmd.Enabled + [vaCollective];
  Check(not ValidateMavlinkDispatch(Cmd, State, Reason), 'invalid axis must fail');

  WriteLn('PASS: MAVLink validation behavioral checks');
end.
