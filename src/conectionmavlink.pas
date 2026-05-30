unit conectionmavlink;

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
    FX, FY, FZ: Byte;
    FB1, FB2, FB3, FB4, FB5, FB6: Byte;
    FHost: string;
    FUdpPort: Integer;

    procedure Log(const ATexto: string);
    procedure SetStatus(const ATexto: string);
    procedure SyncFromMain(var AMudou: Boolean);
    procedure OnProtocolError(Sender: TObject; const AMsg: string);
    procedure OnProtocolStatus(Sender: TObject; const AStatus: string);

  public
    procedure PegaConfiguracao;
    procedure InicioHandShake;
    procedure sendGamepadData;
    procedure DesativaJoystick;
    procedure AtivaJoystick;
    procedure DesativaConnection;
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
  SetStatus('Offline');
  Log('Carregando Conexão MAVLink...');
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
begin
  sendGamepadData;
end;

procedure TfrmConectionMavlink.Log(const ATexto: string);
begin
  if Assigned(meLog) then
  begin
    meLog.Lines.Add(FormatDateTime('hh:nn:ss.zzz ', Now) + ATexto);
    // Limit log lines
    if meLog.Lines.Count > 100 then
      meLog.Lines.Delete(0);
  end;
end;

procedure TfrmConectionMavlink.SetStatus(const ATexto: string);
begin
  if Assigned(lbStateConection) then
    lbStateConection.Caption := ATexto;
end;

procedure TfrmConectionMavlink.SyncFromMain(var AMudou: Boolean);
begin
  if Assigned(frmMain) then
  begin
    if (FX <> frmMain.X) or (FY <> frmMain.Y) or (FZ <> frmMain.Z) or
       (FB1 <> frmMain.B1) or (FB2 <> frmMain.B2) or (FB3 <> frmMain.B3) or
       (FB4 <> frmMain.B4) or (FB5 <> frmMain.B5) or (FB6 <> frmMain.B6) then
    begin
      AMudou := True;
      FX := frmMain.X;
      FY := frmMain.Y;
      FZ := frmMain.Z;
      FB1 := frmMain.B1;
      FB2 := frmMain.B2;
      FB3 := frmMain.B3;
      FB4 := frmMain.B4;
      FB5 := frmMain.B5;
      FB6 := frmMain.B6;
    end;
  end;
end;

procedure TfrmConectionMavlink.OnProtocolError(Sender: TObject; const AMsg: string);
begin
  Log('Erro: ' + AMsg);
  SetStatus('Erro');
end;

procedure TfrmConectionMavlink.OnProtocolStatus(Sender: TObject; const AStatus: string);
begin
  Log(AStatus);
  if AStatus = 'MAVLink conectado.' then
    SetStatus('Online')
  else if AStatus = 'MAVLink desconectado.' then
    SetStatus('Offline');
end;

procedure TfrmConectionMavlink.PegaConfiguracao;
begin
  if Assigned(FSetMain) then
  begin
    FHost := FSetMain.DroneIP;
    FUdpPort := FSetMain.DronePortaVideo; // Port assigned for UDP telemetry
  end;

  if Trim(FHost) = '' then
    FHost := '192.168.1.1';

  if FUdpPort <= 0 then
    FUdpPort := 14550;

  if Assigned(lbIP) then
    lbIP.Caption := FHost;
  if Assigned(lbUDP) then
    lbUDP.Caption := IntToStr(FUdpPort);
  if Assigned(lbdevicename) then
    lbdevicename.Caption := 'MAVLink Autonomous';
end;

procedure TfrmConectionMavlink.InicioHandShake;
begin
  PegaConfiguracao;
  DesativaConnection;

  Log('Inicializando Protocolo MAVLink...');
  FProtocol := TMavlinkProtocol.Create;
  FProtocol.OnError := @OnProtocolError;
  FProtocol.OnStatus := @OnProtocolStatus;

  FProtocol.Connect(FHost, 0, FUdpPort);
  AtivaJoystick;
  
  if Assigned(frmMain) then
    frmMain.AtivouDrone;
end;

procedure TfrmConectionMavlink.sendGamepadData;
var
  Mudou: Boolean;
begin
  if Assigned(FProtocol) and FProtocol.Active then
  begin
    Mudou := False;
    SyncFromMain(Mudou);
    FProtocol.SendCommand(FX, FY, FZ, FB1, FB2, FB3, FB4, FB5, FB6);
  end;
end;

procedure TfrmConectionMavlink.DesativaJoystick;
begin
  if Assigned(timerJoystick) then
    timerJoystick.Enabled := False;
end;

procedure TfrmConectionMavlink.AtivaJoystick;
begin
  if Assigned(timerJoystick) then
    timerJoystick.Enabled := True;
end;

procedure TfrmConectionMavlink.DesativaConnection;
begin
  DesativaJoystick;
  if Assigned(FProtocol) then
  begin
    FProtocol.Disconnect;
    FreeAndNil(FProtocol);
  end;
  SetStatus('Offline');
end;

end.
