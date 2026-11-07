unit multiplayer_websocket;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, SyncObjs, fpjson, jsonparser, URIParser, multiplayer_state;
type
  TMultiplayerWebSocket = class(TThread)
  private
    FSession, FConnection, FRequest, FSocket: Pointer;
    FLock: TCriticalSection;
    FItems: TParticipants;
    FError: string;
    FLastSeen: QWord;
    procedure SendText(const Text: UTF8String);
  protected
    procedure Execute; override;
  public
    constructor Create(const URL: string);
    destructor Destroy; override;
    procedure SendTelemetry(Lat, Lon, Alt: Double);
    function Snapshot: TParticipants;
  end;
implementation
{$IFDEF MSWINDOWS}
uses Windows;
function WinHttpOpen(Agent: PWideChar; Access: DWORD; Proxy, Bypass: PWideChar; Flags: DWORD): Pointer; stdcall; external 'winhttp.dll';
function WinHttpConnect(Session: Pointer; Server: PWideChar; Port: Word; Reserved: DWORD): Pointer; stdcall; external 'winhttp.dll';
function WinHttpOpenRequest(Connection: Pointer; Verb, Path, Version, Referrer: PWideChar; Accept: Pointer; Flags: DWORD): Pointer; stdcall; external 'winhttp.dll';
function WinHttpSetOption(H: Pointer; Option: DWORD; Buffer: Pointer; Size: DWORD): BOOL; stdcall; external 'winhttp.dll';
function WinHttpSetTimeouts(H: Pointer; Resolve, Connect, Send, Receive: Integer): BOOL; stdcall; external 'winhttp.dll';
function WinHttpSendRequest(H: Pointer; Headers: PWideChar; HeaderLength: DWORD; Data: Pointer; Size, Total: DWORD; Context: PtrUInt): BOOL; stdcall; external 'winhttp.dll';
function WinHttpReceiveResponse(H, Reserved: Pointer): BOOL; stdcall; external 'winhttp.dll';
function WinHttpQueryHeaders(H: Pointer; Level: DWORD; Name: PWideChar; Buffer: Pointer; var Size: DWORD; Index: Pointer): BOOL; stdcall; external 'winhttp.dll';
function WinHttpCloseHandle(H: Pointer): BOOL; stdcall; external 'winhttp.dll';
function WinHttpWebSocketCompleteUpgrade(H: Pointer; Context: PtrUInt): Pointer; stdcall; external 'winhttp.dll';
function WinHttpWebSocketSend(H: Pointer; Kind: DWORD; Data: Pointer; Size: DWORD): DWORD; stdcall; external 'winhttp.dll';
function WinHttpWebSocketReceive(H: Pointer; Data: Pointer; Size: DWORD; var Read, Kind: DWORD): DWORD; stdcall; external 'winhttp.dll';
procedure Check(Value: Boolean);
begin if not Value then RaiseLastOSError end;
{$ENDIF}
constructor TMultiplayerWebSocket.Create(const URL: string);
{$IFDEF MSWINDOWS}
var U: TURI; Host, Path: UnicodeString; Port: Word; Flags, Status, Size: DWORD;
{$ENDIF}
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FLock := SyncObjs.TCriticalSection.Create;
  FLastSeen := GetTickCount64;
  {$IFDEF MSWINDOWS}
  U := ParseURI(URL);
  if (U.Protocol <> 'ws') and (U.Protocol <> 'wss') then
    raise Exception.Create('Use ws:// ou wss://');
  if (U.Host = '') or (U.Username <> '') or (U.Password <> '') then
    raise Exception.Create('URL WebSocket invalida');
  Host := UTF8Decode(U.Host);
  Path := UTF8Decode(U.Path + U.Document);
  if Path = '' then Path := '/';
  if U.Params <> '' then Path := Path + '?' + UTF8Decode(U.Params);
  Flags := 0; Port := U.Port;
  if U.Protocol = 'wss' then begin Flags := $00800000; if Port = 0 then Port := 443 end
  else if Port = 0 then Port := 80;
  FSession := WinHttpOpen('CockpitDrone/0.01', 0, nil, nil, 0); Check(FSession <> nil);
  Check(WinHttpSetTimeouts(FSession, 1500, 1500, 1500, 1500));
  FConnection := WinHttpConnect(FSession, PWideChar(Host), Port, 0); Check(FConnection <> nil);
  FRequest := WinHttpOpenRequest(FConnection, 'GET', PWideChar(Path), nil, nil, nil, Flags);
  Check(FRequest <> nil);
  Check(WinHttpSetOption(FRequest, 114, nil, 0));
  Check(WinHttpSendRequest(FRequest, nil, 0, nil, 0, 0, 0));
  Check(WinHttpReceiveResponse(FRequest, nil));
  Size := SizeOf(Status); Status := 0;
  Check(WinHttpQueryHeaders(FRequest, 19 or $20000000, nil, @Status, Size, nil));
  if Status <> 101 then raise Exception.CreateFmt('WebSocket HTTP %d', [Status]);
  FSocket := WinHttpWebSocketCompleteUpgrade(FRequest, 0); Check(FSocket <> nil);
  WinHttpCloseHandle(FRequest); FRequest := nil;
  Start;
  {$ELSE}
  raise Exception.Create('WebSocket nativo requer Windows 8 ou superior');
  {$ENDIF}
end;
destructor TMultiplayerWebSocket.Destroy;
begin
  Terminate;
  {$IFDEF MSWINDOWS}
  // Closing the handle cancels a pending receive, even if the peer is silent.
  if FSocket <> nil then WinHttpCloseHandle(FSocket);
  {$ENDIF}
  if not Suspended then WaitFor;
  {$IFDEF MSWINDOWS}
  if FRequest <> nil then WinHttpCloseHandle(FRequest);
  if FConnection <> nil then WinHttpCloseHandle(FConnection);
  if FSession <> nil then WinHttpCloseHandle(FSession);
  {$ENDIF}
  FLock.Free;
  inherited Destroy;
end;
procedure TMultiplayerWebSocket.SendText(const Text: UTF8String);
{$IFDEF MSWINDOWS}var Code: DWORD;{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  Code := WinHttpWebSocketSend(FSocket, 2, PAnsiChar(Text), Length(Text));
  if Code <> 0 then raise Exception.CreateFmt('WebSocket envio: %d', [Code]);
  {$ENDIF}
end;
procedure TMultiplayerWebSocket.SendTelemetry(Lat, Lon, Alt: Double);
var O: TJSONObject;
begin
  O := TJSONObject.Create(['type','telemetry','telemetry',
    TJSONObject.Create(['lat',Lat,'lon',Lon,'altitude_m',Alt,'state','simulation'])]);
  try SendText(O.AsJSON); finally O.Free end;
end;
function TMultiplayerWebSocket.Snapshot: TParticipants;
begin
  FLock.Enter;
  try
    if FError <> '' then raise Exception.Create(FError);
    if GetTickCount64 - FLastSeen > 5000 then raise Exception.Create('WebSocket sem atualizacao');
    Result := Copy(FItems);
  finally FLock.Leave end;
end;
procedure TMultiplayerWebSocket.Execute;
{$IFDEF MSWINDOWS}
var Buffer: array[0..4095] of Byte; Count, Kind, Code: DWORD;
    Text, Part: UTF8String; J: TJSONData; Items: TParticipants;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  try
    Text := '';
    while not Terminated do
    begin
      Code := WinHttpWebSocketReceive(FSocket, @Buffer[0], SizeOf(Buffer), Count, Kind);
      if Terminated then Exit;
      if Code <> 0 then raise Exception.CreateFmt('WebSocket leitura: %d', [Code]);
      if Kind = 4 then raise Exception.Create('WebSocket desconectado');
      if not (Kind in [2,3]) then raise Exception.Create('WebSocket requer JSON texto');
      SetString(Part, PAnsiChar(@Buffer[0]), Count); Text := Text + Part;
      if Length(Text) > 1048576 then raise Exception.Create('WebSocket mensagem muito grande');
      if Kind = 3 then Continue;
      J := GetJSON(Text); Text := '';
      try
        if not (J is TJSONObject) then raise Exception.Create('WebSocket JSON invalido');
        if TJSONObject(J).Get('type','') = 'snapshot' then
        begin
          Items := ParseParticipants(J);
          FLock.Enter;
          try FItems := Items; FLastSeen := GetTickCount64; finally FLock.Leave end;
        end
        else if TJSONObject(J).Get('type','') = 'error' then
          raise Exception.Create('WebSocket servidor: ' + TJSONObject(J).Get('code','erro'));
      finally J.Free end;
    end;
  except
    on E: Exception do begin
      FLock.Enter;
      try FError := E.Message; FItems := nil; finally FLock.Leave end;
    end;
  end;
  {$ENDIF}
end;
end.
