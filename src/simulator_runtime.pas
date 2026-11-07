unit simulator_runtime;

{$mode objfpc}{$H+}

interface

uses SysUtils, fpjson, simulator_vehicle_core, simulator_multiplayer_client;

type
  TSimulatorRuntime = class
  private
    FVehicle: TSimulatorVehicle;
    FNetwork: TSimulatorMultiplayerClient;
    FOnline: Boolean;
    FTelemetryElapsed, FHeartbeatElapsed: Double;
  public
    constructor Create(AKind: TVehicleKind; const AServerURL: string;
      ALatitude, ALongitude, AAltitudeM: Double);
    destructor Destroy; override;
    procedure Connect;
    procedure Step(ADeltaSeconds: Double);
    procedure Disconnect;
    function Nearby: TJSONData;
    function Events(const AAfter: Int64): TJSONData;
    property Vehicle: TSimulatorVehicle read FVehicle;
    property Online: Boolean read FOnline;
  end;

implementation

constructor TSimulatorRuntime.Create(AKind: TVehicleKind;
  const AServerURL: string; ALatitude, ALongitude, AAltitudeM: Double);
begin
  inherited Create;
  FVehicle := TSimulatorVehicle.Create(AKind, ALatitude, ALongitude, AAltitudeM);
  FNetwork := TSimulatorMultiplayerClient.Create(AServerURL);
end;

destructor TSimulatorRuntime.Destroy;
begin
  if FOnline then
    try Disconnect; except end;
  FNetwork.Free;
  FVehicle.Free;
  inherited Destroy;
end;

procedure TSimulatorRuntime.Connect;
var R: TJSONData;
begin
  if FOnline then Exit;
  R := FNetwork.Connect;
  try
    FOnline := True;
    FTelemetryElapsed := 0.2;
    FHeartbeatElapsed := 0;
  finally
    R.Free;
  end;
end;

procedure TSimulatorRuntime.Step(ADeltaSeconds: Double);
var R: TJSONData; S: TVehicleState;
begin
  FVehicle.Step(ADeltaSeconds);
  if not FOnline then Exit; // offline simulation remains available
  if (ADeltaSeconds <= 0) or (ADeltaSeconds > 1) then Exit;
  FTelemetryElapsed := FTelemetryElapsed + ADeltaSeconds;
  FHeartbeatElapsed := FHeartbeatElapsed + ADeltaSeconds;
  if FTelemetryElapsed >= 0.2 then
  begin
    S := FVehicle.State;
    try
      R := FNetwork.SendTelemetry(S.Latitude, S.Longitude, S.AltitudeM);
      R.Free;
    except
      on E: EMultiplayerAPI do
      begin
        FOnline := False;
        Exit;
      end;
    end;
    FTelemetryElapsed := 0;
    FHeartbeatElapsed := 0;
  end
  else if FHeartbeatElapsed >= 10 then
  begin
    try
      R := FNetwork.Heartbeat;
      R.Free;
    except
      on E: EMultiplayerAPI do FOnline := False;
    end;
    FHeartbeatElapsed := 0;
  end;
end;

procedure TSimulatorRuntime.Disconnect;
var R: TJSONData;
begin
  if not FOnline then Exit;
  FOnline := False;
  R := FNetwork.Disconnect;
  R.Free;
end;

function TSimulatorRuntime.Nearby: TJSONData;
begin
  if not FOnline then raise EMultiplayerAPI.Create('Simulator offline');
  Result := FNetwork.Nearby;
end;

function TSimulatorRuntime.Events(const AAfter: Int64): TJSONData;
begin
  if not FOnline then raise EMultiplayerAPI.Create('Simulator offline');
  Result := FNetwork.GetEvents(AAfter);
end;

end.
