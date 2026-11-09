unit simvehicleprotocols;
{$mode objfpc}{$H+}
interface
uses Classes,SysUtils,Math,fpjson,jsonparser,simemulador,simrede,simtipos,simgeo,
 rc_wire_protocol,vehicle_rc_profile;
type
 TEmuladorVehicle=class(TEmulador)
 private
  FLastCommand:QWord;FCommand:TWiFi8KCommand;FChannels:TRCChannels;FSettings:TRCSettings;
  FNeutralRequired,FAppMode,FArmLowRequired:Boolean;FPreviousFlags:Byte;
  procedure Ack(Channel:Integer;const Peer:TEndereco;const Text:string);
 protected
  function AbreCanais:Boolean;override;
  procedure Processa(Channel:Integer;const B:TBytes;const Peer:TEndereco);override;
 public
  constructor Create(const P:TParametrosModelo;const O:TPontoGeo;E:TLeEstado;F:TLeFalhas);override;
  procedure ReiniciaEstado;override;
  function MontaComando(const E:TEstadoVoo):TComandoVoo;override;
  function Descricao:string;override;
 end;
implementation
function ClassOfModel(const P:TParametrosModelo):TVehicleClass;
var V:TVehicleClass;
begin Result:=vcDrone;for V:=Low(V) to High(V) do if P.Classe=VehicleKeys[V] then Exit(V);end;
constructor TEmuladorVehicle.Create(const P:TParametrosModelo;const O:TPontoGeo;E:TLeEstado;F:TLeFalhas);
begin
 inherited Create(P,O,E,F);FCommand:=WiFi8KNeutral;FNeutralRequired:=True;FArmLowRequired:=True;
 FSettings:=DefaultRCSettings(rcMSP1,ClassOfModel(P));
end;
function TEmuladorVehicle.AbreCanais:Boolean;
var I:Integer;
begin
 Result:=False;
 if FParam.Protocolo='wifi8k' then begin
  if AdicionaCanal(7099)<0 then Exit;if AdicionaCanal(8090)<0 then Exit;if AdicionaCanal(8080)<0 then Exit;
 end else for I:=0 to 4 do if AdicionaCanal(14600+I)<0 then Exit;
 Result:=True;
end;
procedure TEmuladorVehicle.Ack(Channel:Integer;const Peer:TEndereco;const Text:string);
begin EnviaTexto(Channel,Text,Peer.IP,Peer.Porta);end;
procedure TEmuladorVehicle.Processa(Channel:Integer;const B:TBytes;const Peer:TEndereco);
var Variant:TWiFi8KVariant;C:TWiFi8KCommand;Ch:TRCChannels;Text:string;J:TJSONData;
 O:TJSONObject;S:TRCSettings;I:Integer;ErrorText:string;
begin
 if FParam.Protocolo='wifi8k' then begin
  if (Length(B)=2) and (B[0]=1) and (B[1]=1) and (Channel=0) then begin Ack(0,Peer,'SIMW8');Exit;end;
  if (Length(B)=2) and (B[0]=$42) and (Channel=2) then begin
   FLock.Enter;try
    if B[1]=$76 then begin FAppMode:=True;Ack(1,Peer,'SIMW8');end
    else if B[1]=$77 then begin FAppMode:=False;CortarMotores;end;
   finally FLock.Leave;end;Exit;
  end;
  if (Length(B)=2) and (B[0]=8) and (B[1]=1) and (Channel=0) then begin
   FLock.Enter;try CortarMotores;finally FLock.Leave;end;Exit;end;
  if not DecodeWiFi8K(B,Variant,C) then Exit;
  if ((Variant=w8Legacy9) and (Channel<>0)) or ((Variant=w8E58_8) and ((Channel<>1) or not FAppMode)) then Exit;
  FLock.Enter;
  try
   FCommand:=C;FLastCommand:=Agora;
   if FNeutralRequired and (C.Flags=0) and (Abs(Integer(C.Throttle)-128)<=20) then FNeutralRequired:=False;
   if (C.Flags and W8_CUT)<>0 then begin CortarMotores;FNeutralRequired:=True;end
   else if (C.Flags and W8_LAND)<>0 then Pousar
   else if not FNeutralRequired and ((C.Flags and W8_TAKEOFF)<>0) and ((FPreviousFlags and W8_TAKEOFF)=0) then Decolar;
   FPreviousFlags:=C.Flags;
  finally FLock.Leave;end;
  Ack(Channel,Peer,'SIMW8');Exit;
 end;
 if (Length(B)>7) and (B[0]=Ord('R')) and (B[1]=Ord('C')) then begin
  SetLength(Text,Length(B));Move(B[0],Text[1],Length(B));
  if Copy(Text,1,7)<>'RCMETA ' then Exit;
  J:=nil;
  try
   try
    J:=GetJSON(Copy(Text,8,2048));if not(J is TJSONObject) then Exit;O:=TJSONObject(J);
    if O.Get('vehicle','')<>FParam.Classe then begin Ack(Channel,Peer,'SIMRC MISMATCH');Exit;end;
    S:=DefaultRCSettings(TRCWireProtocol(Channel),ClassOfModel(FParam));
    S.ArmChannel:=O.Get('arm',S.ArmChannel);
    for I:=0 to 3 do S.Axis[I]:=O.Get('axis'+IntToStr(I),S.Axis[I]);
    if not ValidateRCSettings(TRCWireProtocol(Channel),S,ErrorText) then Exit;
    FLock.Enter;try FSettings:=S;finally FLock.Leave;end;
    Ack(Channel,Peer,'SIMRC '+FParam.Classe);
   except Exit;end;
  finally J.Free;end;Exit;
 end;
 if (Channel<0) or (Channel>4) or not DecodeRC(TRCWireProtocol(Channel),B,Ch) then Exit;
 FLock.Enter;
 try FChannels:=Ch;FLastCommand:=Agora;
  if Ch[FSettings.ArmChannel-1]<1200 then FArmLowRequired:=False;
 finally FLock.Leave;end;
 Ack(Channel,Peer,'SIMRC '+FParam.Classe);
end;
procedure TEmuladorVehicle.ReiniciaEstado;
begin FLock.Enter;
 try inherited ReiniciaEstado;FCommand:=WiFi8KNeutral;FLastCommand:=0;FPreviousFlags:=0;
 FNeutralRequired:=True;FArmLowRequired:=True;
 finally FLock.Leave;end;end;
function TEmuladorVehicle.MontaComando(const E:TEstadoVoo):TComandoVoo;
var Armed:Boolean;
begin
 FLock.Enter;
 try
  Result:=ComandoNeutro;
  if E.Caiu then begin ComandoDaFase(E,Result);Exit;end;
  if FParam.Protocolo='wifi8k' then begin
   if (FLastCommand>0) and (Agora-FLastCommand>700) then Pousar;
   if ComandoDaFase(E,Result) then Exit;
   Result.Motores:=True;Result.ModoH:=mhAngulo;Result.ModoV:=mvSubida;
   Result.Rolagem:=(Integer(FCommand.Roll)-128)/127;
   Result.Arfagem:=(Integer(FCommand.Pitch)-128)/127;
   Result.Guinada:=(Integer(FCommand.Yaw)-128)/127;
   Result.Vertical:=(Integer(FCommand.Throttle)-128)/127;Exit;
  end;
  if (FLastCommand=0) or (Agora-FLastCommand>700) then Exit;
  Armed:=(FChannels[FSettings.ArmChannel-1]>1600) and not FArmLowRequired;
  Result.Motores:=Armed;Result.ModoH:=mhAngulo;Result.ModoV:=mvEmpuxo;
  if not Armed then begin FFase:=fvPousado;Exit;end;
  FFase:=fvVoando;
  Result.Rolagem:=ChannelAxis(FChannels[FSettings.Axis[0]-1]);
  Result.Arfagem:=ChannelAxis(FChannels[FSettings.Axis[1]-1]);
  Result.Guinada:=ChannelAxis(FChannels[FSettings.Axis[2]-1]);
  if FSettings.Vehicle in [vcCar,vcBoat,vcSubmarine] then Result.Vertical:=ChannelAxis(FChannels[FSettings.Axis[3]-1])
  else Result.Vertical:=(FChannels[FSettings.Axis[3]-1]-1000)/1000;
 finally FLock.Leave;end;
end;
function TEmuladorVehicle.Descricao:string;
begin if FParam.Protocolo='wifi8k' then Result:='WIFI_8K experimental: Legacy9 UDP7099 / E58_8 UDP8090+8080'
 else Result:='RC '+FParam.Classe+': MSP1/MSP2/CRSF/SBUS/iBUS UDP14600..14604 (simulador)';end;
end.
