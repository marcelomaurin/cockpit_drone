unit joystick;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SdpoJoystick, funcs, aijoystick, cockpit_joystick_mapping;

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
    Yaw: Double;
    HasYaw: Boolean;
    Buttons: TJoystickButtons;
  end;

  { TJoystickController }

  TJoystickController = class
  private
    FJoystick: TSdpoJoystick;
    FState: TJoystickState;
    FActive: Boolean;
    FNativeJoystick: TAIJoystick;
    FOwnsNativeJoystick: Boolean;
    FUseXInput: Boolean;
    FDeviceIndex: Integer;
    FSettings: TFlightJoystickSettings;
    FAvailable: Boolean;
    function ReadXInput(out AState: TJoystickState): Boolean;

    procedure SetActive(const AValue: Boolean);
    function MapAxisToByte(const AValue: Double): Byte;
    function GetButtonValue(const AIndex: Integer): Byte;

  public
    constructor Create(AJoystick: TSdpoJoystick; ANativeJoystick: TAIJoystick = nil);
    destructor Destroy; override;
    procedure ResetState;
    function ConfigureDevice(const ADeviceIndex: Integer): Boolean;
    function Activate: Boolean;
    procedure Deactivate;
    function UpdateState: Boolean; // True = leitura bem-sucedida, mesmo sem mudancas

    property Settings: TFlightJoystickSettings read FSettings write FSettings;
    property Available: Boolean read FAvailable;
    property Active: Boolean read FActive write SetActive;
    property State: TJoystickState read FState;
  end;

implementation

{ TJoystickController }

constructor TJoystickController.Create(AJoystick: TSdpoJoystick; ANativeJoystick: TAIJoystick);
begin
  inherited Create;
  FSettings := DefaultFlightJoystickSettings;
  FJoystick := AJoystick;
  FNativeJoystick := ANativeJoystick;
  FOwnsNativeJoystick := not Assigned(ANativeJoystick);
  if FOwnsNativeJoystick then FNativeJoystick := TAIJoystick.Create(nil);
  FDeviceIndex := 0;
  FNativeJoystick.DeviceID := 'xinput:0';
  FActive := False;
  ResetState;
end;

destructor TJoystickController.Destroy;
begin
  Deactivate;
  if FOwnsNativeJoystick then FNativeJoystick.Free;
  inherited Destroy;
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
  FAvailable := False;
  FState := Default(TJoystickState);
  FState.X := JOY_REF;
  FState.Y := JOY_REF;
  FState.Z := 0;

  FState.Buttons.B1 := 0;
  FState.Buttons.B2 := 0;
  FState.Buttons.B3 := 0;
  FState.Buttons.B4 := 0;
  FState.Buttons.B5 := 0;
  FState.Buttons.B6 := 0;
end;

function TJoystickController.ConfigureDevice(const ADeviceIndex: Integer): Boolean;
begin
  Deactivate;
  Result := ADeviceIndex in [0..3];
  if not Result then Exit;
  FDeviceIndex := ADeviceIndex;
  FNativeJoystick.DeviceID := 'xinput:' + IntToStr(FDeviceIndex);
  if Assigned(FJoystick) and (FDeviceIndex<2) then
    if FDeviceIndex = 0 then FJoystick.DeviceWin := dwJoystickID1
    else FJoystick.DeviceWin := dwJoystickID2;
end;

function TJoystickController.Activate: Boolean;
var InitialState: TJoystickState;
begin
  Deactivate;
  // Prefer the native Xbox controller in the selected slot. Generic devices
  // retain their existing Sdpo mapping; never switch devices during a flight.
  FUseXInput := False;
  try
    if FSettings.Profile<>jpLegacy then FUseXInput := ReadXInput(InitialState);
  except ResetState; Exit(False); end;
  if FUseXInput then
  begin
    FActive := True;
    FState := InitialState;
    FAvailable := True;
    Exit(True);
  end;
  Result := False;
  if not Assigned(FJoystick) or (FDeviceIndex>1) then Exit;
  try
    FJoystick.Active := True;
    FActive := True;
    Result := UpdateState;
    if not Result then Deactivate;
  except
    Deactivate;
  end;
end;

procedure TJoystickController.Deactivate;
begin
  FActive := False;
  FUseXInput := False;
  if Assigned(FJoystick) then
    try FJoystick.Active := False; except end;
  ResetState;
end;

function TJoystickController.ReadXInput(out AState: TJoystickState): Boolean;
var S: TAIJoystickState; M:TFlightJoystickSettings; B:array[1..6] of Byte; I:Integer;
begin
  AState := Default(TJoystickState);
  Result := FNativeJoystick.Poll;
  if not Result then Exit;
  S := FNativeJoystick.State;
  Result := S.Connected and (Copy(S.DeviceID, 1, 7) = 'xinput:');
  if not Result then Exit;
  MapFlightJoystick(S.Axes, True, FSettings,
    AState.X, AState.Y, AState.Z, AState.Yaw, AState.HasYaw);
  M:=EffectiveFlightJoystickSettings(FSettings,True);
  for I:=1 to 6 do
    if (M.Button[I]>=1) and (M.Button[I]<=AIJoystickControls) then
      B[I]:=Ord(S.Controls[M.Button[I]])*255 else B[I]:=0;
  AState.Buttons.B1:=B[1]; AState.Buttons.B2:=B[2];
  AState.Buttons.B3:=B[3]; AState.Buttons.B4:=B[4];
  AState.Buttons.B5:=B[5]; AState.Buttons.B6:=B[6];
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
  Axes: array[0..5] of Integer;
  CanonicalAxes: TFlightAxes;
  M: TFlightJoystickSettings;
  B: array[1..6] of Byte;
  I: Integer;
  Buttons: array[0..31] of Integer;
begin
  Result := False;
  if not FActive then Exit;
  try
    if FUseXInput then
    begin
      if not ReadXInput(NewState) then
      begin
        FActive:=False;
        ResetState;
        Exit;
      end;
    end
    else
    begin
      if not Assigned(FJoystick) or not FJoystick.Active then
      begin
        FActive:=False;
        ResetState;
        Exit;
      end;
      // Read raises on a failed WinMM poll. Individual Axis getters can
      // otherwise return the last sample even after the device disappears.
      FJoystick.Read(Axes, Buttons);
      if FSettings.Profile in [jpAutomatic,jpLegacy] then
      begin
        // Preserve the legacy byte mapping for generic controllers exactly.
        NewState:=Default(TJoystickState);
        NewState.X := MapAxisToByte(Axes[0]);
        NewState.Y := MapAxisToByte(Axes[1]);
        NewState.Z := MapAxisToByte(Axes[2]);
        for I:=1 to 6 do B[I]:=Ord(Buttons[I-1]<>0)*255;
      end else begin
        for I:=0 to 5 do CanonicalAxes[I]:=2*Axes[I]/65535.0-1;
        CanonicalAxes[1]:=-CanonicalAxes[1];
        MapFlightJoystick(CanonicalAxes,False,FSettings,
          NewState.X,NewState.Y,NewState.Z,NewState.Yaw,NewState.HasYaw);
        M:=EffectiveFlightJoystickSettings(FSettings,False);
        for I:=1 to 6 do
          if (M.Button[I]>=1) and (M.Button[I]<=32) then
            B[I]:=Ord(Buttons[M.Button[I]-1]<>0)*255 else B[I]:=0;
      end;
      NewState.Buttons.B1:=B[1]; NewState.Buttons.B2:=B[2];
      NewState.Buttons.B3:=B[3]; NewState.Buttons.B4:=B[4];
      NewState.Buttons.B5:=B[5]; NewState.Buttons.B6:=B[6];
    end;
    FState := NewState;
    FAvailable := True;
    Result := True;
  except
    FActive:=False;
    ResetState;
    Result := False;
  end;
end;

end.
