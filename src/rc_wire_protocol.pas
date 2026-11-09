unit rc_wire_protocol;
{$mode objfpc}{$H+}
interface
uses SysUtils,Math;
type
 TRCWireProtocol=(rcMSP1,rcMSP2,rcCRSF,rcSBUS,rcIBUS);
 TRCChannels=array[0..15] of Word;
 TWiFi8KVariant=(w8Legacy9,w8E58_8);
 TWiFi8KCommand=record Roll,Pitch,Throttle,Yaw,Flags:Byte;end;
const W8_TAKEOFF=1;W8_LAND=2;W8_CUT=4;W8_GYRO=128;
function EncodeRC(Protocol:TRCWireProtocol;const Channels:TRCChannels;Address:Byte=$C8):TBytes;
function DecodeRC(Protocol:TRCWireProtocol;const Packet:TBytes;out Channels:TRCChannels):Boolean;
function RCChannelCount(Protocol:TRCWireProtocol):Integer;
function CRC8D5(const B:TBytes;First,Count:Integer):Byte;
function EncodeWiFi8K(Variant:TWiFi8KVariant;const C:TWiFi8KCommand):TBytes;
function DecodeWiFi8K(const B:TBytes;out Variant:TWiFi8KVariant;out C:TWiFi8KCommand):Boolean;
function WiFi8KNeutral:TWiFi8KCommand;
function AxisByte(Value:Double):Byte;
function ChannelAxis(Value:Word):Double;
implementation
function RCChannelCount(Protocol:TRCWireProtocol):Integer;
begin case Protocol of rcMSP1:Result:=8;rcIBUS:Result:=14;else Result:=16;end;end;
function CRC8D5(const B:TBytes;First,Count:Integer):Byte;
var I,J:Integer;C:LongWord;
begin
 C:=0;for I:=First to First+Count-1 do begin C:=C xor B[I];
  for J:=1 to 8 do if (C and $80)<>0 then C:=((C shl 1) xor $D5) and $FF else C:=(C shl 1) and $FF;
 end;Result:=C;
end;
procedure Put16(var B:TBytes;P:Integer;V:Word);
begin B[P]:=V and 255;B[P+1]:=V shr 8;end;
function Get16(const B:TBytes;P:Integer):Word;
begin Result:=Word(B[P]) or (Word(B[P+1]) shl 8);end;
procedure Pack11(const C:TRCChannels;var B:TBytes;Start:Integer);
var I,P,Bits:Integer;Acc,V:LongWord;
begin
 Acc:=0;Bits:=0;P:=Start;
 for I:=0 to 15 do begin V:=172+Round((C[I]-1000)*1639/1000);Acc:=Acc or (V shl Bits);Bits:=Bits+11;
  while Bits>=8 do begin B[P]:=Acc and 255;Inc(P);Acc:=Acc shr 8;Dec(Bits,8);end;
 end;
end;
procedure Unpack11(const B:TBytes;Start:Integer;out C:TRCChannels);
var I,P,Bits:Integer;Acc,V:LongWord;
begin
 Acc:=0;Bits:=0;P:=Start;
 for I:=0 to 15 do begin
  while Bits<11 do begin Acc:=Acc or (LongWord(B[P]) shl Bits);Inc(P);Bits:=Bits+8;end;
  V:=Acc and $7FF;Acc:=Acc shr 11;Dec(Bits,11);
  C[I]:=EnsureRange(1000+Round((Integer(V)-172)*1000/1639),1000,2000);
 end;
end;
function EncodeRC(Protocol:TRCWireProtocol;const Channels:TRCChannels;Address:Byte):TBytes;
var I,N:Integer;CS:LongWord;
begin
 for I:=0 to 15 do if (Channels[I]<1000) or (Channels[I]>2000) then raise EArgumentException.Create('RC channel outside 1000..2000 us');
 Result:=nil;N:=RCChannelCount(Protocol);
 case Protocol of
 rcMSP1:begin SetLength(Result,6+N*2);Result[0]:=Ord('$');Result[1]:=Ord('M');Result[2]:=Ord('<');
  Result[3]:=N*2;Result[4]:=200;for I:=0 to N-1 do Put16(Result,5+I*2,Channels[I]);
  CS:=0;for I:=3 to High(Result)-1 do CS:=CS xor Result[I];Result[High(Result)]:=CS;end;
 rcMSP2:begin SetLength(Result,9+N*2);Result[0]:=Ord('$');Result[1]:=Ord('X');Result[2]:=Ord('<');
  Result[3]:=0;Put16(Result,4,200);Put16(Result,6,N*2);for I:=0 to N-1 do Put16(Result,8+I*2,Channels[I]);
  Result[High(Result)]:=CRC8D5(Result,3,Length(Result)-4);end;
 rcCRSF:begin SetLength(Result,26);Result[0]:=Address;Result[1]:=24;Result[2]:=$16;Pack11(Channels,Result,3);
  Result[25]:=CRC8D5(Result,2,23);end;
 rcSBUS:begin SetLength(Result,25);Result[0]:=$0F;Pack11(Channels,Result,1);Result[23]:=0;Result[24]:=0;end;
 rcIBUS:begin SetLength(Result,32);Result[0]:=$20;Result[1]:=$40;for I:=0 to 13 do Put16(Result,2+I*2,Channels[I]);
  CS:=$FFFF;for I:=0 to 29 do CS:=CS-Result[I];Put16(Result,30,CS);end;
 end;
end;
function DecodeRC(Protocol:TRCWireProtocol;const Packet:TBytes;out Channels:TRCChannels):Boolean;
var I,N,Offset:Integer;CS:LongWord;
begin
 Result:=False;for I:=0 to 15 do Channels[I]:=1500;N:=RCChannelCount(Protocol);Offset:=0;
 case Protocol of
 rcMSP1:begin if Length(Packet)<>6+N*2 then Exit;
  if (Packet[0]<>Ord('$')) or (Packet[1]<>Ord('M')) or (Packet[2]<>Ord('<')) or (Packet[3]<>N*2) or (Packet[4]<>200) then Exit;
  CS:=0;for I:=3 to High(Packet)-1 do CS:=CS xor Packet[I];if CS<>Packet[High(Packet)] then Exit;Offset:=5;end;
 rcMSP2:begin if Length(Packet)<>9+N*2 then Exit;
  if (Packet[0]<>Ord('$')) or (Packet[1]<>Ord('X')) or (Packet[2]<>Ord('<')) or (Get16(Packet,4)<>200) or (Get16(Packet,6)<>N*2) then Exit;
  if CRC8D5(Packet,3,Length(Packet)-4)<>Packet[High(Packet)] then Exit;Offset:=8;end;
 rcCRSF:begin if Length(Packet)<>26 then Exit;
  if (Packet[1]<>24) or (Packet[2]<>$16) or (CRC8D5(Packet,2,23)<>Packet[25]) then Exit;
  Unpack11(Packet,3,Channels);end;
 rcSBUS:begin if Length(Packet)<>25 then Exit;
  if (Packet[0]<>$0F) or (Packet[24]<>0) or ((Packet[23] and $0C)<>0) then Exit;
  Unpack11(Packet,1,Channels);end;
 rcIBUS:begin if Length(Packet)<>32 then Exit;if (Packet[0]<>$20) or (Packet[1]<>$40) then Exit;
  CS:=$FFFF;for I:=0 to 29 do CS:=CS-Packet[I];if CS<>Get16(Packet,30) then Exit;Offset:=2;end;
 end;
 if Offset>0 then for I:=0 to N-1 do begin Channels[I]:=Get16(Packet,Offset+I*2);
  if (Channels[I]<1000) or (Channels[I]>2000) then Exit;
 end;
 Result:=True;
end;
function WiFi8KNeutral:TWiFi8KCommand;
begin Result:=Default(TWiFi8KCommand);Result.Roll:=128;Result.Pitch:=128;Result.Throttle:=128;Result.Yaw:=128;end;
function EncodeWiFi8K(Variant:TWiFi8KVariant;const C:TWiFi8KCommand):TBytes;
var P:Integer;CS:Byte;
begin
 Result:=nil;if Variant=w8Legacy9 then begin SetLength(Result,9);Result[0]:=3;P:=1;end
 else begin SetLength(Result,8);P:=0;end;
 Result[P]:=$66;Result[P+1]:=C.Roll;Result[P+2]:=C.Pitch;Result[P+3]:=C.Throttle;Result[P+4]:=C.Yaw;Result[P+5]:=C.Flags;
 CS:=C.Roll xor C.Pitch xor C.Throttle xor C.Yaw;if Variant=w8Legacy9 then CS:=CS xor C.Flags;
 Result[P+6]:=CS;Result[P+7]:=$99;
end;
function DecodeWiFi8K(const B:TBytes;out Variant:TWiFi8KVariant;out C:TWiFi8KCommand):Boolean;
var P:Integer;CS:Byte;
begin
 Result:=False;C:=WiFi8KNeutral;Variant:=w8Legacy9;
 if Length(B)=9 then begin if B[0]<>3 then Exit;P:=1;end
 else if Length(B)=8 then begin Variant:=w8E58_8;P:=0;end else Exit;
 if (B[P]<>$66) or (B[P+7]<>$99) then Exit;
 CS:=B[P+1] xor B[P+2] xor B[P+3] xor B[P+4];if Variant=w8Legacy9 then CS:=CS xor B[P+5];
 if CS<>B[P+6] then Exit;
 C.Roll:=B[P+1];C.Pitch:=B[P+2];C.Throttle:=B[P+3];C.Yaw:=B[P+4];C.Flags:=B[P+5];Result:=True;
end;
function AxisByte(Value:Double):Byte;
begin if IsNan(Value) or IsInfinite(Value) then raise EArgumentException.Create('Invalid RC axis');
 Result:=EnsureRange(Round(128+EnsureRange(Value,-1.0,1.0)*127),1,255);end;
function ChannelAxis(Value:Word):Double;
begin Result:=EnsureRange((Integer(Value)-1500)/500,-1.0,1.0);end;
end.
