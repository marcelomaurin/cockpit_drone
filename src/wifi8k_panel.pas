unit wifi8k_panel;
{$mode objfpc}{$H+}
interface
uses Classes,SysUtils,Math,Forms,Controls,StdCtrls,ExtCtrls,aiwifi,wifi8k_profile,rc_wire_protocol;
type
 TNativeWiFi8KBackend=class(TWiFi8KBackend)
 private FWifi:TAIWifi;
 public
  constructor Create(AOwner:TComponent);
  destructor Destroy;override;
  function Scan(out Networks:TWiFi8KNetworks;out ErrorText:string):Boolean;override;
  function CurrentSSID:string;override;
  function NetworkInfo(out Data,ErrorText:string):Boolean;
  function Associate(const SSID,Password:string;TimeoutMs:Integer;out ErrorText:string):Boolean;override;
  function Restore(const SSID:string):Boolean;override;
  property Wifi:TAIWifi read FWifi;
 end;
 TWiFi8KPanel=class(TScrollBox)
 private
  FBackend:TNativeWiFi8KBackend;FSession:TWiFi8KSession;FBusy:Boolean;
  FPrefix,FInterface,FHost,FControlPort,FVideoPort,FRate,FTimeout,FPassword,FVideoURL:TEdit;
  FVariant:TComboBox;FEnable:TCheckBox;
  FNetworks:TListBox;FLog:TMemo;FStatus:TLabel;FScan,FConnect,FRestore,FSave,FInfo:TButton;FTimer:TTimer;
  function EditField(const ACaption:string;Y:Integer):TEdit;
  function ReadSettings(out S:TWiFi8KSettings):Boolean;
  procedure Log(const Message:string);
  procedure Wait(Sender:TObject);
  procedure VariantChanged(Sender:TObject);
  procedure ScanClick(Sender:TObject);
  procedure ConnectClick(Sender:TObject);
  procedure InfoClick(Sender:TObject);
  procedure RestoreClick(Sender:TObject);
  procedure SaveClick(Sender:TObject);
  procedure Tick(Sender:TObject);
  procedure ShowStatus;
  procedure Busy(Value:Boolean);
 public
  constructor Create(AOwner:TComponent);override;
  destructor Destroy;override;
  procedure LoadSettings;
  function SaveSettings:Boolean;
 end;
implementation
uses setmain,main,Process;
constructor TNativeWiFi8KBackend.Create(AOwner:TComponent);
begin inherited Create;FWifi:=TAIWifi.Create(AOwner);end;
destructor TNativeWiFi8KBackend.Destroy;begin FWifi.Free;inherited Destroy;end;
function TNativeWiFi8KBackend.Scan(out Networks:TWiFi8KNetworks;out ErrorText:string):Boolean;
var I:Integer;
begin
 Networks:=nil;Result:=FWifi.Scan(True);ErrorText:=FWifi.LastError;if not Result then Exit;
 SetLength(Networks,Length(FWifi.Networks));
 for I:=0 to High(Networks) do begin Networks[I].SSID:=FWifi.Networks[I].SSID;
  Networks[I].BSSID:=FWifi.Networks[I].BSSID;Networks[I].Signal:=FWifi.Networks[I].Signal;
  Networks[I].Secured:=FWifi.Networks[I].Secured;end;
end;
function TNativeWiFi8KBackend.CurrentSSID:string;begin Result:=FWifi.CurrentSSID;end;
function TNativeWiFi8KBackend.Associate(const SSID,Password:string;TimeoutMs:Integer;out ErrorText:string):Boolean;
begin Result:=FWifi.Connect(SSID,Password) and FWifi.WaitForConnection(SSID,TimeoutMs);ErrorText:=FWifi.LastError;end;
function TNativeWiFi8KBackend.NetworkInfo(out Data,ErrorText:string):Boolean;
{$IFDEF WINDOWS}
const Script='$ErrorActionPreference="Stop"; @(Get-NetIPConfiguration | Where-Object {($_.NetAdapter.InterfaceType -eq 71) -or ($_.NetAdapter.NdisPhysicalMedium -in 1,9)} | ForEach-Object {[pscustomobject]@{Interface=[string]$_.InterfaceAlias;IP=[string](@($_.IPv4Address.IPAddress)[0]);Gateway=[string](@($_.IPv4DefaultGateway.NextHop)[0])}}) | ConvertTo-Json -Compress';
var P:TProcess;Started:QWord;Buf:array[0..2047]of Byte;N:Integer;Part:string;
{$ENDIF}
begin
 Data:='';ErrorText:='';Result:=False;
 {$IFDEF WINDOWS}
 P:=TProcess.Create(nil);
 try
  P.Executable:='powershell.exe';P.Parameters.Add('-NoProfile');P.Parameters.Add('-NonInteractive');P.Parameters.Add('-NoLogo');
  P.Parameters.Add('-Command');P.Parameters.Add(Script);P.Options:=[poUsePipes,poStderrToOutput,poNoConsole];P.ShowWindow:=swoHIDE;
  P.Execute;Started:=GetTickCount64;
  try
   while P.Running or (P.Output.NumBytesAvailable>0) do begin
    while P.Output.NumBytesAvailable>0 do begin
     N:=P.Output.Read(Buf,SizeOf(Buf));if N<=0 then Break;
     SetLength(Part,N);Move(Buf[0],Part[1],N);Data:=Data+Part;
     if Length(Data)>32768 then raise Exception.Create('Resposta da rede excedeu o limite');
    end;
    if GetTickCount64-Started>15000 then raise Exception.Create('Prazo para ler IP/gateway expirou');
    if Assigned(FWifi.OnWait) then FWifi.OnWait(Self);
    Sleep(50);
   end;
   Result:=P.ExitStatus=0;if not Result then ErrorText:='Nao foi possivel ler IP/gateway pelo Windows';
  finally if P.Running then P.Terminate(1);end;
 except on E:Exception do ErrorText:=E.Message;end;
 P.Free;
 {$ELSE}
 ErrorText:='Leitura automatica de IP/gateway disponivel nesta versao no Windows';
 {$ENDIF}
end;
function TNativeWiFi8KBackend.Restore(const SSID:string):Boolean;begin Result:=FWifi.ConnectExisting(SSID);end;
function TWiFi8KPanel.EditField(const ACaption:string;Y:Integer):TEdit;
var L:TLabel;
begin L:=TLabel.Create(Self);L.Parent:=Self;L.SetBounds(12,Y+3,200,18);L.Caption:=ACaption;
 Result:=TEdit.Create(Self);Result.Parent:=Self;Result.SetBounds(215,Y,245,24);end;
constructor TWiFi8KPanel.Create(AOwner:TComponent);
var L:TLabel;
begin
 inherited Create(AOwner);Align:=alClient;BorderStyle:=bsNone;
 L:=TLabel.Create(Self);L.Parent:=Self;L.SetBounds(12,10,450,44);L.AutoSize:=False;L.WordWrap:=True;
 L.Caption:='WIFI_8K experimental: escolha o candidato. O simulador usa os mesmos pacotes; compatibilidade do equipamento real ainda nao confirmada.';
 FVariant:=TComboBox.Create(Self);FVariant.Parent:=Self;FVariant.SetBounds(12,62,448,26);FVariant.Style:=csDropDownList;
 FVariant.Items.Add('Legacy 9 bytes - 03 66 ... 99 (UDP 7099)');FVariant.Items.Add('E58 8 bytes - 66 ... 99 (UDP 8090 / auxiliar 8080)');
 FEnable:=TCheckBox.Create(Self);FEnable.Parent:=Self;FEnable.SetBounds(12,96,448,25);FEnable.Caption:='Permitir comandos reais experimentais neste perfil';
 FPrefix:=EditField('Prefixo SSID:',130);FInterface:=EditField('Interface Wi-Fi (opcional):',160);
 FHost:=EditField('IP/gateway (a confirmar):',190);FControlPort:=EditField('Porta controle (0 desconhecida):',220);
 FVideoPort:=EditField('Porta auxiliar E58 (8080):',250);FRate:=EditField('Taxa de comandos (Hz):',280);
 FTimeout:=EditField('Prazo de conexao (ms):',310);FPassword:=EditField('Senha da rede (nao salva aqui):',340);FPassword.PasswordChar:='*';
 FVideoURL:=EditField('URL de video FPV (opcional):',375);
 FSave:=TButton.Create(Self);FSave.Parent:=Self;FSave.SetBounds(12,420,135,28);FSave.Caption:='Salvar perfil';FSave.OnClick:=@SaveClick;
 FScan:=TButton.Create(Self);FScan.Parent:=Self;FScan.SetBounds(155,420,145,28);FScan.Caption:='Procurar Wi-Fi';FScan.OnClick:=@ScanClick;
 FConnect:=TButton.Create(Self);FConnect.Parent:=Self;FConnect.SetBounds(310,420,150,28);FConnect.Caption:='Conectar Wi-Fi';FConnect.OnClick:=@ConnectClick;
 FNetworks:=TListBox.Create(Self);FNetworks.Parent:=Self;FNetworks.SetBounds(12,460,448,95);
 FRestore:=TButton.Create(Self);FRestore.Parent:=Self;FRestore.SetBounds(12,560,210,28);FRestore.Caption:='Voltar a rede anterior';FRestore.OnClick:=@RestoreClick;
 FInfo:=TButton.Create(Self);FInfo.Parent:=Self;FInfo.SetBounds(240,560,220,28);FInfo.Caption:='Ler IP/gateway';FInfo.OnClick:=@InfoClick;
 FStatus:=TLabel.Create(Self);FStatus.Parent:=Self;FStatus.SetBounds(12,600,448,75);FStatus.AutoSize:=False;FStatus.WordWrap:=True;
 FLog:=TMemo.Create(Self);FLog.Parent:=Self;FLog.SetBounds(12,690,448,110);FLog.ReadOnly:=True;FLog.ScrollBars:=ssAutoVertical;
 FBackend:=TNativeWiFi8KBackend.Create(Self);FBackend.Wifi.OnWait:=@Wait;FBackend.Wifi.OnLog:=@Log;
 FTimer:=TTimer.Create(Self);FTimer.Interval:=2000;FTimer.OnTimer:=@Tick;FTimer.Enabled:=True;
 LoadSettings;FVariant.OnChange:=@VariantChanged;ShowStatus;
end;
destructor TWiFi8KPanel.Destroy;
begin if Assigned(FTimer) then FTimer.Enabled:=False;FSession.Free;FBackend.Free;inherited Destroy;end;
procedure TWiFi8KPanel.LoadSettings;
begin
 if not Assigned(FSetMain) then Exit;
 with FSetMain.WiFi8K do begin FVideoURL.Text:=VideoURL;FVariant.ItemIndex:=Ord(Variant);FEnable.Checked:=RealEnabled;FPrefix.Text:=SSIDPrefix;FInterface.Text:=InterfaceName;FHost.Text:=Host;
 FControlPort.Text:=IntToStr(ControlPort);FVideoPort.Text:=IntToStr(VideoPort);FRate.Text:=IntToStr(RateHz);
 FTimeout.Text:=IntToStr(ConnectTimeoutMs);end;
end;
function TWiFi8KPanel.ReadSettings(out S:TWiFi8KSettings):Boolean;
var E:string;
begin
 S:=FSetMain.WiFi8K;S.Variant:=TWiFi8KVariant(Max(0,FVariant.ItemIndex));S.RealEnabled:=FEnable.Checked;S.VideoURL:=Trim(FVideoURL.Text);S.SSIDPrefix:=Trim(FPrefix.Text);S.InterfaceName:=Trim(FInterface.Text);S.Host:=Trim(FHost.Text);
 S.ControlPort:=StrToIntDef(FControlPort.Text,-1);S.VideoPort:=StrToIntDef(FVideoPort.Text,-1);
 S.RateHz:=StrToIntDef(FRate.Text,-1);S.ConnectTimeoutMs:=StrToIntDef(FTimeout.Text,0);
 Result:=ValidateWiFi8KSettings(S,E);if not Result then Log(E);
end;
function TWiFi8KPanel.SaveSettings:Boolean;
var S:TWiFi8KSettings;
begin Result:=Assigned(FSetMain) and ReadSettings(S);if Result then FSetMain.WiFi8K:=S;end;
procedure TWiFi8KPanel.SaveClick(Sender:TObject);
begin if SaveSettings then begin FSetMain.SalvaContexto;Log('Perfil salvo. Start usa a variante selecionada; envio real exige a permissao do perfil.');end;end;
procedure TWiFi8KPanel.Log(const Message:string);
begin FLog.Lines.Add(Message);while FLog.Lines.Count>100 do FLog.Lines.Delete(0);end;
procedure TWiFi8KPanel.Wait(Sender:TObject);
begin Application.ProcessMessages;
 if FSetMain.SimulationMode then raise EAbort.Create('WIFI_8K real interrompido: modo simulador selecionado');end;
procedure TWiFi8KPanel.Busy(Value:Boolean);
begin FBusy:=Value;FScan.Enabled:=not Value;FConnect.Enabled:=not Value;FRestore.Enabled:=not Value;FSave.Enabled:=not Value;FInfo.Enabled:=not Value;end;
procedure TWiFi8KPanel.VariantChanged(Sender:TObject);
begin
 if FVariant.ItemIndex=1 then begin FControlPort.Text:='8090';FVideoPort.Text:='8080';end
 else begin FControlPort.Text:='7099';FVideoPort.Text:='8080';end;FRate.Text:='25';
end;
procedure TWiFi8KPanel.ScanClick(Sender:TObject);
var S:TWiFi8KSettings;I:Integer;
begin
 if FBusy then Exit;
 if FSetMain.SimulationMode then begin Log('Desmarque Modo simulador para procurar o equipamento real.');Exit;end;
 if not ReadSettings(S) then Exit;
 if Assigned(FSession) and (FSession.PreviousSSID<>'') then begin
  Log('Use Voltar a rede anterior antes de iniciar outra busca.');Exit;end;
 Busy(True);
 try
  FreeAndNil(FSession);FSession:=TWiFi8KSession.Create(FBackend,S);FBackend.Wifi.InterfaceName:=S.InterfaceName;
  FNetworks.Clear;Log('Procurando redes com prefixo '+S.SSIDPrefix+'...');
  if not FSession.Discover then Log('Falha na busca: '+FSession.LastError)
  else begin for I:=0 to High(FSession.Networks) do FNetworks.Items.Add(Format('%s | %d%% | %s',
   [FSession.Networks[I].SSID,FSession.Networks[I].Signal,FSession.Networks[I].BSSID]));
   if FNetworks.Count>0 then FNetworks.ItemIndex:=0 else Log('Nenhuma rede do perfil encontrada.');end;
 except on E:Exception do Log(E.Message);end;
 Busy(False);ShowStatus;
end;
procedure TWiFi8KPanel.ConnectClick(Sender:TObject);
var I:Integer;
begin
 if FBusy then Exit;
 if FSetMain.SimulationMode then begin Log('Modo simulador ativo: associacao Wi-Fi real desativada.');Exit;end;
 if Assigned(frmMain) and Assigned(frmMain.frmConnection) then begin Log('Desligue Start antes de mudar a rede Wi-Fi.');Exit;end;
 if not Assigned(FSession) then begin ScanClick(nil);if not Assigned(FSession) then Exit;end;
 I:=FNetworks.ItemIndex;if (I<0) or (I>High(FSession.Networks)) then begin Log('Selecione uma rede na lista.');Exit;end;
 Busy(True);
 try if FSession.Connect(FSession.Networks[I].SSID,FPassword.Text) then
  begin FSetMain.WiFi8K.TargetSSID:=FSession.ConnectedSSID;
  Log('Wi-Fi associado a '+FSession.ConnectedSSID+'. Isso nao confirma video ou controle de voo.');end
 else Log(FSession.LastError);
 except on E:Exception do Log(E.Message);end;
 Busy(False);ShowStatus;
end;
procedure TWiFi8KPanel.InfoClick(Sender:TObject);
var Data,E,Alias,LocalIP,Gateway:string;
begin
 if FBusy or not Assigned(FSession) then Exit;
 FSession.CheckLink;
 if FSession.State<>w8Associated then begin Log('Conecte primeiro a rede selecionada.');Exit;end;
 Busy(True);
 try
  if FBackend.NetworkInfo(Data,E) then begin
   FSession.CheckLink;
   if FSession.State<>w8Associated then Log('Rede mudou durante a leitura; repita a conexao.')
   else if SelectWiFi8KNetworkInfo(Data,FBackend.Wifi.InterfaceName,Alias,LocalIP,Gateway) then begin
    Log('Interface '+Alias+' | IP local '+LocalIP+' | gateway '+Gateway);
    FSetMain.WiFi8K.BindIP:=LocalIP;
    if Gateway<>'' then begin FHost.Text:=Gateway;Log('Gateway observado preenchido no perfil; portas e comandos continuam sem validacao.');end
    else Log('Gateway ainda nao recebido. Aguarde DHCP e tente novamente.');
   end else Log('IP ainda indisponivel ou mais de uma interface Wi-Fi. Informe a interface no perfil.');
  end else Log(E);
 except on Ex:Exception do Log(Ex.Message);end;
 Busy(False);ShowStatus;
end;
procedure TWiFi8KPanel.RestoreClick(Sender:TObject);
begin if FBusy or not Assigned(FSession) then Exit;
 if Assigned(frmMain) and Assigned(frmMain.frmConnection) then begin Log('Desligue Start antes de mudar a rede Wi-Fi.');Exit;end;
 if FSession.RestorePrevious then Log('Solicitada volta a rede anterior.') else Log('Nenhuma rede anterior restaurada.');ShowStatus;end;
procedure TWiFi8KPanel.Tick(Sender:TObject);
begin if FBusy or not IsVisible or not Assigned(FSession) then Exit;
 FSession.CheckLink;ShowStatus;end;
procedure TWiFi8KPanel.ShowStatus;
var S:string;
begin
 S:='nao conectado';
 if Assigned(FSession) then case FSession.State of
 w8Detected:S:='rede detectada';w8Associating:S:='conectando';w8Associated:S:='associado a '+FSession.ConnectedSSID;w8Lost:S:='conexao perdida';end;
 FStatus.Caption:='Wi-Fi: '+S+LineEnding+'Video real: nao identificado | Controle: candidato experimental'+LineEnding+'Telemetria e voo: nao validados';
end;
end.
