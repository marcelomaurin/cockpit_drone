unit funcs;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math;
function MAPA(X0,X1,Y0,y1, valueX: real): byte;

implementation

// Linear mapping for joystick axes. Invalid readings must reach the caller's
// neutralization path instead of wrapping a byte into a non-neutral command.
function MAPA(X0,X1,Y0,Y1,valueX: real): byte;
var
  Value: Double;
begin
  if IsNan(X0) or IsNan(X1) or IsNan(Y0) or IsNan(Y1) or IsNan(valueX) or
     IsInfinite(X0) or IsInfinite(X1) or IsInfinite(Y0) or IsInfinite(Y1) or
     IsInfinite(valueX) or (X0 = X1) then
    raise EArgumentException.Create('Intervalo ou leitura de eixo invalido');
  valueX := EnsureRange(valueX, Min(X0, X1), Max(X0, X1));
  Value := ((valueX - X0) / (X1 - X0)) * (Y1 - Y0) + Y0;
  Result := Byte(Trunc(EnsureRange(Value, 0.0, 255.0)));
end;

end.
