unit wifi8k_profile;
{$mode objfpc}{$H+}
interface
uses Classes,SysUtils,IniFiles,fpjson,jsonparser,rc_wire_protocol;
type
 TWiFi8KSettings=record
  SSIDPrefix,InterfaceName,Host,TargetSSID,BindIP,VideoURL:string;
  Variant:TWiFi8KVariant;RealEnabled:Boolean;
  ControlPort,VideoPort,RateHz,ConnectTimeoutMs:Integer;
 end;
 TWiFi8KNetwork=record SSID,BSSID:string;Signal:Integer;Secured:Boolean;end;
 TWiFi8KNetworks=array of TWiFi8KNetwork;
 TWiFi8KState=(w8Idle,w8Detected,w8Associating,w8Associated,w8Lost);
 TWiFi8KBackend=class
  function Scan(out Networks:TWiFi8KNetworks;out ErrorText:string):Boolean;virtual;abstract;
  function CurrentSSID:string;virtual;abstract;
  function Associate(const SSID,Password:string;TimeoutMs:Integer;out ErrorText:string):Boolean;virtual;abstract;
  function Restore(const SSID:string):Boolean;virtual;abstract;
 end;
 TWiFi8KSession=class
 private
  FBackend:TWiFi8KBackend;FSettings:TWiFi8KSettings;FNetworks:TWiFi8KNetworks;
  FState:TWiFi8KState;FPrevious,FConnected,FError:string;
 public
  constructor Create(Backend:TWiFi8KBackend;const Settings:TWiFi8KSettings);
  function Discover:Boolean;
  function Connect(const SSID,Password:string):Boolean;
  procedure CheckLink;
  function RestorePrevious:Boolean;
  function CanSendFlightCommands:Boolean;
  property Networks:TWiFi8KNetworks read FNetworks;
  property State:TWiFi8KState read FState;
  property PreviousSSID:string read FPrevious;
  property ConnectedSSID:string read FConnected;
  property LastError:string read FError;
 end;
function SelectWiFi8KNetworkInfo(const Text,InterfaceName:string;out Alias,LocalIP,Gateway:string):Boolean;
function DefaultWiFi8KSettings:TWiFi8KSettings;
function ValidateWiFi8KSettings(const S:TWiFi8KSettings;out ErrorText:string):Boolean;
function MatchesWiFi8KSSID(const SSID,Prefix:string):Boolean;
procedure ReadWiFi8KSettings(Ini:TCustomIniFile;var S:TWiFi8KSettings);
procedure WriteWiFi8KSettings(Ini:TCustomIniFile;const S:TWiFi8KSettings);
implementation
function SelectWiFi8KNetworkInfo(const Text,InterfaceName:string;out Alias,LocalIP,Gateway:string):Boolean;
var Root:TJSONData;Items:TJSONArray;I,Count:Integer;
 procedure Pick(O:TJSONObject);
 begin
  if (InterfaceName<>'') and not SameText(O.Get('Interface',''),InterfaceName) then Exit;
  Inc(Count);Alias:=O.Get('Interface','');LocalIP:=O.Get('IP','');Gateway:=O.Get('Gateway','');
 end;
begin
 Alias:='';LocalIP:='';Gateway:='';Result:=False;Count:=0;
 if (Trim(Text)='') or (Length(Text)>32768) then Exit;
 Root:=nil;
 try
  try
   Root:=GetJSON(Text);
   if Root is TJSONObject then Pick(TJSONObject(Root))
   else if Root is TJSONArray then begin Items:=TJSONArray(Root);
    if Items.Count>48 then Exit;
    for I:=0 to Items.Count-1 do if Items[I] is TJSONObject then Pick(TJSONObject(Items[I]));
   end;
   Result:=(Count=1) and (LocalIP<>'');
  except Result:=False;end;
 finally Root.Free;end;
 if not Result then begin Alias:='';LocalIP:='';Gateway:='';end;
end;
function DefaultWiFi8KSettings:TWiFi8KSettings;
begin
 Result:=Default(TWiFi8KSettings);Result.SSIDPrefix:='Wifi_8k_';Result.ConnectTimeoutMs:=20000;Result.ControlPort:=7099;Result.VideoPort:=8080;Result.RateHz:=25;
end;
function ValidateWiFi8KSettings(const S:TWiFi8KSettings;out ErrorText:string):Boolean;
var I:Integer;
begin
 ErrorText:='';
 if (Length(S.SSIDPrefix)<1) or (Length(S.SSIDPrefix)>32) then ErrorText:='Prefixo SSID precisa ter 1 a 32 bytes';
 for I:=1 to Length(S.SSIDPrefix) do
  if (S.SSIDPrefix[I] in ['*','?',';',#0..#31]) then ErrorText:='Use um prefixo SSID literal, sem curingas';
 if (S.ControlPort<0) or (S.ControlPort>65535) or (S.VideoPort<0) or (S.VideoPort>65535) then ErrorText:='Portas: 0 desconhecida, ou 1 a 65535';
 if (S.RateHz<0) or (S.RateHz>100) then ErrorText:='Taxa: 0 desconhecida, ou 1 a 100 Hz';
 if (S.ConnectTimeoutMs<1000) or (S.ConnectTimeoutMs>60000) then ErrorText:='Prazo Wi-Fi: 1000 a 60000 ms';
 Result:=ErrorText='';
end;
function MatchesWiFi8KSSID(const SSID,Prefix:string):Boolean;
begin Result:=(Length(Prefix)>0) and (Length(SSID)>Length(Prefix)) and (Length(SSID)<=32) and
 SameText(Copy(SSID,1,Length(Prefix)),Prefix);end;
procedure ReadWiFi8KSettings(Ini:TCustomIniFile;var S:TWiFi8KSettings);
var E:string;
begin
 S.SSIDPrefix:=Ini.ReadString('WIFI_8K','SSID_PREFIX',S.SSIDPrefix);
 S.InterfaceName:=Ini.ReadString('WIFI_8K','INTERFACE',S.InterfaceName);
 S.Host:=Ini.ReadString('WIFI_8K','IP',S.Host);
 S.VideoURL:=Ini.ReadString('WIFI_8K','VIDEO_URL',S.VideoURL);
 S.TargetSSID:=Ini.ReadString('WIFI_8K','SSID',S.TargetSSID);S.BindIP:=Ini.ReadString('WIFI_8K','LOCAL_IP',S.BindIP);
 S.RealEnabled:=Ini.ReadBool('WIFI_8K','REAL_ENABLED',False);
 if Ini.ReadInteger('WIFI_8K','VARIANT',0)=1 then S.Variant:=w8E58_8 else S.Variant:=w8Legacy9;
 S.ControlPort:=Ini.ReadInteger('WIFI_8K','CONTROL_PORT',S.ControlPort);
 S.VideoPort:=Ini.ReadInteger('WIFI_8K','VIDEO_PORT',S.VideoPort);
 S.RateHz:=Ini.ReadInteger('WIFI_8K','RATE_HZ',S.RateHz);
 S.ConnectTimeoutMs:=Ini.ReadInteger('WIFI_8K','CONNECT_TIMEOUT_MS',S.ConnectTimeoutMs);
 if not ValidateWiFi8KSettings(S,E) then S:=DefaultWiFi8KSettings;
end;
procedure WriteWiFi8KSettings(Ini:TCustomIniFile;const S:TWiFi8KSettings);
var E:string;
begin
 if not ValidateWiFi8KSettings(S,E) then raise EArgumentException.Create(E);
 Ini.WriteString('WIFI_8K','SSID_PREFIX',S.SSIDPrefix);Ini.WriteString('WIFI_8K','INTERFACE',S.InterfaceName);
 Ini.WriteString('WIFI_8K','VIDEO_URL',S.VideoURL);
 Ini.WriteString('WIFI_8K','IP',S.Host);Ini.WriteString('WIFI_8K','SSID',S.TargetSSID);Ini.WriteString('WIFI_8K','LOCAL_IP',S.BindIP);
 Ini.WriteBool('WIFI_8K','REAL_ENABLED',S.RealEnabled);Ini.WriteInteger('WIFI_8K','VARIANT',Ord(S.Variant));Ini.WriteInteger('WIFI_8K','CONTROL_PORT',S.ControlPort);
 Ini.WriteInteger('WIFI_8K','VIDEO_PORT',S.VideoPort);Ini.WriteInteger('WIFI_8K','RATE_HZ',S.RateHz);
 Ini.WriteInteger('WIFI_8K','CONNECT_TIMEOUT_MS',S.ConnectTimeoutMs);
end;
constructor TWiFi8KSession.Create(Backend:TWiFi8KBackend;const Settings:TWiFi8KSettings);
begin
 inherited Create;
 if not Assigned(Backend) then raise EArgumentException.Create('Backend Wi-Fi ausente');
 if not ValidateWiFi8KSettings(Settings,FError) then raise EArgumentException.Create(FError);
 FBackend:=Backend;FSettings:=Settings;
end;
function TWiFi8KSession.Discover:Boolean;
var Found:TWiFi8KNetworks;I,J:Integer;N:TWiFi8KNetwork;
begin
 FError:='';FNetworks:=nil;Result:=FBackend.Scan(Found,FError);if not Result then Exit;
 for I:=0 to High(Found) do if MatchesWiFi8KSSID(Found[I].SSID,FSettings.SSIDPrefix) then begin
  SetLength(FNetworks,Length(FNetworks)+1);FNetworks[High(FNetworks)]:=Found[I];
 end;
 for I:=0 to High(FNetworks)-1 do for J:=I+1 to High(FNetworks) do if FNetworks[J].Signal>FNetworks[I].Signal then begin
  N:=FNetworks[I];FNetworks[I]:=FNetworks[J];FNetworks[J]:=N;
 end;
 if FState<>w8Associated then begin
  if Length(FNetworks)>0 then FState:=w8Detected else FState:=w8Idle;
 end;
end;
function TWiFi8KSession.Connect(const SSID,Password:string):Boolean;
var I:Integer;Found:Boolean;Before:string;
begin
 Result:=False;FError:='';Found:=False;
 for I:=0 to High(FNetworks) do if FNetworks[I].SSID=SSID then Found:=True;
 if not Found then begin FError:='Selecione uma rede descoberta pelo WIFI_8K';Exit;end;
 Before:=FBackend.CurrentSSID;
 if Before=SSID then begin FConnected:=SSID;FState:=w8Associated;Exit(True);end;
 if FPrevious='' then FPrevious:=Before;
 FState:=w8Associating;
 try
  Result:=FBackend.Associate(SSID,Password,FSettings.ConnectTimeoutMs,FError) and (FBackend.CurrentSSID=SSID);
 except on E:Exception do begin FError:=E.Message;Result:=False;end;end;
 if Result then begin FConnected:=SSID;FState:=w8Associated;end
 else begin
  FConnected:='';FState:=w8Lost;if FError='' then FError:='O Windows nao confirmou a rede selecionada';
  if FPrevious<>'' then FBackend.Restore(FPrevious);
 end;
end;
procedure TWiFi8KSession.CheckLink;
begin if (FState=w8Associated) and (FBackend.CurrentSSID<>FConnected) then begin
 FState:=w8Lost;FConnected:='';FError:='Conexao Wi-Fi perdida; controle continua bloqueado';end;end;
function TWiFi8KSession.RestorePrevious:Boolean;
begin Result:=(FPrevious<>'') and FBackend.Restore(FPrevious);
 if Result then begin FState:=w8Idle;FConnected:='';FPrevious:='';end;end;
function TWiFi8KSession.CanSendFlightCommands:Boolean;
begin Result:=(FState=w8Associated) and FSettings.RealEnabled; // Explicit experimental opt-in; not a hardware certification.
end;
end.
