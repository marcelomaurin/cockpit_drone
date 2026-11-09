unit conectiontello;

{ Janela de conexão do DJI/Ryze Tello.

  Protocolo: TAIDroneTello (CHATGPT, pacote openai_drone), SDK em texto.
  Configuração própria na seção [TELLO] do drone.cfg.

  Comandos (frmMain): X/Y = rolagem/arfagem, Z (Q/E) = sobe/desce
  (centro = mantém a altura), botões 1/2 = giro, botão 3 = decolar,
  botão 4 = pousar. Nesta janela: Decolar, Pousar e EMERGÊNCIA.
  Ao desligar, manda pousar antes de soltar a conexão. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StdCtrls, Dialogs, Controls, conexaodrone, aidronetello;

type

  { TfrmConectionTello }

  TfrmConectionTello = class(TfrmConexaoDrone)
  private
    FTello: TAIDroneTello;
    FLbEstado: TLabel;
    FLbBateria: TLabel;
    FLbAltura: TLabel;
    FLbAtitude: TLabel;
    procedure BtDecolarClick(Sender: TObject);
    procedure BtPousarClick(Sender: TObject);
    procedure BtEmergenciaClick(Sender: TObject);
  protected
    function Conectar: Boolean; override;
    procedure Desconectar; override;
    procedure Controle(const C: TComandoManche); override;
    procedure AtualizaPainel; override;
  public
    constructor Create(AOwner: TComponent); override;
    property Tello: TAIDroneTello read FTello;
  end;

implementation

uses
  setmain;

constructor TfrmConectionTello.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'DJI Tello';
  FTello := TAIDroneTello.Create(Self);
  UsaDrone(FTello);
  FLbEstado := NovaLinha('Estado:');
  FLbBateria := NovaLinha('Bateria:');
  FLbAltura := NovaLinha('Altura:');
  FLbAtitude := NovaLinha('Atitude:');
  NovoBotao('Decolar (botão 3)', @BtDecolarClick);
  NovoBotao('Pousar (botão 4)', @BtPousarClick);
  NovoBotao('EMERGÊNCIA', @BtEmergenciaClick, True);
end;

function TfrmConectionTello.Conectar: Boolean;
begin
  with FSetMain.Tello do
  begin
    FTello.Host := FSetMain.TargetHost(IP,'192.168.10.1');
    FTello.VideoEnabled := Video and not FSetMain.SimulationMode;
    PreparaVideo(Video and not FSetMain.SimulationMode, TELLO_VIDEO_WIDTH, TELLO_VIDEO_HEIGHT, FFmpeg);
  end;
  FTello.LandOnDisconnect := True;
  FTello.Connect;
  Result := FTello.Active;
end;

procedure TfrmConectionTello.Desconectar;
begin
  FTello.Disconnect; // pousa antes de fechar
end;

procedure TfrmConectionTello.Controle(const C: TComandoManche);
begin
  FTello.SetSticks(C.Rolagem, C.Arfagem, C.Guinada, C.Subida);
  if C.Apertou[3] then
    FTello.TakeOff
  else if C.Apertou[4] then
    FTello.Land;
end;

procedure TfrmConectionTello.AtualizaPainel;
var
  S: TAITelloState;
begin
  if FTello.SdkMode then
    FLbEstado.Caption := 'conectado (modo SDK)'
  else if FTello.Active then
    FLbEstado.Caption := 'procurando o drone...'
  else
    FLbEstado.Caption := 'desconectado';
  S := FTello.State;
  if not S.Valid then
    Exit;
  FLbBateria.Caption := Format('%d%%', [S.Battery]);
  FLbAltura.Caption := Format('%.2f m  (%d s de voo)', [S.Height, S.FlightTime]);
  FLbAtitude.Caption := Format('arf %d°  rol %d°  rumo %d°', [S.Pitch, S.Roll, S.Yaw]);
end;

procedure TfrmConectionTello.BtDecolarClick(Sender: TObject);
begin
  FTello.TakeOff;
end;

procedure TfrmConectionTello.BtPousarClick(Sender: TObject);
begin
  FTello.Land;
end;

procedure TfrmConectionTello.BtEmergenciaClick(Sender: TObject);
begin
  // Sem confirmação: numa emergência cada segundo conta.
  FTello.Emergency;
end;

end.
