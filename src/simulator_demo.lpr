program simulator_demo;

{$mode objfpc}{$H+}

uses
  SysUtils, simulator_vehicle_core, simulator_runtime, simulator_protocol_bridge;

var
  Sim: TSimulatorRuntime;
  Controls: TVehicleControls;
  State: TVehicleState;
  I: Integer;
  URL: string;
  Bridge: TSimulatorProtocolBridge;
begin
  URL := '';
  if ParamCount > 0 then URL := ParamStr(1);
  Sim := TSimulatorRuntime.Create(vkMultirotor, URL, -21.17, -47.81, 600);
  Bridge := TSimulatorProtocolBridge.Create(Sim.Vehicle);
  try
    Controls.Throttle := 0.5;
    Controls.Turn := 0.05;
    Controls.Climb := 0.1;
    // Demo controls pass through the same normalized bridge as protocol adapters.
    Bridge.ApplyCommand('{"throttle":0.5,"turn":0.05,"climb":0.1,"brake":0,"roll":0,"pitch":0}');
    if URL <> '' then
      try
        Sim.Connect;
        WriteLn('Multiplayer connected');
      except
        on E: Exception do WriteLn('Offline mode: ', E.Message);
      end;
    for I := 1 to 100 do
    begin
      if (I mod 4) = 0 then
        Bridge.ApplyCommand('{"throttle":0.5,"turn":0.05,"climb":0.1,"brake":0,"roll":0,"pitch":0}');
      Bridge.Step(0.1);
      if (I mod 10) = 0 then
      begin
        State := Sim.Vehicle.State;
        WriteLn(Format('t=%.1f lat=%.6f lon=%.6f alt=%.1f speed=%.1f battery=%.2f online=%s',
          [State.SimTimeS, State.Latitude, State.Longitude,
           State.AltitudeM, State.SpeedMps, State.BatteryPct,
           BoolToStr(Sim.Online, True)]));
      end;
      Sleep(100);
    end;
    if Sim.Online then Sim.Disconnect;
  finally
    Bridge.Free;
    Sim.Free;
  end;
end.
