program test_vehicle_physics;
{$mode objfpc}{$H+}
uses SysUtils,Math,simtipos,simgeo,simfisica;
procedure Check(B:Boolean;const M:string);begin if not B then raise Exception.Create(M);end;
var Models:TListaModelos;P:TSimFisica;O:TPontoGeo;C:TComandoVoo;F:TFalhas;I:Integer;
begin
 Models:=ModelosPadrao;O:=Default(TPontoGeo);F:=Default(TFalhas);F.SinalInfinito:=True;
 P:=TSimFisica.Create(Models[IndiceModelo(Models,'rc_airplane')],O);
 try
 C:=ComandoNeutro;C.Motores:=True;C.ModoV:=mvEmpuxo;C.Vertical:=1;C.Arfagem:= -0.5;
 for I:=1 to 1200 do P.Passo(0.02,C,F);
 Check(P.Estado.Z>1,'airplane must gain lift after runway acceleration');
 WriteLn('PASS airplane flight after runway: ',P.Estado.Z:0:2,' m, speed ',Hypot(P.Estado.VX,P.Estado.VY):0:2,' m/s');
 P.Reinicia(O);C.Vertical:=0;
 for I:=1 to 100 do P.Passo(0.02,C,F);
 Check(P.Estado.Z=0,'airplane cannot hover or launch without speed');
 finally P.Free;end;
 P:=TSimFisica.Create(Models[IndiceModelo(Models,'rc_car')],O);
 try C:=ComandoNeutro;C.Motores:=True;C.Vertical:= -0.7;C.Rolagem:=0.4;
 for I:=1 to 200 do P.Passo(0.02,C,F);
 Check((P.Estado.Z=0) and (P.Estado.DistPartida>5),'car reverse motion and ground constraint');
 finally P.Free;end;
 P:=TSimFisica.Create(Models[IndiceModelo(Models,'rc_submarine')],O);
 try C:=ComandoNeutro;C.Motores:=True;C.Vertical:= -1;C.Arfagem:=1;
 for I:=1 to 2000 do P.Passo(0.02,C,F);
 Check((P.Estado.Z= -30) and not P.Estado.Caiu,'submarine depth floor and no aircraft crash');
 C.Vertical:=1;for I:=1 to 3000 do P.Passo(0.02,C,F);
 Check(P.Estado.Z=0,'submarine surface limit');
 finally P.Free;end;
 WriteLn('PASS fixed-wing lift, ground reverse, underwater depth/surface limits');
end.
