unit conexaodrone;

{ Base das janelas de conexão dos drones.

  O protocolo de cada drone é um componente da Lazarus AI Suite (CHATGPT,
  pacote openai_drone); esta base reúne o que é igual para todos e antes se
  repetia em cada janela:
    - janela montada em código: quadro de informações (título e valor),
      botões e registro de mensagens;
    - eventos do componente (mensagens, erros, estado, telemetria) e vídeo
      H.264 entregue ao TAIH264Decoder, com o último quadro em Bitmap e na
      janela da câmera;
    - temporizador que lê o manche do frmMain e chama Controle;
    - fechar a janela só esconde (quem desliga é o botão Start do cockpit).

  Comandos do frmMain convertidos em TComandoManche:
    X/Y = rolagem/arfagem (+ = direita/frente), botões 1/2 = guinada,
    Z = aceleração (0..1) ou subida (-1..1, centro = pairar),
    botões 3..6 com detecção de "acabou de apertar". }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, SyncObjs, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  Dialogs, aidronebase, aih264decoder;

type
  TComandoManche = record
    SampleTick:QWord;
    Rolagem: Double;     // -1..1, + = direita
    Arfagem: Double;     // -1..1, + = frente
    Guinada: Double;     // -1..1, + = gira à direita
    Acelerador: Double;  // 0..1 (Z inteiro)
    Subida: Double;      // -1..1 (Z em relação ao centro)
    Botao: array[1..6] of Boolean;
    Apertou: array[1..6] of Boolean; // apertado agora e solto na leitura anterior
  end;

  TfrmConexaoDrone = class;

  { Linha de execucao dedicada para envio de comandos ao drone.
    Desacopla o envio de pacotes UDP/TCP da interface grafica (evitando que caixas
    de dialogo, selecao de arquivos ou mapas congelem a comunicacao com o drone). }
  TThreadControleDrone = class(TThread)
  private
    FConexao: TfrmConexaoDrone;
    FIntervaloMs: Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(AConexao: TfrmConexaoDrone; AIntervaloMs: Integer);
  end;

  { TfrmConexaoDrone }

  TfrmConexaoDrone = class(TForm)
  private
    FLockComando: TCriticalSection;
    FUltimoComando: TComandoManche;
    FThreadControle: TThreadControleDrone;
    FInfo: TPanel;
    FBotoes: TPanel;
    FMemo: TMemo;
    FTimer: TTimer;
    FBitmap: TBitmap;
    FUltimaImagem: TDateTime;
    FUltimaTela: QWord;
    FUltimoErro: string;
    FUltimaMensagem: string;
    FBotoesAntes: array[1..6] of Boolean;
    FLbVideo: TLabel;
    FVideoLigado: Boolean;
    FDrone: TAIDroneBase;
    procedure TimerTick(Sender: TObject);
    procedure FechaJanela(Sender: TObject; var CanClose: Boolean);
    procedure DroneStatus(Sender: TObject; const AMessage: string);
    procedure DroneErro(Sender: TObject; const AMessage: string);
    procedure DroneEstado(Sender: TObject);
    procedure DroneTelemetria(Sender: TObject);
    procedure DroneVideo(Sender: TObject; AData: PByte; ACount: Integer);
    procedure DecoderQuadro(Sender: TObject; ABitmap: TBitmap);
    procedure DecoderErro(Sender: TObject; const AMessage: string);
  protected
    FDecoder: TAIH264Decoder;
    { Montagem da janela (chame no construtor da janela do drone). }
    function NovaLinha(const ATitulo: string): TLabel;
    function NovoBotao(const ATexto: string; AEvento: TNotifyEvent;
      ADestaque: Boolean = False): TButton;
    { Liga os eventos do componente a esta janela. }
    procedure UsaDrone(ADrone: TAIDroneBase);
    { Prepara o decodificador; com AAtivo = False o vídeo fica desligado. }
    procedure PreparaVideo(AAtivo: Boolean; ALargura, AAltura: Integer;
      const AFFmpeg: string);
    procedure DefineErro(const AMotivo: string);
    procedure AtualizaComandoManche(const ACmd: TComandoManche);
    function ObtemComandoProtegido: TComandoManche;
    { Chamado a cada mensagem (AErro = True para erros), depois do registro. }
    procedure MensagemDrone(const AMessage: string; AErro: Boolean); virtual;

    { Pontos de cada drone. }
    { Lê a configuração e conecta. False = não foi possível (veja DefineErro). }
    function Conectar: Boolean; virtual; abstract;
    { Desconecta com segurança (pousa, desarma ou zera a aceleração). }
    procedure Desconectar; virtual; abstract;
    { Repassa o manche ao drone (chamado a cada IntervaloMs). }
    procedure Controle(const C: TComandoManche); virtual; abstract;
    { Atualiza o quadro de informações (até 4 vezes por segundo). }
    procedure AtualizaPainel; virtual;
    function IntervaloMs: Integer; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Conecta e passa a enviar os comandos. False = drone não encontrado ou
      configuração inválida; o motivo fica em UltimoErro. }
    function Iniciar: Boolean;
    procedure Encerrar;
    procedure Log(const ATexto: string);
    { Comandos atuais do cockpit (frmMain, convertidos pelo controler.pas).
      A janela de um drone pode trocar a fonte (ex.: joystick próprio). }
    function LeComando: TComandoManche; virtual;
    { True se há vídeo chegando (para a janela da câmera). }
    function VideoExternoConfigurado:Boolean;virtual;
    function CarregaQuadroExterno(ABitmap:TBitmap):Boolean;virtual;
    function VideoChegando: Boolean;
    { Telemetria de posição do GPS do Drone (se suportado pelo protocolo) }
    function ObterPosicaoGPS(out ALat, ALon, AAlt: Double): Boolean; virtual;
    function ObterDadosGPS(out ALat, ALon, AAlt, AVel, ACurso: Double;
      out ASat, AFix: Integer): Boolean; virtual;

    property Drone: TAIDroneBase read FDrone;
    property Decoder: TAIH264Decoder read FDecoder;
    property VideoLigado: Boolean read FVideoLigado;
    property Bitmap: TBitmap read FBitmap;
    property UltimaImagemDataHora: TDateTime read FUltimaImagem;
    property UltimoErro: string read FUltimoErro;
  end;

implementation

uses
  main, camera, controler, setmain;

{ TfrmConexaoDrone }

constructor TfrmConexaoDrone.Create(AOwner: TComponent);
begin
  // Janela montada em código: não há .lfm para carregar.
  inherited CreateNew(AOwner, 0);
  Width := 330;
  Height := 470;
  Position := poDesigned;
  if Screen.Width > 0 then
    Left := Screen.Width - Width - 40;
  Top := 120;
  OnCloseQuery := @FechaJanela;

  FBitmap := TBitmap.Create;

  FInfo := TPanel.Create(Self);
  FInfo.Parent := Self;
  FInfo.Align := alTop;
  FInfo.BevelOuter := bvNone;
  FInfo.AutoSize := True;
  FInfo.BorderSpacing.Around := 8;
  FInfo.ChildSizing.Layout := cclLeftToRightThenTopToBottom;
  FInfo.ChildSizing.ControlsPerLine := 2;
  FInfo.ChildSizing.HorizontalSpacing := 10;
  FInfo.ChildSizing.VerticalSpacing := 4;

  FBotoes := TPanel.Create(Self);
  FBotoes.Parent := Self;
  FBotoes.Align := alTop;
  FBotoes.Top := 1000; // abaixo do quadro de informações
  FBotoes.BevelOuter := bvNone;
  FBotoes.AutoSize := True;
  FBotoes.BorderSpacing.Left := 8;
  FBotoes.BorderSpacing.Right := 8;
  FBotoes.BorderSpacing.Bottom := 8;
  FBotoes.ChildSizing.Layout := cclLeftToRightThenTopToBottom;
  FBotoes.ChildSizing.ControlsPerLine := 2;
  FBotoes.ChildSizing.EnlargeHorizontal := crsHomogenousChildResize;
  FBotoes.ChildSizing.HorizontalSpacing := 6;
  FBotoes.ChildSizing.VerticalSpacing := 6;

  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := alClient;
  FMemo.ReadOnly := True;
  FMemo.ScrollBars := ssAutoVertical;

  FDecoder := TAIH264Decoder.Create(Self);
  FDecoder.OnFrame := @DecoderQuadro;
  FDecoder.OnError := @DecoderErro;

  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.OnTimer := @TimerTick;

  FLbVideo := nil;
  FLockComando := TCriticalSection.Create;
end;

destructor TfrmConexaoDrone.Destroy;
begin
  Encerrar;
  FreeAndNil(FLockComando);
  FreeAndNil(FBitmap);
  inherited Destroy;
end;

function TfrmConexaoDrone.NovaLinha(const ATitulo: string): TLabel;
begin
  with TLabel.Create(Self) do
  begin
    Parent := FInfo;
    Caption := ATitulo;
    Font.Style := [fsBold];
  end;
  Result := TLabel.Create(Self);
  Result.Parent := FInfo;
  Result.Caption := '-';
end;

function TfrmConexaoDrone.NovoBotao(const ATexto: string; AEvento: TNotifyEvent;
  ADestaque: Boolean): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := FBotoes;
  Result.Caption := ATexto;
  Result.Height := 30;
  Result.OnClick := AEvento;
  if ADestaque then
  begin
    Result.Font.Style := [fsBold];
    Result.Font.Color := clRed;
  end;
end;

procedure TfrmConexaoDrone.UsaDrone(ADrone: TAIDroneBase);
begin
  FDrone := ADrone;
  FDrone.OnStatus := @DroneStatus;
  FDrone.OnError := @DroneErro;
  FDrone.OnStateChange := @DroneEstado;
  FDrone.OnTelemetry := @DroneTelemetria;
  FDrone.OnVideoData := @DroneVideo;
end;

procedure TfrmConexaoDrone.PreparaVideo(AAtivo: Boolean; ALargura, AAltura: Integer;
  const AFFmpeg: string);
begin
  FVideoLigado := AAtivo;
  if FLbVideo = nil then
    FLbVideo := NovaLinha('Vídeo:');
  if not AAtivo then
  begin
    FLbVideo.Caption := 'desligado';
    Exit;
  end;
  FDecoder.Width := ALargura;
  FDecoder.Height := AAltura;
  FDecoder.FFmpegPath := AFFmpeg;
  FLbVideo.Caption := 'aguardando';
  FDecoder.Start; // sem ffmpeg, o decodificador avisa por OnError
end;

procedure TfrmConexaoDrone.DefineErro(const AMotivo: string);
begin
  FUltimoErro := AMotivo;
  Log(AMotivo);
end;

function TfrmConexaoDrone.IntervaloMs: Integer;
begin
  Result := 50;
end;

procedure TfrmConexaoDrone.AtualizaPainel;
begin
end;

function TfrmConexaoDrone.Iniciar: Boolean;
var
  I: Integer;
begin
  FUltimoErro := '';
  Result := False;
  if (FTimer <> nil) and FTimer.Enabled then
    Exit(True);
  for I := 1 to 6 do
    FBotoesAntes[I] := True; // botão já apertado na largada não vale como clique
  Screen.Cursor := crHourGlass;
  try
    try
      if FSetMain.SimulationMode then Log('MODO SIMULADOR: conexao local 127.0.0.1, sem busca de Wi-Fi real.')
    else Log('MODO EQUIPAMENTO REAL: usando enderecos configurados.');
    Result := Conectar;
    except
      on E: Exception do
      begin
        Result := False;
        FUltimoErro := Caption + ': erro ao conectar: ' + E.Message;
        Log(FUltimoErro);
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
  if not Result then
  begin
    if FUltimoErro = '' then
      FUltimoErro := Caption + ': não foi possível conectar.';
    try
      Desconectar;
    except
    end;
    if Assigned(FDecoder) then
      FDecoder.Stop;
    Exit(False);
  end;

  AtualizaComandoManche(LeComando);
  if FThreadControle = nil then
    FThreadControle := TThreadControleDrone.Create(Self, IntervaloMs);

  FTimer.Interval := IntervaloMs;
  FTimer.Enabled := True;
end;

procedure TfrmConexaoDrone.Encerrar;
begin
  if Assigned(FTimer) then
    FTimer.Enabled := False;
  if Assigned(FThreadControle) then
  begin
    FThreadControle.Terminate;
    FThreadControle.WaitFor;
    FreeAndNil(FThreadControle);
  end;
  if Assigned(FDrone) then
  begin
    try
      Desconectar;
    except
    end;
    // Mensagens que ainda chegariam depois de a janela sumir.
    FDrone.OnVideoData := nil;
    FDrone.CancelPendingEvents;
  end;
  if Assigned(FDecoder) then
    FDecoder.Stop;
end;

procedure TfrmConexaoDrone.Log(const ATexto: string);
begin
  if not Assigned(FMemo) then
    Exit;
  if FMemo.Lines.Count > 500 then
    FMemo.Lines.Delete(0);
  FMemo.Append(FormatDateTime('hh:nn:ss', Now) + '  ' + ATexto);
end;

function TfrmConexaoDrone.LeComando: TComandoManche;
var
  B: array[1..6] of Byte;
  I: Integer;
begin
  Result := Default(TComandoManche);
  if not Assigned(frmMain) then
    Exit;
  B[1] := frmMain.B1; B[2] := frmMain.B2; B[3] := frmMain.B3;
  B[4] := frmMain.B4; B[5] := frmMain.B5; B[6] := frmMain.B6;
  // Conversão única (centro, zona morta, sinais): controler.pas.
  with frmMain.Controler do
  begin
    Result.Rolagem := Rolagem;
    Result.Arfagem := Arfagem;
    Result.Guinada := Guinada;
    Result.Acelerador := Acelerador;
    Result.Subida := Subida;
  end;
  for I := 1 to 6 do
  begin
    Result.Botao[I] := B[I] = 255;
    Result.Apertou[I] := Result.Botao[I] and not FBotoesAntes[I];
    FBotoesAntes[I] := Result.Botao[I];
  end;
end;

function TfrmConexaoDrone.VideoExternoConfigurado:Boolean;
begin Result:=False;end;
function TfrmConexaoDrone.CarregaQuadroExterno(ABitmap:TBitmap):Boolean;
begin Result:=False;end;

function TfrmConexaoDrone.VideoChegando: Boolean;
begin
  Result := FVideoLigado and Assigned(FDrone) and FDrone.VideoStreaming;
end;

function TfrmConexaoDrone.ObterPosicaoGPS(out ALat, ALon, AAlt: Double): Boolean;
var
  V, C: Double;
  S, F: Integer;
begin
  Result := ObterDadosGPS(ALat, ALon, AAlt, V, C, S, F);
end;

function TfrmConexaoDrone.ObterDadosGPS(out ALat, ALon, AAlt, AVel, ACurso: Double;
  out ASat, AFix: Integer): Boolean;
begin
  ALat := 0; ALon := 0; AAlt := 0; AVel := 0; ACurso := 0;
  ASat := 0; AFix := 0;
  Result := False;
end;

procedure TfrmConexaoDrone.AtualizaComandoManche(const ACmd: TComandoManche);
begin
  if Assigned(FLockComando) then
  begin
    FLockComando.Enter;
    try
      FUltimoComando := ACmd;FUltimoComando.SampleTick:=GetTickCount64;
    finally
      FLockComando.Leave;
    end;
  end;
end;

function TfrmConexaoDrone.ObtemComandoProtegido: TComandoManche;
begin
  Result := Default(TComandoManche);
  if Assigned(FLockComando) then
  begin
    FLockComando.Enter;
    try
      Result := FUltimoComando;
    finally
      FLockComando.Leave;
    end;
  end;
end;

procedure TfrmConexaoDrone.TimerTick(Sender: TObject);
begin
  AtualizaComandoManche(LeComando);
  if GetTickCount64 - FUltimaTela >= 250 then
  begin
    FUltimaTela := GetTickCount64;
    if FVideoLigado and Assigned(FLbVideo) then
    begin
      if VideoChegando then
        FLbVideo.Caption := Format('%d quadros', [FDecoder.FramesDecoded])
      else
        FLbVideo.Caption := 'sem imagem';
    end;
    AtualizaPainel;
  end;
end;

{ TThreadControleDrone }

constructor TThreadControleDrone.Create(AConexao: TfrmConexaoDrone; AIntervaloMs: Integer);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FConexao := AConexao;
  FIntervaloMs := Max(10, AIntervaloMs);
end;

procedure TThreadControleDrone.Execute;
var
  Cmd: TComandoManche;
begin
  while not Terminated do
  begin
    if Assigned(FConexao) then
    begin
      Cmd := FConexao.ObtemComandoProtegido;
      try
        FConexao.Controle(Cmd);
      except
        // Evita que erros transientes terminem a thread de controle
      end;
    end;
    Sleep(FIntervaloMs);
  end;
end;

procedure TfrmConexaoDrone.FechaJanela(Sender: TObject; var CanClose: Boolean);
begin
  // Fechar a janela não desconecta (use o botão Start do cockpit).
  Hide;
  CanClose := False;
end;

procedure TfrmConexaoDrone.MensagemDrone(const AMessage: string; AErro: Boolean);
begin
end;

procedure TfrmConexaoDrone.DroneStatus(Sender: TObject; const AMessage: string);
begin
  // Mensagens repetidas em sequência aparecem uma vez só.
  if AMessage = FUltimaMensagem then
    Exit;
  FUltimaMensagem := AMessage;
  Log(AMessage);
  MensagemDrone(AMessage, False);
end;

procedure TfrmConexaoDrone.DroneErro(Sender: TObject; const AMessage: string);
begin
  FUltimoErro := AMessage;
  Log('ERRO: ' + AMessage);
  MensagemDrone(AMessage, True);
end;

procedure TfrmConexaoDrone.DroneEstado(Sender: TObject);
begin
  AtualizaPainel;
end;

procedure TfrmConexaoDrone.DroneTelemetria(Sender: TObject);
begin
  // O painel é atualizado pelo temporizador (até 4 vezes por segundo).
end;

procedure TfrmConexaoDrone.DroneVideo(Sender: TObject; AData: PByte; ACount: Integer);
begin
  // Linha de rede: só repassa ao decodificador (seguro entre linhas).
  if FVideoLigado and (ACount > 0) then
    FDecoder.Feed(AData^, ACount);
end;

procedure TfrmConexaoDrone.DecoderQuadro(Sender: TObject; ABitmap: TBitmap);
begin
  FBitmap.Assign(ABitmap);
  FUltimaImagem := Now;
  if Assigned(frmCam) and frmCam.CameraAtiva and frmCam.Visible then
    frmCam.MostraQuadro(ABitmap);
end;

procedure TfrmConexaoDrone.DecoderErro(Sender: TObject; const AMessage: string);
begin
  Log('Vídeo: ' + AMessage);
end;

end.
