unit conectionardrone;

{ Janela de conexão do Parrot AR.Drone 2.0.

  Protocolo em ardroneproto.pas (TARDroneProtocol). Esta janela:
    - lê a configuração própria do AR.Drone (seção [ARDRONE] do drone.cfg);
    - repassa os comandos do frmMain a cada 30 ms (o drone paira sozinho
      quando os eixos estão centralizados);
    - mostra bateria, altura, atitude e estado vindos da telemetria;
    - entrega o vídeo H.264 ao TAIH264Decoder e guarda o último quadro em
      Bitmap, lido pela janela da câmera;
    - ao fechar, manda o drone pousar antes de soltar a conexão.

  Comandos (frmMain):
    manche/teclas X e Y = rolagem e arfagem, Z (Q/E) = sobe/desce,
    botões 1/2 = giro, botão 3 = decolar, botão 4 = pousar.
  Nesta janela: Decolar, Pousar, EMERGÊNCIA e Calibrar (no chão). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  Dialogs, ardroneproto, aih264decoder;

const
  ARDRONE_VIDEO_WIDTH = 640;
  ARDRONE_VIDEO_HEIGHT = 360;

type

  { TfrmConectionARDrone }

  TfrmConectionARDrone = class(TForm)
  private
    FProtocol: TARDroneProtocol;
    FDecoder: TAIH264Decoder;
    FTimer: TTimer;

    FLbEstado: TLabel;
    FLbBateria: TLabel;
    FLbAltura: TLabel;
    FLbAtitude: TLabel;
    FLbVideo: TLabel;
    FLbComando: TLabel;
    FMemo: TMemo;

    FBitmap: TBitmap;
    FUltimaImagem: TDateTime;
    FUltimaTela: QWord;
    FUltimoStatus: string;
    FUltimoErro: string;

    procedure MontaTela;
    procedure Log(const ATexto: string);
    procedure AtualizaPainel;

    procedure ProtocoloStatus(Sender: TObject; const AStatus: string);
    procedure ProtocoloErro(Sender: TObject; const AMsg: string);
    procedure ProtocoloVideo(Sender: TObject; AData: PByte; ACount: Integer);
    procedure DecoderQuadro(Sender: TObject; ABitmap: TBitmap);
    procedure DecoderErro(Sender: TObject; const AMessage: string);

    procedure TimerControle(Sender: TObject);
    procedure BtDecolarClick(Sender: TObject);
    procedure BtPousarClick(Sender: TObject);
    procedure BtEmergenciaClick(Sender: TObject);
    procedure BtCalibrarClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Abre os canais de comando, telemetria e vídeo. }
    function Iniciar: Boolean;
    { Pousa e fecha a conexão. }
    procedure Encerrar;

    property Protocol: TARDroneProtocol read FProtocol;
    property Decoder: TAIH264Decoder read FDecoder;
    property Bitmap: TBitmap read FBitmap;
    property UltimaImagemDataHora: TDateTime read FUltimaImagem;
    property UltimoErro: string read FUltimoErro;
  end;

implementation

uses
  setmain, main, Camera;

const
  INTERVALO_COMANDO_MS = 30;

function EstadoTexto(const N: TARDroneNavdata): string;
begin
  if not N.Valida then
    Exit('sem telemetria');
  if (N.Estado and ARDRONE_STATE_EMERGENCY) <> 0 then
    Result := 'EMERGÊNCIA'
  else if (N.Estado and ARDRONE_STATE_FLY) <> 0 then
    Result := 'voando'
  else
    Result := 'pousado';
  if (N.Estado and ARDRONE_STATE_VBAT_LOW) <> 0 then
    Result := Result + ' / BATERIA BAIXA';
  if (N.Estado and ARDRONE_STATE_CUTOUT) <> 0 then
    Result := Result + ' / motor travado';
end;

{ TfrmConectionARDrone }

constructor TfrmConectionARDrone.Create(AOwner: TComponent);
begin
  // Formulário montado em código: não há .lfm para carregar.
  inherited CreateNew(AOwner, 0);
  Caption := 'Parrot AR.Drone 2.0';
  Width := 320;
  Height := 500;
  Position := poDesigned;
  if Screen.Width > 0 then
    Left := Screen.Width - Width - 40;
  Top := 120;

  FBitmap := TBitmap.Create;

  FProtocol := TARDroneProtocol.Create;
  FProtocol.OnStatus := @ProtocoloStatus;
  FProtocol.OnError := @ProtocoloErro;
  FProtocol.OnVideoData := @ProtocoloVideo;

  FDecoder := TAIH264Decoder.Create(Self);
  FDecoder.Width := ARDRONE_VIDEO_WIDTH;
  FDecoder.Height := ARDRONE_VIDEO_HEIGHT;
  FDecoder.OnFrame := @DecoderQuadro;
  FDecoder.OnError := @DecoderErro;

  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := INTERVALO_COMANDO_MS;
  FTimer.OnTimer := @TimerControle;

  MontaTela;
end;

destructor TfrmConectionARDrone.Destroy;
begin
  Encerrar;
  FreeAndNil(FProtocol);
  FreeAndNil(FBitmap);
  inherited Destroy;
end;

procedure TfrmConectionARDrone.MontaTela;
var
  Topo: TPanel;

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

  function NovoBotao(ALeft, ATop, AWidth: Integer; const ATexto: string;
    AEvento: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := Topo;
    Result.Left := ALeft;
    Result.Top := ATop;
    Result.Width := AWidth;
    Result.Height := 30;
    Result.Caption := ATexto;
    Result.OnClick := AEvento;
  end;

begin
  Topo := TPanel.Create(Self);
  Topo.Parent := Self;
  Topo.Align := alTop;
  Topo.Height := 230;
  Topo.BevelOuter := bvNone;

  FLbEstado := NovoRotulo(8, 'Estado:');
  FLbBateria := NovoRotulo(28, 'Bateria:');
  FLbAltura := NovoRotulo(48, 'Altura:');
  FLbAtitude := NovoRotulo(68, 'Atitude:');
  FLbVideo := NovoRotulo(88, 'Vídeo:');
  FLbComando := NovoRotulo(108, 'Comando:');

  NovoBotao(8, 134, 148, 'Decolar (botão 3)', @BtDecolarClick);
  NovoBotao(164, 134, 148, 'Pousar (botão 4)', @BtPousarClick);
  with NovoBotao(8, 168, 304, 'EMERGÊNCIA (corta os motores)', @BtEmergenciaClick) do
  begin
    Font.Style := [fsBold];
    Font.Color := clRed;
  end;
  NovoBotao(8, 200, 304, 'Calibrar horizontal (drone no chão)', @BtCalibrarClick);

  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := alClient;
  FMemo.ReadOnly := True;
  FMemo.ScrollBars := ssAutoVertical;
end;

procedure TfrmConectionARDrone.Log(const ATexto: string);
begin
  if not Assigned(FMemo) then
    Exit;
  if FMemo.Lines.Count > 500 then
    FMemo.Lines.Delete(0);
  FMemo.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + ATexto);
end;

function TfrmConectionARDrone.Iniciar: Boolean;
var
  Host, FFmpeg: string;
  Video, Externo: Boolean;
  AlturaMax, Sens: Integer;
begin
  FUltimoErro := '';
  Host := ARDRONE_DEFAULT_HOST;
  FFmpeg := '';
  Video := True;
  Externo := False;
  AlturaMax := 3;
  Sens := 50;

  if Assigned(FSetMain) then
  begin
    if Trim(FSetMain.ARDrone.IP) <> '' then
      Host := Trim(FSetMain.ARDrone.IP);
    Video := FSetMain.ARDrone.Video;
    FFmpeg := FSetMain.ARDrone.FFmpeg;
    Externo := FSetMain.ARDrone.Externo;
    AlturaMax := FSetMain.ARDrone.AlturaMaxima;
    Sens := FSetMain.ARDrone.Sensibilidade;
  end;

  FProtocol.VideoEnabled := Video;
  FProtocol.Sensibilidade := EnsureRange(Sens, 10, 100) / 100;
  if Video then
  begin
    FDecoder.FFmpegPath := FFmpeg;
    if not FDecoder.Start then
      Log('Vídeo: ffmpeg não encontrado. Coloque o ffmpeg.exe na pasta do programa ou no PATH.');
  end;

  Log(Format('Conectando em %s (altura máx. %d m, %s, sensibilidade %d%%).',
    [Host, AlturaMax, BoolToStr(Externo, 'externo', 'interno'), Sens]));
  FProtocol.Connect(Host, ARDRONE_PORT_VIDEO, ARDRONE_PORT_AT);

  Result := FProtocol.Active;
  if not Result then
  begin
    if FUltimoErro = '' then
      FUltimoErro := 'AR.Drone não encontrado em ' + Host + '.';
    Exit;
  end;

  // Limites de voo enviados ao drone (um por vez, com confirmação).
  FProtocol.Configura('control:altitude_max', IntToStr(EnsureRange(AlturaMax, 1, 100) * 1000));
  FProtocol.Configura('control:outdoor', BoolToStr(Externo, 'TRUE', 'FALSE'));
  FProtocol.Configura('control:flight_without_shell', BoolToStr(Externo, 'TRUE', 'FALSE'));

  FTimer.Enabled := True;
  if Assigned(frmMain) then
    frmMain.AtivouDrone;
end;

procedure TfrmConectionARDrone.Encerrar;
begin
  FTimer.Enabled := False;
  if Assigned(FProtocol) then
  begin
    FProtocol.OnStatus := nil;
    FProtocol.OnError := nil;
    FProtocol.OnVideoData := nil;
    FProtocol.Disconnect; // envia o pouso antes de fechar
  end;
  if Assigned(FDecoder) then
    FDecoder.Stop;
end;

procedure TfrmConectionARDrone.ProtocoloStatus(Sender: TObject; const AStatus: string);
begin
  if AStatus <> FUltimoStatus then
    Log(AStatus);
  FUltimoStatus := AStatus;
end;

procedure TfrmConectionARDrone.ProtocoloErro(Sender: TObject; const AMsg: string);
begin
  FUltimoErro := AMsg;
  Log('Erro: ' + AMsg);
end;

procedure TfrmConectionARDrone.ProtocoloVideo(Sender: TObject; AData: PByte;
  ACount: Integer);
begin
  if Assigned(FDecoder) and (ACount > 0) then
    FDecoder.Feed(AData^, ACount);
end;

procedure TfrmConectionARDrone.DecoderQuadro(Sender: TObject; ABitmap: TBitmap);
begin
  FBitmap.Assign(ABitmap);
  FUltimaImagem := Now;
  if Assigned(frmCam) and frmCam.CameraAtiva and frmCam.Visible then
    frmCam.MostraQuadro(ABitmap);
end;

procedure TfrmConectionARDrone.DecoderErro(Sender: TObject; const AMessage: string);
begin
  Log('Vídeo: ' + AMessage);
end;

procedure TfrmConectionARDrone.TimerControle(Sender: TObject);
begin
  if not FProtocol.Active then
    Exit;

  if Assigned(frmMain) then
    FProtocol.SendCommand(frmMain.X, frmMain.Y, frmMain.Z,
      frmMain.B1, frmMain.B2, frmMain.B3, frmMain.B4, frmMain.B5, frmMain.B6);

  FProtocol.Tick;

  if GetTickCount64 - FUltimaTela >= 250 then
  begin
    FUltimaTela := GetTickCount64;
    AtualizaPainel;
  end;
end;

procedure TfrmConectionARDrone.AtualizaPainel;
var
  N: TARDroneNavdata;
begin
  N := FProtocol.Navdata;
  FLbEstado.Caption := EstadoTexto(N);
  if N.Valida then
  begin
    FLbBateria.Caption := IntToStr(N.Bateria) + '%';
    FLbAltura.Caption := FormatFloat('0.00', N.Altura) + ' m';
    FLbAtitude.Caption := Format('arf %.0f°  rol %.0f°  rumo %.0f°',
      [N.Arfagem, N.Rolagem, N.Rumo]);
  end;
  if FProtocol.VideoConnected then
    FLbVideo.Caption := Format('%d quadros', [FDecoder.FramesDecoded])
  else
    FLbVideo.Caption := 'desconectado';
  FLbComando.Caption := Format('%d comandos, %d telemetrias',
    [FProtocol.Comandos, FProtocol.NavPacotes]);
end;

procedure TfrmConectionARDrone.BtDecolarClick(Sender: TObject);
begin
  FProtocol.Decolar;
end;

procedure TfrmConectionARDrone.BtPousarClick(Sender: TObject);
begin
  FProtocol.Pousar;
end;

procedure TfrmConectionARDrone.BtEmergenciaClick(Sender: TObject);
begin
  FProtocol.Emergencia;
end;

procedure TfrmConectionARDrone.BtCalibrarClick(Sender: TObject);
begin
  FProtocol.CalibrarPlano;
end;

end.
