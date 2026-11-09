unit cockpit_joystick_mapping;
{$mode objfpc}{$H+}
interface
const jpAutomatic=0; jpMode2=1; jpXboxRT=2; jpCustom=3; jpLegacy=4;
type
  TFlightAxes = array[0..5] of Double;
  TFlightJoystickSettings = record
    Profile: Integer;
    Axis: array[0..3] of Integer; // roll, pitch, yaw (-1 = buttons), throttle
    Invert: array[0..3] of Boolean;
    TriggerThrottle: Boolean;
    DeadZone: Integer;
    Button: array[1..6] of Integer; // canonical button, 0 = disabled
  end;
function DefaultFlightJoystickSettings: TFlightJoystickSettings;
function EffectiveFlightJoystickSettings(const S: TFlightJoystickSettings;
  IsXbox: Boolean): TFlightJoystickSettings;
procedure MapFlightJoystick(const Axes: TFlightAxes; IsXbox: Boolean;
  const Settings: TFlightJoystickSettings; out AX, AY, AZ: Byte;
  out AYaw: Double; out HasYaw: Boolean);
implementation
uses SysUtils, Math;
function DefaultFlightJoystickSettings: TFlightJoystickSettings;
begin
  Result := Default(TFlightJoystickSettings);
  Result.Profile := jpAutomatic;
  Result.Axis[0]:=2; Result.Axis[1]:=3; Result.Axis[2]:=0; Result.Axis[3]:=1;
  Result.DeadZone:=8;
  Result.Button[3]:=1; Result.Button[4]:=2;
end;
function EffectiveFlightJoystickSettings(const S: TFlightJoystickSettings;
  IsXbox: Boolean): TFlightJoystickSettings;
var P,I: Integer;
begin
  Result:=S; P:=S.Profile;
  if (P<jpAutomatic) or (P>jpLegacy) then P:=jpAutomatic;
  if P=jpAutomatic then
    if IsXbox then P:=jpMode2 else P:=jpLegacy;
  if P=jpCustom then Exit;
  Result:=DefaultFlightJoystickSettings;
  Result.Profile:=P; Result.DeadZone:=EnsureRange(S.DeadZone,0,40);
  if P=jpXboxRT then
  begin
    Result.Axis[0]:=0; Result.Axis[1]:=1;
    Result.Axis[2]:=2; Result.Axis[3]:=5;
    Result.TriggerThrottle:=True;
  end
  else if P=jpLegacy then
  begin
    Result.Axis[0]:=0; Result.Axis[1]:=1;
    Result.Axis[2]:=-1; Result.Axis[3]:=2;
    for I:=1 to 6 do Result.Button[I]:=I;
  end;
end;
procedure MapFlightJoystick(const Axes: TFlightAxes; IsXbox: Boolean;
  const Settings: TFlightJoystickSettings; out AX, AY, AZ: Byte;
  out AYaw: Double; out HasYaw: Boolean);
var S:TFlightJoystickSettings; V:array[0..3] of Double; I:Integer;
begin
  S:=EffectiveFlightJoystickSettings(Settings,IsXbox);
  for I:=0 to 3 do
  begin
    if (I=2) and (S.Axis[I]=-1) then V[I]:=0
    else begin
      if (S.Axis[I]<0) or (S.Axis[I]>5) then
        raise EArgumentException.Create('Eixo de joystick fora de 0..5');
      V[I]:=Axes[S.Axis[I]];
      if IsNan(V[I]) or IsInfinite(V[I]) then
        raise EArgumentException.Create('Leitura de joystick invalida');
    end;
    if S.Invert[I] then
      if (I=3) and S.TriggerThrottle then V[I]:=1-V[I]
      else V[I]:=-V[I];
  end;
  AX:=Byte(Round((EnsureRange(V[0],-1.0,1.0)+1)*127.5));
  AY:=Byte(Round((1-EnsureRange(V[1],-1.0,1.0))*127.5));
  if S.TriggerThrottle then
    AZ:=Byte(Round(EnsureRange(V[3],0.0,1.0)*255))
  else AZ:=Byte(Round((EnsureRange(V[3],-1.0,1.0)+1)*127.5));
  AYaw:=EnsureRange(V[2],-1.0,1.0); HasYaw:=S.Axis[2]>=0;
end;
end.
