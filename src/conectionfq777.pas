unit conectionfq777;

{ Conexão exclusiva do quadricóptero FQ777-954.

  Usa os componentes da Lazarus AI Suite (CHATGPT):
    TAIWifi        - acha a rede Wi-Fi do drone e conecta (openai_hardware)
    TAIDroneFQ777  - protocolo do drone: comandos e vídeo (openai_drone)
    TAIH264Decoder - transforma o vídeo H.264 em imagem (openai_video)
    TAIJoystick    - controle XInput/genérico com eixos proporcionais (openai_input)

  Se a rede do drone não for encontrada, Iniciar retorna False e o cockpit não
  liga o equipamento.

  Comandos (padrão, ajustáveis na configuração):
    Manche esquerdo X/Y = rolagem/arfagem, manche direito X = guinada,
    gatilho direito = aceleração, botão B = corte dos motores.
    Teclado: W/S arfagem, A/D rolagem, Q/E guinada, setas cima/baixo
    aceleração, Espaço = corte dos motores. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Dialogs,
  LCLType, LCLIntf, aidronefq777, aih264decoder, aijoystick, aiwifi;

type

  { TfrmConectionFQ777 }

  TfrmConectionFQ777 = class(TForm)
  private
    FDrone: TAIDroneFQ777;
    FDecoder: TAIH264Decoder;
    FJoystick: TAIJoystick;
    FWifi: TAIWifi;
    FTimer: TTimer;

    FLbWifi: TLabel;
    FLbControle: TLabel;
    FLbVideo: TLabel;
    FLbComando: TLabel;
    FLbEntrada: TLabel;
    FMemo: TMemo;

    FBitmap: TBitmap;
    FUltimaImagem: TDateTime;
    FAceleradorTeclado: Double;
    FCorte: Boolean;
    FUltimoTick: QWord;
    FUltimaTela: QWord;
    FRedeAnterior: string;
    FRedeDrone: string;
    FIniciando: Boolean;
    FUltimoErro: string;

    procedure MontaTela;
    procedure Log(const ATexto: string);
    procedure LogWifi(const ATexto: string);
    procedure EsperaWifi(Sender: TObject);
    function PreparaWifi: Boolean;

    procedure DroneStatus(Sender: TObject; const AMessage: string);
    procedure DroneErro(Sender: TObject; const AMessage: string);
    procedure DroneEstado(Sender: TObject);
    procedure DroneVideo(Sender: TObject; AData: PByte; ACount: Integer);
    procedure DecoderQuadro(Sender: TObject; ABitmap: TBitmap);
    procedure DecoderErro(Sender: TObject; const AMessage: string);

    procedure TimerControle(Sender: TObject);
    procedure BtCorteClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    function TeclaPressionada(AKey: Word): Boolean;
    function LeEixo(const AState: TAIJoystickState; AIndice: Integer): Double;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Conecta no Wi-Fi do drone (se configurado) e inicia a comunicação.
      False = drone não encontrado; o motivo fica em UltimoErro. }
    function Iniciar: Boolean;
    procedure Encerrar;
    { Aceleração zero até o acelerador voltar ao mínimo. }
    procedure CorteMotores;

    property Bitmap: TBitmap read FBitmap;
    property UltimaImagemDataHora: TDateTime read FUltimaImagem;
    property Drone: TAIDroneFQ777 read FDrone;
    property Decoder: TAIH264Decoder read FDecoder;
    property UltimoErro: string read FUltimoErro;
  end;

implementation

uses
  setmain, Camera;

const
  TAXA_ACELERADOR_TECLADO = 0.5; // fração do curso por segundo

{ TfrmConectionFQ777 }

constructor TfrmConectionFQ777.Create(AOwner: TComponent);
begin
  // Formulário montado em código: não há .lfm para carregar.
  inherited CreateNew(AOwner, 0);
  Caption := 'FQ777-954';
  Width := 300;
  Height := 470;
  Position := poDesigned;
  if Screen.Width > 0 then
    Left := Screen.Width - Width - 40;
  Top := 120;
  OnCloseQuery := @FormCloseQuery;

  FBitmap := TBitmap.Create;

  FWifi := TAIWifi.Create(Self);
  FWifi.OnWait := @EsperaWifi;
  FWifi.OnLog := @LogWifi;

  FDrone := TAIDroneFQ777.Create(Self);
  FDrone.OnStatus := @DroneStatus;
  FDrone.OnError := @DroneErro;
  FDrone.OnStateChange := @DroneEstado;
  FDrone.OnVideoData := @DroneVideo;

  FDecoder := TAIH264Decoder.Create(Self);
  FDecoder.Width := FQ777_VIDEO_WIDTH;
  FDecoder.Height := FQ777_VIDEO_HEIGHT;
  FDecoder.OnFrame := @DecoderQuadro;
  FDecoder.OnError := @DecoderErro;

  FJoystick := TAIJoystick.Create(Self);

  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 50;
  FTimer.OnTimer := @TimerControle;

  MontaTela;
end;

destructor TfrmConectionFQ777.Destroy;
begin
  Encerrar;
  FreeAndNil(FBitmap);
  inherited Destroy;
end;

procedure TfrmConectionFQ777.MontaTela;
var
  Topo: TPanel;
  Bt: TButton;

  function NovoRotulo(ATop: Integer; const ATitulo: string): TLabel;
  begin
    with TLabel.Create(Self) do
    begin
      Parent := Topo;
      Left := 8;
      Top := ATop;
      Caption := ATitulo;
      Font.Style := [fsBold];
    end;
    Result := TLabel.Create(Self);
    Result.Parent := Topo;
    Result.Left := 80;
    Result.Top := ATop;
    Result.Caption := '-';
  end;

begin
  Topo := TPanel.Create(Self);
  Topo.Parent := Self;
  Topo.Align := alTop;
  Topo.Height := 160;
  Topo.BevelOuter := bvNone;

  FLbWifi := NovoRotulo(8, 'Wi-Fi:');
  FLbControle := NovoRotulo(28, 'Controle:');
  FLbVideo := NovoRotulo(48, 'Vídeo:');
  FLbComando := NovoRotulo(68, 'Comando:');
  FLbEntrada := NovoRotulo(88, 'Entrada:');

  Bt := TButton.Create(Self);
  Bt.Parent := Topo;
  Bt.Left := 8;
  Bt.Top := 116;
  Bt.Width := Topo.Width - 16;
  Bt.Anchors := [akLeft, akTop, akRight];
  Bt.Height := 32;
  Bt.Caption := 'CORTAR MOTORES (Espaço)';
  Bt.Font.Style := [fsBold];
  Bt.Font.Color := clRed;
  Bt.OnClick := @BtCorteClick;

  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := alClient;
  FMemo.ReadOnly := True;
  FMemo.ScrollBars := ssAutoVertical;
end;

procedure TfrmConectionFQ777.Log(const ATexto: string);
begin
  if Assigned(FMemo) then
    FMemo.Append(FormatDateTime('hh:nn:ss', Now) + '  ' + ATexto);
end;

procedure TfrmConectionFQ777.LogWifi(const ATexto: string);
begin
  Log(ATexto);
  if Assigned(FLbWifi) then
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
    FUltimoErro := 'Não foi possível procurar redes Wi-Fi: ' + FWifi.LastError;
    LogWifi(FUltimoErro);
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
    FUltimoErro := 'Rede Wi-Fi do FQ777-954 não encontrada (procurado: "' + Padrao +
      '"). Ligue o drone, aguarde o LED piscar e tente de novo. Redes visíveis: ' +
      Lista + '. Se o nome da rede do drone for outro, ajuste em Configuração > FQ777-954.';
    LogWifi('Rede do drone não encontrada.');
    Log(FUltimoErro);
    Exit;
  end;

  LogWifi(Format('Conectando em %s (sinal %d%%)...', [Rede.SSID, Rede.Signal]));
  if not FWifi.Connect(Rede.SSID, FSetMain.FQ777.WifiSenha) or
     not FWifi.WaitForConnection(Rede.SSID, 20000) then
  begin
    FUltimoErro := 'Não foi possível conectar na rede ' + Rede.SSID + ': ' + FWifi.LastError;
    LogWifi('Falha ao conectar no Wi-Fi do drone.');
    Log(FUltimoErro);
    if FRedeAnterior <> '' then
      FWifi.ConnectExisting(FRedeAnterior);
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

function TfrmConectionFQ777.Iniciar: Boolean;
var
  Pasta: string;
  Principal: TCustomForm;
begin
  Result := False;
  FUltimoErro := '';
  if FDrone.Active then
    Exit(True);

  Principal := nil;
  if Owner is TCustomForm then
    Principal := TCustomForm(Owner);

  FIniciando := True;
  if Assigned(Principal) then
    Principal.Enabled := False; // evita religar/desligar no meio da busca
  Screen.Cursor := crHourGlass;
  try
    with FSetMain.FQ777 do
    begin
      FDrone.Host := IP;
      FDrone.TcpPort := PortaTCP;
      FDrone.UdpPort := PortaUDP;
      FDrone.VideoEnabled := Video;
      FDrone.DeadZone := EnsureRange(ZonaMorta, 0, 50) / 100;
      FDecoder.FFmpegPath := FFmpeg;
      FDecoder.RecordFileName := '';
      if Video and GravarVideo then
      begin
        Pasta := ExtractFilePath(ParamStr(0)) + 'videos';
        ForceDirectories(Pasta);
        FDecoder.RecordFileName := IncludeTrailingPathDelimiter(Pasta) +
          'FQ777_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.h264';
      end;

      if WifiAuto then
      begin
        if not PreparaWifi then
          Exit;
      end
      else
        LogWifi('Conexão automática desligada (rede gerenciada pelo usuário).');
    end;

    FAceleradorTeclado := 0;
    FCorte := True; // inicia bloqueado ate habilitacao explicita em revisao futura
    FUltimoTick := GetTickCount64;
    FDrone.Connect;
    FTimer.Enabled := True;
    Result := True;
  finally
    Screen.Cursor := crDefault;
    if Assigned(Principal) then
      Principal.Enabled := True;
    FIniciando := False;
  end;
end;

procedure TfrmConectionFQ777.Encerrar;
begin
  if Assigned(FTimer) then
    FTimer.Enabled := False;
  if Assigned(FDrone) then
    FDrone.Disconnect; // envia aceleração zero antes de fechar
  if Assigned(FDecoder) then
    FDecoder.Stop;
  if Assigned(FWifi) and (FRedeAnterior <> '') then
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
  if Assigned(FDrone) then
    FDrone.Throttle := 0;
end;

procedure TfrmConectionFQ777.BtCorteClick(Sender: TObject);
begin
  CorteMotores;
  Log('Corte dos motores acionado.');
end;

procedure TfrmConectionFQ777.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  // Fechar a janela não desconecta (use o botão Start do cockpit).
  CanClose := not FIniciando;
  if CanClose then
  begin
    Hide;
    CanClose := False;
  end;
end;

procedure TfrmConectionFQ777.DroneStatus(Sender: TObject; const AMessage: string);
begin
  Log(AMessage);
end;

procedure TfrmConectionFQ777.DroneErro(Sender: TObject; const AMessage: string);
begin
  Log('ERRO: ' + AMessage);
end;

procedure TfrmConectionFQ777.DroneEstado(Sender: TObject);
begin
  if FDrone.ControlConnected then
    FLbControle.Caption := 'conectado'
  else
    FLbControle.Caption := 'desconectado';
  if not FDrone.VideoEnabled then
    FLbVideo.Caption := 'desligado'
  else if FDrone.VideoConnected then
    FLbVideo.Caption := 'aguardando imagem'
  else
    FLbVideo.Caption := 'desconectado';
end;

procedure TfrmConectionFQ777.DroneVideo(Sender: TObject; AData: PByte; ACount: Integer);
begin
  // Linha de rede: só repassa ao decodificador (seguro entre linhas).
  FDecoder.Feed(AData^, ACount);
end;

procedure TfrmConectionFQ777.DecoderQuadro(Sender: TObject; ABitmap: TBitmap);
begin
  FBitmap.Assign(ABitmap);
  FUltimaImagem := Now;
  if Assigned(frmCam) and frmCam.CameraAtiva and frmCam.Visible then
    frmCam.MostraQuadro(ABitmap);
end;

procedure TfrmConectionFQ777.DecoderErro(Sender: TObject; const AMessage: string);
begin
  Log('Vídeo: ' + AMessage);
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

procedure TfrmConectionFQ777.TimerControle(Sender: TObject);
var
  S: TAIJoystickState;
  Rolagem, Arfagem, Guinada, AceleradorJoy, Acelerador, Dt: Double;
  Agora: QWord;
  BotaoCorte: Boolean;
begin
  Agora := GetTickCount64;
  Dt := (Agora - FUltimoTick) / 1000;
  FUltimoTick := Agora;
  if Dt > 0.5 then
    Dt := 0.5;

  S := Default(TAIJoystickState);
  if FJoystick.Poll then
    S := FJoystick.State;

  with FSetMain.FQ777 do
  begin
    Rolagem := LeEixo(S, EixoRolagem);
    Arfagem := LeEixo(S, EixoArfagem);
    Guinada := LeEixo(S, EixoGuinada);
    if AceleradorCentrado then
      AceleradorJoy := (LeEixo(S, EixoAcelerador) + 1) / 2
    else
      AceleradorJoy := Max(0, LeEixo(S, EixoAcelerador));
  end;

  // Teclado soma ao joystick (sem joystick, comanda sozinho).
  if TeclaPressionada(VK_W) then Arfagem := Arfagem + 1;
  if TeclaPressionada(VK_S) then Arfagem := Arfagem - 1;
  if TeclaPressionada(VK_D) then Rolagem := Rolagem + 1;
  if TeclaPressionada(VK_A) then Rolagem := Rolagem - 1;
  if TeclaPressionada(VK_E) then Guinada := Guinada + 1;
  if TeclaPressionada(VK_Q) then Guinada := Guinada - 1;
  if TeclaPressionada(VK_UP) then
    FAceleradorTeclado := Min(1, FAceleradorTeclado + TAXA_ACELERADOR_TECLADO * Dt);
  if TeclaPressionada(VK_DOWN) then
    FAceleradorTeclado := Max(0, FAceleradorTeclado - TAXA_ACELERADOR_TECLADO * Dt);

  BotaoCorte := TeclaPressionada(VK_SPACE) or (S.Connected and S.Controls[ajB]);
  if BotaoCorte and not FCorte then
  begin
    CorteMotores;
    Log('Corte dos motores acionado.');
  end;

  Acelerador := Max(AceleradorJoy, FAceleradorTeclado);
  if FCorte then
  begin
    // Bloqueio persistente: retorno do acelerador ao minimo nao rearma motores.
    Acelerador := 0;
  end;

  // Nao transmitir comandos enquanto o canal de controle estiver desconectado.
  if not FDrone.ControlConnected then
  begin
    FCorte := True;
    FAceleradorTeclado := 0;
    FLbControle.Caption := 'desconectado - motores bloqueados';
    Exit;
  end;

  FDrone.SetSticks(EnsureRange(Rolagem, -1, 1), EnsureRange(Arfagem, -1, 1),
    EnsureRange(Guinada, -1, 1), Acelerador);

  if Agora - FUltimaTela >= 250 then
  begin
    FUltimaTela := Agora;
    FLbComando.Caption := TAIDroneFQ777.PacketToHex(FDrone.LastPacket);
    if S.Connected then
      FLbEntrada.Caption := S.DeviceName
    else
      FLbEntrada.Caption := 'teclado (sem joystick)';
    if FDrone.VideoEnabled and FDrone.VideoStreaming then
      FLbVideo.Caption := Format('%d quadros', [FDecoder.FramesDecoded]);
  end;
end;

end.
