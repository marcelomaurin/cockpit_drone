unit conectionopendrone;

{ Janela de conexão do ESP-Drone da Espressif / OpenDrone (firmware
  Crazyflie, pacotes CRTP em UDP).

  Protocolo: TAIDroneESPDrone (CHATGPT, pacote openai_drone). Configuração
  própria na seção [ESPDRONE] do drone.cfg.

  Comandos (frmMain): X/Y = rolagem/arfagem, Z (Q/E) = aceleração,
  botões 1/2 = giro. A aceleração só é liberada depois que desce ao mínimo
  (exigência do firmware); "Parar motores" volta a travar.
  Ao desligar, envia aceleração zero antes de soltar a conexão. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StdCtrls, conexaodrone, aidroneespdrone;

type

  { TfrmConectionOpendrone }

  TfrmConectionOpendrone = class(TfrmConexaoDrone)
  private
    FESP: TAIDroneESPDrone;
    FParado: Boolean;
    FLbEnlace: TLabel;
    FLbAcelerador: TLabel;
    FLbPacotes: TLabel;
    procedure BtPararClick(Sender: TObject);
  protected
    function Conectar: Boolean; override;
    procedure Desconectar; override;
    procedure Controle(const C: TComandoManche); override;
    procedure AtualizaPainel; override;
  public
    constructor Create(AOwner: TComponent); override;
    property ESPDrone: TAIDroneESPDrone read FESP;
  end;

implementation

uses
  setmain;

constructor TfrmConectionOpendrone.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'ESP-Drone / OpenDrone';
  FESP := TAIDroneESPDrone.Create(Self);
  UsaDrone(FESP);
  FLbEnlace := NovaLinha('Enlace:');
  FLbAcelerador := NovaLinha('Aceleração:');
  FLbPacotes := NovaLinha('Comandos:');
  NovoBotao('PARAR MOTORES', @BtPararClick, True);
end;

function TfrmConectionOpendrone.Conectar: Boolean;
begin
  with FSetMain.ESPDrone do
  begin
    if Trim(IP) <> '' then
      FESP.Host := Trim(IP);
    if Porta > 0 then
      FESP.Port := Porta;
    FESP.MaxAngle := AnguloMaximo;
  end;
  FParado := False;
  FESP.Connect;
  Result := FESP.Active;
end;

procedure TfrmConectionOpendrone.Desconectar;
begin
  FESP.Disconnect; // aceleração zero antes de fechar
end;

procedure TfrmConectionOpendrone.Controle(const C: TComandoManche);
begin
  if FParado then
  begin
    // Depois de "Parar motores", só volta com o acelerador no mínimo.
    if C.Acelerador >= 0.02 then
      Exit;
    FParado := False;
  end;
  FESP.SetSticks(C.Rolagem, C.Arfagem, C.Guinada, C.Acelerador);
end;

procedure TfrmConectionOpendrone.AtualizaPainel;
begin
  if FESP.LinkAlive then
    FLbEnlace.Caption := 'drone respondendo'
  else if FESP.Active then
    FLbEnlace.Caption := 'enviando (sem resposta)'
  else
    FLbEnlace.Caption := 'desconectado';
  if FESP.ThrustUnlocked then
    FLbAcelerador.Caption := 'liberada'
  else
    FLbAcelerador.Caption := 'travada: baixe ao mínimo';
  FLbPacotes.Caption := IntToStr(FESP.PacketsSent);
end;

procedure TfrmConectionOpendrone.BtPararClick(Sender: TObject);
begin
  FParado := True;
  FESP.Stop;
  Log('Motores parados: baixe a aceleração ao mínimo para liberar.');
end;

end.
