unit sitl_telemetry_bridge;

{ Read-only subprocess bridge for local SITL heartbeat monitor.
  The caller must invoke Poll on the Lazarus UI thread periodically.
  No command channel to the vehicle is implemented. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, sitl_telemetry_state;

type
  TSitlTelemetryBridge = class
  private
    FProcess: TProcess;
    FBuffer: string;
    FState: TSitlTelemetry;
    FLastError: string;
  public
    constructor Create;
    destructor Destroy; override;
    function Start(const PythonExecutable, ScriptPath: string; Port: Word = 14550): Boolean;
    procedure Stop;
    procedure Poll(NowMs: QWord; TimeoutMs: QWord = 3000);
    property State: TSitlTelemetry read FState;
    property LastError: string read FLastError;
  end;

implementation

constructor TSitlTelemetryBridge.Create;
begin
  inherited Create;
  ResetSitlTelemetry(FState);
end;

destructor TSitlTelemetryBridge.Destroy;
begin
  Stop;
  inherited Destroy;
end;

function TSitlTelemetryBridge.Start(const PythonExecutable, ScriptPath: string;
  Port: Word): Boolean;
begin
  Result := False;
  Stop;
  FLastError := '';
  if (PythonExecutable = '') or (ScriptPath = '') or not FileExists(ScriptPath) or
     (Port < 1024) then
  begin
    FLastError := 'Parametros do monitor SITL invalidos';
    Exit;
  end;
  FProcess := TProcess.Create(nil);
  try
    FProcess.Executable := PythonExecutable;
    FProcess.Parameters.Add('-u');
    FProcess.Parameters.Add(ScriptPath);
    FProcess.Parameters.Add('--port');
    FProcess.Parameters.Add(IntToStr(Port));
    FProcess.Options := [poUsePipes, poNoConsole];
    FProcess.Execute;
    Result := FProcess.Running;
    if not Result then
    begin
      FLastError := 'Monitor SITL encerrou na inicializacao';
      Stop;
    end;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      Stop;
    end;
  end;
end;

procedure TSitlTelemetryBridge.Stop;
begin
  if Assigned(FProcess) then
  begin
    if FProcess.Running then
    begin
      FProcess.Terminate(0);
      FProcess.WaitOnExit;
    end;
    FreeAndNil(FProcess);
  end;
  FBuffer := '';
  ResetSitlTelemetry(FState);
end;

procedure TSitlTelemetryBridge.Poll(NowMs: QWord; TimeoutMs: QWord);
var
  Data: array[0..2047] of Byte;
  Count, I, PosLF: Integer;
  Line, ErrorText: string;
begin
  ExpireSitlTelemetry(FState, NowMs, TimeoutMs);
  if not Assigned(FProcess) then Exit;
  if not FProcess.Running then
  begin
    FLastError := 'Monitor SITL finalizado';
    ResetSitlTelemetry(FState);
    Exit;
  end;
  // Bounded reads avoid blocking the UI thread on an idle subprocess.
  for I := 1 to 8 do
  begin
    Count := FProcess.Output.NumBytesAvailable;
    if Count <= 0 then Break;
    if Count > SizeOf(Data) then Count := SizeOf(Data);
    Count := FProcess.Output.Read(Data, Count);
    if Count <= 0 then Break;
    FBuffer := FBuffer + TEncoding.UTF8.GetString(Data, 0, Count);
    if Length(FBuffer) > 65536 then
    begin
      FLastError := 'Linha de telemetria excedeu limite';
      FBuffer := '';
      ResetSitlTelemetry(FState);
      Exit;
    end;
    PosLF := Pos(#10, FBuffer);
    while PosLF > 0 do
    begin
      Line := Trim(Copy(FBuffer, 1, PosLF - 1));
      Delete(FBuffer, 1, PosLF);
      if (Line <> '') and not ApplySitlEvent(Line, FState, NowMs, ErrorText) then
        FLastError := ErrorText;
      PosLF := Pos(#10, FBuffer);
    end;
  end;
end;

end.
