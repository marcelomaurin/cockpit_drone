unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Arrow, Menus, CADSys4, SdpoJoystick, A3nalogGauge,
  IndLed, LedNumber, AdvLed, BCGameGrid, BCSVGViewer, gpssignalplot, gpsskyplot,
  gpstarget, nmeadecode, gpsportconnected, about,
  config, camera, map, funcs, GPS,
  joystick, LCLType, controler, setmain, tacticalhud, flightplan,
  conexaodrone, ConectionCX10W, conectionmavlink, conectiontello,
  conectionopendrone, conectionfq777, conectionardrone, conectionesp32drone,
  aidronemavlink, protocols, rotavoo, cockpit_i18n, sitl_telemetry_bridge,
  sitl_telemetry_state, cockpit_runtime_paths;

const
  refJoy = 127;
  versao = 0.42;

type

  { TfrmMain }

  TfrmMain = class(TForm)
// ... (trimmed fields)
    A3nalogGauge1: TA3nalogGauge;
    AdvCamera: TAdvLed;
    AdvJoyB2: TAdvLed;
    AdvJoyB3: TAdvLed;
    AdvJoyB4: TAdvLed;
    AdvJoyB5: TAdvLed;
    AdvJoyB6: TAdvLed;
    AdvJoystick: TAdvLed;
    AdvJoyB1: TAdvLed;
    AdvMap: TAdvLed;
    AdvGPS: TAdvLed;
    AdvStart: TAdvLed;
    ArrowLeft: TArrow;
    ArrowUp: TArrow;
    ArrowRigth: TArrow;
    ArrowDown: TArrow;
    btGridCAM: TButton;
    btGridCAM1: TButton;
    Button1: TButton;
    btExit: TButton;
    GPSPortConnected1: TGPSPortConnected;
    Label10: TLabel;
    Label11: TLabel;
    lbB1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    ledrotor1: TLEDNumber;
    ledrotor3: TLEDNumber;
    ledrotor2: TLEDNumber;
    ledrotor4: TLEDNumber;
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    NMEADecode1: TNMEADecode;
    Panel1: TPanel;
    pnBaterry: TPanel;
    pnScreens: TPanel;
    pnNAV: TPanel;
    Panel3: TPanel;
    popTray: TPopupMenu;
    SdpoJoystick1: TSdpoJoystick;
    timerJoystick: TTimer;
    TrayIcon1: TTrayIcon;

    procedure AdvGPSChange(Sender: TObject; AState: TLedState);
    procedure AdvGPSClick(Sender: TObject);
    procedure AdvMapChange(Sender: TObject; AState: TLedState);
    procedure AdvCameraChange(Sender: TObject; AState: TLedState);
    procedure AdvCameraClick(Sender: TObject);
    procedure AdvMapClick(Sender: TObject);
    procedure AdvStartChange(Sender: TObject; AState: TLedState);
    procedure AdvStartClick(Sender: TObject);
    procedure ArrowUpChangeBounds(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormKeyPress(Sender: TObject; var Key: char);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure lbB1Click(Sender: TObject);
    procedure btExitClick(Sender: TObject);
    procedure btGridCAM1Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure gridCamClickControl(Sender: TObject; n, x, y: integer);
    procedure btGridCAMClick(Sender: TObject);
    procedure GPSSignalPlot1Click(Sender: TObject);
    procedure Image1Click(Sender: TObject);
    procedure indLed1Click(Sender: TObject);
    procedure ledrotor1Click(Sender: TObject);
    procedure MenuItem1Click(Sender: TObject);
    procedure MenuItem2Click(Sender: TObject);
    procedure MenuItem3Click(Sender: TObject);
    procedure Shape1ChangeBounds(Sender: TObject);
    procedure timerJoystickTimer(Sender: TObject);

  private
    FJoystick: TJoystickController;
    FControler: TDroneControler;

    FKeyUp: Boolean;
    FKeyDown: Boolean;
    FKeyLeft: Boolean;
    FKeyRight: Boolean;
    FKeyZUp: Boolean;
    FKeyZDown: Boolean;

    FKeyB1: Boolean;
    FKeyB2: Boolean;
    FKeyB3: Boolean;
    FKeyB4: Boolean;
    FKeyB5: Boolean;
    FKeyB6: Boolean;

    FBtRota: TButton;
    FSitlBridge: TSitlTelemetryBridge;
    FSitlTimer: TTimer;
    FSitlPanel: TPanel;
    FSitlButton: TButton;
    FSitlStatus: TLabel;
    procedure SitlToggle(Sender: TObject);
    procedure SitlTick(Sender: TObject);

    procedure BtRotaClick(Sender: TObject);
    procedure EnsureAbout;
    procedure EnsureConfig;
    procedure EnsureCam;
    procedure EnsureMap;
    procedure EnsureGPS;
    procedure EnsureTacticalHUD;

    procedure AtualizaLedsBotoes;
    procedure AtualizaRotorDisplay;
    procedure CentralizaComandos;
    procedure LimpaTeclado;
    procedure AplicaTecladoNosBotoes;

    procedure AtivaMapa;
    procedure DesativaMapa;
    procedure AtualizaMapaDrone;

    procedure CarregaConfiguracoesLocais;
    procedure SalvaConfiguracoesLocais;
    procedure AplicaSetMainAoControle;
    procedure SincronizaConfigComSetMain;
    function UsaJoystick: Boolean;

  public
    X, Y, Z: Byte;
    B1, B2, B3, B4, B5, B6: Byte;

    frmConnection: TForm;
    procedure AtivaJoystick;
    procedure DesativaJoystick;
    procedure ConfiguraJoy;
    procedure DesativaDrone;
    procedure AtivaDrone;
    procedure AtivouDrone;
    procedure AtivaGPS;
    procedure DesativaGPS;
    { Mostra o mapa (usado pela janela de rota de voo). }
    procedure MostraMapa;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.lfm}

{ TfrmMain }

procedure TfrmMain.EnsureConfig;
begin
  if not Assigned(frmConfig) then
    frmConfig := TfrmConfig.Create(Self);
end;

procedure TfrmMain.EnsureCam;
begin
  if not Assigned(frmCam) then
    frmCam := TfrmCam.Create(Self);
end;

procedure TfrmMain.EnsureMap;
begin
  if not Assigned(frmMap) then
    frmMap := TfrmMap.Create(Self);
end;

procedure TfrmMain.EnsureGPS;
begin
  if not Assigned(frmGPS) then
    frmGPS := TfrmGPS.Create(Self);
end;

procedure TfrmMain.EnsureTacticalHUD;
begin
  if not Assigned(frmTacticalHUD) then
    frmTacticalHUD := TfrmTacticalHUD.Create(Self);
end;

procedure TfrmMain.EnsureAbout;
begin
  if not Assigned(frmAbout) then
    frmAbout := TfrmAbout.Create(Self);
end;

function TfrmMain.UsaJoystick: Boolean;
begin
  Result := Assigned(FSetMain) and FSetMain.JoystickAtivo;
end;

procedure TfrmMain.CarregaConfiguracoesLocais;
begin
  if not Assigned(FSetMain) then
    Exit;

  if FSetMain.Width > 200 then Width := FSetMain.Width;
  if FSetMain.Height > 200 then Height := FSetMain.Height;

  Left := FSetMain.PosX;
  Top := FSetMain.PosY;

  if FSetMain.Maximizado then
    WindowState := wsMaximized
  else
    WindowState := wsNormal;
end;

procedure TfrmMain.SalvaConfiguracoesLocais;
begin
  if not Assigned(FSetMain) then
    Exit;

  if WindowState = wsNormal then
  begin
    FSetMain.PosX := Left;
    FSetMain.PosY := Top;
    FSetMain.Width := Width;
    FSetMain.Height := Height;
  end;

  FSetMain.Maximizado := WindowState = wsMaximized;
  FSetMain.JoystickAtivo := UsaJoystick;
  FSetMain.AutoStart := AdvStart.State = lsOn;

  if Assigned(FControler) then
  begin
    FSetMain.ThrottleMin := FControler.MinMotor;
    FSetMain.ThrottleMax := FControler.MaxMotor;
    FSetMain.CentroJoy := FControler.CentroJoy;
    FSetMain.ZonaMorta := FControler.ZonaMorta;
    FSetMain.EscalaComando := FControler.EscalaComando;
  end;

  FSetMain.SalvaContexto;
end;

procedure TfrmMain.AplicaSetMainAoControle;
begin
  if (not Assigned(FSetMain)) or (not Assigned(FControler)) then
    Exit;

  FControler.MinMotor := FSetMain.ThrottleMin;
  FControler.MaxMotor := FSetMain.ThrottleMax;
  FControler.CentroJoy := FSetMain.CentroJoy;
  FControler.ZonaMorta := FSetMain.ZonaMorta;
  FControler.EscalaComando := FSetMain.EscalaComando;

  timerJoystick.Interval := FSetMain.TimerInterval;
end;

procedure TfrmMain.SincronizaConfigComSetMain;
begin
  EnsureConfig;

  if not Assigned(FSetMain) then
    Exit;

  if Assigned(frmConfig.cbDevice) then
    frmConfig.cbDevice.ItemIndex := FSetMain.JoystickDeviceIndex;

  if Assigned(frmConfig.ckJoyActive) then
    frmConfig.ckJoyActive.Checked := FSetMain.JoystickAtivo;
end;

procedure TfrmMain.AtualizaLedsBotoes;
begin
  if B1 = 255 then AdvJoyB1.State := lsOn else AdvJoyB1.State := lsOff;
  if B2 = 255 then AdvJoyB2.State := lsOn else AdvJoyB2.State := lsOff;
  if B3 = 255 then AdvJoyB3.State := lsOn else AdvJoyB3.State := lsOff;
  if B4 = 255 then AdvJoyB4.State := lsOn else AdvJoyB4.State := lsOff;
  if B5 = 255 then AdvJoyB5.State := lsOn else AdvJoyB5.State := lsOff;
  if B6 = 255 then AdvJoyB6.State := lsOn else AdvJoyB6.State := lsOff;
end;

procedure TfrmMain.AtualizaRotorDisplay;
begin
  if Assigned(FControler) then
  begin
    ledrotor1.Caption := IntToStr(FControler.Motor1);
    ledrotor2.Caption := IntToStr(FControler.Motor2);
    ledrotor3.Caption := IntToStr(FControler.Motor3);
    ledrotor4.Caption := IntToStr(FControler.Motor4);
  end
  else
  begin
    ledrotor1.Caption := '0';
    ledrotor2.Caption := '0';
    ledrotor3.Caption := '0';
    ledrotor4.Caption := '0';
  end;
end;

procedure TfrmMain.CentralizaComandos;
begin
  X := refJoy;
  Y := refJoy;
  Z := refJoy;
end;

procedure TfrmMain.LimpaTeclado;
begin
  FKeyUp := False;
  FKeyDown := False;
  FKeyLeft := False;
  FKeyRight := False;
  FKeyZUp := False;
  FKeyZDown := False;

  FKeyB1 := False;
  FKeyB2 := False;
  FKeyB3 := False;
  FKeyB4 := False;
  FKeyB5 := False;
  FKeyB6 := False;
end;

procedure TfrmMain.AplicaTecladoNosBotoes;
begin
  if FKeyB1 then B1 := 255;
  if FKeyB2 then B2 := 255;
  if FKeyB3 then B3 := 255;
  if FKeyB4 then B4 := 255;
  if FKeyB5 then B5 := 255;
  if FKeyB6 then B6 := 255;
end;

procedure TfrmMain.AtivaMapa;
begin
  EnsureMap;
  frmMap.Show;
  frmMap.MostrarGrid;
  AdvMap.Blink := True;
  AdvMap.State := lsOn;
  AtualizaMapaDrone;
end;

procedure TfrmMain.MostraMapa;
begin
  AtivaMapa;
end;

procedure TfrmMain.BtRotaClick(Sender: TObject);
begin
  // Só abre para drones com GPS; para os demais explica o motivo.
  AbreRotaVoo;
end;

procedure TfrmMain.DesativaMapa;
begin
  if Assigned(frmMap) then
    frmMap.Hide;

  AdvMap.Blink := False;
  AdvMap.State := lsOff;
end;

procedure TfrmMain.AtualizaMapaDrone;
var
  Lat, Lon: Double;
  Col, Row: Integer;
  Tel: TAIMavTelemetry;
begin
  if not Assigned(frmMap) then
    Exit;

  Col := X div 16;
  Row := Y div 16;

  // Drone MAVLink conectado: posição real do GPS do drone.
  if frmConnection is TfrmConectionMavlink then
  begin
    Tel := TfrmConectionMavlink(frmConnection).Mavlink.Telemetry;
    if Tel.Connected and Tel.PositionValid then
    begin
      frmMap.AtualizaDrone(Tel.Lat, Tel.Lon, Col, Row);
      Exit;
    end;
  end;

  if GlobalFlightPlan.SimulationActive then
  begin
    Lat := GlobalFlightPlan.SimulatedDroneLat;
    Lon := GlobalFlightPlan.SimulatedDroneLon;
    frmMap.AtualizaDrone(Lat, Lon, Col, Row);
    Exit;
  end;

  EnsureGPS;
  if Assigned(frmGPS) then
    frmGPS.Atualiza;

  if Assigned(frmGPS) and frmGPS.TemPosicao then
  begin
    Lat := frmGPS.Latitude;
    Lon := frmGPS.Longitude;
    frmMap.AtualizaDrone(Lat, Lon, Col, Row);
    Exit;
  end;

  Lat := -21.1775 + ((Y - refJoy) / 10000);
  Lon := -47.8103 + ((X - refJoy) / 10000);

  frmMap.AtualizaDrone(Lat, Lon, Col, Row);
end;

procedure TfrmMain.SitlToggle(Sender: TObject);
var
  ScriptPath, PythonExe: string;
begin
  if not Assigned(FSitlBridge) then Exit;
  if FSitlTimer.Enabled then
  begin
    FSitlTimer.Enabled := False;
    FSitlBridge.Stop;
    FSitlButton.Caption := 'Iniciar SITL';
    FSitlStatus.Caption := 'SITL: desligado (somente leitura)';
    Exit;
  end;
  ScriptPath := ResolveCockpitToolPath('sitl_heartbeat_monitor.py', ParamStr(0));
  PythonExe := CockpitPythonExecutable;
  if not FSitlBridge.Start(PythonExe, ScriptPath) then
  begin
    FSitlStatus.Caption := 'SITL: erro - ' + FSitlBridge.LastError;
    Exit;
  end;
  FSitlTimer.Enabled := True;
  FSitlButton.Caption := 'Parar SITL';
  FSitlStatus.Caption := 'SITL: aguardando heartbeat local';
end;

procedure TfrmMain.SitlTick(Sender: TObject);
var
  Tel: TSitlTelemetry;
begin
  if not Assigned(FSitlBridge) then Exit;
  FSitlBridge.Poll(GetTickCount64);
  if not FSitlBridge.IsRunning then
  begin
    FSitlTimer.Enabled := False;
    FSitlButton.Caption := 'Iniciar SITL';
    FSitlStatus.Caption := 'SITL: monitor encerrado - ' + FSitlBridge.LastError;
    Exit;
  end;
  Tel := FSitlBridge.State;
  if Tel.Connected then
    FSitlStatus.Caption := Format('SITL: conectado | %s | sys %d / comp %d | modo %d | armado: %s',
      [Tel.VehicleClass, Tel.SystemId, Tel.ComponentId, Tel.CustomMode,
       BoolToStr(Tel.ArmedReported, True)])
  else if FSitlBridge.LastError <> '' then
    FSitlStatus.Caption := 'SITL: ' + FSitlBridge.LastError
  else
    FSitlStatus.Caption := 'SITL: sem heartbeat (sem controle)';
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  FSitlBridge := TSitlTelemetryBridge.Create;
  FSitlPanel := TPanel.Create(Self);
  FSitlPanel.Parent := Self;
  FSitlPanel.Align := alBottom;
  FSitlPanel.Height := 34;
  FSitlButton := TButton.Create(Self);
  FSitlButton.Parent := FSitlPanel;
  FSitlButton.Align := alLeft;
  FSitlButton.Width := 120;
  FSitlButton.Caption := 'Iniciar SITL';
  FSitlButton.OnClick := @SitlToggle;
  FSitlStatus := TLabel.Create(Self);
  FSitlStatus.Parent := FSitlPanel;
  FSitlStatus.Left := 130;
  FSitlStatus.Top := 9;
  FSitlStatus.Caption := 'SITL: desligado (somente leitura)';
  FSitlTimer := TTimer.Create(Self);
  FSitlTimer.Enabled := False;
  FSitlTimer.Interval := 250;
  FSitlTimer.OnTimer := @SitlTick;
  TrayIcon1.Visible := True;
  KeyPreview := True;

  FJoystick := TJoystickController.Create(SdpoJoystick1);
  FControler := TDroneControler.Create;
  FControler.Ativo := False;

  frmConnection := nil;
  CentralizaComandos;
  LimpaTeclado;

  B1 := 0;
  B2 := 0;
  B3 := 0;
  B4 := 0;
  B5 := 0;
  B6 := 0;

  CarregaConfiguracoesLocais;
  AplicaSetMainAoControle;
  SincronizaConfigComSetMain;

  AtualizaLedsBotoes;
  AtualizaRotorDisplay;

  if UsaJoystick then
    AdvJoystick.State := lsOn
  else
    AdvJoystick.State := lsOff;
  AdvJoystick.Blink := False;

  // Botão da rota de voo (somente drones com GPS), abaixo do botão Sair.
  FBtRota := TButton.Create(Self);
  FBtRota.Parent := btExit.Parent;
  FBtRota.SetBounds(btExit.Left, btExit.Top + btExit.Height + 4, btExit.Width, btExit.Height);
  FBtRota.Caption := 'Rota de voo';
  FBtRota.Hint := 'Planejamento de rota de voo (somente drones com GPS: MAVLink)';
  FBtRota.ShowHint := True;
  FBtRota.OnClick := @BtRotaClick;

  EnsureAbout;
  if Assigned(frmAbout) then
  begin
    frmAbout.BorderStyle := bsNone;
    frmAbout.Position := poScreenCenter;
    frmAbout.AlphaBlend := True;
    frmAbout.AlphaBlendValue := 0;
    frmAbout.Show;
    frmAbout.Update;
    Application.ProcessMessages;

    for I := 0 to 255 do
    begin
      frmAbout.AlphaBlendValue := I;
      frmAbout.Update;
      Application.ProcessMessages;
      Sleep(16);
    end;

    Sleep(5000);

    frmAbout.Hide;
    Application.ProcessMessages;
  end;

  if Assigned(FSetMain) and FSetMain.AutoStart then
    AdvStartClick(Self);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  timerJoystick.Enabled := False;
  FSitlTimer.Enabled := False;
  FreeAndNil(FSitlBridge);
  SalvaConfiguracoesLocais;

  if Assigned(frmAbout) then
    FreeAndNil(frmAbout);

  if Assigned(frmConnection) then
    FreeAndNil(frmConnection);

  if Assigned(frmCam) then
    FreeAndNil(frmCam);

  if Assigned(frmMap) then
    FreeAndNil(frmMap);

  if Assigned(frmGPS) then
    FreeAndNil(frmGPS);

  if Assigned(frmTacticalHUD) then
    FreeAndNil(frmTacticalHUD);

  if Assigned(frmConfig) then
    FreeAndNil(frmConfig);

  if Assigned(FControler) then
    FreeAndNil(FControler);

  FreeAndNil(FJoystick);
end;

procedure TfrmMain.btGridCAMClick(Sender: TObject);
begin
  EnsureCam;
  frmCam.AlternaGrid;
end;

procedure TfrmMain.gridCamClickControl(Sender: TObject; n, x, y: integer);
begin
end;

procedure TfrmMain.btGridCAM1Click(Sender: TObject);
begin
  EnsureMap;
  frmMap.AlternaGrid;
end;

procedure TfrmMain.AdvCameraClick(Sender: TObject);
begin
  EnsureCam;

  if frmCam.Visible then
  begin
    frmCam.Hide;
    frmCam.DesativaCamera;
    AdvCamera.Blink := False;
    AdvCamera.State := lsOff;
  end
  else
  begin
    frmCam.Show;
    frmCam.AtivaCamera;
    AdvCamera.Blink := True;
    AdvCamera.State := lsOn;
  end;
end;

procedure TfrmMain.AdvMapClick(Sender: TObject);
begin
  EnsureMap;

  if frmMap.Visible then
    DesativaMapa
  else
    AtivaMapa;
end;

procedure TfrmMain.AdvStartChange(Sender: TObject; AState: TLedState);
begin
end;

procedure TfrmMain.AtivaGPS;
begin
  AdvGPS.Blink := False;
  AdvGPS.State := lsOn;
end;

procedure TfrmMain.DesativaGPS;
begin
  AdvGPS.Blink := False;
  AdvGPS.State := lsOff;
end;

procedure TfrmMain.AtivaJoystick;
begin
  if not Assigned(FJoystick) then
    Exit;

  if not UsaJoystick then
  begin
    timerJoystick.Enabled := True;
    AdvJoystick.State := lsOff;
    AdvJoystick.Blink := False;
    Exit;
  end;

  try
    if FJoystick.Activate then
    begin
      AdvJoystick.State := lsOn;
      AdvJoystick.Blink := False;
      timerJoystick.Enabled := True;
      CentralizaComandos;
    end
    else
    begin
      AdvJoystick.State := lsOff;
      AdvJoystick.Blink := False;
      timerJoystick.Enabled := False;
      Beep;
    end;
  except
    AdvJoystick.State := lsOff;
    AdvJoystick.Blink := False;
    timerJoystick.Enabled := False;
    Beep;
  end;
end;

procedure TfrmMain.DesativaJoystick;
begin
  timerJoystick.Enabled := False;

  if Assigned(FJoystick) then
    FJoystick.Deactivate;

  AdvJoystick.State := lsOff;
  AdvJoystick.Blink := False;
end;

procedure TfrmMain.ConfiguraJoy;
begin
  EnsureConfig;

  if not Assigned(FJoystick) then
    Exit;

  if not UsaJoystick then
    Exit;

  if Assigned(frmConfig.cbDevice) then
  begin
    FJoystick.ConfigureDevice(frmConfig.cbDevice.ItemIndex);
    if Assigned(FSetMain) then
      FSetMain.JoystickDeviceIndex := frmConfig.cbDevice.ItemIndex;
  end;
end;

procedure TfrmMain.AtivouDrone;
begin
  AdvStart.Blink := False;
  AdvStart.State := lsOn;
end;

procedure TfrmMain.AtivaDrone;
var
  ConnFQ: TfrmConectionFQ777;
  Conn: TfrmConexaoDrone;
  Motivo: string;
begin
  EnsureConfig;

  if frmConnection <> nil then
  begin
    frmConnection.Show;
    Exit;
  end;

  if frmConfig.TipoAtivo = PROTOCOLO_FQ777 then
  begin
    ConnFQ := TfrmConectionFQ777.Create(Self);
    frmConnection := ConnFQ;
    ConnFQ.Show;
    if ConnFQ.Iniciar then
    begin
      AtivouDrone;
      Exit;
    end;
    // Sem a rede do drone não há como ligar o equipamento.
    Motivo := ConnFQ.UltimoErro;
  end
  else
  begin
    case frmConfig.TipoAtivo of
      PROTOCOLO_CX10W: Conn := TfrmConectionCX10W.Create(Self);
      PROTOCOLO_MAVLINK: Conn := TfrmConectionMavlink.Create(Self);
      PROTOCOLO_TELLO: Conn := TfrmConectionTello.Create(Self);
      PROTOCOLO_OPENDRONE: Conn := TfrmConectionOpendrone.Create(Self);
      PROTOCOLO_ARDRONE: Conn := TfrmConectionARDrone.Create(Self);
      PROTOCOLO_ESP32DRONE: Conn := TfrmConectionESP32Drone.Create(Self);
    else
      Conn := nil;
    end;
    if Conn = nil then
      Motivo := 'Selecione o drone em Configuração > Protocolo.'
    else
    begin
      frmConnection := Conn;
      Conn.Show;
      if Conn.Iniciar then
      begin
        AtivouDrone;
        Exit;
      end;
      Motivo := Conn.UltimoErro;
    end;
  end;

  if Motivo = '' then
    Motivo := NomeProtocolo(frmConfig.TipoAtivo) + ' não encontrado.';
  MessageDlg(NomeProtocolo(frmConfig.TipoAtivo), Motivo, mtWarning, [mbOK], 0);
  if AdvStart.State = lsOn then
    AdvStartClick(Self) // mesmo caminho do botão desligar
  else
    DesativaDrone;
end;

procedure TfrmMain.DesativaDrone;
begin
  if frmConnection <> nil then
  begin
    frmConnection.Hide;
    FreeAndNil(frmConnection);
  end;
end;

procedure TfrmMain.AdvStartClick(Sender: TObject);
begin
  if AdvStart.State = lsOff then
  begin
    AdvStart.State := lsOn;
    AdvStart.Blink := True;

    if Assigned(FControler) then
      FControler.Ativo := True;

    ConfiguraJoy;
    AtivaJoystick;
    AtivaDrone;
  end
  else
  begin
    AdvStart.State := lsOff;
    AdvStart.Blink := False;

    if Assigned(FControler) then
    begin
      FControler.Ativo := False;
      FControler.Reset;
    end;

    DesativaJoystick;
    DesativaDrone;
    AtualizaRotorDisplay;
  end;
end;

procedure TfrmMain.ArrowUpChangeBounds(Sender: TObject);
begin
end;

procedure TfrmMain.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_UP:    FKeyUp := True;
    VK_DOWN:  FKeyDown := True;
    VK_LEFT:  FKeyLeft := True;
    VK_RIGHT: FKeyRight := True;
    VK_RETURN:
      begin
        AdvStartClick(Self);
        Key := 0;
      end;
    VK_ESCAPE:
      begin
        Close;
        Key := 0;
      end;
  end;
end;

procedure TfrmMain.FormKeyPress(Sender: TObject; var Key: char);
begin
  case UpCase(Key) of
    'W': FKeyUp := True;
    'S': FKeyDown := True;
    'A': FKeyLeft := True;
    'D': FKeyRight := True;
    'Q': FKeyZDown := True;
    'E': FKeyZUp := True;
    '1': FKeyB1 := True;
    '2': FKeyB2 := True;
    '3': FKeyB3 := True;
    '4': FKeyB4 := True;
    '5': FKeyB5 := True;
    '6': FKeyB6 := True;
    'R': CentralizaComandos;
    'T':
      begin
        EnsureTacticalHUD;
        if frmTacticalHUD.Visible then
          frmTacticalHUD.Hide
        else
          frmTacticalHUD.Show;
      end;
  end;
end;

procedure TfrmMain.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_UP:    FKeyUp := False;
    VK_DOWN:  FKeyDown := False;
    VK_LEFT:  FKeyLeft := False;
    VK_RIGHT: FKeyRight := False;
    // Teclas de letra: são ligadas no KeyPress e precisam ser soltas aqui,
    // senão o comando fica preso depois de soltar a tecla.
    VK_W: FKeyUp := False;
    VK_S: FKeyDown := False;
    VK_A: FKeyLeft := False;
    VK_D: FKeyRight := False;
    VK_Q: FKeyZDown := False;
    VK_E: FKeyZUp := False;
    VK_SPACE:
      begin
        FKeyB1 := False;
        FKeyB2 := False;
        FKeyB3 := False;
        FKeyB4 := False;
        FKeyB5 := False;
        FKeyB6 := False;
      end;
  end;
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  AplicarIdioma(Self);
  KeyPreview := True;

  if (AdvMap.State = lsOn) and Assigned(frmMap) then
    AtualizaMapaDrone;
end;

procedure TfrmMain.lbB1Click(Sender: TObject);
begin
end;

procedure TfrmMain.btExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmMain.AdvCameraChange(Sender: TObject; AState: TLedState);
begin
end;

procedure TfrmMain.AdvMapChange(Sender: TObject; AState: TLedState);
begin
end;

procedure TfrmMain.AdvGPSChange(Sender: TObject; AState: TLedState);
begin
end;

procedure TfrmMain.AdvGPSClick(Sender: TObject);
begin
  EnsureGPS;

  if frmGPS.Visible then
  begin
    frmGPS.Hide;
    AdvGPS.State := lsOff;
    AdvGPS.Blink := False;
  end
  else
  begin
    frmGPS.Show;
    AdvGPS.Blink := True;
    AdvGPS.State := lsOn;
  end;
end;

procedure TfrmMain.Button1Click(Sender: TObject);
begin
  EnsureConfig;
  frmConfig.ShowModal;

  if Assigned(frmConfig.ckJoyActive) and Assigned(FSetMain) then
    FSetMain.JoystickAtivo := frmConfig.ckJoyActive.Checked;

  if Assigned(frmConfig.cbDevice) and Assigned(FSetMain) then
    FSetMain.JoystickDeviceIndex := frmConfig.cbDevice.ItemIndex;

  AplicaSetMainAoControle;
end;

procedure TfrmMain.GPSSignalPlot1Click(Sender: TObject);
begin
end;

procedure TfrmMain.Image1Click(Sender: TObject);
begin
end;

procedure TfrmMain.indLed1Click(Sender: TObject);
begin
end;

procedure TfrmMain.ledrotor1Click(Sender: TObject);
begin
end;

procedure TfrmMain.MenuItem1Click(Sender: TObject);
begin
  EnsureConfig;
  frmConfig.Show;
end;

procedure TfrmMain.MenuItem2Click(Sender: TObject);
begin
  Show;

  if frmConnection <> nil then
    frmConnection.Show;

  if (AdvCamera.State = lsOn) then
  begin
    EnsureCam;
    frmCam.Show;
  end;

  if (AdvMap.State = lsOn) then
    AtivaMapa;

  if (AdvGPS.State = lsOn) then
  begin
    EnsureGPS;
    frmGPS.Show;
  end;
end;

procedure TfrmMain.MenuItem3Click(Sender: TObject);
begin
  Close;
end;

procedure TfrmMain.Shape1ChangeBounds(Sender: TObject);
begin
end;

procedure TfrmMain.timerJoystickTimer(Sender: TObject);
var
  X0, Y0, Z0: Double;
  JoyDisponivel: Boolean;
begin
  X0 := refJoy;
  Y0 := refJoy;
  Z0 := Z;

  JoyDisponivel := UsaJoystick and Assigned(FJoystick) and FJoystick.Active;
  if JoyDisponivel then
    JoyDisponivel := FJoystick.UpdateState;

  if JoyDisponivel then
  begin
    X0 := FJoystick.State.X;
    Y0 := FJoystick.State.Y;
    Z0 := FJoystick.State.Z;

    B1 := FJoystick.State.Buttons.B1;
    B2 := FJoystick.State.Buttons.B2;
    B3 := FJoystick.State.Buttons.B3;
    B4 := FJoystick.State.Buttons.B4;
    B5 := FJoystick.State.Buttons.B5;
    B6 := FJoystick.State.Buttons.B6;
  end
  else
  begin
    // Falha/desconexao do joystick: neutro para direcao e acelerador minimo.
    if UsaJoystick then Z0 := 0;
    B1 := 0;
    B2 := 0;
    B3 := 0;
    B4 := 0;
    B5 := 0;
    B6 := 0;
  end;

  if FKeyUp and (not FKeyDown) then
    Y0 := 0
  else if FKeyDown and (not FKeyUp) then
    Y0 := 255;

  if FKeyLeft and (not FKeyRight) then
    X0 := 0
  else if FKeyRight and (not FKeyLeft) then
    X0 := 255;

  if FKeyZDown and (not FKeyZUp) then
  begin
    if Z > 0 then
      Dec(Z);
  end
  else if FKeyZUp and (not FKeyZDown) then
  begin
    if Z < 255 then
      Inc(Z);
  end
  else
    Z := Byte(EnsureRange(Round(Z0), 0, 255));

  AplicaTecladoNosBotoes;
  AtualizaLedsBotoes;

  if B5 = 255 then
  begin
    CentralizaComandos;
    X0 := refJoy;
    Y0 := refJoy;
  end;

  // Comando proporcional: soltar o manche retorna ao centro imediatamente.
  // Zona morta evita deriva por pequenas oscilacoes do dispositivo.
  if Abs(Round(X0) - refJoy) <= 12 then X0 := refJoy;
  if Abs(Round(Y0) - refJoy) <= 12 then Y0 := refJoy;
  X := Byte(EnsureRange(Round(X0), 0, 255));
  Y := Byte(EnsureRange(Round(Y0), 0, 255));
  ArrowUp.ArrowColor := clBlack;
  ArrowDown.ArrowColor := clBlack;
  ArrowLeft.ArrowColor := clBlack;
  ArrowRigth.ArrowColor := clBlack;
  if Y > refJoy then ArrowUp.ArrowColor := clRed;
  if Y < refJoy then ArrowDown.ArrowColor := clRed;
  if X > refJoy then ArrowLeft.ArrowColor := clRed;
  if X < refJoy then ArrowRigth.ArrowColor := clRed;

  if Assigned(FControler) then
    FControler.Atualiza(X, Y, Z, B1, B2, B3, B4, B5, B6);

  AtualizaRotorDisplay;

  if Assigned(frmMap) and frmMap.Visible then
    AtualizaMapaDrone;
end;

end.
