unit ConectionCX10W;

{ Janela de conexão do Cheerson CX-10W.

  O protocolo (pacotes de inicialização, canais TCP, comando UDP e vídeo)
  fica em cx10w.pas (TCheersonCX10WProtocol). Esta janela:
    - lê a configuração própria do CX-10W (seção [CX10W] do drone.cfg);
    - envia os comandos do frmMain a cada 50 ms, sempre (o drone espera um
      fluxo contínuo; parar de enviar não é "manter a posição");
    - entrega o vídeo H.264 ao TAIH264Decoder (ffmpeg) e guarda o último
      quadro em Bitmap, lido pela janela da câmera;
    - ao fechar, corta a aceleração antes de soltar a conexão.

  LTCPComponent1 e LUDPComponent1 continuam no formulário apenas por
  compatibilidade com o .lfm; a comunicação é toda feita pelo protocolo. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Menus, lNetComponents, lNet, AdvLed, setmain, protocols, cx10w,
  aih264decoder;

const
  CX10W_VIDEO_WIDTH = 720;
  CX10W_VIDEO_HEIGHT = 576;
  CX10W_INTERVALO_COMANDO_MS = 50;

type
  { TfrmConectionCX10W }

  TfrmConectionCX10W = class(TForm)
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    lbStateConection: TLabel;
    lbTCP: TLabel;
    lbIP: TLabel;
    lbdevicename: TLabel;
    lbUDP: TLabel;
    LTCPComponent1: TLTCPComponent;
    LUDPComponent1: TLUDPComponent;
    meLog: TMemo;
    MenuItem1: TMenuItem;
    pnTop: TPanel;
    pnBotton: TPanel;
    popLog: TPopupMenu;
    timerJoystick: TTimer;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Label5Click(Sender: TObject);
    procedure lbStateConectionChangeBounds(Sender: TObject);
    procedure LTCPComponent1Accept(aSocket: TLSocket);
    procedure LTCPComponent1Connect(aSocket: TLSocket);
    procedure LTCPComponent1Disconnect(aSocket: TLSocket);
    procedure LTCPComponent1Error(const msg: string; aSocket: TLSocket);
    procedure LTCPComponent1Receive(aSocket: TLSocket);
    procedure LUDPComponent1Error(const msg: string; aSocket: TLSocket);
    procedure LUDPComponent1Receive(aSocket: TLSocket);
    procedure pnBottonClick(Sender: TObject);
    procedure timerJoystickTimer(Sender: TObject);

  private
    FProtocol: TCheersonCX10WProtocol;
    FDecoder: TAIH264Decoder;
    FBitmap: TBitmap;
    FUltimaImagemDataHora: TDateTime;
    FUltimoStatus: string;

    FHost: string;
    FTcpPort: Integer;
    FUdpPort: Integer;
    FVideo: Boolean;
    FFFmpeg: string;

    procedure Log(const ATexto: string);
    procedure SetStatus(const ATexto: string);
    procedure UpdateMainOfflineState;

    procedure ProtocolStatus(Sender: TObject; const AStatus: string);
    procedure ProtocolError(Sender: TObject; const AMsg: string);
    procedure ProtocolVideo(Sender: TObject; AData: PByte; ACount: Integer);
    procedure DecoderQuadro(Sender: TObject; ABitmap: TBitmap);
    procedure DecoderErro(Sender: TObject; const AMessage: string);

    function GetTotalPacotesTCP: Int64;
    function GetTotalPacotesUDP: Int64;
    function GetUltimoPacoteUDPHex: string;
  public
    procedure PegaConfiguracao;
    procedure InicioHandShake;
    procedure DesativaJoystick;
    procedure AtivaJoystick;
    procedure DesativaConnection;
    { Corta a aceleração imediatamente (eixos centralizados, motores parados). }
    procedure CorteMotores;

    property Protocol: TCheersonCX10WProtocol read FProtocol;
    property Bitmap: TBitmap read FBitmap;
    property UltimaImagemDataHora: TDateTime read FUltimaImagemDataHora;
    property UltimoPacoteUDPHex: string read GetUltimoPacoteUDPHex;
    property TotalPacotesTCP: Int64 read GetTotalPacotesTCP;
    property TotalPacotesUDP: Int64 read GetTotalPacotesUDP;
  end;

var
  frmConectionCX10W: TfrmConectionCX10W;

implementation

{$R *.lfm}

uses
  main;

{ TfrmConectionCX10W }

procedure TfrmConectionCX10W.Log(const ATexto: string);
begin
  if Assigned(meLog) then
  begin
    // Limita o histórico para não crescer sem fim durante o voo.
    if meLog.Lines.Count > 500 then
      meLog.Lines.Delete(0);
    meLog.Append(FormatDateTime('dd/mm/yyyy hh:nn:ss', Now) + ': ' + ATexto);
  end;
end;

procedure TfrmConectionCX10W.SetStatus(const ATexto: string);
begin
  if Assigned(lbStateConection) then
    lbStateConection.Caption := ATexto;
  if ATexto <> FUltimoStatus then
    Log(ATexto);
  FUltimoStatus := ATexto;
end;

procedure TfrmConectionCX10W.UpdateMainOfflineState;
begin
  if Assigned(frmMain) then
  begin
    frmMain.AdvStart.State := lsOff;
    frmMain.AdvStart.Blink := False;
    frmMain.DesativaJoystick;
  end;
end;

function TfrmConectionCX10W.GetTotalPacotesTCP: Int64;
begin
  if Assigned(FProtocol) then
    Result := FProtocol.TotalPacotesTCP
  else
    Result := 0;
end;

function TfrmConectionCX10W.GetTotalPacotesUDP: Int64;
begin
  // Comandos enviados: o CX-10W praticamente não responde pelo UDP.
  if Assigned(FProtocol) then
    Result := FProtocol.TotalComandos
  else
    Result := 0;
end;

function TfrmConectionCX10W.GetUltimoPacoteUDPHex: string;
begin
  if Assigned(FProtocol) then
    Result := TCheersonCX10WProtocol.PacketToHex(FProtocol.LastPacket)
  else
    Result := '';
end;

procedure TfrmConectionCX10W.PegaConfiguracao;
begin
  FHost := CX10W_DEFAULT_HOST;
  FTcpPort := CX10W_DEFAULT_TCP_PORT;
  FUdpPort := CX10W_DEFAULT_UDP_PORT;
  FVideo := True;
  FFFmpeg := '';

  if Assigned(FSetMain) then
    with FSetMain.CX10W do
    begin
      if Trim(IP) <> '' then
        FHost := Trim(IP);
      if PortaTCP > 0 then
        FTcpPort := PortaTCP;
      if PortaUDP > 0 then
        FUdpPort := PortaUDP;
      FVideo := Video;
      FFFmpeg := FFmpeg;
    end;

  if Assigned(lbdevicename) then
    lbdevicename.Caption := 'Cheerson CX-10W';
  if Assigned(lbIP) then
    lbIP.Caption := FHost;
  if Assigned(lbTCP) then
    lbTCP.Caption := IntToStr(FTcpPort);
  if Assigned(lbUDP) then
    lbUDP.Caption := IntToStr(FUdpPort);

  Log(Format('Configuração CX-10W: IP=%s TCP=%d UDP=%d Vídeo=%s',
    [FHost, FTcpPort, FUdpPort, BoolToStr(FVideo, 'sim', 'não')]));
end;

procedure TfrmConectionCX10W.InicioHandShake;
begin
  PegaConfiguracao;

  if Assigned(FProtocol) then
  begin
    FProtocol.Disconnect;
    FreeAndNil(FProtocol);
  end;

  FProtocol := TCheersonCX10WProtocol.Create;
  FProtocol.VideoEnabled := FVideo;
  FProtocol.OnStatus := @ProtocolStatus;
  FProtocol.OnError := @ProtocolError;
  FProtocol.OnVideoData := @ProtocolVideo;

  if FVideo then
  begin
    FDecoder.FFmpegPath := FFFmpeg;
    if not FDecoder.Start then
      Log('Vídeo: ffmpeg não encontrado. Coloque o ffmpeg.exe na pasta do programa ou no PATH.');
  end;

  FProtocol.Connect(FHost, FTcpPort, FUdpPort);
  AtivaJoystick;

  if Assigned(frmMain) then
    frmMain.AtivouDrone;
end;

procedure TfrmConectionCX10W.DesativaJoystick;
begin
  if Assigned(timerJoystick) then
    timerJoystick.Enabled := False;
end;

procedure TfrmConectionCX10W.AtivaJoystick;
begin
  if Assigned(timerJoystick) then
  begin
    timerJoystick.Interval := CX10W_INTERVALO_COMANDO_MS;
    timerJoystick.Enabled := True;
  end;
end;

procedure TfrmConectionCX10W.CorteMotores;
begin
  if Assigned(FProtocol) and FProtocol.Active then
    FProtocol.SendNeutral;
end;

procedure TfrmConectionCX10W.DesativaConnection;
begin
  DesativaJoystick;

  if Assigned(FProtocol) then
  begin
    // Disconnect envia aceleração zero antes de fechar os canais.
    FProtocol.OnStatus := nil;
    FProtocol.OnError := nil;
    FProtocol.OnVideoData := nil;
    FProtocol.Disconnect;
    FreeAndNil(FProtocol);
  end;

  if Assigned(FDecoder) then
    FDecoder.Stop;

  SetStatus('Conexão encerrada.');
end;

procedure TfrmConectionCX10W.ProtocolStatus(Sender: TObject; const AStatus: string);
begin
  SetStatus(AStatus);
end;

procedure TfrmConectionCX10W.ProtocolError(Sender: TObject; const AMsg: string);
begin
  SetStatus('Erro: ' + AMsg);
  // Sem canal de controle não há voo: para de enviar e apaga o Start.
  DesativaJoystick;
  UpdateMainOfflineState;
end;

procedure TfrmConectionCX10W.ProtocolVideo(Sender: TObject; AData: PByte;
  ACount: Integer);
begin
  if Assigned(FDecoder) and (ACount > 0) then
    FDecoder.Feed(AData^, ACount);
end;

procedure TfrmConectionCX10W.DecoderQuadro(Sender: TObject; ABitmap: TBitmap);
begin
  if Assigned(ABitmap) and Assigned(FBitmap) then
  begin
    FBitmap.Assign(ABitmap);
    FUltimaImagemDataHora := Now;
  end;
end;

procedure TfrmConectionCX10W.DecoderErro(Sender: TObject; const AMessage: string);
begin
  Log('Vídeo: ' + AMessage);
end;

procedure TfrmConectionCX10W.FormCreate(Sender: TObject);
begin
  // O .lfm não liga o OnDestroy: sem isto o corte dos motores nunca rodava.
  OnDestroy := @FormDestroy;

  FProtocol := nil;
  FBitmap := TBitmap.Create;
  FUltimaImagemDataHora := 0;
  FUltimoStatus := '';

  FDecoder := TAIH264Decoder.Create(Self);
  FDecoder.Width := CX10W_VIDEO_WIDTH;
  FDecoder.Height := CX10W_VIDEO_HEIGHT;
  FDecoder.OnFrame := @DecoderQuadro;
  FDecoder.OnError := @DecoderErro;

  if Assigned(timerJoystick) then
  begin
    timerJoystick.Interval := CX10W_INTERVALO_COMANDO_MS;
    timerJoystick.Enabled := False;
  end;

  SetStatus('Aguardando início...');
end;

procedure TfrmConectionCX10W.FormDestroy(Sender: TObject);
begin
  DesativaConnection;
  FreeAndNil(FBitmap);
end;

procedure TfrmConectionCX10W.timerJoystickTimer(Sender: TObject);
begin
  if (not Assigned(FProtocol)) or (not FProtocol.Active) or (not Assigned(frmMain)) then
    Exit;

  // Envio contínuo: o CX-10W precisa receber o comando a cada 50 ms.
  FProtocol.SendCommand(frmMain.X, frmMain.Y, frmMain.Z,
    frmMain.B1, frmMain.B2, frmMain.B3, frmMain.B4, frmMain.B5, frmMain.B6);
end;

{ Componentes do .lfm mantidos por compatibilidade (não são usados). }

procedure TfrmConectionCX10W.Label5Click(Sender: TObject);
begin
end;

procedure TfrmConectionCX10W.lbStateConectionChangeBounds(Sender: TObject);
begin
end;

procedure TfrmConectionCX10W.LTCPComponent1Accept(aSocket: TLSocket);
begin
end;

procedure TfrmConectionCX10W.LTCPComponent1Connect(aSocket: TLSocket);
begin
end;

procedure TfrmConectionCX10W.LTCPComponent1Disconnect(aSocket: TLSocket);
begin
end;

procedure TfrmConectionCX10W.LTCPComponent1Error(const msg: string; aSocket: TLSocket);
begin
end;

procedure TfrmConectionCX10W.LTCPComponent1Receive(aSocket: TLSocket);
begin
end;

procedure TfrmConectionCX10W.LUDPComponent1Error(const msg: string; aSocket: TLSocket);
begin
end;

procedure TfrmConectionCX10W.LUDPComponent1Receive(aSocket: TLSocket);
begin
end;

procedure TfrmConectionCX10W.pnBottonClick(Sender: TObject);
begin
end;

end.
