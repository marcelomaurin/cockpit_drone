unit vehicle_control_contract;

{ Contrato neutro de comandos por classe de veiculo.
  Nao transmite comandos nem implementa protocolo de hardware.
  Adaptadores devem validar capabilities e estado de seguranca antes de enviar. }

{$mode objfpc}{$H+}

interface

uses SysUtils, Math;

type
  TVehicleClass = (vcMultirotor, vcFixedWing, vcHelicopter, vcBoat, vcSubmersible);
  TVehicleAxis = (vaRoll, vaPitch, vaYaw, vaThrottle, vaCollective,
    vaRudder, vaForward, vaLateral, vaVertical);
  TVehicleAxes = set of TVehicleAxis;
  TVehicleCommand = record
    VehicleClass: TVehicleClass;
    Values: array[TVehicleAxis] of Double;
    Enabled: TVehicleAxes;
    Armed: Boolean;
  end;

function AllowedAxes(AClass: TVehicleClass): TVehicleAxes;
function ValidateCommand(const Cmd: TVehicleCommand; out ErrorText: string): Boolean;
procedure NeutralCommand(out Cmd: TVehicleCommand; AClass: TVehicleClass);

implementation

function AllowedAxes(AClass: TVehicleClass): TVehicleAxes;
begin
  case AClass of
    vcMultirotor: Result := [vaRoll, vaPitch, vaYaw, vaThrottle];
    vcFixedWing: Result := [vaRoll, vaPitch, vaRudder, vaThrottle];
    vcHelicopter: Result := [vaRoll, vaPitch, vaYaw, vaCollective, vaThrottle];
    vcBoat: Result := [vaRudder, vaForward];
    vcSubmersible: Result := [vaForward, vaLateral, vaVertical, vaRoll, vaPitch, vaYaw];
  end;
end;

procedure NeutralCommand(out Cmd: TVehicleCommand; AClass: TVehicleClass);
var Axis: TVehicleAxis;
begin
  Cmd := Default(TVehicleCommand);
  Cmd.VehicleClass := AClass;
  Cmd.Enabled := AllowedAxes(AClass);
  Cmd.Armed := False;
  for Axis := Low(TVehicleAxis) to High(TVehicleAxis) do
    Cmd.Values[Axis] := 0;
end;

function ValidateCommand(const Cmd: TVehicleCommand; out ErrorText: string): Boolean;
var Axis: TVehicleAxis;
begin
  Result := False;
  ErrorText := '';
  if not (Cmd.Enabled <= AllowedAxes(Cmd.VehicleClass)) then
  begin
    ErrorText := 'Eixo nao permitido para esta classe de veiculo';
    Exit;
  end;
  for Axis := Low(TVehicleAxis) to High(TVehicleAxis) do
  begin
    if IsNan(Cmd.Values[Axis]) or IsInfinite(Cmd.Values[Axis]) then
    begin
      ErrorText := 'Valor nao finito';
      Exit;
    end;
    if (Cmd.Values[Axis] < -1) or (Cmd.Values[Axis] > 1) then
    begin
      ErrorText := 'Eixo fora do intervalo [-1,1]';
      Exit;
    end;
    if not (Axis in Cmd.Enabled) and (Cmd.Values[Axis] <> 0) then
    begin
      ErrorText := 'Eixo desabilitado com valor diferente de zero';
      Exit;
    end;
  end;
  if not Cmd.Armed then
    for Axis := Low(TVehicleAxis) to High(TVehicleAxis) do
      if Cmd.Values[Axis] <> 0 then
      begin
        ErrorText := 'Comando nao neutro com veiculo desarmado';
        Exit;
      end;
  Result := True;
end;

end.
