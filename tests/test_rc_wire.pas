program test_rc_wire;
{$mode objfpc}{$H+}
uses SysUtils,Math,rc_wire_protocol,vehicle_rc_profile,cockpit_binary_link;
procedure Check(B:Boolean;const S:string);begin if not B then raise Exception.Create(S);end;
var P:TRCWireProtocol;C,D:TRCChannels;B:TBytes;I:Integer;V,W:TWiFi8KVariant;Cmd,Decoded:TWiFi8KCommand;
 S:TRCSettings;Vehicle:TVehicleClass;
begin
 for P:=Low(P) to High(P) do begin
  for I:=0 to 15 do C[I]:=1000+((I*137) mod 1001);
  B:=EncodeRC(P,C);Check(DecodeRC(P,B,D),'decode '+RCKeys[P]);
  for I:=0 to RCChannelCount(P)-1 do Check(Abs(Integer(D[I])-C[I])<=1,'channel range/packing');
  SetLength(B,Length(B)-1);Check(not DecodeRC(P,B,D),'truncation must fail');
  B:=EncodeRC(P,C);
  if P=rcSBUS then B[23]:=8 else B[High(B)]:=B[High(B)] xor 1;
  Check(not DecodeRC(P,B,D),'checksum/failsafe must fail');
 end;
 C:=Default(TRCChannels);for I:=0 to 15 do C[I]:=1500;
 B:=EncodeRC(rcIBUS,C);Check((B[0]=$20) and (B[1]=$40) and (B[2]=$DC) and (B[3]=$05),'iBUS known channel 1500 vector');
 for V:=Low(V) to High(V) do begin
  Cmd:=WiFi8KNeutral;Cmd.Flags:=1;B:=EncodeWiFi8K(V,Cmd);Check(DecodeWiFi8K(B,W,Decoded) and (V=W),'Wi-Fi variant roundtrip');
  if V=w8Legacy9 then Check((Length(B)=9) and (B[7]=1),'legacy XOR includes flag')
  else Check((Length(B)=8) and (B[6]=0),'E58 XOR excludes flag');
  B[High(B)-1]:=B[High(B)-1] xor 1;Check(not DecodeWiFi8K(B,W,Decoded),'Wi-Fi checksum rejection');
 end;
 for Vehicle:=Low(Vehicle) to High(Vehicle) do for P:=Low(P) to High(P) do begin
  S:=DefaultRCSettings(P,Vehicle);MapRCChannels(S,1,-1,0,1,False,C);
  if Vehicle in [vcCar,vcBoat,vcSubmarine] then Check(C[S.Axis[3]-1]=1500,'bidirectional idle')
  else Check(C[S.Axis[3]-1]=1000,'aircraft disarmed throttle');
  MapRCChannels(S,1,-1,0,1,True,C);Check(C[S.ArmChannel-1]=2000,'arm channel');
  Check(DecodeRC(P,EncodeRC(P,C),D),'all vehicle/protocol combinations');
 end;
 WriteLn('PASS 5 RC formats, CRC/checksums, channel packing, failsafe, 2 WIFI variants and 30 vehicle/protocol mappings');
end.
