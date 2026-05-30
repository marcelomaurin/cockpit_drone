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

    procedure AtualizaAbasProtocolo;
    procedure CarregarValoresTela;
    procedure SalvarConfiguracoes;
  end;

var
  frmconfig: Tfrmconfig;

implementation

{$R *.lfm}

uses
  main, setmain;

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

  TabSheet1.Caption := 'Cheerson CX-10W';

  CarregarValoresTela;
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

  edIP.Text := FSetMain.DroneIP;
  edTCPPORT.Text := IntToStr(FSetMain.DronePortaComando);
  edUDPPORT.Text := IntToStr(FSetMain.DronePortaVideo);

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
        FSetMain.DroneIP := edIP.Text;
        if TryStrToInt(Trim(edTCPPORT.Text), Val) then
          FSetMain.DronePortaComando := Val;
        if TryStrToInt(Trim(edUDPPORT.Text), Val) then
          FSetMain.DronePortaVideo := Val;
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
  end;

  FSetMain.DroneProtocolo := TipoAtivo;
  FSetMain.SalvaContexto;
end;

end.
