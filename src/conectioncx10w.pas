unit ConectionCX10W;

{ Janela de conexão do Cheerson CX-10W.

  Protocolo: TAIDroneCX10W (CHATGPT, pacote openai_drone), o mesmo do
  FQ777-954. Configuração própria na seção [CX10W] do drone.cfg.

  Comandos (frmMain): X/Y = rolagem/arfagem, Z (Q/E) = aceleração,
  botões 1/2 = giro. A aceleração fica travada depois de conectar até descer
  ao mínimo. Ao desligar, envia aceleração zero antes de soltar a conexão. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StdCtrls, conexaodrone, aidronefq777, aidronecx10w;

type

  { TfrmConectionCX10W }

  TfrmConectionCX10W = class(TfrmConexaoDrone)
  private
    FCX: TAIDroneCX10W;
    FLbControle: TLabel;
    FLbComando: TLabel;
    FCorte: Boolean;
    procedure BtCorteClick(Sender: TObject);
  protected
    function Conectar: Boolean; override;
    procedure Desconectar; override;
    procedure Controle(const C: TComandoManche); override;
    procedure AtualizaPainel; override;
  public
    constructor Create(AOwner: TComponent); override;
    { Aceleração zero e eixos no centro; volta a travar a aceleração. }
    procedure CorteMotores;
    property CX10W: TAIDroneCX10W read FCX;
  end;

implementation

uses
  setmain;

constructor TfrmConectionCX10W.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'Cheerson CX-10W';
  FCX := TAIDroneCX10W.Create(Self);
  UsaDrone(FCX);
  FLbControle := NovaLinha('Controle:');
  FLbComando := NovaLinha('Comando:');
  NovoBotao('CORTAR MOTORES', @BtCorteClick, True);
end;

function TfrmConectionCX10W.Conectar: Boolean;
var
  TargetHost: string;
  UsarVideo: Boolean;
begin
  with FSetMain.CX10W do
  begin
    TargetHost:=FSetMain.TargetHost(IP,'172.16.10.1');
    FCX.Host := TargetHost;
    if PortaTCP > 0 then
      FCX.TcpPort := PortaTCP;
    if PortaUDP > 0 then
      FCX.UdpPort := PortaUDP;
    UsarVideo := Video and (not FSetMain.SimulationMode);
    FCX.VideoEnabled := UsarVideo;
    PreparaVideo(UsarVideo, FQ777_VIDEO_WIDTH, FQ777_VIDEO_HEIGHT, FFmpeg);
  end;
  if FSetMain.SimulationMode then begin FCX.TcpPort:=8888; FCX.UdpPort:=8895; end;
  FCX.ThrottleArmLock := True;
  FCX.Connect;
  Result := FCX.Active;
end;

procedure TfrmConectionCX10W.Desconectar;
begin
  FCX.Disconnect; // envia aceleração zero antes de fechar
end;

procedure TfrmConectionCX10W.Controle(const C: TComandoManche);
var
  Acelerador: Double;
begin
  Acelerador := C.Acelerador;
  if FCorte then
  begin
    // Só libera depois que o acelerador voltar ao mínimo.
    if Acelerador < 0.05 then
      FCorte := False;
    Acelerador := 0;
  end;
  FCX.SetSticks(C.Rolagem, C.Arfagem, C.Guinada, Acelerador);
end;

procedure TfrmConectionCX10W.AtualizaPainel;
begin
  if FCX.ControlConnected then
  begin
    if FSetMain.SimulationMode then
      FLbControle.Caption := Format('Simulador conectado (127.0.0.1, %d pacotes)', [FCX.PacketsSent])
    else
      FLbControle.Caption := Format('conectado (%d pacotes)', [FCX.PacketsSent]);
  end
  else if FCX.Active then
  begin
    if FSetMain.SimulationMode then
      FLbControle.Caption := 'conectando ao simulador local (127.0.0.1)...'
    else
      FLbControle.Caption := 'conectando...';
  end
  else
    FLbControle.Caption := 'desconectado';
  FLbComando.Caption := TAIDroneFQ777.PacketToHex(FCX.LastPacket);
end;

procedure TfrmConectionCX10W.CorteMotores;
begin
  FCorte := True;
  FCX.Neutral;
  Log('Corte dos motores: baixe a aceleração ao mínimo para liberar.');
end;

procedure TfrmConectionCX10W.BtCorteClick(Sender: TObject);
begin
  CorteMotores;
end;

end.
