program test_simulator_bridge;

{$mode objfpc}{$H+}

uses SysUtils, Math, simulator_vehicle_core, simulator_protocol_bridge;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

var
  Vehicle: TSimulatorVehicle;
  Bridge: TSimulatorProtocolBridge;
  C: TVehicleControls;
  InitialLat: Double;
begin
  Vehicle := TSimulatorVehicle.Create(vkMultirotor, -21.17, -47.81, 600);
  Bridge := TSimulatorProtocolBridge.Create(Vehicle, 0.5);
  try
    InitialLat := Vehicle.State.Latitude;
    Bridge.ApplyCommand('{"throttle":0.7,"turn":0,"climb":0.5,"brake":0,"roll":0,"pitch":0}');
    Bridge.Step(0.1);
    Check(Vehicle.State.SpeedMps > 0, 'Throttle must accelerate the simulator');
    Check(Vehicle.State.AltitudeM > 600, 'Climb must increase altitude');
    Check(Vehicle.State.Latitude <> InitialLat, 'Movement must update coordinates');
    Check(Pos('"battery_pct"', Bridge.TelemetryJSON) > 0, 'Telemetry must include battery');
    Bridge.Step(0.5);
    C := Vehicle.Controls;
    Check(C.Throttle = 0, 'Control timeout must zero throttle');
    Check(C.Climb = 0, 'Control timeout must zero climb');
    Check(C.Turn = 0, 'Control timeout must zero turn');
    WriteLn('Simulator physics, telemetry and timeout: PASS');
  finally
    Bridge.Free;
    Vehicle.Free;
  end;
end.
