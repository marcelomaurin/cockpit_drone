unit simulator_protocol_bridge;

{$mode objfpc}{$H+}

interface

uses SysUtils, Math, fpjson, jsonparser, simulator_vehicle_core;

type
  ESimulatorBridge = class(Exception);
  TSimulatorProtocolBridge = class
  private
    FVehicle: TSimulatorVehicle;
    FLastCommandS: Double;
    FTimeoutS: Double;
  public
    constructor Create(AVehicle: TSimulatorVehicle; ATimeoutS: Double = 0.5);
    procedure ApplyCommand(const AJSON: string);
    procedure Step(ADeltaSeconds: Double);
    function TelemetryJSON: string;
  end;

implementation

function Bounded(const AValue: TJSONData; const AMin, AMax: Double): Double;
var V: Double;
begin
  if (AValue = nil) or (AValue.JSONType <> jtNumber) then
    raise ESimulatorBridge.Create('Invalid or missing numeric control');
  V := AValue.AsFloat;
  if IsNan(V) or IsInfinite(V) then
    raise ESimulatorBridge.Create('Non-finite control');
  Result := Max(AMin, Min(AMax, V));
end;

constructor TSimulatorProtocolBridge.Create(AVehicle: TSimulatorVehicle;
  ATimeoutS: Double);
begin
  inherited Create;
  if AVehicle = nil then raise ESimulatorBridge.Create('Vehicle required');
  FVehicle := AVehicle;
  FTimeoutS := Max(0.05, ATimeoutS);
  FLastCommandS := -1;
end;

procedure TSimulatorProtocolBridge.ApplyCommand(const AJSON: string);
var Root: TJSONData; Obj: TJSONObject; C: TVehicleControls;
begin
  Root := GetJSON(AJSON);
  try
    if Root.JSONType <> jtObject then
      raise ESimulatorBridge.Create('Command must be JSON object');
    Obj := TJSONObject(Root);
    // Full snapshot required: absent axes must not retain stale values.
    C.Throttle := Bounded(Obj.Find('throttle'), 0, 1);
    C.Turn := Bounded(Obj.Find('turn'), -1, 1);
    C.Climb := Bounded(Obj.Find('climb'), -1, 1);
    C.Brake := Bounded(Obj.Find('brake'), 0, 1);
    C.Roll := Bounded(Obj.Find('roll'), -1, 1);
    C.Pitch := Bounded(Obj.Find('pitch'), -1, 1);
    FVehicle.Controls := C;
    FLastCommandS := FVehicle.State.SimTimeS;
  finally
    Root.Free;
  end;
end;

procedure TSimulatorProtocolBridge.Step(ADeltaSeconds: Double);
var C: TVehicleControls;
begin
  if (ADeltaSeconds <= 0) or (ADeltaSeconds > 1) then Exit;
  if (FLastCommandS < 0) or
    (FVehicle.State.SimTimeS + ADeltaSeconds - FLastCommandS > FTimeoutS) then
  begin
    FillChar(C, SizeOf(C), 0);
    FVehicle.Controls := C;
  end;
  FVehicle.Step(ADeltaSeconds);
end;

function TSimulatorProtocolBridge.TelemetryJSON: string;
var S: TVehicleState; O: TJSONObject;
begin
  S := FVehicle.State;
  O := TJSONObject.Create;
  try
    O.Add('lat', S.Latitude);
    O.Add('lon', S.Longitude);
    O.Add('altitude_m', S.AltitudeM);
    O.Add('heading_deg', S.HeadingDeg);
    O.Add('speed_mps', S.SpeedMps);
    O.Add('vertical_speed_mps', S.VerticalSpeedMps);
    O.Add('battery_pct', S.BatteryPct);
    O.Add('sim_time_s', S.SimTimeS);
    Result := O.AsJSON;
  finally
    O.Free;
  end;
end;

end.
