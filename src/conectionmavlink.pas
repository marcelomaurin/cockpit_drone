unit conectionmavlink;

{ Janela de conexão MAVLink (ArduPilot/PX4).

  Protocolo: TAIDroneMavlink (CHATGPT, pacote openai_drone). Configuração
  própria na seção [MAVLINK] do drone.cfg. Esta janela:
    - repassa o manche do frmMain a cada 100 ms (o componente ignora o manche
      durante a rota e nos modos autônomos);
    - mostra modo, GPS, bateria e posição;
    - guarda as mensagens do drone para a janela "Rota de voo" (ProximoAviso).
  A rota é planejada e enviada pela janela "Rota de voo" (rotavoo.pas). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StdCtrls, conexaodrone, aidronemavlink;

type

  { TfrmConectionMavlink }

  TfrmConectionMavlink = class(TfrmConexaoDrone)
  private
    FMav: TAIDroneMavlink;
    FAvisos: TStringList;
    FLbLigacao: TLabel;
    FLbModo: TLabel;
    FLbGps: TLabel;
    FLbBateria: TLabel;
    FLbPosicao: TLabel;
    procedure BtRotaClick(Sender: TObject);
    procedure BtVoltarClick(Sender: TObject);
    procedure BtPousarClick(Sender: TObject);
  protected
    function Conectar: Boolean; override;
    procedure Desconectar; override;
    procedure Controle(const C: TComandoManche); override;
    procedure AtualizaPainel; override;
    procedure MensagemDrone(const AMessage: string; AErro: Boolean); override;
    function IntervaloMs: Integer; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { Próxima mensagem do drone ainda não lida pela janela de rota. }
    function ProximoAviso(out AMensagem: string): Boolean;
    function ObterPosicaoGPS(out ALat, ALon, AAlt: Double): Boolean; override;
    function ObterDadosGPS(out ALat, ALon, AAlt, AVel, ACurso: Double;
      out ASat, AFix: Integer): Boolean; override;
    property Mavlink: TAIDroneMavlink read FMav;
  end;

implementation

uses
  setmain, rotavoo;

constructor TfrmConectionMavlink.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'MAVLink (ArduPilot/PX4)';
  FAvisos := TStringList.Create;
  FMav := TAIDroneMavlink.Create(Self);
  UsaDrone(FMav);
  FLbLigacao := NovaLinha('Ligação:');
  FLbModo := NovaLinha('Modo:');
  FLbGps := NovaLinha('GPS:');
  FLbBateria := NovaLinha('Bateria:');
  FLbPosicao := NovaLinha('Posição:');
  NovoBotao('Rota de voo', @BtRotaClick);
  NovoBotao('Voltar à partida', @BtVoltarClick);
  NovoBotao('Pousar', @BtPousarClick, True);
end;

destructor TfrmConectionMavlink.Destroy;
begin
  inherited Destroy;
  FreeAndNil(FAvisos);
end;

function TfrmConectionMavlink.IntervaloMs: Integer;
begin
  Result := 100;
end;

function TfrmConectionMavlink.Conectar: Boolean;
begin
  FMav.Host := FSetMain.TargetHost(FSetMain.Mavlink.IP,'192.168.4.1');
  if FSetMain.Mavlink.Porta > 0 then
    FMav.Port := FSetMain.Mavlink.Porta;
  if FSetMain.SimulationMode then FMav.Port:=14550;
  FMav.Connect;
  Result := FMav.Active;
  if not Result then
    DefineErro(Format('Não foi possível abrir a porta UDP %d.', [FMav.Port]));
end;

procedure TfrmConectionMavlink.Desconectar;
begin
  FMav.Disconnect;
end;

procedure TfrmConectionMavlink.Controle(const C: TComandoManche);
begin
  FMav.SetSticks(C.Rolagem, C.Arfagem, C.Guinada, C.Acelerador);
end;

procedure TfrmConectionMavlink.AtualizaPainel;
var
  T: TAIMavTelemetry;
begin
  T := FMav.Telemetry;
  if not FMav.Active then
    FLbLigacao.Caption := 'desligado'
  else if not T.Connected then
    FLbLigacao.Caption := 'aguardando o drone...'
  else
    FLbLigacao.Caption := Format('sistema %d', [T.SysId]);
  if not T.Connected then
    Exit;
  FLbModo.Caption := FMav.ModeText;
  FLbGps.Caption := FMav.GpsText;
  if T.BatteryPct >= 0 then
    FLbBateria.Caption := Format('%d%% (%.2f V)', [T.BatteryPct, T.BatteryVoltage])
  else if T.BatteryVoltage > 0 then
    FLbBateria.Caption := Format('%.2f V', [T.BatteryVoltage])
  else
    FLbBateria.Caption := '-';
  if T.PositionValid then
    FLbPosicao.Caption := Format('%.6f, %.6f  alt %.1f m',
      [T.Lat, T.Lon, T.RelativeAlt])
  else
    FLbPosicao.Caption := 'sem posição';
end;

procedure TfrmConectionMavlink.MensagemDrone(const AMessage: string; AErro: Boolean);
begin
  if AErro then
    FAvisos.Add('Erro: ' + AMessage)
  else
    FAvisos.Add(AMessage);
  while FAvisos.Count > 100 do
    FAvisos.Delete(0);
end;

function TfrmConectionMavlink.ProximoAviso(out AMensagem: string): Boolean;
begin
  AMensagem := '';
  Result := Assigned(FAvisos) and (FAvisos.Count > 0);
  if Result then
  begin
    AMensagem := FAvisos[0];
    FAvisos.Delete(0);
  end;
end;

procedure TfrmConectionMavlink.BtRotaClick(Sender: TObject);
begin
  AbreRotaVoo;
end;

procedure TfrmConectionMavlink.BtVoltarClick(Sender: TObject);
begin
  FMav.ReturnToLaunch;
end;

procedure TfrmConectionMavlink.BtPousarClick(Sender: TObject);
begin
  FMav.Land;
end;

function TfrmConectionMavlink.ObterPosicaoGPS(out ALat, ALon, AAlt: Double): Boolean;
var
  T: TAIMavTelemetry;
begin
  T := FMav.Telemetry;
  Result := T.Connected and T.PositionValid;
  if Result then
  begin
    ALat := T.Lat;
    ALon := T.Lon;
    AAlt := T.RelativeAlt;
  end
  else
  begin
    ALat := 0; ALon := 0; AAlt := 0;
  end;
end;

function TfrmConectionMavlink.ObterDadosGPS(out ALat, ALon, AAlt, AVel, ACurso: Double;
  out ASat, AFix: Integer): Boolean;
var
  T: TAIMavTelemetry;
begin
  T := FMav.Telemetry;
  Result := T.Connected and T.PositionValid;
  if Result then
  begin
    ALat := T.Lat;
    ALon := T.Lon;
    AAlt := T.RelativeAlt;
    AVel := T.GroundSpeed;
    ACurso := T.Heading;
    ASat := T.Satellites;
    AFix := T.GpsFix;
  end
  else
  begin
    ALat := 0; ALon := 0; AAlt := 0; AVel := 0; ACurso := 0;
    ASat := 0; AFix := 0;
  end;
end;

end.
