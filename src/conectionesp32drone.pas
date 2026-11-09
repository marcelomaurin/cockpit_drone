unit conectionesp32drone;

{ Janela de conexão do drone ESP32 com o firmware do Cockpit (CDP v1).

  Protocolo: TAIDroneCDP (CHATGPT, pacote openai_drone); firmware em
  firmware/esp32_drone. Configuração própria na seção [ESP32DRONE].

  Comandos (frmMain): X/Y = rolagem/arfagem, Z (Q/E) = aceleração,
  botões 1/2 = giro, botão 3 = armar, botão 4 = desarmar.
  Para armar, a aceleração precisa estar no mínimo. O pacote de controle é
  também o sinal de vida: sem ele por 500 ms o firmware desce e desarma.
  Ao desligar, desarma antes de soltar a conexão. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StdCtrls, conexaodrone, aidronecdp;

type

  { TfrmConectionESP32Drone }

  TfrmConectionESP32Drone = class(TfrmConexaoDrone)
  private
    FCDP: TAIDroneCDP;
    FLbEstado: TLabel;
    FLbBateria: TLabel;
    FLbAtitude: TLabel;
    FLbAcelerador: TLabel;
    FLbSinal: TLabel;
    FLbAlertas: TLabel;
    procedure BtArmarClick(Sender: TObject);
    procedure BtDesarmarClick(Sender: TObject);
    procedure BtCorteClick(Sender: TObject);
    procedure BtCalibrarClick(Sender: TObject);
  protected
    function Conectar: Boolean; override;
    procedure Desconectar; override;
    procedure Controle(const C: TComandoManche); override;
    procedure AtualizaPainel; override;
    function IntervaloMs: Integer; override;
  public
    constructor Create(AOwner: TComponent); override;
    property CDP: TAIDroneCDP read FCDP;
  end;

implementation

uses
  setmain;

constructor TfrmConectionESP32Drone.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'Drone ESP32';
  FCDP := TAIDroneCDP.Create(Self);
  UsaDrone(FCDP);
  FLbEstado := NovaLinha('Estado:');
  FLbBateria := NovaLinha('Bateria:');
  FLbAtitude := NovaLinha('Atitude:');
  FLbAcelerador := NovaLinha('Aceleração:');
  FLbSinal := NovaLinha('Sinal:');
  FLbAlertas := NovaLinha('Alertas:');
  NovoBotao('Armar (botão 3)', @BtArmarClick);
  NovoBotao('Desarmar (botão 4)', @BtDesarmarClick);
  NovoBotao('CORTE DOS MOTORES', @BtCorteClick, True);
  NovoBotao('Calibrar (nivelado)', @BtCalibrarClick);
end;

function TfrmConectionESP32Drone.IntervaloMs: Integer;
begin
  Result := 30;
end;

function TfrmConectionESP32Drone.Conectar: Boolean;
begin
  with FSetMain.ESP32Drone do
  begin
    FCDP.Host := FSetMain.TargetHost(IP,'192.168.4.1');
    if Porta > 0 then
      FCDP.Port := Porta;
  end;
  Log(Format('Conectando em %s, UDP %d.', [FCDP.Host, FCDP.Port]));
  if FSetMain.SimulationMode then FCDP.Port:=4210;
  FCDP.Connect;
  Result := FCDP.Active;
end;

procedure TfrmConectionESP32Drone.Desconectar;
begin
  FCDP.Disconnect; // desarma e zera a aceleração antes de fechar
end;

procedure TfrmConectionESP32Drone.Controle(const C: TComandoManche);
begin
  FCDP.SetSticks(C.Rolagem, C.Arfagem, C.Guinada, C.Acelerador);
  if C.Apertou[3] then
    FCDP.Arm
  else if C.Apertou[4] then
    FCDP.Disarm;
end;

procedure TfrmConectionESP32Drone.AtualizaPainel;
var
  T: TAICdpTelemetry;
  A: string;
begin
  T := FCDP.Telemetry;
  if (not T.Valid) or (GetTickCount64 - T.ReceivedTick > 2000) then
  begin
    FLbEstado.Caption := 'sem telemetria';
    FLbSinal.Caption := Format('%d comandos enviados', [FCDP.PacketsSent]);
    Exit;
  end;

  FLbEstado.Caption := TAIDroneCDP.StateText(T.State);
  FLbBateria.Caption := FormatFloat('0.00', T.BatteryMv / 1000) + ' V';
  FLbAtitude.Caption := Format('rol %.1f°  arf %.1f°  rumo %.0f°',
    [T.Roll, T.Pitch, T.Heading]);
  FLbAcelerador.Caption := Format('%d / 1000', [T.Throttle]);
  FLbSinal.Caption := Format('%d dBm, %d cmd/s, laço %d Hz',
    [T.Rssi, T.ControlsPerSecond, T.LoopHz]);

  A := '';
  if (T.Alerts and CDP_ALERT_LOW_BATTERY) <> 0 then
    A := A + 'bateria baixa; ';
  if (T.Alerts and CDP_ALERT_SENSOR_OK) = 0 then
    A := A + 'sensor com falha; ';
  if (T.Alerts and CDP_ALERT_THROTTLE_HIGH) <> 0 then
    A := A + 'acelerador alto (baixe p/ armar); ';
  if (T.Alerts and CDP_ALERT_TILTED) <> 0 then
    A := A + 'inclinado; ';
  if A = '' then
    A := 'nenhum';
  FLbAlertas.Caption := A;
end;

procedure TfrmConectionESP32Drone.BtArmarClick(Sender: TObject);
begin
  FCDP.Arm;
end;

procedure TfrmConectionESP32Drone.BtDesarmarClick(Sender: TObject);
begin
  FCDP.Disarm;
end;

procedure TfrmConectionESP32Drone.BtCorteClick(Sender: TObject);
begin
  FCDP.Cut;
end;

procedure TfrmConectionESP32Drone.BtCalibrarClick(Sender: TObject);
begin
  FCDP.Calibrate;
end;

end.
