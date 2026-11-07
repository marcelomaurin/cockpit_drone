program test_multiplayer_ws;
{$mode objfpc}{$H+}
uses Classes, SysUtils, cockpit_multiplayer, multiplayer_state;
var C: TCockpitMultiplayer; P: TParticipants; S: string; I: Integer;
    Seen, Cleared, Restored: Boolean;
begin
  Seen := False; Cleared := False; Restored := False;
  C := TCockpitMultiplayer.Create(ParamStr(1));
  try
    for I := 1 to 250 do
    begin
      C.SetPosition(-21.17,-47.81,10,True); Sleep(100); C.Snapshot(P,S);
      if Length(P)>0 then begin
        if not Seen then begin WriteLn('SEEN'); Flush(Output) end;
        if Cleared then begin Restored := True; Break end;
        Seen := True;
      end else if Seen and not Cleared then begin
        Cleared := True; WriteLn('CLEARED'); Flush(Output);
      end;
    end;
    if not Restored then raise Exception.Create('WebSocket lifecycle failed: '+S);
    C.SetPosition(0,0,0,False); Sleep(700); C.Snapshot(P,S);
    if Length(P)<>0 then raise Exception.Create('Stale participants');
  finally C.Free end;
  WriteLn('PASS: native WebSocket snapshot, clear, restore and shutdown');
end.
