program test_multiplayer_http;
{$mode objfpc}{$H+}
uses Classes, SysUtils, cockpit_multiplayer, multiplayer_state;
var C: TCockpitMultiplayer; P: TParticipants; S: string; I: Integer;
    Seen, Cleared, Reconnected: Boolean;
begin
  Seen := False; Cleared := False; Reconnected := False;
  C := TCockpitMultiplayer.Create(ParamStr(1));
  try
    for I := 1 to 100 do
    begin
      C.SetPosition(-21.17, -47.81, 10, True);
      Sleep(100);
      C.Snapshot(P,S);
      if Length(P)>0 then begin
        if Cleared then Reconnected := True;
        Seen := True;
      end else if Seen then Cleared := True;
      if Reconnected then Break;
    end;
    if not (Seen and Cleared and Reconnected) then
      raise Exception.Create('Lifecycle failed: '+S);
    C.SetPosition(0,0,0,False);
    Sleep(800);
    C.Snapshot(P,S);
    if Length(P)<>0 then raise Exception.Create('Stale participants');
  finally C.Free end;
  WriteLn('PASS: HTTP polling, 401 reconnect, clear stale participants, disconnect');
end.
