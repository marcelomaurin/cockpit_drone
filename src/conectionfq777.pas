unit conectionfq777;

{ Conexão exclusiva do quadricóptero FQ777-954.

  Base comum: conexaodrone.pas (janela, mensagens, vídeo H.264, temporizador).
  Componentes da Lazarus AI Suite (CHATGPT):
    TAIWifi        - acha a rede Wi-Fi do drone e conecta (openai_hardware)
    TAIDroneFQ777  - protocolo do drone: comandos e vídeo (openai_drone)
    TAIJoystick    - controle XInput/genérico com eixos proporcionais (openai_input)

  Se a rede do drone não for encontrada, Iniciar retorna False e o cockpit não
  liga o equipamento.

  Entrada própria (em vez do manche do frmMain), configurável em
  Configuração > FQ777-954:
    Manche esquerdo X/Y = rolagem/arfagem, manche direito X = guinada,
    gatilho direito = aceleração, botão B = corte dos motores.
    Teclado: W/S arfagem, A/D rolagem, Q/E guinada, setas cima/baixo
    aceleração, Espaço = corte dos motores. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, StdCtrls, Dialogs, LCLType, LCLIntf,
  conexaodrone, aidronefq777, aijoystick, aiwifi;

type

  { TfrmConectionFQ777 }

  TfrmConectionFQ777 = class(TfrmConexaoDrone)
  private
    FFQ: TAIDroneFQ777;
    FJoystick: TAIJoystick;
    FWifi: TAIWifi;
    FLbWifi: TLabel;
    FLbControle: TLabel;
    FLbComando: TLabel;
    FLbEntrada: TLabel;
    FAceleradorTeclado: Double;
    FCorte: Boolean;
    FUltimoTick: QWord;
    FRedeAnterior: string;
    FRedeDrone: string;
    FEntrada: string;
    FJoystickAnteriorConectado: Boolean;
    procedure LogWifi(const ATexto: string);
    procedure EsperaWifi(Sender: TObject);
    function PreparaWifi: Boolean;
    procedure BtCorteClick(Sender: TObject);
    procedure BtRearmarClick(Sender: TObject);
    function TeclaPressionada(AKey: Word): Boolean;
    function LeEixo(const AState: TAIJoystickState; AIndice: Integer): Double;
  protected
    function Conectar: Boolean; override;
    procedure Desconectar; override;
    function LeComando: TComandoManche; override;
    procedure Controle(const C: TComandoManche); override;
    procedure AtualizaPainel; override;
  public
    constructor Create(AOwner: TComponent); override;
    { Aceleração zero até o acelerador voltar ao mínimo. }
    procedure CorteMotores;
    property FQ777: TAIDroneFQ777 read FFQ;
  end;

implementation

uses
  setmain, main;

const
  TAXA_ACELERADOR_TECLADO = 0.5; // fração do curso por segundo

{ TfrmConectionFQ777 }

constructor TfrmConectionFQ777.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'FQ777-954';
  FWifi := TAIWifi.Create(Self);
  FWifi.OnWait := @EsperaWifi;
  FWifi.OnLog := @LogWifi;
  FFQ := TAIDroneFQ777.Create(Self);
  UsaDrone(FFQ);
  FJoystick := TAIJoystick.Create(Self);
  FLbWifi := NovaLinha('Wi-Fi:');
  FLbControle := NovaLinha('Controle:');
  FLbComando := NovaLinha('Comando:');
  FLbEntrada := NovaLinha('Entrada:');
  NovoBotao('CORTAR MOTORES (Espaço)', @BtCorteClick, True);
  NovoBotao('REARMAR (confirmação obrigatória)', @BtRearmarClick);
end;

procedure TfrmConectionFQ777.LogWifi(const ATexto: string);
begin
  Log(ATexto);
  FLbWifi.Caption := ATexto;
end;

procedure TfrmConectionFQ777.EsperaWifi(Sender: TObject);
begin
  Application.ProcessMessages;
end;

function TfrmConectionFQ777.PreparaWifi: Boolean;
var
  Padrao, Lista: string;
  Rede: TAIWifiNetwork;
  I: Integer;
  T: QWord;
begin
  Result := False;
  Padrao := FSetMain.FQ777.WifiSSID;
  if Trim(Padrao) = '' then
    Padrao := 'FQ777';

  FRedeAnterior := FWifi.CurrentSSID;
  if TAIWifi.MatchesPattern(FRedeAnterior, Padrao) then
  begin
    FRedeDrone := FRedeAnterior;
    FRedeAnterior := '';
    LogWifi('Já conectado em ' + FRedeDrone);
    Exit(True);
  end;

  LogWifi('Procurando a rede do FQ777-954 ("' + Padrao + '")...');
  if not FWifi.Scan(True) then
  begin
    DefineErro('Não foi possível procurar redes Wi-Fi: ' + FWifi.LastError);
    Exit;
  end;

  if not FWifi.FindNetwork(Padrao, Rede) then
  begin
    Lista := '';
    for I := 0 to High(FWifi.Networks) do
    begin
      if Lista <> '' then
        Lista := Lista + ', ';
      Lista := Lista + FWifi.Networks[I].SSID;
    end;
    if Lista = '' then
      Lista := 'nenhuma';
    LogWifi('Rede do drone não encontrada.');
    DefineErro('Rede Wi-Fi do FQ777-954 não encontrada (procurado: "' + Padrao +
      '"). Ligue o drone, aguarde o LED piscar e tente de novo. Redes visíveis: ' +
      Lista + '. Se o nome da rede do drone for outro, ajuste em Configuração > FQ777-954.');
    Exit;
  end;

  LogWifi(Format('Conectando em %s (sinal %d%%)...', [Rede.SSID, Rede.Signal]));
  if not FWifi.Connect(Rede.SSID, FSetMain.FQ777.WifiSenha) or
     not FWifi.WaitForConnection(Rede.SSID, 20000) then
  begin
    LogWifi('Falha ao conectar no Wi-Fi do drone.');
    DefineErro('Não foi possível conectar na rede ' + Rede.SSID + ': ' + FWifi.LastError);
    if FRedeAnterior <> '' then
      FWifi.ConnectExisting(FRedeAnterior);
    FRedeAnterior := '';
    Exit;
  end;

  FRedeDrone := Rede.SSID;
  LogWifi('Conectado em ' + FRedeDrone);

  // Tempo para o drone entregar o endereço IP (DHCP).
  T := GetTickCount64 + 2500;
  while GetTickCount64 < T do
  begin
    Application.ProcessMessages;
    Sleep(50);
  end;
  Result := True;
end;

function TfrmConectionFQ777.Conectar: Boolean;
var
  Pasta: string;
  Principal: TCustomForm;
begin
  Result := False;
  Principal := nil;
  if Owner is TCustomForm then
    Principal := TCustomForm(Owner);
  if Assigned(Principal) then
    Principal.Enabled := False; // evita religar/desligar no meio da busca
  try
    with FSetMain.FQ777 do
    begin
      FFQ.Host := FSetMain.TargetHost(IP,'172.16.10.1');
      FFQ.TcpPort := PortaTCP;
      FFQ.UdpPort := PortaUDP;
      FFQ.VideoEnabled := Video and not FSetMain.SimulationMode;
      FFQ.DeadZone := EnsureRange(ZonaMorta, 0, 50) / 100;
      Decoder.RecordFileName := '';
      if Video and GravarVideo and not FSetMain.SimulationMode then
      begin
        Pasta := ExtractFilePath(ParamStr(0)) + 'videos';
        ForceDirectories(Pasta);
        Decoder.RecordFileName := IncludeTrailingPathDelimiter(Pasta) +
          'FQ777_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.h264';
      end;

      if WifiAuto and not FSetMain.SimulationMode then
      begin
        if not PreparaWifi then
          Exit;
      end
      else
        LogWifi('Conexão automática desligada (rede gerenciada pelo usuário).');

      PreparaVideo(Video and not FSetMain.SimulationMode, FQ777_VIDEO_WIDTH, FQ777_VIDEO_HEIGHT, FFmpeg);
    end;
    FAceleradorTeclado := 0;
    FJoystickAnteriorConectado := False;
    FCorte := True; // começa bloqueado: só o REARMAR libera os motores
    FUltimoTick := GetTickCount64;
    if FSetMain.SimulationMode then begin FFQ.TcpPort:=8888; FFQ.UdpPort:=8895; end;
    FFQ.ThrottleArmLock := True;
    FFQ.Connect;
    Result := FFQ.Active;
  finally
    if Assigned(Principal) then
      Principal.Enabled := True;
  end;
end;

procedure TfrmConectionFQ777.Desconectar;
begin
  FFQ.Disconnect; // envia aceleração zero antes de fechar
  if FRedeAnterior <> '' then
  begin
    Log('Voltando para a rede ' + FRedeAnterior);
    FWifi.ConnectExisting(FRedeAnterior);
    FRedeAnterior := '';
  end;
end;

procedure TfrmConectionFQ777.CorteMotores;
begin
  FCorte := True;
  FAceleradorTeclado := 0;
  FFQ.Throttle := 0;
  Log('Corte dos motores acionado.');
end;

procedure TfrmConectionFQ777.BtCorteClick(Sender: TObject);
begin
  CorteMotores;
end;

procedure TfrmConectionFQ777.BtRearmarClick(Sender: TObject);
var
  S: TAIJoystickState;
  AceleradorJoy: Double;
begin
  if not FCorte then Exit;
  if not FFQ.ControlConnected then
  begin
    Log('Rearme negado: controle desconectado.');
    Exit;
  end;
  S:=Default(TAIJoystickState);
  if FSetMain.JoystickAtivo then
  begin
    if not frmMain.JoystickController.Available then
    begin Log('Rearme negado: joystick indisponivel.'); Exit; end;
    AceleradorJoy:=frmMain.Controler.Acelerador;
    if (Abs(frmMain.Controler.Rolagem)>0.05) or
       (Abs(frmMain.Controler.Arfagem)>0.05) or
       (Abs(frmMain.Controler.Guinada)>0.05) or (frmMain.B4=255) then
    begin Log('Rearme negado: centralize a direcao e solte o botao de corte.'); Exit; end;
  end else begin
  S := Default(TAIJoystickState);
  if FJoystick.Poll then
    S := FJoystick.State;
  if FJoystickAnteriorConectado and not S.Connected then
  begin
    Log('Rearme negado: joystick desconectado.');
    Exit;
  end;
  with FSetMain.FQ777 do
  begin
    AceleradorJoy := 0;
    if S.Connected then
    begin
      if AceleradorCentrado then
        AceleradorJoy := (LeEixo(S, EixoAcelerador) + 1) / 2
      else
        AceleradorJoy := Max(0, LeEixo(S, EixoAcelerador));
    end;
    if S.Connected and
       ((Abs(LeEixo(S, EixoRolagem)) > 0.05) or
        (Abs(LeEixo(S, EixoArfagem)) > 0.05) or
        (Abs(LeEixo(S, EixoGuinada)) > 0.05)) then
    begin
      Log('Rearme negado: centralize os comandos direcionais.');
      Exit;
    end;
  end;
  end;
  if (AceleradorJoy >= 0.05) or (FAceleradorTeclado > 0) or
     TeclaPressionada(VK_UP) or TeclaPressionada(VK_SPACE) or
     (S.Connected and S.Controls[ajB]) then
  begin
    Log('Rearme negado: acelerador ou corte ativo.');
    Exit;
  end;
  if not FSetMain.SimulationMode and (MessageDlg('Rearmar FQ777',
    'Confirme somente em bancada sem hélices. Liberar comandos de motor?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then Exit;
  if not FFQ.ControlConnected then Exit;
  FCorte := False;
  Log('Rearme manual autorizado. Ainda não homologado para voo.');
end;

function TfrmConectionFQ777.TeclaPressionada(AKey: Word): Boolean;
begin
  Result := Application.Active and ((GetKeyState(AKey) and $8000) <> 0);
end;

function TfrmConectionFQ777.LeEixo(const AState: TAIJoystickState; AIndice: Integer): Double;
begin
  if AState.Connected and (AIndice >= 0) and (AIndice < AIJoystickAxes) then
    Result := AState.Axes[AIndice]
  else
    Result := 0;
end;

function TfrmConectionFQ777.LeComando: TComandoManche;
var
  S: TAIJoystickState;
  AceleradorJoy, Dt: Double;
  Agora: QWord;
  BotaoCorte: Boolean;
begin
  Result := Default(TComandoManche);
  Agora := GetTickCount64;
  Dt := Min(0.5, (Agora - FUltimoTick) / 1000);
  FUltimoTick := Agora;

  if FSetMain.JoystickAtivo then
  begin
    Result:=inherited LeComando;
    FEntrada:='Perfil de voo por marca/modelo';
    if Assigned(frmMain.JoystickController) then
    begin
      if FJoystickAnteriorConectado and not frmMain.JoystickController.Available then
      begin CorteMotores; Log('Joystick perdido: rearme manual necessario.'); end;
      FJoystickAnteriorConectado:=frmMain.JoystickController.Available;
    end;
    if Result.Apertou[4] then CorteMotores;
    if FCorte then begin Result.Acelerador:=0; Result.Rolagem:=0;
      Result.Arfagem:=0; Result.Guinada:=0; end;
    Exit;
  end;

  S := Default(TAIJoystickState);
  if FJoystick.Poll then
    S := FJoystick.State;
  if FJoystickAnteriorConectado and not S.Connected then
  begin
    CorteMotores;
    Log('Joystick perdido: corte travado até rearme manual.');
  end;
  FJoystickAnteriorConectado := S.Connected;
  if S.Connected then
    FEntrada := S.DeviceName
  else
    FEntrada := 'teclado (sem joystick)';

  with FSetMain.FQ777 do
  begin
    Result.Rolagem := LeEixo(S, EixoRolagem);
    Result.Arfagem := LeEixo(S, EixoArfagem);
    Result.Guinada := LeEixo(S, EixoGuinada);
    if AceleradorCentrado then
      AceleradorJoy := (LeEixo(S, EixoAcelerador) + 1) / 2
    else
      AceleradorJoy := Max(0, LeEixo(S, EixoAcelerador));
  end;

  // Teclado soma ao joystick (sem joystick, comanda sozinho).
  if TeclaPressionada(VK_W) then Result.Arfagem := Result.Arfagem + 1;
  if TeclaPressionada(VK_S) then Result.Arfagem := Result.Arfagem - 1;
  if TeclaPressionada(VK_D) then Result.Rolagem := Result.Rolagem + 1;
  if TeclaPressionada(VK_A) then Result.Rolagem := Result.Rolagem - 1;
  if TeclaPressionada(VK_E) then Result.Guinada := Result.Guinada + 1;
  if TeclaPressionada(VK_Q) then Result.Guinada := Result.Guinada - 1;
  if TeclaPressionada(VK_UP) then
    FAceleradorTeclado := Min(1, FAceleradorTeclado + TAXA_ACELERADOR_TECLADO * Dt);
  if TeclaPressionada(VK_DOWN) then
    FAceleradorTeclado := Max(0, FAceleradorTeclado - TAXA_ACELERADOR_TECLADO * Dt);
  Result.Rolagem := EnsureRange(Result.Rolagem, -1, 1);
  Result.Arfagem := EnsureRange(Result.Arfagem, -1, 1);
  Result.Guinada := EnsureRange(Result.Guinada, -1, 1);

  BotaoCorte := TeclaPressionada(VK_SPACE) or (S.Connected and S.Controls[ajB]);
  if BotaoCorte and not FCorte then
    CorteMotores;

  Result.Acelerador := Max(AceleradorJoy, FAceleradorTeclado);
  if FCorte then
  begin
    // Corte bloqueia todos os eixos e a aceleração até o REARMAR.
    Result.Acelerador := 0;
    Result.Rolagem := 0;
    Result.Arfagem := 0;
    Result.Guinada := 0;
  end;
end;

procedure TfrmConectionFQ777.Controle(const C: TComandoManche);
begin
  // Sem o canal de controle, nada é transmitido e o corte fica travado.
  if not FFQ.ControlConnected then
  begin
    FCorte := True;
    FAceleradorTeclado := 0;
    Exit;
  end;
  FFQ.SetSticks(C.Rolagem, C.Arfagem, C.Guinada, C.Acelerador);
end;

procedure TfrmConectionFQ777.AtualizaPainel;
begin
  if FFQ.ControlConnected and FCorte then
    FLbControle.Caption := 'conectado - motores bloqueados (REARMAR)'
  else if FFQ.ControlConnected then
    FLbControle.Caption := Format('conectado (%d pacotes)', [FFQ.PacketsSent])
  else if FFQ.Active then
    FLbControle.Caption := 'conectando...'
  else
    FLbControle.Caption := 'desconectado - motores bloqueados';
  FLbComando.Caption := TAIDroneFQ777.PacketToHex(FFQ.LastPacket);
  FLbEntrada.Caption := FEntrada;
end;

end.
