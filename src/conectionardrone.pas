unit conectionardrone;

{ Janela de conexão do Parrot AR.Drone 2.0.

  Protocolo: TAIDroneARDrone (CHATGPT, pacote openai_drone). Configuração
  própria na seção [ARDRONE] do drone.cfg; altura máxima e voo externo são
  enviados ao drone ao conectar.

  Comandos (frmMain): X/Y = rolagem/arfagem, Z (Q/E) = sobe/desce
  (centro = mantém a altura), botões 1/2 = giro, botão 3 = decolar,
  botão 4 = pousar. Nesta janela: Decolar, Pousar, EMERGÊNCIA e Calibrar.
  Ao desligar, manda pousar antes de soltar a conexão. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, StdCtrls, conexaodrone, aidroneardrone;

type

  { TfrmConectionARDrone }

  TfrmConectionARDrone = class(TfrmConexaoDrone)
  private
    FAR: TAIDroneARDrone;
    FLbEstado: TLabel;
    FLbBateria: TLabel;
    FLbAltura: TLabel;
    FLbAtitude: TLabel;
    FLbComando: TLabel;
    procedure BtDecolarClick(Sender: TObject);
    procedure BtPousarClick(Sender: TObject);
    procedure BtEmergenciaClick(Sender: TObject);
    procedure BtCalibrarClick(Sender: TObject);
  protected
    function Conectar: Boolean; override;
    procedure Desconectar; override;
    procedure Controle(const C: TComandoManche); override;
    procedure AtualizaPainel; override;
    function IntervaloMs: Integer; override;
  public
    constructor Create(AOwner: TComponent); override;
    property ARDrone: TAIDroneARDrone read FAR;
  end;

implementation

uses
  setmain;

constructor TfrmConectionARDrone.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'Parrot AR.Drone 2.0';
  FAR := TAIDroneARDrone.Create(Self);
  UsaDrone(FAR);
  FLbEstado := NovaLinha('Estado:');
  FLbBateria := NovaLinha('Bateria:');
  FLbAltura := NovaLinha('Altura:');
  FLbAtitude := NovaLinha('Atitude:');
  FLbComando := NovaLinha('Enlace:');
  NovoBotao('Decolar (botão 3)', @BtDecolarClick);
  NovoBotao('Pousar (botão 4)', @BtPousarClick);
  NovoBotao('EMERGÊNCIA', @BtEmergenciaClick, True);
  NovoBotao('Calibrar (no chão)', @BtCalibrarClick);
end;

function TfrmConectionARDrone.IntervaloMs: Integer;
begin
  Result := 30;
end;

function TfrmConectionARDrone.Conectar: Boolean;
begin
  with FSetMain.ARDrone do
  begin
    FAR.Host := FSetMain.TargetHost(IP,'192.168.1.1');
    FAR.VideoEnabled := Video and not FSetMain.SimulationMode;
    FAR.Sensitivity := EnsureRange(Sensibilidade, 10, 100) / 100;
    PreparaVideo(Video and not FSetMain.SimulationMode, ARDRONE_VIDEO_WIDTH, ARDRONE_VIDEO_HEIGHT, FFmpeg);
    Log(Format('Conectando em %s (altura máx. %d m, %s, sensibilidade %d%%).',
      [FAR.Host, AlturaMaxima, BoolToStr(Externo, 'externo', 'interno'), Sensibilidade]));
    FAR.LandOnDisconnect := True;
    FAR.Connect;
    Result := FAR.Active;
    if not Result then
      Exit;
    // Limites de voo enviados ao drone (um por vez, com confirmação).
    FAR.Configure('control:altitude_max', IntToStr(EnsureRange(AlturaMaxima, 1, 100) * 1000));
    FAR.Configure('control:outdoor', BoolToStr(Externo, 'TRUE', 'FALSE'));
    FAR.Configure('control:flight_without_shell', BoolToStr(Externo, 'TRUE', 'FALSE'));
  end;
end;

procedure TfrmConectionARDrone.Desconectar;
begin
  FAR.Disconnect; // pousa antes de fechar
end;

procedure TfrmConectionARDrone.Controle(const C: TComandoManche);
begin
  FAR.SetSticks(C.Rolagem, C.Arfagem, C.Guinada, C.Subida);
  if C.Apertou[3] then
    FAR.TakeOff
  else if C.Apertou[4] then
    FAR.Land;
end;

procedure TfrmConectionARDrone.AtualizaPainel;
var
  N: TAIARDroneNavdata;
begin
  N := FAR.Navdata;
  FLbEstado.Caption := TAIDroneARDrone.StateText(N);
  if N.Valid then
  begin
    FLbBateria.Caption := IntToStr(N.Battery) + '%';
    FLbAltura.Caption := FormatFloat('0.00', N.Altitude) + ' m';
    FLbAtitude.Caption := Format('arf %.0f°  rol %.0f°  rumo %.0f°',
      [N.Pitch, N.Roll, N.Heading]);
  end;
  FLbComando.Caption := Format('%d comandos, %d telemetrias',
    [FAR.CommandsSent, FAR.NavPackets]);
end;

procedure TfrmConectionARDrone.BtDecolarClick(Sender: TObject);
begin
  FAR.TakeOff;
end;

procedure TfrmConectionARDrone.BtPousarClick(Sender: TObject);
begin
  FAR.Land;
end;

procedure TfrmConectionARDrone.BtEmergenciaClick(Sender: TObject);
begin
  FAR.Emergency;
end;

procedure TfrmConectionARDrone.BtCalibrarClick(Sender: TObject);
begin
  FAR.FlatTrim;
end;

end.
