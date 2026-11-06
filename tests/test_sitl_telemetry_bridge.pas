program test_sitl_telemetry_bridge;

{$mode objfpc}{$H+}

uses
  SysUtils, sitl_telemetry_bridge, sitl_telemetry_state;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  Bridge: TSitlTelemetryBridge;
begin
  Bridge := TSitlTelemetryBridge.Create;
  try
    Check(not Bridge.IsRunning, 'bridge must start stopped');
    Check(not Bridge.Start('python3', '__missing_sitl_monitor__.py'),
      'nonexistent monitor must be rejected');
    Check(not Bridge.IsRunning, 'failed start must not leave running process');
    Check(Bridge.LastError <> '', 'failed start must explain error');
    Bridge.Poll(1000);
    Check(not Bridge.State.Connected, 'failed start must remain disconnected');
    Bridge.Stop;
    Check(not Bridge.IsRunning, 'stop must be idempotent');
    Bridge.Stop;
  finally
    Bridge.Free;
  end;
  WriteLn('SITL bridge lifecycle tests passed');
end.
