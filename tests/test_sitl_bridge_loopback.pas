program test_sitl_bridge_loopback;
{$mode objfpc}{$H+}
uses SysUtils, sitl_telemetry_bridge, sitl_telemetry_state;
function Run: Integer;
var Bridge: TSitlTelemetryBridge; Started: QWord; Seen: Boolean; Port: Integer;
begin
  if (ParamCount <> 3) or not TryStrToInt(ParamStr(3), Port) then Exit(2);
  Bridge := TSitlTelemetryBridge.Create;
  try
    if not Bridge.Start(ParamStr(1), ParamStr(2), Port) then
    begin WriteLn(StdErr, Bridge.LastError); Exit(3); end;
    WriteLn('READY'); Flush(Output);
    Seen := False;
    Started := GetTickCount64;
    while GetTickCount64 - Started < 12000 do
    begin
      Bridge.Poll(GetTickCount64);
      if Bridge.State.Connected and not Seen then
      begin
        if (Bridge.State.SystemId <> 37) or (Bridge.State.ComponentId <> 1) or
           (Bridge.State.VehicleClass <> 'multirotor') or
           (Bridge.State.CustomMode <> High(Cardinal)) or
           not Bridge.State.ArmedReported then Exit(4);
        Seen := True;
        WriteLn('CONNECTED'); Flush(Output);
      end;
      if Seen and not Bridge.State.Connected then
      begin
        if (Bridge.State.SystemId <> 0) or (Bridge.State.ComponentId <> 0) or
           (Bridge.State.CustomMode <> 0) or Bridge.State.ArmedReported then Exit(5);
        Bridge.Stop;
        Bridge.Stop;
        if Bridge.IsRunning then Exit(6);
        WriteLn('PASS: Python MAVLink UDP -> Pascal bridge -> heartbeat expiry');
        Exit(0);
      end;
      if not Bridge.IsRunning then
      begin WriteLn(StdErr, Bridge.LastError); Exit(7); end;
      Sleep(20);
    end;
    WriteLn(StdErr, 'Timed out waiting for loopback telemetry/expiry');
    Exit(8);
  finally
    Bridge.Free;
  end;
end;
begin Halt(Run); end.
