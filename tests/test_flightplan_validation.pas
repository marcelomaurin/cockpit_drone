program test_flightplan_validation;
{$mode objfpc}{$H+}
uses SysUtils, Classes, Math, flightplan;
procedure Check(Ok:Boolean; const Text:string);
begin if not Ok then raise Exception.Create(Text); end;
var Plan:TFlightPlan; Errors,Warnings:TStringList; Number:Double;
begin
  Plan:=TFlightPlan.Create; Errors:=TStringList.Create; Warnings:=TStringList.Create;
  try
    Check(not Plan.Valida(Errors,Warnings),'empty route');
    Plan.DefineHome(-21.17,-47.81);
    Plan.AddWaypoint(-21.1701,-47.8101,20,5);
    Check(Plan.Valida(Errors,Warnings),'valid route');
    Check(LeNumero('1,5',Number) and (Number=1.5),'localized finite number');
    Check(not LeNumero('NaN',Number),'NaN text');
    Check(not LeNumero('Inf',Number),'infinity text');
    Plan[0].Latitude:=NaN;
    Check(not Plan.Valida(Errors,Warnings),'NaN latitude must reject');
    Plan[0].Latitude:=-21.1701;
    Plan[0].Altitude:=NaN;
    Check(not Plan.Valida(Errors,Warnings),'NaN altitude must reject');
    Plan[0].Altitude:=20;
    Plan[0].Speed:=Infinity;
    Check(not Plan.Valida(Errors,Warnings),'infinite speed must reject');
    Plan[0].Speed:=5;
    Plan.DistanciaMaxima:=NaN;
    Check(not Plan.Valida(Errors,Warnings),'NaN distance limit must reject');
    Plan.DistanciaMaxima:=500;
    Plan.DefineHome(Infinity,-47.81);
    Check(not Plan.Valida(Errors,Warnings),'infinite home must reject');
    Plan.DefineHome(-21.17,-47.81);
    Plan.AltitudeDecolagem:=NaN;
    Check(not Plan.Valida(Errors,Warnings),'NaN takeoff altitude must reject');
    Plan.AltitudeDecolagem:=10;
    Check(Plan.Valida(Errors,Warnings),'valid state after rejected values');
    WriteLn('PASS: flightplan finite values and route validation');
  finally Warnings.Free; Errors.Free; Plan.Free; end;
end.
