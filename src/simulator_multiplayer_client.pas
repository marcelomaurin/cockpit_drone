unit simulator_multiplayer_client;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, fphttpclient, fpjson, jsonparser;

type
  EMultiplayerAPI = class(Exception);
  TSimulatorMultiplayerClient = class
  private
    FBaseURL, FToken: string;
    FHTTP: TFPHTTPClient;
    function Request(const AMethod, AEndpoint: string; ABody: TJSONObject = nil): TJSONData;
  public
    constructor Create(const ABaseURL: string);
    destructor Destroy; override;
    function Connect: TJSONData;
    function SendTelemetry(const ALatitude, ALongitude, AAltitude: Double;
      const AState: string = 'flying'): TJSONData;
    function Nearby: TJSONData;
    function SendEvent(const AType: string; APayload: TJSONObject): TJSONData;
    function GetEvents(const AAfter: Int64 = 0): TJSONData;
    function Heartbeat: TJSONData;
    function Disconnect: TJSONData;
    property Token: string read FToken;
  end;

implementation

constructor TSimulatorMultiplayerClient.Create(const ABaseURL: string);
begin
  inherited Create;
  FBaseURL := ABaseURL;
  while (Length(FBaseURL) > 0) and (FBaseURL[Length(FBaseURL)] = '/') do
    Delete(FBaseURL, Length(FBaseURL), 1);
  FHTTP := TFPHTTPClient.Create(nil);
  FHTTP.AddHeader('Accept', 'application/json');
end;

destructor TSimulatorMultiplayerClient.Destroy;
begin
  FHTTP.Free;
  inherited Destroy;
end;

function TSimulatorMultiplayerClient.Request(const AMethod, AEndpoint: string;
  ABody: TJSONObject): TJSONData;
var
  Response: TStringStream;
  Input: TStringStream;
  TextBody: string;
begin
  Result := nil;
  Response := TStringStream.Create('');
  Input := nil;
  try
    FHTTP.RequestHeaders.Clear;
    FHTTP.AddHeader('Accept', 'application/json');
    if FToken <> '' then
      FHTTP.AddHeader('Authorization', 'Bearer ' + FToken);
    if ABody <> nil then
    begin
      TextBody := ABody.AsJSON;
      Input := TStringStream.Create(TextBody);
      FHTTP.AddHeader('Content-Type', 'application/json');
      FHTTP.RequestBody := Input;
    end
    else
      FHTTP.RequestBody := nil;
    try
      FHTTP.HTTPMethod(AMethod, FBaseURL + '/' + AEndpoint, Response, [200, 201, 202]);
      Result := GetJSON(Response.DataString);
    except
      on E: Exception do
        raise EMultiplayerAPI.Create('Multiplayer ' + AMethod + ' /' +
          AEndpoint + ': ' + E.Message);
    end;
  finally
    FHTTP.RequestBody := nil;
    Input.Free;
    Response.Free;
  end;
end;

function TSimulatorMultiplayerClient.Connect: TJSONData;
var
  Obj: TJSONObject;
begin
  FToken := '';
  Obj := TJSONObject.Create;
  try
    Result := Request('POST', 'connect', Obj);
    if Result.JSONType = jtObject then
      FToken := TJSONObject(Result).Get('token', '');
    if FToken = '' then
    begin
      Result.Free;
      raise EMultiplayerAPI.Create('Connect returned no token');
    end;
  finally
    Obj.Free;
  end;
end;

function TSimulatorMultiplayerClient.SendTelemetry(
  const ALatitude, ALongitude, AAltitude: Double;
  const AState: string): TJSONData;
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.Add('lat', ALatitude);
    Obj.Add('lon', ALongitude);
    Obj.Add('altitude_m', AAltitude);
    Obj.Add('state', AState);
    Result := Request('POST', 'telemetry', Obj);
  finally
    Obj.Free;
  end;
end;

function TSimulatorMultiplayerClient.Nearby: TJSONData;
begin
  Result := Request('GET', 'nearby');
end;

function TSimulatorMultiplayerClient.SendEvent(const AType: string;
  APayload: TJSONObject): TJSONData;
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.Add('type', AType);
    if APayload <> nil then
      Obj.Add('payload', APayload.Clone)
    else
      Obj.Add('payload', TJSONObject.Create);
    Result := Request('POST', 'events', Obj);
  finally
    Obj.Free;
  end;
end;

function TSimulatorMultiplayerClient.GetEvents(const AAfter: Int64): TJSONData;
begin
  Result := Request('GET', 'events?after=' + IntToStr(AAfter));
end;

function TSimulatorMultiplayerClient.Heartbeat: TJSONData;
begin
  Result := Request('POST', 'heartbeat', TJSONObject.Create);
end;

function TSimulatorMultiplayerClient.Disconnect: TJSONData;
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Result := Request('POST', 'disconnect', Obj);
    FToken := '';
  finally
    Obj.Free;
  end;
end;

end.
