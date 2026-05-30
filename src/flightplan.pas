unit flightplan;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, Math;

type
  { TWaypoint }

  TWaypoint = class
  private
    FLatitude: Double;
    FLongitude: Double;
    FAltitude: Double;
    FSpeed: Double;
    FStatus: string; // 'PENDING', 'ACTIVE', 'COMPLETED'
  public
    constructor Create(ALat, ALon, AAlt, ASpeed: Double);
    property Latitude: Double read FLatitude write FLatitude;
    property Longitude: Double read FLongitude write FLongitude;
    property Altitude: Double read FAltitude write FAltitude;
    property Speed: Double read FSpeed write FSpeed;
    property Status: string read FStatus write FStatus;
  end;

  TGeofencePoint = record
    Latitude: Double;
    Longitude: Double;
  end;

  { TFlightPlan }

  TFlightPlan = class
  private
    FWaypoints: TObjectList;
    FCurrentIndex: Integer;
    FGeofence: array[0..3] of TGeofencePoint;
    FGeofenceActive: Boolean;
    FMaxAltitude: Double;
    FMinAltitude: Double;
    FAltitudeActive: Boolean;

    FSimulatedDroneLat: Double;
    FSimulatedDroneLon: Double;
    FSimulatedDroneAlt: Double;
    FSimulationActive: Boolean;

    function GetWaypoint(AIndex: Integer): TWaypoint;
    function GetWaypointCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddWaypoint(ALat, ALon, AAlt, ASpeed: Double);
    procedure DeleteWaypoint(AIndex: Integer);
    procedure ClearWaypoints;

    function IsWithinGeofence(ALat, ALon: Double): Boolean;
    function CheckAltitudeLimits(AAlt: Double; out AWarning: string): Boolean;

    procedure StartRoute;
    procedure UpdateRouteTracking(ADroneLat, ADroneLon: Double; out ANextWaypointMsg: string);
    procedure SimulateStep(const ATimeStepSec: Double);

    procedure SetGeofenceCorner(AIndex: Integer; ALat, ALon: Double);
    function GetGeofenceCorner(AIndex: Integer): TGeofencePoint;

    property Waypoints[AIndex: Integer]: TWaypoint read GetWaypoint; default;
    property WaypointCount: Integer read GetWaypointCount;
    property CurrentIndex: Integer read FCurrentIndex write FCurrentIndex;
    property GeofenceActive: Boolean read FGeofenceActive write FGeofenceActive;
    property MaxAltitude: Double read FMaxAltitude write FMaxAltitude;
    property MinAltitude: Double read FMinAltitude write FMinAltitude;
    property AltitudeActive: Boolean read FAltitudeActive write FAltitudeActive;

    property SimulatedDroneLat: Double read FSimulatedDroneLat write FSimulatedDroneLat;
    property SimulatedDroneLon: Double read FSimulatedDroneLon write FSimulatedDroneLon;
    property SimulatedDroneAlt: Double read FSimulatedDroneAlt write FSimulatedDroneAlt;
    property SimulationActive: Boolean read FSimulationActive write FSimulationActive;
  end;

var
  GlobalFlightPlan: TFlightPlan;

implementation

{ TWaypoint }

constructor TWaypoint.Create(ALat, ALon, AAlt, ASpeed: Double);
begin
  inherited Create;
  FLatitude := ALat;
  FLongitude := ALon;
  FAltitude := AAlt;
  FSpeed := ASpeed;
  FStatus := 'PENDING';
end;

{ TFlightPlan }

constructor TFlightPlan.Create;
var
  I: Integer;
begin
  inherited Create;
  FWaypoints := TObjectList.Create(True);
  FCurrentIndex := -1;
  FGeofenceActive := False;
  FMaxAltitude := 120.0; // 120 meters (FAA standard)
  FMinAltitude := 2.0;   // 2 meters
  FAltitudeActive := False;

  FSimulatedDroneLat := 0.0;
  FSimulatedDroneLon := 0.0;
  FSimulatedDroneAlt := 0.0;
  FSimulationActive := False;

  // Initialize geofence with safe default coordinates (Jardinópolis/SP region)
  for I := 0 to 3 do
  begin
    FGeofence[I].Latitude := 0.0;
    FGeofence[I].Longitude := 0.0;
  end;
end;

destructor TFlightPlan.Destroy;
begin
  FWaypoints.Free;
  inherited Destroy;
end;

function TFlightPlan.GetWaypoint(AIndex: Integer): TWaypoint;
begin
  if (AIndex >= 0) and (AIndex < FWaypoints.Count) then
    Result := TWaypoint(FWaypoints[AIndex])
  else
    Result := nil;
end;

function TFlightPlan.GetWaypointCount: Integer;
begin
  Result := FWaypoints.Count;
end;

procedure TFlightPlan.AddWaypoint(ALat, ALon, AAlt, ASpeed: Double);
begin
  FWaypoints.Add(TWaypoint.Create(ALat, ALon, AAlt, ASpeed));
end;

procedure TFlightPlan.DeleteWaypoint(AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < FWaypoints.Count) then
    FWaypoints.Delete(AIndex);
end;

procedure TFlightPlan.ClearWaypoints;
begin
  FWaypoints.Clear;
  FCurrentIndex := -1;
end;

function TFlightPlan.IsWithinGeofence(ALat, ALon: Double): Boolean;
var
  I, J: Integer;
  Inside: Boolean;
begin
  Result := True;

  // If geofence is active, but corners are unconfigured, skip check
  if not FGeofenceActive then
    Exit;

  if (Abs(FGeofence[0].Latitude) < 0.0001) and (Abs(FGeofence[0].Longitude) < 0.0001) then
    Exit;

  Inside := False;
  J := 3;
  for I := 0 to 3 do
  begin
    if ((FGeofence[I].Latitude > ALat) <> (FGeofence[J].Latitude > ALat)) and
       (ALon < (FGeofence[J].Longitude - FGeofence[I].Longitude) * (ALat - FGeofence[I].Latitude) / (FGeofence[J].Latitude - FGeofence[I].Latitude) + FGeofence[I].Longitude) then
      Inside := not Inside;
    J := I;
  end;
  Result := Inside;
end;

function TFlightPlan.CheckAltitudeLimits(AAlt: Double; out AWarning: string): Boolean;
begin
  Result := True;
  AWarning := '';

  if not FAltitudeActive then
    Exit;

  if AAlt > FMaxAltitude then
  begin
    Result := False;
    AWarning := Format('ALTITUDE CRÍTICA: Relação %.1fm excede Máximo %.1fm!', [AAlt, FMaxAltitude]);
  end
  else if AAlt < FMinAltitude then
  begin
    Result := False;
    AWarning := Format('ALTITUDE CRÍTICA: Relação %.1fm é inferior ao Mínimo %.1fm!', [AAlt, FMinAltitude]);
  end;
end;

procedure TFlightPlan.StartRoute;
var
  I: Integer;
begin
  if FWaypoints.Count = 0 then
  begin
    FCurrentIndex := -1;
    Exit;
  end;

  for I := 0 to FWaypoints.Count - 1 do
    TWaypoint(FWaypoints[I]).Status := 'PENDING';

  FCurrentIndex := 0;
  TWaypoint(FWaypoints[0]).Status := 'ACTIVE';

  if FSimulationActive then
  begin
    FSimulatedDroneLat := TWaypoint(FWaypoints[0]).Latitude;
    FSimulatedDroneLon := TWaypoint(FWaypoints[0]).Longitude;
    FSimulatedDroneAlt := TWaypoint(FWaypoints[0]).Altitude;
  end;
end;

procedure TFlightPlan.UpdateRouteTracking(ADroneLat, ADroneLon: Double; out ANextWaypointMsg: string);
var
  W: TWaypoint;
  Dist: Double;
begin
  ANextWaypointMsg := '';
  if (FCurrentIndex < 0) or (FCurrentIndex >= FWaypoints.Count) then
    Exit;

  W := TWaypoint(FWaypoints[FCurrentIndex]);

  // Distance using flat-surface approximation for tiny offsets
  Dist := Sqrt(Sqr((W.Latitude - ADroneLat) * 111320) + Sqr((W.Longitude - ADroneLon) * 96000));
  if Dist < 4.0 then // 4 meter threshold
  begin
    W.Status := 'COMPLETED';
    Inc(FCurrentIndex);
    if FCurrentIndex < FWaypoints.Count then
    begin
      TWaypoint(FWaypoints[FCurrentIndex]).Status := 'ACTIVE';
      ANextWaypointMsg := Format('Waypoint %d alcançado. Direcionando ao Waypoint %d...', [FCurrentIndex, FCurrentIndex + 1]);
    end
    else
    begin
      FCurrentIndex := -1;
      ANextWaypointMsg := 'ROTA PROGRAMADA CONCLUÍDA COM SUCESSO.';
    end;
  end;
end;

procedure TFlightPlan.SimulateStep(const ATimeStepSec: Double);
var
  W: TWaypoint;
  DirLat, DirLon, Dist: Double;
  StepDist: Double;
begin
  if not FSimulationActive then
    Exit;

  if (FCurrentIndex < 0) or (FCurrentIndex >= FWaypoints.Count) then
    Exit;

  W := TWaypoint(FWaypoints[FCurrentIndex]);
  DirLat := W.Latitude - FSimulatedDroneLat;
  DirLon := W.Longitude - FSimulatedDroneLon;
  Dist := Sqrt(Sqr(DirLat * 111320) + Sqr(DirLon * 96000));

  if Dist > 0.2 then
  begin
    StepDist := W.Speed * ATimeStepSec;
    if StepDist >= Dist then
    begin
      FSimulatedDroneLat := W.Latitude;
      FSimulatedDroneLon := W.Longitude;
    end
    else
    begin
      FSimulatedDroneLat := FSimulatedDroneLat + (DirLat * (StepDist / Dist));
      FSimulatedDroneLon := FSimulatedDroneLon + (DirLon * (StepDist / Dist));
    end;
  end;

  if Abs(FSimulatedDroneAlt - W.Altitude) > 0.1 then
  begin
    if FSimulatedDroneAlt < W.Altitude then
      FSimulatedDroneAlt := FSimulatedDroneAlt + (1.5 * ATimeStepSec) // 1.5 m/s climb
    else
      FSimulatedDroneAlt := FSimulatedDroneAlt - (1.5 * ATimeStepSec); // 1.5 m/s descent
  end
  else
    FSimulatedDroneAlt := W.Altitude;
end;

procedure TFlightPlan.SetGeofenceCorner(AIndex: Integer; ALat, ALon: Double);
begin
  if (AIndex >= 0) and (AIndex < 4) then
  begin
    FGeofence[AIndex].Latitude := ALat;
    FGeofence[AIndex].Longitude := ALon;
  end;
end;

function TFlightPlan.GetGeofenceCorner(AIndex: Integer): TGeofencePoint;
begin
  if (AIndex >= 0) and (AIndex < 4) then
    Result := FGeofence[AIndex]
  else
  begin
    Result.Latitude := 0.0;
    Result.Longitude := 0.0;
  end;
end;

initialization
  GlobalFlightPlan := TFlightPlan.Create;

finalization
  GlobalFlightPlan.Free;

end.
