unit config;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ComCtrls, ExtCtrls, Arrow, AdvLed, Types, SdpoJoystick, funcs, SdpoSerial
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

type

  { Tfrmconfig }

  Tfrmconfig = class(TForm)
    advButton0: TAdvLed;
    advButton1: TAdvLed;
    advButton2: TAdvLed;
    advButton3: TAdvLed;
    advButton4: TAdvLed;
    advButton5: TAdvLed;
    Arrow1: TArrow;
    Arrow2: TArrow;
    Arrow3: TArrow;
    Arrow4: TArrow;
    cbDevice: TComboBox;
    ckbGPS: TCheckBox;
    ckTest: TCheckBox;
    ckJoyActive: TCheckBox;
    cbBaudrate: TComboBox;
    cbSerialPort: TComboBox;
    edIP: TEdit;
    edTCPPORT: TEdit;
    edUDPPORT: TEdit;
    Label1: TLabel;
    Label10: TLabel;
    Label11: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    label1b1: TLabel;
    label1b2: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    lbX: TLabel;
    label1b: TLabel;
    lbY: TLabel;
    lbZ: TLabel;
    pcDrones: TPageControl;
    pnNAV: TPanel;
    cbDatabits: TRadioGroup;
    rgFlowControl: TRadioGroup;
    rgParity: TRadioGroup;
    rgStopbit: TRadioGroup;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    tsEquipamento: TTabSheet;
    timerJoystick: TTimer;

    procedure btCalibrationClick(Sender: TObject);
    procedure cbDeviceChange(Sender: TObject);
    procedure cbDroneClick(Sender: TObject);
    procedure cbSerialPortChange(Sender: TObject);
    procedure ckJoyActiveChange(Sender: TObject);
    procedure ckTestChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Label4Click(Sender: TObject);
    procedure TabSheet1ContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure timerJoystickTimer(Sender: TObject);
    procedure cbProtocolChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormShow(Sender: TObject);

  private
    procedure AtualizaLedsBotoes;
    procedure LimpaLeitura;
    function MainDisponivel: Boolean;
    function PortaSerialExiste(const APorta: string): Boolean;
    procedure CarregaPortasSeriais;
    procedure AdicionaPortaSeExistir(const APorta: string);
    function CriaCampo(AParent: TWinControl; ALeft, ATop, AWidth: Integer;
      const ARotulo, ANome: string): TEdit;
    function CriaOpcao(AParent: TWinControl; ALeft, ATop: Integer;
      const ARotulo, ANome: string): TCheckBox;
    procedure CriaAbaFQ777;
    procedure CriaAbaARDrone;
    procedure CriaAbaESP32Drone;

  public
    TipoAtivo: Integer;
    cbProtocol: TComboBox;

    // Dynamic tabs and edits
    tsMavlink: TTabSheet;
    edMavIP: TEdit;
    edMavPort: TEdit;
    edMavSysId: TEdit;

    tsTello: TTabSheet;
    edTelloIP: TEdit;
    edTelloCmdPort: TEdit;
    edTelloVidPort: TEdit;
    edTelloStatePort: TEdit;

    tsOpendrone: TTabSheet;
    edOpendroneIP: TEdit;
    edOpendronePort: TEdit;

    tsFQ777: TTabSheet;
    edFQ777IP: TEdit;
    edFQ777TCP: TEdit;
    edFQ777UDP: TEdit;
    ckFQ777WifiAuto: TCheckBox;
    edFQ777SSID: TEdit;
    edFQ777Senha: TEdit;
    ckFQ777Video: TCheckBox;
    ckFQ777Gravar: TCheckBox;
    edFQ777FFmpeg: TEdit;
    edFQ777ZonaMorta: TEdit;
    edFQ777EixoRolagem: TEdit;
    edFQ777EixoArfagem: TEdit;
    edFQ777EixoGuinada: TEdit;
    edFQ777EixoAcelerador: TEdit;
    cbFQ777Acelerador: TComboBox;

    tsARDrone: TTabSheet;
    edARDroneIP: TEdit;
    ckARDroneVideo: TCheckBox;
    edARDroneFFmpeg: TEdit;
    edARDroneAltura: TEdit;
    ckARDroneExterno: TCheckBox;
    edARDroneSensibilidade: TEdit;

    tsESP32Drone: TTabSheet;
    edESP32IP: TEdit;
    edESP32Porta: TEdit;

    procedure AtualizaAbasProtocolo;
    procedure CarregarValoresTela;
    procedure SalvarConfiguracoes;
  end;

var
  frmconfig: Tfrmconfig;

implementation

{$R *.lfm}

uses
  main, setmain, Math;

{ Tfrmconfig }

function Tfrmconfig.MainDisponivel: Boolean;
begin
  Result := Assigned(frmMain) and Assigned(frmMain.SdpoJoystick1);
end;

procedure Tfrmconfig.LimpaLeitura;
begin
  lbX.Caption := '0';
  lbY.Caption := '0';
  lbZ.Caption := '0';

  advButton0.State := lsOff;
  advButton1.State := lsOff;
  advButton2.State := lsOff;
  advButton3.State := lsOff;
  advButton4.State := lsOff;
  advButton5.State := lsOff;
end;

procedure Tfrmconfig.AtualizaLedsBotoes;
begin
  if not MainDisponivel then
  begin
    LimpaLeitura;
    Exit;
  end;

  if frmMain.SdpoJoystick1.Buttons[0].ToBoolean then advButton0.State := lsOn else advButton0.State := lsOff;
  if frmMain.SdpoJoystick1.Buttons[1].ToBoolean then advButton1.State := lsOn else advButton1.State := lsOff;
  if frmMain.SdpoJoystick1.Buttons[2].ToBoolean then advButton2.State := lsOn else advButton2.State := lsOff;
  if frmMain.SdpoJoystick1.Buttons[3].ToBoolean then advButton3.State := lsOn else advButton3.State := lsOff;
  if frmMain.SdpoJoystick1.Buttons[4].ToBoolean then advButton4.State := lsOn else advButton4.State := lsOff;
  if frmMain.SdpoJoystick1.Buttons[5].ToBoolean then advButton5.State := lsOn else advButton5.State := lsOff;
end;

function Tfrmconfig.PortaSerialExiste(const APorta: string): Boolean;
{$IFDEF MSWINDOWS}
var
  Buffer: array[0..1023] of Char;
  NomeInterno: string;
begin
  FillChar(Buffer, SizeOf(Buffer), 0);

  NomeInterno := APorta;
  Result := QueryDosDevice(PChar(NomeInterno), Buffer, SizeOf(Buffer) div SizeOf(Char)) <> 0;
end;
{$ELSE}
begin
  Result := FileExists(APorta);
end;
{$ENDIF}

procedure Tfrmconfig.AdicionaPortaSeExistir(const APorta: string);
begin
  if (Trim(APorta) <> '') and PortaSerialExiste(APorta) then
  begin
    if cbSerialPort.Items.IndexOf(APorta) < 0 then
      cbSerialPort.Items.Add(APorta);
  end;
end;

procedure Tfrmconfig.CarregaPortasSeriais;
var
  I: Integer;
  Porta: string;
  PortaAnterior: string;
  SR: TSearchRec;
begin
  PortaAnterior := Trim(cbSerialPort.Text);

  cbSerialPort.Items.BeginUpdate;
  try
    cbSerialPort.Items.Clear;

    {$IFDEF MSWINDOWS}
    for I := 1 to 256 do
    begin
      Porta := 'COM' + IntToStr(I);
      AdicionaPortaSeExistir(Porta);
    end;
    {$ELSE}

    if FindFirst('/dev/ttyUSB*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') then
          AdicionaPortaSeExistir('/dev/' + SR.Name);
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;

    if FindFirst('/dev/ttyACM*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') then
          AdicionaPortaSeExistir('/dev/' + SR.Name);
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;

    if FindFirst('/dev/ttyS*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') then
          AdicionaPortaSeExistir('/dev/' + SR.Name);
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;

    if DirectoryExists('/dev/serial/by-id') then
    begin
      if FindFirst('/dev/serial/by-id/*', faAnyFile, SR) = 0 then
      begin
        repeat
          if (SR.Name <> '.') and (SR.Name <> '..') then
            AdicionaPortaSeExistir('/dev/serial/by-id/' + SR.Name);
        until FindNext(SR) <> 0;
        FindClose(SR);
      end;
    end;
    {$ENDIF}

    if PortaAnterior <> '' then
      cbSerialPort.ItemIndex := cbSerialPort.Items.IndexOf(PortaAnterior);

    if (cbSerialPort.ItemIndex < 0) and (cbSerialPort.Items.Count > 0) then
      cbSerialPort.ItemIndex := 0;
  finally
    cbSerialPort.Items.EndUpdate;
  end;
end;

procedure Tfrmconfig.FormCreate(Sender: TObject);
begin
  TipoAtivo := 0;
  LimpaLeitura;
  CarregaPortasSeriais;

  OnShow := @FormShow;
  OnClose := @FormClose;

  cbProtocol := TComboBox.Create(Self);
  cbProtocol.Parent := tsEquipamento;
  cbProtocol.Left := edIP.Left;
  cbProtocol.Width := edIP.Width;
  cbProtocol.Top := edIP.Top + edIP.Height + 10;
  cbProtocol.Style := csDropDownList;
  cbProtocol.Items.Add('Cheerson CX-10W');
  cbProtocol.Items.Add('MAVLink (Standard)');
  cbProtocol.Items.Add('DJI Tello (UDP)');
  cbProtocol.Items.Add('OpenDrone ESP32 (UDP)');
  cbProtocol.Items.Add('FQ777-954 (Wi-Fi)');
  cbProtocol.Items.Add('Parrot AR.Drone 2.0');
  cbProtocol.Items.Add('Drone ESP32 (firmware Cockpit)');

  if Assigned(FSetMain) then
  begin
    cbProtocol.ItemIndex := FSetMain.DroneProtocolo;
    TipoAtivo := FSetMain.DroneProtocolo;
  end
  else
    cbProtocol.ItemIndex := 0;

  cbProtocol.OnChange := @cbProtocolChange;

  with TLabel.Create(Self) do
  begin
    Parent := tsEquipamento;
    Left := cbProtocol.Left - 85;
    Top := cbProtocol.Top + 3;
    Caption := 'Protocol:';
    Font.Style := [fsBold];
  end;

  // Create tsMavlink
  tsMavlink := TTabSheet.Create(Self);
  tsMavlink.Name := 'tsMavlink';
  tsMavlink.PageControl := pcDrones;
  tsMavlink.Caption := 'MAVLink';

  with TLabel.Create(Self) do
  begin
    Parent := tsMavlink;
    Left := 15; Top := 15;
    Caption := 'MAVLink IP:';
  end;
  edMavIP := TEdit.Create(Self);
  edMavIP.Name := 'edMavIP';
  edMavIP.Parent := tsMavlink;
  edMavIP.Left := 15; edMavIP.Top := 32; edMavIP.Width := 150;
  edMavIP.Text := '192.168.1.1';

  with TLabel.Create(Self) do
  begin
    Parent := tsMavlink;
    Left := 15; Top := 65;
    Caption := 'UDP Port:';
  end;
  edMavPort := TEdit.Create(Self);
  edMavPort.Name := 'edMavPort';
  edMavPort.Parent := tsMavlink;
  edMavPort.Left := 15; edMavPort.Top := 82; edMavPort.Width := 100;
  edMavPort.Text := '14550';

  with TLabel.Create(Self) do
  begin
    Parent := tsMavlink;
    Left := 15; Top := 115;
    Caption := 'System ID:';
  end;
  edMavSysId := TEdit.Create(Self);
  edMavSysId.Name := 'edMavSysId';
  edMavSysId.Parent := tsMavlink;
  edMavSysId.Left := 15; edMavSysId.Top := 132; edMavSysId.Width := 80;
  edMavSysId.Text := '255';

  // Create tsTello
  tsTello := TTabSheet.Create(Self);
  tsTello.Name := 'tsTello';
  tsTello.PageControl := pcDrones;
  tsTello.Caption := 'DJI Tello';

  with TLabel.Create(Self) do
  begin
    Parent := tsTello;
    Left := 15; Top := 15;
    Caption := 'Tello IP:';
  end;
  edTelloIP := TEdit.Create(Self);
  edTelloIP.Name := 'edTelloIP';
  edTelloIP.Parent := tsTello;
  edTelloIP.Left := 15; edTelloIP.Top := 32; edTelloIP.Width := 150;
  edTelloIP.Text := '192.168.10.1';

  with TLabel.Create(Self) do
  begin
    Parent := tsTello;
    Left := 15; Top := 65;
    Caption := 'Command Port UDP:';
  end;
  edTelloCmdPort := TEdit.Create(Self);
  edTelloCmdPort.Name := 'edTelloCmdPort';
  edTelloCmdPort.Parent := tsTello;
  edTelloCmdPort.Left := 15; edTelloCmdPort.Top := 82; edTelloCmdPort.Width := 100;
  edTelloCmdPort.Text := '8889';

  with TLabel.Create(Self) do
  begin
    Parent := tsTello;
    Left := 15; Top := 115;
    Caption := 'State Port UDP:';
  end;
  edTelloStatePort := TEdit.Create(Self);
  edTelloStatePort.Name := 'edTelloStatePort';
  edTelloStatePort.Parent := tsTello;
  edTelloStatePort.Left := 15; edTelloStatePort.Top := 132; edTelloStatePort.Width := 100;
  edTelloStatePort.Text := '8890';

  // Create tsOpendrone
  tsOpendrone := TTabSheet.Create(Self);
  tsOpendrone.Name := 'tsOpendrone';
  tsOpendrone.PageControl := pcDrones;
  tsOpendrone.Caption := 'OpenDrone ESP32';

  with TLabel.Create(Self) do
  begin
    Parent := tsOpendrone;
    Left := 15; Top := 15;
    Caption := 'OpenDrone IP:';
  end;
  edOpendroneIP := TEdit.Create(Self);
  edOpendroneIP.Name := 'edOpendroneIP';
  edOpendroneIP.Parent := tsOpendrone;
  edOpendroneIP.Left := 15; edOpendroneIP.Top := 32; edOpendroneIP.Width := 150;
  edOpendroneIP.Text := '192.168.4.1';

  with TLabel.Create(Self) do
  begin
    Parent := tsOpendrone;
    Left := 15; Top := 65;
    Caption := 'UDP Port:';
  end;
  edOpendronePort := TEdit.Create(Self);
  edOpendronePort.Name := 'edOpendronePort';
  edOpendronePort.Parent := tsOpendrone;
  edOpendronePort.Left := 15; edOpendronePort.Top := 82; edOpendronePort.Width := 100;
  edOpendronePort.Text := '2399';

  CriaAbaFQ777;
  CriaAbaARDrone;
  CriaAbaESP32Drone;

  TabSheet1.Caption := 'Cheerson CX-10W';

  CarregarValoresTela;
end;

function Tfrmconfig.CriaCampo(AParent: TWinControl; ALeft, ATop, AWidth: Integer;
  const ARotulo, ANome: string): TEdit;
begin
  with TLabel.Create(Self) do
  begin
    Parent := AParent;
    Left := ALeft; Top := ATop;
    Caption := ARotulo;
  end;
  Result := TEdit.Create(Self);
  Result.Name := ANome;
  Result.Parent := AParent;
  Result.Left := ALeft; Result.Top := ATop + 17; Result.Width := AWidth;
  Result.Text := '';
end;

function Tfrmconfig.CriaOpcao(AParent: TWinControl; ALeft, ATop: Integer;
  const ARotulo, ANome: string): TCheckBox;
begin
  Result := TCheckBox.Create(Self);
  Result.Name := ANome;
  Result.Parent := AParent;
  Result.Left := ALeft; Result.Top := ATop;
  Result.Caption := ARotulo;
end;

procedure Tfrmconfig.CriaAbaFQ777;
var
  Box: TScrollBox;
begin
  tsFQ777 := TTabSheet.Create(Self);
  tsFQ777.Name := 'tsFQ777';
  tsFQ777.PageControl := pcDrones;
  tsFQ777.Caption := 'FQ777-954';

  Box := TScrollBox.Create(Self);
  Box.Parent := tsFQ777;
  Box.Align := alClient;
  Box.BorderStyle := bsNone;

  // Rede do drone
  edFQ777IP := CriaCampo(Box, 15, 10, 130, 'IP do drone:', 'edFQ777IP');
  edFQ777TCP := CriaCampo(Box, 155, 10, 60, 'TCP:', 'edFQ777TCP');
  edFQ777UDP := CriaCampo(Box, 225, 10, 60, 'UDP:', 'edFQ777UDP');

  // Wi-Fi
  ckFQ777WifiAuto := CriaOpcao(Box, 15, 60,
    'Procurar e conectar no Wi-Fi do drone ao ligar', 'ckFQ777WifiAuto');
  edFQ777SSID := CriaCampo(Box, 15, 82, 130, 'Nome da rede (padrões ;):', 'edFQ777SSID');
  edFQ777Senha := CriaCampo(Box, 155, 82, 130, 'Senha (vazio = aberta):', 'edFQ777Senha');
  edFQ777Senha.PasswordChar := '*';

  // Vídeo
  ckFQ777Video := CriaOpcao(Box, 15, 132, 'Receber vídeo da câmera', 'ckFQ777Video');
  ckFQ777Gravar := CriaOpcao(Box, 15, 152, 'Gravar vídeo (.h264 na pasta videos)', 'ckFQ777Gravar');
  edFQ777FFmpeg := CriaCampo(Box, 15, 174, 270,
    'ffmpeg (vazio = ao lado do programa ou no PATH):', 'edFQ777FFmpeg');

  // Controle
  edFQ777ZonaMorta := CriaCampo(Box, 15, 224, 50, 'Zona morta %:', 'edFQ777ZonaMorta');
  with TLabel.Create(Self) do
  begin
    Parent := Box;
    Left := 85; Top := 224;
    Caption := 'Acelerador:';
  end;
  cbFQ777Acelerador := TComboBox.Create(Self);
  cbFQ777Acelerador.Name := 'cbFQ777Acelerador';
  cbFQ777Acelerador.Parent := Box;
  cbFQ777Acelerador.Left := 85; cbFQ777Acelerador.Top := 241; cbFQ777Acelerador.Width := 200;
  cbFQ777Acelerador.Style := csDropDownList;
  cbFQ777Acelerador.Items.Add('Gatilho (solto = parado)');
  cbFQ777Acelerador.Items.Add('Manche (embaixo = parado)');

  with TLabel.Create(Self) do
  begin
    Parent := Box;
    Left := 15; Top := 276;
    Caption := 'Eixo do joystick (0..5) para cada comando:';
  end;
  edFQ777EixoRolagem := CriaCampo(Box, 15, 296, 40, 'Rolagem', 'edFQ777EixoRolagem');
  edFQ777EixoArfagem := CriaCampo(Box, 80, 296, 40, 'Arfagem', 'edFQ777EixoArfagem');
  edFQ777EixoGuinada := CriaCampo(Box, 145, 296, 40, 'Guinada', 'edFQ777EixoGuinada');
  edFQ777EixoAcelerador := CriaCampo(Box, 210, 296, 40, 'Acelerador', 'edFQ777EixoAcelerador');
end;

procedure Tfrmconfig.CriaAbaARDrone;
var
  Box: TScrollBox;
begin
  tsARDrone := TTabSheet.Create(Self);
  tsARDrone.Name := 'tsARDrone';
  tsARDrone.PageControl := pcDrones;
  tsARDrone.Caption := 'AR.Drone 2.0';

  Box := TScrollBox.Create(Self);
  Box.Parent := tsARDrone;
  Box.Align := alClient;
  Box.BorderStyle := bsNone;

  edARDroneIP := CriaCampo(Box, 15, 10, 130, 'IP do drone:', 'edARDroneIP');
  with TLabel.Create(Self) do
  begin
    Parent := Box;
    Left := 155; Top := 30;
    Caption := 'Portas fixas: AT 5556, telemetria 5554, vídeo 5555';
  end;

  ckARDroneVideo := CriaOpcao(Box, 15, 60, 'Receber vídeo da câmera frontal', 'ckARDroneVideo');
  edARDroneFFmpeg := CriaCampo(Box, 15, 82, 270,
    'ffmpeg (vazio = ao lado do programa ou no PATH):', 'edARDroneFFmpeg');

  edARDroneAltura := CriaCampo(Box, 15, 132, 60, 'Altura máx. (m):', 'edARDroneAltura');
  edARDroneSensibilidade := CriaCampo(Box, 145, 132, 60, 'Sensibilidade %:', 'edARDroneSensibilidade');
  ckARDroneExterno := CriaOpcao(Box, 15, 182,
    'Voo ao ar livre (sem protetor de hélices)', 'ckARDroneExterno');

  with TLabel.Create(Self) do
  begin
    Parent := Box;
    Left := 15; Top := 212;
    Caption := 'Botão 3 decola, botão 4 pousa. Emergência e calibração na janela do drone.';
  end;
end;

procedure Tfrmconfig.CriaAbaESP32Drone;
var
  Box: TScrollBox;
begin
  tsESP32Drone := TTabSheet.Create(Self);
  tsESP32Drone.Name := 'tsESP32Drone';
  tsESP32Drone.PageControl := pcDrones;
  tsESP32Drone.Caption := 'Drone ESP32';

  Box := TScrollBox.Create(Self);
  Box.Parent := tsESP32Drone;
  Box.Align := alClient;
  Box.BorderStyle := bsNone;

  edESP32IP := CriaCampo(Box, 15, 10, 130, 'IP do drone:', 'edESP32IP');
  edESP32Porta := CriaCampo(Box, 155, 10, 60, 'UDP:', 'edESP32Porta');

  with TLabel.Create(Self) do
  begin
    Parent := Box;
    Left := 15; Top := 62;
    Caption := 'Firmware: pasta firmware/esp32_drone (rede CockpitDrone-XXXX).';
  end;
  with TLabel.Create(Self) do
  begin
    Parent := Box;
    Left := 15; Top := 82;
    Caption := 'Botão 3 arma (aceleração no mínimo), botão 4 desarma.';
  end;
end;

procedure Tfrmconfig.cbProtocolChange(Sender: TObject);
begin
  if Assigned(FSetMain) and Assigned(cbProtocol) then
  begin
    FSetMain.DroneProtocolo := cbProtocol.ItemIndex;
    TipoAtivo := cbProtocol.ItemIndex;
    AtualizaAbasProtocolo;
    SalvarConfiguracoes;
  end;
end;

procedure Tfrmconfig.Label4Click(Sender: TObject);
begin
end;

procedure Tfrmconfig.cbDroneClick(Sender: TObject);
begin
end;

procedure Tfrmconfig.cbSerialPortChange(Sender: TObject);
begin
end;

procedure Tfrmconfig.ckJoyActiveChange(Sender: TObject);
begin
  if not MainDisponivel then
    Exit;

  try
    frmMain.SdpoJoystick1.Active := False;

    if cbDevice.ItemIndex = 0 then
      frmMain.SdpoJoystick1.DeviceWin := dwJoystickID1
    else
      frmMain.SdpoJoystick1.DeviceWin := dwJoystickID2;

    if ckJoyActive.Checked then
      frmMain.SdpoJoystick1.Active := True;

  except
    on E: Exception do
    begin
      ckJoyActive.Checked := False;
      timerJoystick.Enabled := False;
      LimpaLeitura;
    end;
  end;
end;

procedure Tfrmconfig.ckTestChange(Sender: TObject);
begin
  if ckTest.Checked then
  begin
    ckJoyActive.Checked := True;
    ckJoyActiveChange(ckJoyActive);
    timerJoystick.Enabled := True;
  end
  else
  begin
    timerJoystick.Enabled := False;
    LimpaLeitura;
  end;
end;

procedure Tfrmconfig.btCalibrationClick(Sender: TObject);
begin
end;

procedure Tfrmconfig.cbDeviceChange(Sender: TObject);
begin
  if ckJoyActive.Checked then
    ckJoyActiveChange(ckJoyActive);
end;

procedure Tfrmconfig.TabSheet1ContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
begin
end;

procedure Tfrmconfig.timerJoystickTimer(Sender: TObject);
var
  X, Y, Z: Integer;
begin
  if not MainDisponivel then
  begin
    LimpaLeitura;
    Exit;
  end;

  if not frmMain.SdpoJoystick1.Active then
  begin
    LimpaLeitura;
    Exit;
  end;

  try
    X := MAPA(0, 65535, 0, 255, frmMain.SdpoJoystick1.Axis[0].ToDouble);
    Y := MAPA(0, 65535, 0, 255, frmMain.SdpoJoystick1.Axis[1].ToDouble);
    Z := MAPA(0, 65535, 0, 255, frmMain.SdpoJoystick1.Axis[2].ToDouble);

    lbX.Caption := IntToStr(X);
    lbY.Caption := IntToStr(Y);
    lbZ.Caption := IntToStr(Z);

    AtualizaLedsBotoes;
  except
    on E: Exception do
      LimpaLeitura;
  end;
end;

procedure Tfrmconfig.FormShow(Sender: TObject);
begin
  CarregarValoresTela;
end;

procedure Tfrmconfig.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  SalvarConfiguracoes;
  CloseAction := caHide;
end;

procedure Tfrmconfig.AtualizaAbasProtocolo;
begin
  if Assigned(TabSheet1) then
    TabSheet1.TabVisible := (TipoAtivo = 0);
  if Assigned(tsMavlink) then
    tsMavlink.TabVisible := (TipoAtivo = 1);
  if Assigned(tsTello) then
    tsTello.TabVisible := (TipoAtivo = 2);
  if Assigned(tsOpendrone) then
    tsOpendrone.TabVisible := (TipoAtivo = 3);
  if Assigned(tsFQ777) then
    tsFQ777.TabVisible := (TipoAtivo = 4);
  if Assigned(tsARDrone) then
    tsARDrone.TabVisible := (TipoAtivo = 5);
  if Assigned(tsESP32Drone) then
    tsESP32Drone.TabVisible := (TipoAtivo = 6);
end;

procedure Tfrmconfig.CarregarValoresTela;
begin
  if not Assigned(FSetMain) then
    Exit;

  ckJoyActive.Checked := FSetMain.JoystickAtivo;
  cbDevice.ItemIndex := FSetMain.JoystickDeviceIndex;

  cbSerialPort.Text := FSetMain.SerialPort;
  cbBaudrate.ItemIndex := FSetMain.BaudRate;
  ckbGPS.Checked := FSetMain.UsaSerial;

  if Assigned(cbProtocol) then
  begin
    cbProtocol.ItemIndex := FSetMain.DroneProtocolo;
    TipoAtivo := FSetMain.DroneProtocolo;
  end;

  // Aba do Cheerson CX-10W: seção própria [CX10W].
  edIP.Text := FSetMain.CX10W.IP;
  edTCPPORT.Text := IntToStr(FSetMain.CX10W.PortaTCP);
  edUDPPORT.Text := IntToStr(FSetMain.CX10W.PortaUDP);

  if Assigned(edMavIP) then
    edMavIP.Text := FSetMain.DroneIP;
  if Assigned(edMavPort) then
    edMavPort.Text := IntToStr(FSetMain.DronePortaVideo);
  if Assigned(edMavSysId) then
    edMavSysId.Text := IntToStr(FSetMain.DronePortaStatus);

  if Assigned(edTelloIP) then
    edTelloIP.Text := FSetMain.DroneIP;
  if Assigned(edTelloCmdPort) then
    edTelloCmdPort.Text := IntToStr(FSetMain.DronePortaComando);
  if Assigned(edTelloStatePort) then
    edTelloStatePort.Text := IntToStr(FSetMain.DronePortaStatus);

  if Assigned(edOpendroneIP) then
    edOpendroneIP.Text := FSetMain.DroneIP;
  if Assigned(edOpendronePort) then
    edOpendronePort.Text := IntToStr(FSetMain.DronePortaComando);

  if Assigned(tsFQ777) then
    with FSetMain.FQ777 do
    begin
      edFQ777IP.Text := IP;
      edFQ777TCP.Text := IntToStr(PortaTCP);
      edFQ777UDP.Text := IntToStr(PortaUDP);
      ckFQ777WifiAuto.Checked := WifiAuto;
      edFQ777SSID.Text := WifiSSID;
      edFQ777Senha.Text := WifiSenha;
      ckFQ777Video.Checked := Video;
      ckFQ777Gravar.Checked := GravarVideo;
      edFQ777FFmpeg.Text := FFmpeg;
      edFQ777ZonaMorta.Text := IntToStr(ZonaMorta);
      edFQ777EixoRolagem.Text := IntToStr(EixoRolagem);
      edFQ777EixoArfagem.Text := IntToStr(EixoArfagem);
      edFQ777EixoGuinada.Text := IntToStr(EixoGuinada);
      edFQ777EixoAcelerador.Text := IntToStr(EixoAcelerador);
      if AceleradorCentrado then
        cbFQ777Acelerador.ItemIndex := 1
      else
        cbFQ777Acelerador.ItemIndex := 0;
    end;

  if Assigned(tsARDrone) then
    with FSetMain.ARDrone do
    begin
      edARDroneIP.Text := IP;
      ckARDroneVideo.Checked := Video;
      edARDroneFFmpeg.Text := FFmpeg;
      edARDroneAltura.Text := IntToStr(AlturaMaxima);
      ckARDroneExterno.Checked := Externo;
      edARDroneSensibilidade.Text := IntToStr(Sensibilidade);
    end;

  if Assigned(tsESP32Drone) then
    with FSetMain.ESP32Drone do
    begin
      edESP32IP.Text := IP;
      edESP32Porta.Text := IntToStr(Porta);
    end;

  AtualizaAbasProtocolo;
end;

procedure Tfrmconfig.SalvarConfiguracoes;
var
  Val: Integer;
begin
  if not Assigned(FSetMain) then
    Exit;

  FSetMain.JoystickAtivo := ckJoyActive.Checked;
  FSetMain.JoystickDeviceIndex := cbDevice.ItemIndex;

  FSetMain.SerialPort := cbSerialPort.Text;
  FSetMain.BaudRate := cbBaudrate.ItemIndex;
  FSetMain.UsaSerial := ckbGPS.Checked;

  case TipoAtivo of
    0:
      begin
        // Cheerson CX-10W: não altera a seção [DRONE] dos outros protocolos.
        if Trim(edIP.Text) <> '' then
          FSetMain.CX10W.IP := Trim(edIP.Text);
        if TryStrToInt(Trim(edTCPPORT.Text), Val) and (Val > 0) then
          FSetMain.CX10W.PortaTCP := Val;
        if TryStrToInt(Trim(edUDPPORT.Text), Val) and (Val > 0) then
          FSetMain.CX10W.PortaUDP := Val;
      end;
    1:
      begin
        if Assigned(edMavIP) then
          FSetMain.DroneIP := edMavIP.Text;
        if Assigned(edMavPort) then
        begin
          if TryStrToInt(Trim(edMavPort.Text), Val) then
            FSetMain.DronePortaVideo := Val;
        end;
        if Assigned(edMavSysId) then
        begin
          if TryStrToInt(Trim(edMavSysId.Text), Val) then
            FSetMain.DronePortaStatus := Val;
        end;
      end;
    2:
      begin
        if Assigned(edTelloIP) then
          FSetMain.DroneIP := edTelloIP.Text;
        if Assigned(edTelloCmdPort) then
        begin
          if TryStrToInt(Trim(edTelloCmdPort.Text), Val) then
            FSetMain.DronePortaComando := Val;
        end;
        if Assigned(edTelloStatePort) then
        begin
          if TryStrToInt(Trim(edTelloStatePort.Text), Val) then
            FSetMain.DronePortaStatus := Val;
        end;
      end;
    3:
      begin
        if Assigned(edOpendroneIP) then
          FSetMain.DroneIP := edOpendroneIP.Text;
        if Assigned(edOpendronePort) then
        begin
          if TryStrToInt(Trim(edOpendronePort.Text), Val) then
            FSetMain.DronePortaComando := Val;
        end;
      end;
    4:
      // Seção própria [FQ777]: não altera a configuração dos outros drones.
      if Assigned(tsFQ777) then
        with FSetMain.FQ777 do
        begin
          if Trim(edFQ777IP.Text) <> '' then
            IP := Trim(edFQ777IP.Text);
          PortaTCP := StrToIntDef(Trim(edFQ777TCP.Text), PortaTCP);
          PortaUDP := StrToIntDef(Trim(edFQ777UDP.Text), PortaUDP);
          WifiAuto := ckFQ777WifiAuto.Checked;
          WifiSSID := Trim(edFQ777SSID.Text);
          WifiSenha := edFQ777Senha.Text;
          Video := ckFQ777Video.Checked;
          GravarVideo := ckFQ777Gravar.Checked;
          FFmpeg := Trim(edFQ777FFmpeg.Text);
          ZonaMorta := StrToIntDef(Trim(edFQ777ZonaMorta.Text), ZonaMorta);
          EixoRolagem := StrToIntDef(Trim(edFQ777EixoRolagem.Text), EixoRolagem);
          EixoArfagem := StrToIntDef(Trim(edFQ777EixoArfagem.Text), EixoArfagem);
          EixoGuinada := StrToIntDef(Trim(edFQ777EixoGuinada.Text), EixoGuinada);
          EixoAcelerador := StrToIntDef(Trim(edFQ777EixoAcelerador.Text), EixoAcelerador);
          AceleradorCentrado := cbFQ777Acelerador.ItemIndex = 1;
        end;
    5:
      // Seção própria [ARDRONE].
      if Assigned(tsARDrone) then
        with FSetMain.ARDrone do
        begin
          if Trim(edARDroneIP.Text) <> '' then
            IP := Trim(edARDroneIP.Text);
          Video := ckARDroneVideo.Checked;
          FFmpeg := Trim(edARDroneFFmpeg.Text);
          AlturaMaxima := EnsureRange(StrToIntDef(Trim(edARDroneAltura.Text), AlturaMaxima), 1, 100);
          Externo := ckARDroneExterno.Checked;
          Sensibilidade := EnsureRange(StrToIntDef(Trim(edARDroneSensibilidade.Text), Sensibilidade), 10, 100);
        end;
    6:
      // Seção própria [ESP32DRONE].
      if Assigned(tsESP32Drone) then
        with FSetMain.ESP32Drone do
        begin
          if Trim(edESP32IP.Text) <> '' then
            IP := Trim(edESP32IP.Text);
          Porta := StrToIntDef(Trim(edESP32Porta.Text), Porta);
        end;
  end;

  FSetMain.DroneProtocolo := TipoAtivo;
  FSetMain.SalvaContexto;
end;

end.
