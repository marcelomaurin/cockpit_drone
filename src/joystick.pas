unit joystick;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SdpoJoystick, funcs;

const
  JOY_REF        = 127;
  JOY_OUT_MIN    = 0;
  JOY_OUT_MAX    = 255;
  JOY_IN_MIN     = 0;
  JOY_IN_MAX     = 65535;
  JOY_DEAD_LOW   = 120;
  JOY_DEAD_HIGH  = 140;

type
  TJoystickButtons = record
    B1: Byte;
    B2: Byte;
    B3: Byte;
    B4: Byte;
    B5: Byte;
    B6: Byte;
  end;

  TJoystickState = record
    X: Byte;
    Y: Byte;
    Z: Byte;
    Buttons: TJoystickButtons;
  end;

  { TJoystickController }

  TJoystickController = class
  private
    FJoystick: TSdpoJoystick;
    FState: TJoystickState;
    FActive: Boolean;

    procedure SetActive(const AValue: Boolean);
    function MapAxisToByte(const AValue: Double): Byte;
    function GetButtonValue(const AIndex: Integer): Byte;

  public
    constructor Create(AJoystick: TSdpoJoystick);
    procedure ResetState;
    function ConfigureDevice(const ADeviceIndex: Integer): Boolean;
    function Activate: Boolean;
    procedure Deactivate;
    function UpdateState: Boolean;

    property Active: Boolean read FActive write SetActive;
    property State: TJoystickState read FState;
  end;

implementation

{ TJoystickController }

constructor TJoystickController.Create(AJoystick: TSdpoJoystick);
begin
  inherited Create;
  FJoystick := AJoystick;
  FActive := False;
  ResetState;
end;

procedure TJoystickController.SetActive(const AValue: Boolean);
begin
  if AValue then
    Activate
  else
    Deactivate;
end;

procedure TJoystickController.ResetState;
begin
  FState.X := JOY_REF;
  FState.Y := JOY_REF;
  FState.Z := JOY_REF;

  FState.Buttons.B1 := 0;
  FState.Buttons.B2 := 0;
  FState.Buttons.B3 := 0;
  FState.Buttons.B4 := 0;
  FState.Buttons.B5 := 0;
  FState.Buttons.B6 := 0;
end;

function TJoystickController.ConfigureDevice(const ADeviceIndex: Integer): Boolean;
begin
  Result := False;

  if not Assigned(FJoystick) then
    Exit;

  try
    FJoystick.Active := False;

    if ADeviceIndex = 0 then
      FJoystick.DeviceWin := dwJoystickID1
    else
      FJoystick.DeviceWin := dwJoystickID2;

    Result := True;
  except
    Result := False;
  end;
end;

function TJoystickController.Activate: Boolean;
begin
  Result := False;

  if not Assigned(FJoystick) then
    Exit;

  try
    FJoystick.Active := True;
    FActive := True;
    ResetState;
    Result := True;
  except
    FActive := False;
    Result := False;
  end;
end;

procedure TJoystickController.Deactivate;
begin
  if not Assigned(FJoystick) then
    Exit;

  try
    FJoystick.Active := False;
  except
  end;

  FActive := False;
  ResetState;
end;

function TJoystickController.MapAxisToByte(const AValue: Double): Byte;
begin
  Result := MAPA(JOY_IN_MIN, JOY_IN_MAX, JOY_OUT_MIN, JOY_OUT_MAX, AValue);
end;

function TJoystickController.GetButtonValue(const AIndex: Integer): Byte;
begin
  Result := 0;

  if not Assigned(FJoystick) then
    Exit;

  try
    if FJoystick.Buttons[AIndex].ToBoolean then
      Result := 255
    else
      Result := 0;
  except
    Result := 0;
  end;
end;

function TJoystickController.UpdateState: Boolean;
var
  NewState: TJoystickState;
begin
  Result := False;

  if (not Assigned(FJoystick)) or (not FActive) then
    Exit;

  try
    NewState.X := MapAxisToByte(FJoystick.Axis[0].ToDouble);
    NewState.Y := MapAxisToByte(FJoystick.Axis[1].ToDouble);
    NewState.Z := MapAxisToByte(FJoystick.Axis[2].ToDouble);

    NewState.Buttons.B1 := GetButtonValue(0);
    NewState.Buttons.B2 := GetButtonValue(1);
    NewState.Buttons.B3 := GetButtonValue(2);
    NewState.Buttons.B4 := GetButtonValue(3);
    NewState.Buttons.B5 := GetButtonValue(4);
    NewState.Buttons.B6 := GetButtonValue(5);

    Result :=
      (NewState.X <> FState.X) or
      (NewState.Y <> FState.Y) or
      (NewState.Z <> FState.Z) or
      (NewState.Buttons.B1 <> FState.Buttons.B1) or
      (NewState.Buttons.B2 <> FState.Buttons.B2) or
      (NewState.Buttons.B3 <> FState.Buttons.B3) or
      (NewState.Buttons.B4 <> FState.Buttons.B4) or
      (NewState.Buttons.B5 <> FState.Buttons.B5) or
      (NewState.Buttons.B6 <> FState.Buttons.B6);

    FState := NewState;
  except
    Result := False;
  end;
end;

end.
