unit conectionmavlink;

{ Janela de conexão MAVLink (ArduPilot/PX4).

  Protocolo em mavlinkproto.pas. Esta janela:
    - lê a configuração própria (seção [MAVLINK] do drone.cfg);
    - a cada 100 ms chama Tick (sinal de vida, prazos) e repassa o manche do
      frmMain (ignorado pelo protocolo durante a rota e nos modos autônomos);
    - mostra GPS, modo, bateria e as mensagens do drone.
  A rota de voo é planejada e enviada pela janela "Rota de voo" (rotavoo.pas). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Menus, setmain, protocols, mavlinkproto;

type
  { TfrmConectionMavlink }

  TfrmConectionMavlink = class(TForm)
    Label1: TLabel;
    Label2: TLabel;
    Label4: TLabel;
    lbStateConection: TLabel;
    lbIP: TLabel;
    lbdevicename: TLabel;
    lbUDP: TLabel;
    meLog: TMemo;
    MenuItem1: TMenuItem;
    pnTop: TPanel;
    pnBotton: TPanel;
    popLog: TPopupMenu;
    timerJoystick: TTimer;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure pnBottonClick(Sender: TObject);
    procedure timerJoystickTimer(Sender: TObject);

  private
    FProtocol: TMavlinkProtocol;
    FHost: string;
    FUdpPort: Integer;
    FUltimaTela: QWord;

    procedure Log(const ATexto: string);
    procedure SetStatus(const ATexto: string);
    procedure OnProtocolError(Sender: TObject; const AMsg: string);
    procedure OnProtocolStatus(Sender: TObject; const AStatus: string);

  public
    procedure PegaConfiguracao;
    procedure InicioHandShake;
    procedure sendGamepadData;
    procedure DesativaJoystick;
    procedure AtivaJoystick;
    procedure DesativaConnection;

    property Protocol: TMavlinkProtocol read FProtocol;
  end;

var
  frmConectionMavlink: TfrmConectionMavlink;

implementation

uses
  main;

{$R *.lfm}

procedure TfrmConectionMavlink.FormCreate(Sender: TObject);
begin
  FProtocol := nil;
  // O .lfm não liga o OnDestroy.
  OnDestroy := @FormDestroy;
  if Assigned(timerJoystick) then
  begin
    timerJoystick.Interval := 100;
    timerJoystick.Enabled := False;
  end;
  SetStatus('Offline');
end;

procedure TfrmConectionMavlink.FormDestroy(Sender: TObject);
begin
  DesativaConnection;
end;

procedure TfrmConectionMavlink.pnBottonClick(Sender: TObject);
begin
  DesativaConnection;
  Close;
end;

procedure TfrmConectionMavlink.timerJoystickTimer(Sender: TObject);
var
  T: TMavTelemetria;
begin
  if not Assigned(FProtocol) then
    Exit;
  sendGamepadData;
  FProtocol.Tick;

  if GetTickCount64 - FUltimaTela >= 500 then
  begin
    FUltimaTela := GetTickCount64;
    T := FProtocol.Telemetria;
    if not FProtocol.Active then
      SetStatus('Offline')
    else if not T.Conectado then
      SetStatus('Aguardando o drone...')
    else
    begin
      SetStatus(FProtocol.TextoModo + '  |  GPS ' + FProtocol.TextoGps);
      if T.BateriaPct >= 0 then
        lbdevicename.Caption := Format('MAVLink — bateria %d%% (%.2f V)', [T.BateriaPct, T.BateriaV]);
    end;
  end;
end;

procedure TfrmConectionMavlink.Log(const ATexto: string);
begin
  if Assigned(meLog) then
  begin
    meLog.Lines.Add(FormatDateTime('hh:nn:ss ', Now) + ATexto);
    if meLog.Lines.Count > 300 then
      meLog.Lines.Delete(0);
  end;
end;

procedure TfrmConectionMavlink.SetStatus(const ATexto: string);
begin
  if Assigned(lbStateConection) then
    lbStateConection.Caption := ATexto;
end;

procedure TfrmConectionMavlink.OnProtocolError(Sender: TObject; const AMsg: string);
begin
  Log('Erro: ' + AMsg);
  SetStatus('Erro');
end;

procedure TfrmConectionMavlink.OnProtocolStatus(Sender: TObject; const AStatus: string);
begin
  Log(AStatus);
end;

procedure TfrmConectionMavlink.PegaConfiguracao;
begin
  FHost := '';
  FUdpPort := MAV_PORTA_PADRAO;
  if Assigned(FSetMain) then
  begin
    FHost := Trim(FSetMain.Mavlink.IP);
    if FSetMain.Mavlink.Porta > 0 then
      FUdpPort := FSetMain.Mavlink.Porta;
  end;

  if Assigned(lbIP) then
    lbIP.Caption := FHost;
  if Assigned(lbUDP) then
    lbUDP.Caption := IntToStr(FUdpPort);
  if Assigned(lbdevicename) then
    lbdevicename.Caption := 'MAVLink (ArduPilot/PX4)';
end;

procedure TfrmConectionMavlink.InicioHandShake;
begin
  PegaConfiguracao;
  DesativaConnection;

  Log('Iniciando MAVLink...');
  FProtocol := TMavlinkProtocol.Create;
  FProtocol.OnError := @OnProtocolError;
  FProtocol.OnStatus := @OnProtocolStatus;

  FProtocol.Connect(FHost, 0, FUdpPort);
  AtivaJoystick;

  if Assigned(frmMain) then
    frmMain.AtivouDrone;
end;

procedure TfrmConectionMavlink.sendGamepadData;
begin
  if Assigned(FProtocol) and FProtocol.Active and Assigned(frmMain) then
    FProtocol.SendCommand(frmMain.X, frmMain.Y, frmMain.Z,
      frmMain.B1, frmMain.B2, frmMain.B3, frmMain.B4, frmMain.B5, frmMain.B6);
end;

procedure TfrmConectionMavlink.DesativaJoystick;
begin
  if Assigned(timerJoystick) then
    timerJoystick.Enabled := False;
end;

procedure TfrmConectionMavlink.AtivaJoystick;
begin
  if Assigned(timerJoystick) then
  begin
    timerJoystick.Interval := 100;
    timerJoystick.Enabled := True;
  end;
end;

procedure TfrmConectionMavlink.DesativaConnection;
begin
  DesativaJoystick;
  if Assigned(FProtocol) then
  begin
    FProtocol.OnError := nil;
    FProtocol.OnStatus := nil;
    FProtocol.Disconnect;
    FreeAndNil(FProtocol);
  end;
  SetStatus('Offline');
end;

end.
