unit simulator_vehicle_core;

{$mode objfpc}{$H+}

interface

uses SysUtils, Math;

type
  TVehicleKind = (vkMultirotor, vkAirplane, vkBoat, vkCar, vkHelicopter);
  TVehicleControls = record
    Throttle: Double;  // 0..1
    Turn: Double;      // -1..1
    Climb: Double;     // -1..1; ignored for boats and cars
    Brake: Double;     // 0..1; car brake, ignored by other vehicles
  end;
  TVehicleState = record
    Latitude, Longitude, AltitudeM: Double;
    HeadingDeg, SpeedMps, VerticalSpeedMps, BatteryPct: Double;
    SimTimeS: Double;
  end;
  TSimulatorVehicle = class
  private
    FKind: TVehicleKind;
    FState: TVehicleState;
    FControls: TVehicleControls;
    function MaxSpeed: Double;
  public
    constructor Create(AKind: TVehicleKind; ALatitude, ALongitude,
      AAltitudeM: Double);
    procedure Step(ADeltaSeconds: Double);
    property State: TVehicleState read FState;
    property Controls: TVehicleControls read FControls write FControls;
    property Kind: TVehicleKind read FKind;
  end;

implementation

function Clamp(const V, Lo, Hi: Double): Double;
begin
  Result := Max(Lo, Min(Hi, V));
end;

constructor TSimulatorVehicle.Create(AKind: TVehicleKind;
  ALatitude, ALongitude, AAltitudeM: Double);
begin
  inherited Create;
  FKind := AKind;
  FState.Latitude := Clamp(ALatitude, -90, 90);
  FState.Longitude := Clamp(ALongitude, -180, 180);
  FState.AltitudeM := Max(0, AAltitudeM);
  FState.BatteryPct := 100;
  FControls.Throttle := 0;
  FControls.Turn := 0;
  FControls.Climb := 0;
  FControls.Brake := 0;
end;

function TSimulatorVehicle.MaxSpeed: Double;
begin
  case FKind of
    vkMultirotor: Result := 20;
    vkAirplane: Result := 65;
    vkBoat: Result := 12;
    vkCar: Result := 35;
    vkHelicopter: Result := 28;
  else
    Result := 10;
  end;
end;

procedure TSimulatorVehicle.Step(ADeltaSeconds: Double);
const
  EarthRadiusM = 6371000.0;
var
  Dt, TargetSpeed, Accel, TurnRate, ClimbRate: Double;
  NorthM, EastM, CosLat, LatRad, Steering: Double;
begin
  if (ADeltaSeconds <= 0) or (ADeltaSeconds > 1) then Exit;
  if FState.BatteryPct <= 0 then Exit;
  Dt := ADeltaSeconds;
  TargetSpeed := Clamp(FControls.Throttle, 0, 1) * MaxSpeed;
  case FKind of
    vkMultirotor: begin Accel := 4; TurnRate := 90; ClimbRate := 5; end;
    vkAirplane: begin Accel := 2; TurnRate := 25; ClimbRate := 8; end;
    vkBoat: begin Accel := 1; TurnRate := 35; ClimbRate := 0; end;
    vkCar: begin Accel := 3.5; TurnRate := 65; ClimbRate := 0; end;
    vkHelicopter: begin Accel := 2.5; TurnRate := 65; ClimbRate := 7; end;
  end;
  if FKind = vkCar then
    TargetSpeed := TargetSpeed * (1 - Clamp(FControls.Brake, 0, 1));
  FState.SpeedMps := FState.SpeedMps +
    Clamp(TargetSpeed - FState.SpeedMps,
      -Accel * (1 + 4 * Clamp(FControls.Brake, 0, 1)) * Dt, Accel * Dt);
  // Boats and cars cannot rotate in place: steering requires forward speed.
  Steering := 1;
  if FKind in [vkBoat, vkCar] then
    Steering := Clamp(FState.SpeedMps / 4, 0, 1);
  FState.HeadingDeg := FState.HeadingDeg +
    Clamp(FControls.Turn, -1, 1) * TurnRate * Steering * Dt;
  FState.HeadingDeg := FState.HeadingDeg -
    Floor(FState.HeadingDeg / 360) * 360;
  FState.VerticalSpeedMps := Clamp(FControls.Climb, -1, 1) * ClimbRate;
  FState.AltitudeM := Max(0, FState.AltitudeM + FState.VerticalSpeedMps * Dt);
  NorthM := Cos(DegToRad(FState.HeadingDeg)) * FState.SpeedMps * Dt;
  EastM := Sin(DegToRad(FState.HeadingDeg)) * FState.SpeedMps * Dt;
  LatRad := DegToRad(FState.Latitude);
  FState.Latitude := Clamp(FState.Latitude +
    RadToDeg(NorthM / EarthRadiusM), -90, 90);
  CosLat := Cos(LatRad);
  if Abs(CosLat) > 0.000001 then
    FState.Longitude := FState.Longitude +
      RadToDeg(EastM / (EarthRadiusM * CosLat));
  while FState.Longitude > 180 do FState.Longitude := FState.Longitude - 360;
  while FState.Longitude < -180 do FState.Longitude := FState.Longitude + 360;
  FState.BatteryPct := Max(0, FState.BatteryPct -
    Dt * (0.002 + 0.006 * Clamp(FControls.Throttle, 0, 1)));
  FState.SimTimeS := FState.SimTimeS + Dt;
end;

end.
