unit config;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ComCtrls, ExtCtrls, Arrow, AdvLed, Types,sdpojoystick,funcs;

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
    ckTest: TCheckBox;
    ckJoyActive: TCheckBox;
    edIP: TEdit;
    edTCPPORT: TEdit;
    edUDPPORT: TEdit;
    Label1: TLabel;
    Label10: TLabel;
    Label11: TLabel;
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
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    timerJoystick: TTimer;
    procedure btCalibrationClick(Sender: TObject);
    procedure cbDeviceChange(Sender: TObject);
    procedure cbDroneClick(Sender: TObject);
    procedure ckJoyActiveChange(Sender: TObject);
    procedure ckTestChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Label4Click(Sender: TObject);
    procedure TabSheet1ContextPopup(Sender: TObject; MousePos: TPoint;
      var Handled: Boolean);
    procedure timerJoystickTimer(Sender: TObject);
  private

  public
    TipoAtivo : integer;


  end;

var
  frmconfig: Tfrmconfig;


implementation

{$R *.lfm}

{ Tfrmconfig }
uses
   main;



procedure Tfrmconfig.FormCreate(Sender: TObject);
begin
  TipoAtivo := 0; //Por enquanto só tem 1
end;

procedure Tfrmconfig.Label4Click(Sender: TObject);
begin

end;

procedure Tfrmconfig.cbDroneClick(Sender: TObject);
begin
end;

procedure Tfrmconfig.ckJoyActiveChange(Sender: TObject);
begin
    frmMain.SdpoJoystick1.Active:=false;
    if cbDevice.ItemIndex = 0 then
        frmMain.SdpoJoystick1.DeviceWin :=  dwJoystickID1
    else
        frmMain.SdpoJoystick1.DeviceWin :=  dwJoystickID2;
    frmMain.SdpoJoystick1.Active:=true;
end;

procedure Tfrmconfig.ckTestChange(Sender: TObject);
begin
  if ckTest.State = cbChecked then
  begin
    ckJoyActive.State:= cbChecked;
    timerJoystick.Enabled:= true;

  end
  else
  begin
    timerJoystick.Enabled:= false;
  end;
end;

procedure Tfrmconfig.btCalibrationClick(Sender: TObject);
begin

end;

procedure Tfrmconfig.cbDeviceChange(Sender: TObject);
begin

end;

procedure Tfrmconfig.TabSheet1ContextPopup(Sender: TObject; MousePos: TPoint;
  var Handled: Boolean);
begin

end;

procedure Tfrmconfig.timerJoystickTimer(Sender: TObject);
var
  X,Y,Z : integer;
begin
  X := MAPA(0,65535,0,255, frmmain.SdpoJoystick1.Axis[0].ToDouble);
  Y := MAPA(0,65535,0,255, frmmain.SdpoJoystick1.Axis[1].ToDouble);
  Z := MAPA(0,65535,0,255, frmmain.SdpoJoystick1.Axis[2].ToDouble);
  lbX.Caption := inttostr(X);
  lbY.Caption := inttostr(Y);
  lbZ.Caption := inttostr(Z);

  if frmMain.SdpoJoystick1.Buttons[0].ToBoolean then
  begin
    advButton0.State := lsOn;
  end
  else
  begin
    advButton0.State := lsOff;
  end;
  if frmMain.SdpoJoystick1.Buttons[1].ToBoolean then
  begin
    advButton1.State := lsOn;
  end
  else
  begin
    advButton1.State := lsOff;
  end;
  if frmMain.SdpoJoystick1.Buttons[2].ToBoolean then
  begin
    advButton2.State := lsOn;
  end
  else
  begin
    advButton2.State := lsOff;
  end;
  if frmMain.SdpoJoystick1.Buttons[3].ToBoolean then
  begin
    advButton3.State := lsOn;
  end
  else
  begin
    advButton3.State := lsOff;
  end;
  if frmMain.SdpoJoystick1.Buttons[4].ToBoolean then
  begin
    advButton4.State := lsOn;
  end
  else
  begin
    advButton4.State := lsOff;
  end;
  if frmMain.SdpoJoystick1.Buttons[5].ToBoolean then
  begin
    advButton5.State := lsOn;
  end
  else
  begin
    advButton5.State := lsOff;
  end;
end;

end.

