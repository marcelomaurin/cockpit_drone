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

  private
    procedure AtualizaLedsBotoes;
    procedure LimpaLeitura;
    function MainDisponivel: Boolean;
    function PortaSerialExiste(const APorta: string): Boolean;
    procedure CarregaPortasSeriais;
    procedure AdicionaPortaSeExistir(const APorta: string);

  public
    TipoAtivo: Integer;
  end;

var
  frmconfig: Tfrmconfig;

implementation

{$R *.lfm}

uses
  main;

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
  TipoAtivo := 0; // Por enquanto só tem 1
  LimpaLeitura;
  CarregaPortasSeriais;
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

end.
