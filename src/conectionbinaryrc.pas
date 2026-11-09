unit conectionbinaryrc;
{$mode objfpc}{$H+}
interface
uses Classes,SysUtils,Math,SyncObjs,Forms,Graphics,StdCtrls,fpjson,
 conexaodrone,aidronebase,aiwifi,cockpit_binary_link,rc_wire_protocol,vehicle_rc_profile,wifi8k_profile,wifi8k_panel,cockpit_url_video;
type
 TfrmConectionBinaryRC=class(TfrmConexaoDrone)
 private
  FVideo:TURLVideoSource;FLink:TBinaryLink;FMarker:TAIDroneBase;FWifi:TNativeWiFi8KBackend;FLock:TCriticalSection;
  FIsWiFi,FSimulation,FArmed,FCut,FLinkLost:Boolean;FProtocol:TRCWireProtocol;FRC:TRCSettings;FW8:TWiFi8KSettings;
  FInterval:Integer;FRequested,FPulse:Byte;FUntil,FLastHeartbeat,FNextMode,FModeEnd,FLastWifiCheck:QWord;
  FSent,FRx:Int64;FLastRaw:string;FInfo,FLinkInfo:TLabel;
  procedure WifiWait(Sender:TObject);
  procedure Request(RequestedAction:Byte);
  procedure ArmClick(Sender:TObject);procedure LandClick(Sender:TObject);procedure CutClick(Sender:TObject);
  function WriteFrame(const B:TBytes):Boolean;
 protected
  function Conectar:Boolean;override;procedure Desconectar;override;
  procedure Controle(const C:TComandoManche);override;
  procedure AtualizaPainel;override;function IntervaloMs:Integer;override;
 public
  constructor Create(AOwner:TComponent);override;destructor Destroy;override;
  function VideoExternoConfigurado:Boolean;override;
  function CarregaQuadroExterno(ABitmap:TBitmap):Boolean;override;
  procedure Emergency;
 end;
implementation
uses setmain;
constructor TfrmConectionBinaryRC.Create(AOwner:TComponent);
begin
 inherited Create(AOwner);FLock:=TCriticalSection.Create;FIsWiFi:=FSetMain.DroneProtocolo=7;
 FMarker:=TAIDroneBase.Create(Self);UsaDrone(FMarker);FWifi:=TNativeWiFi8KBackend.Create(Self);FWifi.Wifi.OnWait:=@WifiWait;
 if FIsWiFi then begin Caption:='WIFI_8K experimental';FW8:=FSetMain.WiFi8K;FInterval:=1000 div Max(10,FW8.RateHz);end
 else begin FProtocol:=TRCWireProtocol(EnsureRange(FSetMain.DroneProtocolo-8,0,4));
  FRC:=FSetMain.RCSettings[FProtocol,FSetMain.RCSelected[FProtocol]];Caption:=RCKeys[FProtocol]+' / '+VehicleKeys[FRC.Vehicle];FInterval:=1000 div FRC.RateHz;end;
 FInfo:=NovaLinha('Controle:');FLinkInfo:=NovaLinha('Conexao:');
 NovoBotao('A: armar / decolar',@ArmClick);NovoBotao('B: desarmar / pousar',@LandClick);NovoBotao('CORTAR (Espaco)',@CutClick,True);
end;
destructor TfrmConectionBinaryRC.Destroy;
begin Encerrar;FWifi.Free;FLock.Free;inherited Destroy;end;
procedure TfrmConectionBinaryRC.WifiWait(Sender:TObject);
begin Application.ProcessMessages;if FSetMain.SimulationMode then raise EAbort.Create('Associacao real interrompida: modo simulador selecionado');end;
function TfrmConectionBinaryRC.IntervaloMs:Integer;begin Result:=FInterval;end;
function TfrmConectionBinaryRC.WriteFrame(const B:TBytes):Boolean;
begin Result:=Assigned(FLink) and FLink.Write(B);if Result then Inc(FSent)
 else if not FLinkLost then begin FLinkLost:=True;FMarker.PostError('Falha de transporte; reconecte antes de pilotar.');end;end;
function TfrmConectionBinaryRC.Conectar:Boolean;
var Host,BindIP,SSID,Data,E,Alias,LocalIP,Gateway,Expected,FrameText,URL:string;Port,I,Matches:Integer;
 Network:TAIWifiNetwork;B:TBytes;O:TJSONObject;Deadline:QWord;
begin
 Result:=False;FSimulation:=FSetMain.SimulationMode;FArmed:=False;FCut:=False;FLinkLost:=False;FRequested:=0;FPulse:=0;
 if FIsWiFi then begin
  Host:=FW8.Host;Port:=FW8.ControlPort;BindIP:=FW8.BindIP;

  if FSimulation then begin Host:='127.0.0.1';BindIP:='127.0.0.1';Expected:='SIMW8';
   if FW8.Variant=w8E58_8 then Port:=8090 else Port:=7099;end
  else begin
   if not FW8.RealEnabled then begin DefineErro('Ative Permitir comandos reais experimentais no perfil WIFI_8K; o modelo ainda nao foi confirmado.');Exit;end;
   FWifi.Wifi.InterfaceName:=FW8.InterfaceName;SSID:=FWifi.CurrentSSID;
   if not MatchesWiFi8KSSID(SSID,FW8.SSIDPrefix) or ((FW8.TargetSSID<>'') and not SameText(SSID,FW8.TargetSSID)) then begin
    if not FWifi.Wifi.Scan(True) then begin DefineErro(FWifi.Wifi.LastError);Exit;end;
    Matches:=0;for I:=0 to High(FWifi.Wifi.Networks) do if MatchesWiFi8KSSID(FWifi.Wifi.Networks[I].SSID,FW8.SSIDPrefix) and
      ((FW8.TargetSSID='') or SameText(FWifi.Wifi.Networks[I].SSID,FW8.TargetSSID)) then begin Network:=FWifi.Wifi.Networks[I];Inc(Matches);end;
    if Matches<>1 then begin DefineErro('Selecione a rede exata em Configuracao > WIFI_8K; nao ha uma unica rede correspondente.');Exit;end;
    if Network.Secured then begin DefineErro('Conecte a rede protegida pela aba WIFI_8K ou pelo Windows primeiro.');Exit;end;
    if not FWifi.Associate(Network.SSID,'',FW8.ConnectTimeoutMs,E) then begin DefineErro(E);Exit;end;
    SSID:=Network.SSID;
   end;
   if FWifi.NetworkInfo(Data,E) and SelectWiFi8KNetworkInfo(Data,FW8.InterfaceName,Alias,LocalIP,Gateway) then begin
    BindIP:=LocalIP;if Host='' then Host:=Gateway;
   end;
   if (Host='') or (BindIP='') then begin DefineErro('IP/gateway ou IP local desconhecido. Use Conectar Wi-Fi e Ler IP/gateway no perfil.');Exit;end;
   FW8.TargetSSID:=SSID;
   Log('Wi-Fi associado: '+SSID+'. Envio experimental; resposta UDP nao comprova voo validado.');
  end;
  if Port=0 then begin if FW8.Variant=w8E58_8 then Port:=8090 else Port:=7099;end;
  FLink:=TUDPBinaryLink.Create(Host,Port,BindIP);
  if FW8.Variant=w8E58_8 then begin
   B:=TBytes.Create($42,$76);TUDPBinaryLink(FLink).WritePort(B,Word(IfThen(FSimulation,8080,FW8.VideoPort)));
   if not FSimulation then begin Deadline:=GetTickCount64+1000;
    repeat Sleep(150);WifiWait(Self);TUDPBinaryLink(FLink).WritePort(B,FW8.VideoPort);until GetTickCount64>=Deadline;
   end;FModeEnd:=0;FNextMode:=0;
  end
  else WriteFrame(TBytes.Create(1,1));
 end else begin
  if not ValidateRCSettings(FProtocol,FRC,E) then begin DefineErro(E);Exit;end;
  if FSimulation then begin
   FLink:=TUDPBinaryLink.Create('127.0.0.1',14600+Ord(FProtocol));Expected:='SIMRC '+VehicleKeys[FRC.Vehicle];
   O:=TJSONObject.Create;
   try O.Add('vehicle',VehicleKeys[FRC.Vehicle]);O.Add('arm',FRC.ArmChannel);
    for I:=0 to 3 do O.Add('axis'+IntToStr(I),FRC.Axis[I]);FrameText:='RCMETA '+O.AsJSON;
   finally O.Free;end;
   SetLength(B,Length(FrameText));Move(FrameText[1],B[0],Length(FrameText));WriteFrame(B);
  end else begin
   if not FRC.RealEnabled then begin DefineErro('Ative a saida serial real no perfil RC depois de configurar o receptor/controladora.');Exit;end;
   FLink:=TSerialBinaryLink.Create(FRC.Device,FRC.Baud,FProtocol=rcSBUS,FProtocol=rcSBUS);
  end;
 end;
 if FSimulation then begin
  Deadline:=GetTickCount64+2000;
  repeat
   if FLink.Read(B) then begin SetLength(FrameText,Length(B));Move(B[0],FrameText[1],Length(B));
    if FrameText=Expected then begin Result:=True;Break;end;
    if Pos('MISMATCH',FrameText)>0 then begin DefineErro('Escolha a mesma categoria de veiculo no simulador e no cockpit.');Exit;end;
   end;
   Sleep(10);Application.ProcessMessages;
  until GetTickCount64>=Deadline;
  if not Result then begin DefineErro('Simulador nao confirmou o protocolo. Ligue o modelo correspondente no simulador.');Exit;end;
  Log('Simulador confirmou '+Expected);
 end else Result:=True;
 if Result and not FSimulation then begin
  if FIsWiFi then URL:=FW8.VideoURL else URL:=FRC.VideoURL;
  if URL<>'' then try FVideo:=TURLVideoSource.Create(URL,FindCockpitFFmpeg,
   IncludeTrailingPathDelimiter(GetTempDir)+'cockpit_fpv_'+IntToStr(GetProcessID)+'.bmp');
  except on Ex:Exception do Log('Video FPV: '+Ex.Message);end;
 end;
 FLastHeartbeat:=GetTickCount64;FLastWifiCheck:=GetTickCount64;
end;
procedure TfrmConectionBinaryRC.Request(RequestedAction:Byte);
begin FLock.Enter;try FRequested:=FRequested or RequestedAction;finally FLock.Leave;end;end;
procedure TfrmConectionBinaryRC.ArmClick(Sender:TObject);begin Request(W8_TAKEOFF);end;
procedure TfrmConectionBinaryRC.LandClick(Sender:TObject);begin Request(W8_LAND);end;
procedure TfrmConectionBinaryRC.CutClick(Sender:TObject);begin Emergency;end;
procedure TfrmConectionBinaryRC.Emergency;begin Request(W8_CUT);end;
procedure TfrmConectionBinaryRC.Controle(const C:TComandoManche);
var RequestedAction:Byte;NowTick:QWord;Fresh,Neutral:Boolean;W:TWiFi8KCommand;Channels:TRCChannels;B:TBytes;I:Integer;
begin
 if not Assigned(FLink) or FLinkLost then Exit;NowTick:=GetTickCount64;
 if not FSimulation and FSetMain.SimulationMode then begin FLinkLost:=True;Exit;end;
 Fresh:=(C.SampleTick>0) and (NowTick-C.SampleTick<=500);
 FLock.Enter;
 try
  RequestedAction:=FRequested;FRequested:=0;
  if Fresh then begin if C.Apertou[3] then RequestedAction:=RequestedAction or W8_TAKEOFF;if C.Apertou[4] then RequestedAction:=RequestedAction or W8_LAND;end;
  if not Fresh then begin if FArmed and FIsWiFi then RequestedAction:=W8_LAND;FArmed:=False;end;
  if FIsWiFi or (FRC.Vehicle in [vcCar,vcBoat,vcSubmarine]) then Neutral:=Abs(C.Acelerador-0.5)<0.15 else Neutral:=C.Acelerador<0.1;
  if (RequestedAction and W8_CUT)<>0 then begin FCut:=True;FArmed:=False;FPulse:=W8_CUT;FUntil:=NowTick+1000;end
  else if (RequestedAction and W8_LAND)<>0 then begin FArmed:=False;FPulse:=W8_LAND;FUntil:=NowTick+1000;end
  else if (RequestedAction and W8_TAKEOFF)<>0 then begin
   if Fresh and Neutral then begin FArmed:=True;FCut:=False;FPulse:=W8_TAKEOFF;FUntil:=NowTick+1000;end
   else FMarker.PostStatus('Centralize a subida (WIFI/solo/sub) ou baixe o acelerador (RC aereo) antes de armar/decolar.');
  end;
  if NowTick>=FUntil then FPulse:=0;
  if FIsWiFi then begin
   W:=WiFi8KNeutral;
   if Fresh and not FCut and FArmed then begin W.Roll:=AxisByte(C.Rolagem);W.Pitch:=AxisByte(C.Arfagem);W.Yaw:=AxisByte(C.Guinada);W.Throttle:=AxisByte(C.Subida);end;
   W.Flags:=FPulse;
   if (FW8.Variant=w8E58_8) and (NowTick<FModeEnd) then begin
    if NowTick>=FNextMode then begin TUDPBinaryLink(FLink).WritePort(TBytes.Create($42,$76),Word(IfThen(FSimulation,8080,FW8.VideoPort)));FNextMode:=NowTick+150;end;
   end else WriteFrame(EncodeWiFi8K(FW8.Variant,W));
   if (FW8.Variant=w8Legacy9) and (NowTick-FLastHeartbeat>=1000) then begin WriteFrame(TBytes.Create(1,1));FLastHeartbeat:=NowTick;end;
  end else begin
   MapRCChannels(FRC,C.Rolagem,C.Arfagem,C.Guinada,C.Acelerador,FArmed and Fresh and not FCut,Channels);
   WriteFrame(EncodeRC(FProtocol,Channels,FRC.Address));
  end;
  if FLink.Read(B) then begin Inc(FRx);FLastRaw:='';for I:=0 to Min(High(B),31) do FLastRaw:=FLastRaw+IntToHex(B[I],2)+' ';end;
 finally FLock.Leave;end;
end;
procedure TfrmConectionBinaryRC.AtualizaPainel;
var FrameText:string;
begin
 if FIsWiFi and not FSimulation and (GetTickCount64-FLastWifiCheck>=2000) then begin
  FLastWifiCheck:=GetTickCount64;
  if not SameText(FWifi.CurrentSSID,FW8.TargetSSID) then begin FLinkLost:=True;FMarker.PostError('Wi-Fi do equipamento perdido. Envio suspenso.');end;
 end;
 FLock.Enter;
 try FrameText:=Format('%d quadros enviados | %d respostas',[FSent,FRx]);
  if FLinkLost then FrameText:=FrameText+' | enlace perdido' else if FArmed then FrameText:=FrameText+' | armamento/decolagem solicitado' else FrameText:=FrameText+' | desarmado/sem pedido de decolagem';
  FInfo.Caption:=FrameText;FLinkInfo.Caption:=FLastRaw;
 finally FLock.Leave;end;
end;
function TfrmConectionBinaryRC.VideoExternoConfigurado:Boolean;
begin Result:=Assigned(FVideo);end;
function TfrmConectionBinaryRC.CarregaQuadroExterno(ABitmap:TBitmap):Boolean;
begin Result:=Assigned(FVideo) and FVideo.LoadFrame(ABitmap);end;
procedure TfrmConectionBinaryRC.Desconectar;
var I:Integer;W:TWiFi8KCommand;Ch:TRCChannels;
begin
 FreeAndNil(FVideo);
 if not Assigned(FLink) then Exit;
 if not FLinkLost then begin
  if FIsWiFi then begin W:=WiFi8KNeutral;W.Flags:=W8_LAND;
   for I:=1 to 5 do begin FLink.Write(EncodeWiFi8K(FW8.Variant,W));Sleep(40);end;
   if FW8.Variant=w8Legacy9 then FLink.Write(TBytes.Create(8,1));
  end else begin MapRCChannels(FRC,0,0,0,0,False,Ch);
   for I:=1 to 3 do FLink.Write(EncodeRC(FProtocol,Ch,FRC.Address));end;
 end;
 FreeAndNil(FLink);
end;
end.
