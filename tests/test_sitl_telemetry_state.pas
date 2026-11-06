program test_sitl_telemetry_state;

{$mode objfpc}{$H+}

uses
  SysUtils, sitl_telemetry_state;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  State: TSitlTelemetry;
  Err: string;
begin
  ResetSitlTelemetry(State);
  Check(not State.Connected, 'initial state must be disconnected');
  Check(not ApplySitlEvent('not json', State, 100, Err),
    'malformed JSON must be rejected');
  Check(not State.Connected, 'invalid JSON must not connect');

  Check(ApplySitlEvent(
    '{"event":"heartbeat","system_id":1,"component_id":1,' +
    '"vehicle_class":"boat","custom_mode":3,"armed_reported":true}',
    State, 1000, Err), 'valid heartbeat rejected: ' + Err);
  Check(State.Connected, 'heartbeat must connect');
  Check(State.VehicleClass = 'boat', 'wrong vehicle class');
  Check(State.ArmedReported, 'reported armed state missing');
  Check(State.CustomMode = 3, 'wrong custom mode');

  Check(not ApplySitlEvent(
    '{"event":"heartbeat","system_id":0,"component_id":1,' +
    '"vehicle_class":"boat"}', State, 1200, Err),
    'invalid system id accepted');
  Check(State.SystemId = 1, 'invalid packet changed state');

  Check(not ApplySitlEvent(
    '{"event":"heartbeat","system_id":"1","component_id":1,' +
    '"vehicle_class":"boat"}', State, 1300, Err),
    'string system id must be rejected');
  Check(not ApplySitlEvent(
    '{"event":"heartbeat","system_id":1,"component_id":1,' +
    '"vehicle_class":12}', State, 1400, Err),
    'numeric vehicle class must be rejected');
  Check(State.LastHeartbeatMs = 1000,
    'invalid field types must not refresh heartbeat');

  Check(not ApplySitlEvent(
    '{"event":"heartbeat","system_id":1,"component_id":1,' +
    '"vehicle_class":"boat","armed_reported":"true"}',
    State, 1500, Err), 'string armed state must be rejected');
  Check(not ApplySitlEvent(
    '{"event":"heartbeat","system_id":1,"component_id":1,' +
    '"vehicle_class":"boat","custom_mode":"3"}',
    State, 1600, Err), 'string custom mode must be rejected');
  Check(State.LastHeartbeatMs = 1000,
    'malformed optional fields must not refresh heartbeat');

  ExpireSitlTelemetry(State, 3999, 3000);
  Check(State.Connected, 'heartbeat expired too early');
  ExpireSitlTelemetry(State, 4001, 3000);
  Check(not State.Connected, 'stale heartbeat remained connected');
  Check(not State.ArmedReported, 'timeout must clear armed report');

  Check(ApplySitlEvent(
    '{"event":"heartbeat","system_id":2,"component_id":1,' +
    '"vehicle_class":"multirotor"}', State, 5000, Err),
    'second heartbeat rejected');
  Check(not State.ArmedReported,
    'missing armed_reported must not inherit old armed state');
  Check(State.CustomMode = 0,
    'missing custom_mode must not inherit old mode');
  Check(ApplySitlEvent('{"event":"heartbeat_timeout"}',
    State, 5001, Err), 'timeout event rejected');
  Check(not State.Connected, 'timeout event must disconnect');
  WriteLn('SITL telemetry state tests passed');
end.
