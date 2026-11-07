unit multiplayer_state;
{$mode objfpc}{$H+}
interface
uses SysUtils, Math, fpjson;
type
  TParticipant = record
    Id, Name: string;
    Lat, Lon, Altitude, Distance: Double;
  end;
  TParticipants = array of TParticipant;
function ParseParticipants(Data: TJSONData): TParticipants;
implementation
function Number(O: TJSONObject; const Key: string; MinV, MaxV: Double): Double;
var V: TJSONData;
begin
  V := O.Find(Key);
  if (V = nil) or (V.JSONType <> jtNumber) then
    raise EConvertError.Create('Campo numerico ausente: ' + Key);
  Result := V.AsFloat;
  if IsNan(Result) or IsInfinite(Result) or (Result < MinV) or (Result > MaxV) then
    raise EConvertError.Create('Campo fora da faixa: ' + Key);
end;
function ParseParticipants(Data: TJSONData): TParticipants;
var A: TJSONData; O, T: TJSONObject; I: Integer; P: TParticipant;
begin
  Result := nil;
  if not (Data is TJSONObject) then raise EConvertError.Create('Resposta invalida');
  A := TJSONObject(Data).Find('participants');
  if not (A is TJSONArray) then raise EConvertError.Create('Participantes ausentes');
  for I := 0 to A.Count - 1 do
  begin
    if not (A.Items[I] is TJSONObject) then Continue;
    O := TJSONObject(A.Items[I]);
    if not (O.Find('telemetry') is TJSONObject) then Continue;
    T := TJSONObject(O.Find('telemetry'));
    try
      P := Default(TParticipant);
      P.Id := O.Get('id', '');
      if P.Id = '' then Continue;
      P.Name := Copy(T.Get('name', P.Id), 1, 64);
      P.Lat := Number(T, 'lat', -90, 90);
      P.Lon := Number(T, 'lon', -180, 180);
      P.Altitude := Number(T, 'altitude_m', -10000, 100000);
      P.Distance := Number(O, 'distance_m', 0, 2000);
      SetLength(Result, Length(Result)+1);
      Result[High(Result)] := P;
      if Length(Result) >= 100 then Break;
    except
      on E: EConvertError do Continue;
      on E: EJSON do Continue;
    end;
  end;
end;
end.
