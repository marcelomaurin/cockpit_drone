program test_multiplayer_state;
{$mode objfpc}{$H+}
uses SysUtils, fpjson, jsonparser, multiplayer_state, cockpit_multiplayer;
var D: TJSONData; P: TParticipants;
procedure Check(const S: string; Count: Integer);
begin
  D := GetJSON(S);
  try P := ParseParticipants(D); if Length(P) <> Count then Halt(1);
  finally D.Free end;
end;
begin
  Check('{"participants":[{"id":"a","distance_m":1999,"telemetry":{"lat":0,"lon":0,"altitude_m":10}}]}',1);
  Check('{"participants":[{"id":"a","distance_m":2000,"telemetry":{"lat":0,"lon":0,"altitude_m":10}}]}',1);
  Check('{"participants":[{"id":"a","distance_m":2001,"telemetry":{"lat":0,"lon":0,"altitude_m":10}}]}',0);
  Check('{"participants":[{"id":"a","distance_m":10,"telemetry":{"lat":91,"lon":0,"altitude_m":10}}]}',0);
  Check('{"participants":[{"id":"a","distance_m":10,"telemetry":{}}]}',0);
  Check('{"participants":[]}',0);
  try Check('{}',0); Halt(2); except on E:EConvertError do end;
  WriteLn('PASS: radius boundaries, coordinates, malformed records, empty snapshot');
end.
