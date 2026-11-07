unit cockpit_multiplayer;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, SyncObjs, fpjson, multiplayer_state, simulator_multiplayer_client, multiplayer_websocket;
type
  TCockpitMultiplayer = class(TThread)
  private
    FLock: TCriticalSection;
    FClient: TSimulatorMultiplayerClient;
    FURL: string;
    FWebSocket: Boolean;
    FLat, FLon, FAlt: Double;
    FPositionAt: QWord;
    FValid: Boolean;
    FParticipants: TParticipants;
    FStatus: string;
    procedure ExecuteWebSocket;
    procedure Publish(const Items: TParticipants; const Status: string);
  protected
    procedure Execute; override;
  public
    constructor Create(const URL: string);
    destructor Destroy; override;
    procedure SetPosition(Lat, Lon, Alt: Double; Valid: Boolean);
    procedure Snapshot(out Items: TParticipants; out Status: string);
  end;
implementation
constructor TCockpitMultiplayer.Create(const URL: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FLock := TCriticalSection.Create;
  FURL := URL;
  FWebSocket := (Pos('ws://', URL) = 1) or (Pos('wss://', URL) = 1);
  if not FWebSocket then FClient := TSimulatorMultiplayerClient.Create(URL);
  FStatus := 'Aguardando simulacao de rota';
  Start;
end;
destructor TCockpitMultiplayer.Destroy;
begin
  Terminate;
  WaitFor;
  FClient.Free;
  FLock.Free;
  inherited Destroy;
end;
procedure TCockpitMultiplayer.SetPosition(Lat, Lon, Alt: Double; Valid: Boolean);
begin
  FLock.Enter;
  try
    FLat := Lat; FLon := Lon; FAlt := Alt; FValid := Valid;
    FPositionAt := GetTickCount64;
    if not Valid then FParticipants := nil;
  finally FLock.Leave end;
end;
procedure TCockpitMultiplayer.Publish(const Items: TParticipants; const Status: string);
begin
  FLock.Enter;
  try FParticipants := Copy(Items); FStatus := Status;
  finally FLock.Leave end;
end;
procedure TCockpitMultiplayer.Snapshot(out Items: TParticipants; out Status: string);
begin
  FLock.Enter;
  try Items := Copy(FParticipants); Status := FStatus;
  finally FLock.Leave end;
end;
procedure TCockpitMultiplayer.Execute;
var Lat, Lon, Alt: Double; Valid, Online: Boolean; R: TJSONData;
    Items: TParticipants; Next: QWord;
begin
  if FWebSocket then begin ExecuteWebSocket; Exit end;
  Online := False; Next := 0;
  while not Terminated do
  begin
    if GetTickCount64 < Next then begin Sleep(25); Continue end;
    Next := GetTickCount64 + 500;
    FLock.Enter;
    try
      Lat := FLat; Lon := FLon; Alt := FAlt;
      Valid := FValid and (GetTickCount64 - FPositionAt < 2000);
    finally FLock.Leave end;
    try
      if not Valid then
      begin
        Publish(nil, 'Aguardando simulacao de rota');
        if Online then begin Online := False; R := FClient.Disconnect; R.Free end;
        Continue;
      end;
      if not Online then begin R := FClient.Connect; R.Free; Online := True end;
      R := FClient.SendTelemetry(Lat, Lon, Alt, 'simulation'); R.Free;
      if Terminated then Break;
      R := FClient.Nearby;
      try Items := ParseParticipants(R); finally R.Free end;
      Publish(Items, Format('Multiplayer: %d participantes ate 2 km', [Length(Items)]));
    except
      on E: Exception do
      begin
        Publish(nil, 'Multiplayer: sem conexao - ' + E.Message);
        // Reuse a live session after transient errors; reconnect only on 401.
        if (E is EMultiplayerAPI) and (EMultiplayerAPI(E).StatusCode = 401) then
          Online := False;
        Next := GetTickCount64 + 2000;
      end;
    end;
  end;
  if Online then try R := FClient.Disconnect; R.Free except end;
end;
procedure TCockpitMultiplayer.ExecuteWebSocket;
var WS: TMultiplayerWebSocket; Lat, Lon, Alt: Double; Valid: Boolean;
    NextSend, RetryAt: QWord; Items: TParticipants;
begin
  WS := nil; NextSend := 0; RetryAt := 0;
  try
    while not Terminated do
    begin
      Sleep(25);
      FLock.Enter;
      try
        Lat := FLat; Lon := FLon; Alt := FAlt;
        Valid := FValid and (GetTickCount64 - FPositionAt < 2000);
      finally FLock.Leave end;
      if not Valid then
      begin
        FreeAndNil(WS); Publish(nil, 'Aguardando simulacao de rota'); Continue;
      end;
      if GetTickCount64 < RetryAt then Continue;
      try
        if WS = nil then begin WS := TMultiplayerWebSocket.Create(FURL); NextSend := 0 end;
        if GetTickCount64 >= NextSend then
        begin WS.SendTelemetry(Lat, Lon, Alt); NextSend := GetTickCount64 + 500 end;
        Items := WS.Snapshot;
        Publish(Items, Format('WebSocket: %d participantes ate 2 km', [Length(Items)]));
      except
        on E: Exception do
        begin
          Publish(nil, 'WebSocket: sem conexao - ' + E.Message);
          FreeAndNil(WS); RetryAt := GetTickCount64 + 2000;
        end;
      end;
    end;
  finally WS.Free end;
end;

end.
