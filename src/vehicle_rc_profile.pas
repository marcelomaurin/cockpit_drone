unit vehicle_rc_profile;
{$mode objfpc}{$H+}
interface
uses SysUtils,Math,IniFiles,rc_wire_protocol;
type
 TVehicleClass=(vcDrone,vcHelicopter,vcAirplane,vcCar,vcBoat,vcSubmarine);
 TRCSettings=record
  Vehicle:TVehicleClass;Device,VideoURL:string;Baud,RateHz:Integer;
  Axis:array[0..3]of Integer; // roll, pitch/forward, yaw, throttle/heave; 1-based
  Invert:array[0..3]of Boolean;
  ArmChannel:Integer;Address:Byte;RealEnabled:Boolean;
 end;
const VehicleKeys:array[TVehicleClass]of string=('drone','helicopter','airplane','car','boat','submarine');
 RCKeys:array[TRCWireProtocol]of string=('MSP1','MSP2','CRSF','SBUS','IBUS');
function DefaultRCSettings(P:TRCWireProtocol;V:TVehicleClass):TRCSettings;
function ValidateRCSettings(P:TRCWireProtocol;const S:TRCSettings;out ErrorText:string):Boolean;
procedure MapRCChannels(const S:TRCSettings;Roll,Pitch,Yaw,Throttle:Double;Armed:Boolean;out C:TRCChannels);
procedure ReadRCSettings(Ini:TCustomIniFile;P:TRCWireProtocol;V:TVehicleClass;var S:TRCSettings);
procedure WriteRCSettings(Ini:TCustomIniFile;P:TRCWireProtocol;V:TVehicleClass;const S:TRCSettings);
implementation
function DefaultRCSettings(P:TRCWireProtocol;V:TVehicleClass):TRCSettings;
begin
 Result:=Default(TRCSettings);Result.Vehicle:=V;Result.RateHz:=25;Result.Baud:=115200;Result.Address:=$C8;
 if P=rcCRSF then Result.Baud:=420000 else if P=rcSBUS then begin Result.Baud:=100000;Result.RateHz:=50;end;
 Result.Axis[0]:=1;Result.Axis[1]:=2;Result.Axis[2]:=4;Result.Axis[3]:=3;Result.ArmChannel:=5;
 if V=vcSubmarine then begin Result.Axis[0]:=6;Result.Axis[1]:=5;Result.ArmChannel:=7;end;
end;
function ValidateRCSettings(P:TRCWireProtocol;const S:TRCSettings;out ErrorText:string):Boolean;
var I,J,MaxC:Integer;
begin
 ErrorText:='';MaxC:=RCChannelCount(P);
 if (S.RateHz<10) or (S.RateHz>100) then ErrorText:='Taxa RC precisa estar entre 10 e 100 Hz';
 if (S.Baud<9600) or (S.Baud>1000000) then ErrorText:='Baud serial invalido';
 if (S.ArmChannel<1) or (S.ArmChannel>MaxC) then ErrorText:='Canal de armamento fora do protocolo';
 for I:=0 to 3 do begin
  if (S.Axis[I]<1) or (S.Axis[I]>MaxC) then ErrorText:='Canal do eixo fora do protocolo';
  if S.Axis[I]=S.ArmChannel then ErrorText:='Canal do eixo conflita com armamento';
  for J:=0 to I-1 do if S.Axis[I]=S.Axis[J] then ErrorText:='Dois eixos no mesmo canal';
 end;
 Result:=ErrorText='';
end;
procedure MapRCChannels(const S:TRCSettings;Roll,Pitch,Yaw,Throttle:Double;Armed:Boolean;out C:TRCChannels);
var Values:array[0..3]of Double;I:Integer;E:string;
begin
 Values[0]:=Roll;Values[1]:=Pitch;Values[2]:=Yaw;Values[3]:=2*Throttle-1;
 for I:=0 to 3 do if IsNan(Values[I]) or IsInfinite(Values[I]) then raise EArgumentException.Create('Eixo RC invalido');
 for I:=0 to 15 do C[I]:=1500;
 for I:=0 to 3 do begin
  if (S.Axis[I]<1) or (S.Axis[I]>16) then raise EArgumentException.Create('Canal RC invalido');
  if S.Invert[I] then Values[I]:=-Values[I];
  C[S.Axis[I]-1]:=EnsureRange(Round(1500+500*EnsureRange(Values[I],-1.0,1.0)),1000,2000);
 end;
 if (S.ArmChannel<1) or (S.ArmChannel>16) then raise EArgumentException.Create('Armamento RC invalido');
 if Armed then C[S.ArmChannel-1]:=2000 else begin
  C[S.ArmChannel-1]:=1000;
  for I:=0 to 2 do C[S.Axis[I]-1]:=1500;
  if S.Vehicle in [vcCar,vcBoat,vcSubmarine] then C[S.Axis[3]-1]:=1500 else C[S.Axis[3]-1]:=1000;
 end;
end;
procedure ReadRCSettings(Ini:TCustomIniFile;P:TRCWireProtocol;V:TVehicleClass;var S:TRCSettings);
var Sec,E:string;I:Integer;
begin
 Sec:='RC_'+RCKeys[P]+'_'+VehicleKeys[V];S.Device:=Ini.ReadString(Sec,'PORT',S.Device);S.VideoURL:=Ini.ReadString(Sec,'VIDEO_URL',S.VideoURL);
 S.Baud:=Ini.ReadInteger(Sec,'BAUD',S.Baud);S.RateHz:=Ini.ReadInteger(Sec,'RATE_HZ',S.RateHz);
 S.ArmChannel:=Ini.ReadInteger(Sec,'ARM_CHANNEL',S.ArmChannel);S.Address:=EnsureRange(Ini.ReadInteger(Sec,'CRSF_ADDRESS',S.Address),0,255);
 S.RealEnabled:=Ini.ReadBool(Sec,'REAL_ENABLED',False);
 for I:=0 to 3 do begin S.Axis[I]:=Ini.ReadInteger(Sec,'AXIS_'+IntToStr(I),S.Axis[I]);S.Invert[I]:=Ini.ReadBool(Sec,'INVERT_'+IntToStr(I),S.Invert[I]);end;
 if not ValidateRCSettings(P,S,E) then S:=DefaultRCSettings(P,V);
end;
procedure WriteRCSettings(Ini:TCustomIniFile;P:TRCWireProtocol;V:TVehicleClass;const S:TRCSettings);
var Sec,E:string;I:Integer;
begin
 if not ValidateRCSettings(P,S,E) then raise EArgumentException.Create(E);
 Sec:='RC_'+RCKeys[P]+'_'+VehicleKeys[V];Ini.WriteString(Sec,'PORT',S.Device);Ini.WriteString(Sec,'VIDEO_URL',S.VideoURL);Ini.WriteInteger(Sec,'BAUD',S.Baud);
 Ini.WriteInteger(Sec,'RATE_HZ',S.RateHz);Ini.WriteInteger(Sec,'ARM_CHANNEL',S.ArmChannel);Ini.WriteInteger(Sec,'CRSF_ADDRESS',S.Address);
 Ini.WriteBool(Sec,'REAL_ENABLED',S.RealEnabled);
 for I:=0 to 3 do begin Ini.WriteInteger(Sec,'AXIS_'+IntToStr(I),S.Axis[I]);Ini.WriteBool(Sec,'INVERT_'+IntToStr(I),S.Invert[I]);end;
end;
end.
