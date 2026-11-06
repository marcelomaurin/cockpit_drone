unit sitl_telemetry_state;

{ Read-only state holder for JSON heartbeat events produced by
  tools/sitl_heartbeat_monitor.py. No MAVLink commands or transport. }

{$mode objfpc}{$H+}

interface

uses SysUtils, fpjson, jsonparser;

type
  TSitlTelemetry = record
    Connected: Boolean;
    VehicleClass: string;
    SystemId: Integer;
    ComponentId: Integer;
    CustomMode: Cardinal;
    ArmedReported: Boolean;
    LastHeartbeatMs: QWord;
  end;

procedure ResetSitlTelemetry(out State: TSitlTelemetry);
function ApplySitlEvent(const Line: string; var State: TSitlTelemetry;
  NowMs: QWord; out ErrorText: string): Boolean;
procedure ExpireSitlTelemetry(var State: TSitlTelemetry; NowMs, TimeoutMs: QWord);

implementation

procedure ResetSitlTelemetry(out State: TSitlTelemetry);
begin
  State := Default(TSitlTelemetry);
  State.VehicleClass := 'unknown';
end;

procedure ExpireSitlTelemetry(var State: TSitlTelemetry; NowMs, TimeoutMs: QWord);
begin
  if State.Connected and
     ((NowMs < State.LastHeartbeatMs) or
      (NowMs - State.LastHeartbeatMs > TimeoutMs)) then
  begin
    ResetSitlTelemetry(State);
  end;
end;

function ApplySitlEvent(const Line: string; var State: TSitlTelemetry;
  NowMs: QWord; out ErrorText: string): Boolean;
var
  Data: TJSONData;
  Obj: TJSONObject;
  EventName: string;
  Candidate: TSitlTelemetry;
  ParsedId: Int64;
begin
  Result := False;
  ErrorText := '';
  Data := nil;
  try
    try
      Data := GetJSON(Line);
    if Data.JSONType <> jtObject then
    begin
      ErrorText := 'Evento nao e objeto JSON';
      Exit;
    end;
    Obj := TJSONObject(Data);
    EventName := Obj.Get('event', '');
    if EventName = 'heartbeat_timeout' then
    begin
      ResetSitlTelemetry(State);
      Result := True;
      Exit;
    end;
    if EventName <> 'heartbeat' then
    begin
      ErrorText := 'Evento desconhecido';
      Exit;
    end;
    if not (Obj.Find('system_id') <> nil) or
       not (Obj.Find('component_id') <> nil) or
       not (Obj.Find('vehicle_class') <> nil) then
    begin
      ErrorText := 'Campos obrigatorios ausentes';
      Exit;
    end;
    if (Obj.Find('system_id').JSONType <> jtNumber) or
       (Obj.Find('component_id').JSONType <> jtNumber) or
       (Obj.Find('vehicle_class').JSONType <> jtString) then
    begin
      ErrorText := 'Tipos de campos MAVLink invalidos';
      Exit;
    end;
    if ((Obj.Find('custom_mode') <> nil) and
        (Obj.Find('custom_mode').JSONType <> jtNumber)) or
       ((Obj.Find('armed_reported') <> nil) and
        (Obj.Find('armed_reported').JSONType <> jtBoolean)) then
    begin
      ErrorText := 'Tipos de campos opcionais invalidos';
      Exit;
    end;
    ResetSitlTelemetry(Candidate);
    if not TryStrToInt64(Obj.Find('system_id').AsJSON, ParsedId) or
       (ParsedId < 1) or (ParsedId > 255) then
    begin
      ErrorText := 'Identificador MAVLink de sistema invalido';
      Exit;
    end;
    Candidate.SystemId := ParsedId;
    if not TryStrToInt64(Obj.Find('component_id').AsJSON, ParsedId) or
       (ParsedId < 1) or (ParsedId > 255) then
    begin
      ErrorText := 'Identificador MAVLink de componente invalido';
      Exit;
    end;
    Candidate.ComponentId := ParsedId;
    Candidate.VehicleClass := Obj.Get('vehicle_class', 'unsupported');
    if (Candidate.VehicleClass <> 'fixed_wing') and
       (Candidate.VehicleClass <> 'multirotor') and
       (Candidate.VehicleClass <> 'helicopter') and
       (Candidate.VehicleClass <> 'boat') and
       (Candidate.VehicleClass <> 'submersible') then
    begin
      ErrorText := 'Classe de veiculo SITL desconhecida';
      Exit;
    end;
    if Obj.Find('custom_mode') <> nil then
    begin
      if not TryStrToInt64(Obj.Find('custom_mode').AsJSON, ParsedId) or
         (ParsedId < 0) or (ParsedId > High(Cardinal)) then
      begin
        ErrorText := 'Modo MAVLink invalido ou fora da faixa suportada';
        Exit;
      end;
      Candidate.CustomMode := ParsedId;
    end;
    Candidate.ArmedReported := Obj.Get('armed_reported', False);
    if (Candidate.SystemId < 1) or (Candidate.SystemId > 255) or
       (Candidate.ComponentId < 1) or (Candidate.ComponentId > 255) then
    begin
      ErrorText := 'Identificadores MAVLink invalidos';
      Exit;
    end;
    Candidate.LastHeartbeatMs := NowMs;
    Candidate.Connected := True;
    State := Candidate;
    Result := True;
    except
      on E: Exception do ErrorText := E.Message;
    end;
  finally
    Data.Free;
  end;
end;

end.
