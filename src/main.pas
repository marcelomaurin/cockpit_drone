unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Arrow, Menus, acs_mixer, CADSys4, SdpoJoystick, A3nalogGauge,
  IndLed, LedNumber, AdvLed, BCGameGrid, BCSVGViewer, gpssignalplot, gpsskyplot,
  gpstarget, nmeadecode, gpsportconnected, about,
  lNetComponents, config, cd10w, camera, map, ConectionCX10W, funcs, GPS,
  joystick, LCLType, uplaysound, controler, setmain;

const
  refJoy = 127;
  versao = 0.34;

type

  { TfrmMain }

  TfrmMain = class(TForm)
    A3nalogGauge1: TA3nalogGauge;
    AcsMixer1: TAcsMixer;
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
    playsound1: Tplaysound;
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

    procedure EnsureAbout;
    procedure EnsureConfig;
    procedure EnsureCam;
    procedure EnsureMap;
    procedure EnsureGPS;

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
begin
  if not Assigned(frmMap) then
    Exit;

  Col := X div 16;
  Row := Y div 16;

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

procedure TfrmMain.FormCreate(Sender: TObject);
var
  I: Integer;
begin
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
begin
  EnsureConfig;

  if frmConnection = nil then
  begin
    if frmConfig.TipoAtivo = 0 then
    begin
      frmConnection := TfrmConectionCX10W.Create(Self);
      TfrmConectionCX10W(frmConnection).Show;
      TfrmConectionCX10W(frmConnection).PegaConfiguracao;
      TfrmConectionCX10W(frmConnection).InicioHandShake;
    end;
  end
  else
    frmConnection.Show;
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
  end;
end;

procedure TfrmMain.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_UP:    FKeyUp := False;
    VK_DOWN:  FKeyDown := False;
    VK_LEFT:  FKeyLeft := False;
    VK_RIGHT: FKeyRight := False;
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
begin
  X0 := refJoy;
  Y0 := refJoy;
  Z0 := Z;

  if UsaJoystick and Assigned(FJoystick) then
    FJoystick.UpdateState;

  if UsaJoystick and Assigned(FJoystick) and FJoystick.Active then
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
    Z := Byte(Round(Z0)) and $FF;

  AplicaTecladoNosBotoes;
  AtualizaLedsBotoes;

  if B5 = 255 then
    CentralizaComandos;

  if (Y0 < 120) then
  begin
    ArrowUp.ArrowColor := clRed;
    if Y < 255 then Inc(Y);
    if Y < refJoy then Y := refJoy;
  end
  else
  begin
    ArrowUp.ArrowColor := clBlack;
    if (Round(Y0) = refJoy) and (Y > refJoy) and (B6 = 0) then
      Dec(Y);
  end;

  if (Y0 > 140) then
  begin
    ArrowDown.ArrowColor := clRed;
    if Y > 0 then Dec(Y);
    if Y > refJoy then Y := refJoy;
  end
  else
  begin
    ArrowDown.ArrowColor := clBlack;
    if (Round(Y0) = refJoy) and (Y < refJoy) and (B6 = 0) then
      Inc(Y);
  end;

  if (X0 < 120) then
  begin
    ArrowLeft.ArrowColor := clRed;
    if X < 255 then Inc(X);
    if X < refJoy then X := refJoy;
  end
  else
  begin
    ArrowLeft.ArrowColor := clBlack;
    if (Round(X0) = refJoy) and (X > refJoy) and (B6 = 0) then
      Dec(X);
  end;

  if (X0 > 140) then
  begin
    ArrowRigth.ArrowColor := clRed;
    if X > 0 then Dec(X);
    if X > refJoy then X := refJoy;
  end
  else
  begin
    ArrowRigth.ArrowColor := clBlack;
    if (Round(X0) = refJoy) and (X < refJoy) and (B6 = 0) then
      Inc(X);
  end;

  if Assigned(FControler) then
    FControler.Atualiza(X, Y, Z, B1, B2, B3, B4, B5, B6);

  AtualizaRotorDisplay;

  if Assigned(frmMap) and frmMap.Visible then
    AtualizaMapaDrone;
end;

end.
