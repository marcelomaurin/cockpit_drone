program test_wifi8k;
{$mode objfpc}{$H+}
uses Classes,SysUtils,IniFiles,wifi8k_profile,setmain,protocols;
type
 TFakeBackend=class(TWiFi8KBackend)
  Networks:TWiFi8KNetworks;Current,Restored,Requested:string;Fail,WrongNetwork:Boolean;Connects,Restores:Integer;
  function Scan(out Found:TWiFi8KNetworks;out E:string):Boolean;override;
  function CurrentSSID:string;override;
  function Associate(const SSID,Password:string;TimeoutMs:Integer;out E:string):Boolean;override;
  function Restore(const SSID:string):Boolean;override;
 end;
function TFakeBackend.Scan(out Found:TWiFi8KNetworks;out E:string):Boolean;
begin Found:=Networks;E:='';Result:=True;end;
function TFakeBackend.CurrentSSID:string;begin Result:=Current;end;
function TFakeBackend.Associate(const SSID,Password:string;TimeoutMs:Integer;out E:string):Boolean;
begin Inc(Connects);Requested:=SSID;Result:=not Fail;E:='';
 if Fail then E:='mock association failed' else if WrongNetwork then Current:='different' else Current:=SSID;end;
function TFakeBackend.Restore(const SSID:string):Boolean;
begin Inc(Restores);Restored:=SSID;Current:=SSID;Result:=True;end;
procedure Check(B:Boolean;const M:string);begin if not B then raise Exception.Create(M);end;
var S,R:TWiFi8KSettings;B:TFakeBackend;Session:TWiFi8KSession;E,Dir,CXIP:string;
 Config:TSetMain;Ini:TIniFile;Alias,LocalIP,Gateway:string;
begin
 S:=DefaultWiFi8KSettings;
 Check((S.SSIDPrefix='Wifi_8k_') and (S.ControlPort=7099) and (S.VideoPort=8080) and (S.RateHz=25) and not S.RealEnabled,'candidate defaults, real flight disabled');
 Check(MatchesWiFi8KSSID('WIFI_8K_a83a9a',S.SSIDPrefix),'observed SSID');
 Check(MatchesWiFi8KSSID('wifi_8K_ABC',S.SSIDPrefix),'case-insensitive prefix');
 Check(not MatchesWiFi8KSSID('Free Wifi_8k_abc',S.SSIDPrefix),'substring must not match');
 S.SSIDPrefix:='*';Check(not ValidateWiFi8KSettings(S,E),'broad wildcard rejected');S:=DefaultWiFi8KSettings;
 B:=TFakeBackend.Create;
 try
 SetLength(B.Networks,3);B.Networks[0].SSID:='Wifi_8k_a83a9a';B.Networks[0].Signal:=40;
 B.Networks[1].SSID:='Unrelated';B.Networks[1].Signal:=100;
 B.Networks[2].SSID:='Wifi_8k_other';B.Networks[2].Signal:=80;B.Current:='PreviousNetwork';
 Session:=TWiFi8KSession.Create(B,S);
 try
 Check(not Session.CanSendFlightCommands,'idle flight gate');Check(Session.Discover,'discovery');
 Check((Length(Session.Networks)=2) and (Session.Networks[0].Signal=80),'filter and signal sort');
 Check(Session.State=w8Detected,'detection is not association');
 Check(not Session.Connect('Unrelated',''),'only a discovered candidate can be connected');Check(B.Connects=0,'no association for unrelated SSID');
 Check(Session.Connect('Wifi_8k_a83a9a',''),'association');
 Check((Session.State=w8Associated) and (Session.PreviousSSID='PreviousNetwork'),'remember prior connection');
 Check(not Session.CanSendFlightCommands,'Wi-Fi must not imply flight support');
 B.Current:='OtherNetwork';Session.CheckLink;
 Check((Session.State=w8Lost) and not Session.CanSendFlightCommands,'link-loss gate');
 Check(Session.RestorePrevious and (B.Restored='PreviousNetwork'),'restore previous network');
 B.WrongNetwork:=True;
 Check(not Session.Connect('Wifi_8k_a83a9a',''),'backend success must be confirmed against actual SSID');
 Check(B.Restored='PreviousNetwork','restore after wrong-network association');B.WrongNetwork:=False;B.Fail:=True;
 Check(not Session.Connect('Wifi_8k_other',''),'association failure');Check(not Session.CanSendFlightCommands,'failed association flight gate');
 finally Session.Free;end;
 B.Fail:=False;B.WrongNetwork:=False;S.RealEnabled:=True;
 Session:=TWiFi8KSession.Create(B,S);
 try Check(not Session.CanSendFlightCommands,'opt-in still requires association');
 Check(Session.Discover and Session.Connect('Wifi_8k_a83a9a',''),'explicit opt-in association');
 Check(Session.CanSendFlightCommands,'explicit opt-in enables selected candidate');
 B.Current:='Other';Session.CheckLink;Check(not Session.CanSendFlightCommands,'opt-in cannot bypass link loss');
 finally Session.Free;end;
 finally B.Free;end;
 if ParamStr(1)='' then Dir:=ExtractFilePath(ParamStr(0))+'wifi8k-test-config' else Dir:=ParamStr(1);
 Dir:=IncludeTrailingPathDelimiter(ExpandFileName(Dir));ForceDirectories(Dir);
 Config:=TSetMain.Create(Dir);
 try CXIP:=Config.CX10W.IP;Config.WiFi8K.Host:='192.168.0.1';Config.WiFi8K.ControlPort:=12345;
 Config.WiFi8K.InterfaceName:='Wi-Fi';Config.SalvaContexto;finally Config.Free;end;
 Config:=TSetMain.Create(Dir);
 try Check((Config.WiFi8K.Host='192.168.0.1') and (Config.WiFi8K.ControlPort=12345),'profile roundtrip');
 Check(Config.CX10W.IP=CXIP,'other models preserved');
 finally Config.Free;end;
 Check((PROTOCOLO_WIFI8K=7) and not ProtocoloTemGPS(PROTOCOLO_WIFI8K),'stable protocol index; no invented GPS');
 Check(SelectWiFi8KNetworkInfo('{"Interface":"Wi-Fi 2","IP":"192.168.0.2","Gateway":"192.168.0.1"}','',Alias,LocalIP,Gateway),'single Wi-Fi adapter');
 Check((LocalIP='192.168.0.2') and (Gateway='192.168.0.1'),'observed IP/gateway');
 Check(not SelectWiFi8KNetworkInfo('[{"Interface":"Wi-Fi 1","IP":"a"},{"Interface":"Wi-Fi 2","IP":"b"}]','',Alias,LocalIP,Gateway),'multiple adapters must not be guessed');
 Check(SelectWiFi8KNetworkInfo('[{"Interface":"Wi-Fi 1","IP":"a"},{"Interface":"Wi-Fi 2","IP":"b"}]','Wi-Fi 2',Alias,LocalIP,Gateway) and (LocalIP='b'),'selected adapter');
 Check(not SelectWiFi8KNetworkInfo('not JSON','',Alias,LocalIP,Gateway),'invalid diagnostic response');
 WriteLn('PASS WIFI_8K discovery, selected-SSID association, confirmation, link loss, restoration, persisted profile and explicit experimental flight gate');
end.
