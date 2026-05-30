unit conectionopendrone;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Menus, setmain, protocols, opendroneproto;

type
  { TfrmConectionOpendrone }

  TfrmConectionOpendrone = class(TForm)
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
    FProtocol: TOpendroneProtocol;
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
  frmConectionOpendrone: TfrmConectionOpendrone;

implementation

uses
  main;

{$R *.lfm}

procedure TfrmConectionOpendrone.FormCreate(Sender: TObject);
begin
  FProtocol := nil;
  SetStatus('Offline');
  Log('Carregando Conexão OpenDrone ESP32...');
end;

procedure TfrmConectionOpendrone.FormDestroy(Sender: TObject);
begin
  DesativaConnection;
end;

procedure TfrmConectionOpendrone.pnBottonClick(Sender: TObject);
begin
  DesativaConnection;
  Close;
end;

procedure TfrmConectionOpendrone.timerJoystickTimer(Sender: TObject);
begin
  sendGamepadData;
end;

procedure TfrmConectionOpendrone.Log(const ATexto: string);
begin
  if Assigned(meLog) then
  begin
    meLog.Lines.Add(FormatDateTime('hh:nn:ss.zzz ', Now) + ATexto);
    if meLog.Lines.Count > 100 then
      meLog.Lines.Delete(0);
  end;
end;

procedure TfrmConectionOpendrone.SetStatus(const ATexto: string);
begin
  if Assigned(lbStateConection) then
    lbStateConection.Caption := ATexto;
end;

procedure TfrmConectionOpendrone.SyncFromMain(var AMudou: Boolean);
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

procedure TfrmConectionOpendrone.OnProtocolError(Sender: TObject; const AMsg: string);
begin
  Log('Erro: ' + AMsg);
  SetStatus('Erro');
end;

procedure TfrmConectionOpendrone.OnProtocolStatus(Sender: TObject; const AStatus: string);
begin
  Log(AStatus);
  if Pos('conectado na porta', AStatus) > 0 then
    SetStatus('Online')
  else if AStatus = 'OpenDrone desconectado.' then
    SetStatus('Offline');
end;

procedure TfrmConectionOpendrone.PegaConfiguracao;
begin
  if Assigned(FSetMain) then
  begin
    FHost := FSetMain.DroneIP;
    FUdpPort := FSetMain.DronePortaComando;
  end;

  if Trim(FHost) = '' then
    FHost := '192.168.4.1';

  if FUdpPort <= 0 then
    FUdpPort := 2399;

  if Assigned(lbIP) then
    lbIP.Caption := FHost;
  if Assigned(lbUDP) then
    lbUDP.Caption := IntToStr(FUdpPort);
  if Assigned(lbdevicename) then
    lbdevicename.Caption := 'OpenDrone ESP32 (UDP)';
end;

procedure TfrmConectionOpendrone.InicioHandShake;
begin
  PegaConfiguracao;
  DesativaConnection;

  Log('Inicializando Protocolo OpenDrone...');
  FProtocol := TOpendroneProtocol.Create;
  FProtocol.OnError := @OnProtocolError;
  FProtocol.OnStatus := @OnProtocolStatus;

  FProtocol.Connect(FHost, 0, FUdpPort);
  AtivaJoystick;
  
  if Assigned(frmMain) then
    frmMain.AtivouDrone;
end;

procedure TfrmConectionOpendrone.sendGamepadData;
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

procedure TfrmConectionOpendrone.DesativaJoystick;
begin
  if Assigned(timerJoystick) then
    timerJoystick.Enabled := False;
end;

procedure TfrmConectionOpendrone.AtivaJoystick;
begin
  if Assigned(timerJoystick) then
    timerJoystick.Enabled := True;
end;

procedure TfrmConectionOpendrone.DesativaConnection;
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
