unit conectionesp32drone;

{ Janela de conexão do drone ESP32 (firmware Cockpit, protocolo CDP).

  Protocolo em esp32droneproto.pas; firmware em firmware/esp32_drone.
  Esta janela:
    - lê a configuração própria (seção [ESP32DRONE] do drone.cfg);
    - envia os comandos do frmMain a cada 30 ms (o pacote também é o sinal de
      vida: sem ele por 500 ms o firmware desce e desarma sozinho);
    - mostra estado, bateria, atitude, sinal Wi-Fi e alertas;
    - ao fechar, desarma antes de soltar a conexão.

  Comandos (frmMain): X/Y = rolagem/arfagem, Z (Q/E) = aceleração,
  botões 1/2 = giro, botão 3 = armar, botão 4 = desarmar.
  Para armar, a aceleração precisa estar no mínimo. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  Dialogs, esp32droneproto;

type

  { TfrmConectionESP32Drone }

  TfrmConectionESP32Drone = class(TForm)
  private
    FProtocol: TESP32DroneProtocol;
    FTimer: TTimer;

    FLbEstado: TLabel;
    FLbBateria: TLabel;
    FLbAtitude: TLabel;
    FLbAcelerador: TLabel;
    FLbSinal: TLabel;
    FLbAlertas: TLabel;
    FMemo: TMemo;

    FUltimaTela: QWord;
    FUltimoStatus: string;
    FUltimoErro: string;

    procedure MontaTela;
    procedure Log(const ATexto: string);
    procedure AtualizaPainel;

    procedure ProtocoloStatus(Sender: TObject; const AStatus: string);
    procedure ProtocoloErro(Sender: TObject; const AMsg: string);

    procedure TimerControle(Sender: TObject);
    procedure BtArmarClick(Sender: TObject);
    procedure BtDesarmarClick(Sender: TObject);
    procedure BtCorteClick(Sender: TObject);
    procedure BtCalibrarClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function Iniciar: Boolean;
    procedure Encerrar;
    { Mata os motores imediatamente. }
    procedure CorteMotores;

    property Protocol: TESP32DroneProtocol read FProtocol;
    property UltimoErro: string read FUltimoErro;
  end;

implementation

uses
  setmain, main;

const
  INTERVALO_COMANDO_MS = 30;

{ TfrmConectionESP32Drone }

constructor TfrmConectionESP32Drone.Create(AOwner: TComponent);
begin
  // Formulário montado em código: não há .lfm para carregar.
  inherited CreateNew(AOwner, 0);
  Caption := 'Drone ESP32 (firmware Cockpit)';
  Width := 320;
  Height := 500;
  Position := poDesigned;
  if Screen.Width > 0 then
    Left := Screen.Width - Width - 40;
  Top := 120;

  FProtocol := TESP32DroneProtocol.Create;
  FProtocol.OnStatus := @ProtocoloStatus;
  FProtocol.OnError := @ProtocoloErro;

  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := INTERVALO_COMANDO_MS;
  FTimer.OnTimer := @TimerControle;

  MontaTela;
end;

destructor TfrmConectionESP32Drone.Destroy;
begin
  Encerrar;
  FreeAndNil(FProtocol);
  inherited Destroy;
end;

procedure TfrmConectionESP32Drone.MontaTela;
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
    Result.Left := 90;
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
  Topo.Height := 236;
  Topo.BevelOuter := bvNone;

  FLbEstado := NovoRotulo(8, 'Estado:');
  FLbBateria := NovoRotulo(28, 'Bateria:');
  FLbAtitude := NovoRotulo(48, 'Atitude:');
  FLbAcelerador := NovoRotulo(68, 'Aceleração:');
  FLbSinal := NovoRotulo(88, 'Ligação:');
  FLbAlertas := NovoRotulo(108, 'Alertas:');

  NovoBotao(8, 136, 148, 'Armar (botão 3)', @BtArmarClick);
  NovoBotao(164, 136, 148, 'Desarmar (botão 4)', @BtDesarmarClick);
  with NovoBotao(8, 170, 304, 'CORTE DOS MOTORES', @BtCorteClick) do
  begin
    Font.Style := [fsBold];
    Font.Color := clRed;
  end;
  NovoBotao(8, 204, 304, 'Calibrar sensor (desarmado, nivelado)', @BtCalibrarClick);

  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := alClient;
  FMemo.ReadOnly := True;
  FMemo.ScrollBars := ssAutoVertical;
end;

procedure TfrmConectionESP32Drone.Log(const ATexto: string);
begin
  if not Assigned(FMemo) then
    Exit;
  if FMemo.Lines.Count > 500 then
    FMemo.Lines.Delete(0);
  FMemo.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + ATexto);
end;

function TfrmConectionESP32Drone.Iniciar: Boolean;
var
  Host: string;
  Porta: Integer;
begin
  FUltimoErro := '';
  Host := ESP32_DEFAULT_HOST;
  Porta := ESP32_DEFAULT_PORT;
  if Assigned(FSetMain) then
  begin
    if Trim(FSetMain.ESP32Drone.IP) <> '' then
      Host := Trim(FSetMain.ESP32Drone.IP);
    if FSetMain.ESP32Drone.Porta > 0 then
      Porta := FSetMain.ESP32Drone.Porta;
  end;

  FProtocol.Connect(Host, 0, Porta);
  Result := FProtocol.Active;
  if not Result then
  begin
    if FUltimoErro = '' then
      FUltimoErro := 'Drone ESP32 não encontrado em ' + Host + '.';
    Exit;
  end;

  FTimer.Enabled := True;
  if Assigned(frmMain) then
    frmMain.AtivouDrone;
end;

procedure TfrmConectionESP32Drone.Encerrar;
begin
  FTimer.Enabled := False;
  if Assigned(FProtocol) then
  begin
    FProtocol.OnStatus := nil;
    FProtocol.OnError := nil;
    FProtocol.Disconnect; // desarma antes de fechar
  end;
end;

procedure TfrmConectionESP32Drone.CorteMotores;
begin
  if Assigned(FProtocol) then
    FProtocol.Corte;
end;

procedure TfrmConectionESP32Drone.ProtocoloStatus(Sender: TObject; const AStatus: string);
begin
  if AStatus <> FUltimoStatus then
    Log(AStatus);
  FUltimoStatus := AStatus;
end;

procedure TfrmConectionESP32Drone.ProtocoloErro(Sender: TObject; const AMsg: string);
begin
  FUltimoErro := AMsg;
  Log('Erro: ' + AMsg);
end;

procedure TfrmConectionESP32Drone.TimerControle(Sender: TObject);
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

procedure TfrmConectionESP32Drone.AtualizaPainel;
var
  T: TESP32Telemetria;
  A: string;
begin
  T := FProtocol.Telemetria;
  if (not T.Valida) or (Now - T.Recebida > 2 / 86400) then
  begin
    FLbEstado.Caption := 'sem telemetria';
    FLbSinal.Caption := Format('%d comandos enviados', [FProtocol.Comandos]);
    Exit;
  end;

  FLbEstado.Caption := TESP32DroneProtocol.EstadoTexto(T.Estado);
  FLbBateria.Caption := FormatFloat('0.00', T.BateriaMv / 1000) + ' V';
  FLbAtitude.Caption := Format('rol %.1f°  arf %.1f°  rumo %.0f°',
    [T.Rolagem, T.Arfagem, T.Rumo]);
  FLbAcelerador.Caption := Format('%d / 1000', [T.Acelerador]);
  FLbSinal.Caption := Format('%d dBm, %d cmd/s, laço %d Hz',
    [T.RSSI, T.ControlesPorSegundo, T.LacoHz]);

  A := '';
  if (T.Alertas and CDP_ALERTA_BATERIA_BAIXA) <> 0 then
    A := A + 'bateria baixa; ';
  if (T.Alertas and CDP_ALERTA_SENSOR_OK) = 0 then
    A := A + 'sensor com falha; ';
  if (T.Alertas and CDP_ALERTA_ACEL_TRAVADO) <> 0 then
    A := A + 'acelerador alto (baixe p/ armar); ';
  if (T.Alertas and CDP_ALERTA_INCLINADO) <> 0 then
    A := A + 'inclinado; ';
  if A = '' then
    A := 'nenhum';
  FLbAlertas.Caption := A;
end;

procedure TfrmConectionESP32Drone.BtArmarClick(Sender: TObject);
begin
  FProtocol.Armar;
end;

procedure TfrmConectionESP32Drone.BtDesarmarClick(Sender: TObject);
begin
  FProtocol.Desarmar;
end;

procedure TfrmConectionESP32Drone.BtCorteClick(Sender: TObject);
begin
  FProtocol.Corte;
end;

procedure TfrmConectionESP32Drone.BtCalibrarClick(Sender: TObject);
begin
  FProtocol.Calibrar;
end;

end.
