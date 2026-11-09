program test_binary_vehicle_pipeline;
{$mode objfpc}{$H+}
uses Interfaces,Forms,Classes,SysUtils,Math,setmain,conexaodrone,conectionbinaryrc,
 rc_wire_protocol,vehicle_rc_profile,simtipos,simgeo,simsimulacao;
type TAdapter=class(TfrmConectionBinaryRC)
 public function Open:Boolean;procedure Step(const C:TComandoManche);procedure Stop;
 end;
function TAdapter.Open:Boolean;begin Result:=Conectar;end;
procedure TAdapter.Step(const C:TComandoManche);begin Controle(C);end;
procedure TAdapter.Stop;begin Desconectar;end;
procedure Check(B:Boolean;const M:string);begin if not B then raise Exception.Create(M);end;
var Sim:TSimulacao;Models:TListaModelos;Origin:TPontoGeo;M:TOpcoesMavlink;ErrorText,Key:string;
 Adapter:TAdapter;C:TComandoManche;P:TRCWireProtocol;V:TVehicleClass;Variant:TWiFi8KVariant;I,Idx:Integer;
procedure Send;
begin C.SampleTick:=GetTickCount64;Adapter.Step(C);Sleep(40);end;
procedure BeginCase(const ModelKey:string;ProtocolIndex:Integer);
begin
 Idx:=IndiceModelo(Models,ModelKey);Check(Idx>=0,'model '+ModelKey);
 Check(Sim.Liga(Models[Idx],Origin,M,ErrorText),ErrorText);
 FSetMain.DroneProtocolo:=ProtocolIndex;Adapter:=TAdapter.Create(nil);
 Check(Adapter.Open,'cockpit transport handshake: '+Adapter.UltimoErro);
 C:=Default(TComandoManche);
end;
procedure EndCase;
begin Adapter.Stop;Adapter.Free;Adapter:=nil;Sim.Desliga;end;
begin
 try
 Application.Initialize;FSetMain:=TSetMain.Create(ParamStr(1));FSetMain.SimulationMode:=True;
 Models:=ModelosPadrao;Origin:=Default(TPontoGeo);M:=Default(TOpcoesMavlink);Sim:=TSimulacao.Create;
 try
 for Variant:=Low(Variant) to High(Variant) do begin
  FSetMain.WiFi8K.Variant:=Variant;FSetMain.WiFi8K.RealEnabled:=False;
  BeginCase('wifi8k',7);C.Acelerador:=0.5;C.Subida:=0;Send;
  C.Apertou[3]:=True;Send;C.Apertou[3]:=False;
  for I:=1 to 45 do Send;
  Check(Sim.LeEstado.Z>0.2,'WIFI_8K takeoff must move real physics');
  Adapter.Emergency;Send;Sleep(80);Check(not Sim.LeEstado.Motores,'WIFI_8K cut');
  EndCase;WriteLn('PASS cockpit -> UDP -> WIFI_8K variant ',Ord(Variant),' -> takeoff and cut');
 end;
 for P:=Low(P) to High(P) do begin
  FSetMain.RCSelected[P]:=vcDrone;BeginCase('rc_drone',8+Ord(P));
  C.Acelerador:=0;Send;C.Apertou[3]:=True;Send;C.Apertou[3]:=False;C.Acelerador:=0.75;
  for I:=1 to 24 do Send;
  Check(Sim.LeEstado.Z>0.2,'RC drone climb '+RCKeys[P]);
  Adapter.Emergency;Send;Sleep(80);Check(not Sim.LeEstado.Motores,'RC cut '+RCKeys[P]);
  EndCase;WriteLn('PASS cockpit -> ',RCKeys[P],' frame -> UDP -> simulated flight and cut');
 end;
 for V:=vcHelicopter to vcSubmarine do begin
  FSetMain.RCSelected[rcMSP2]:=V;Key:='rc_'+VehicleKeys[V];BeginCase(Key,9);
  if V in [vcCar,vcBoat,vcSubmarine] then C.Acelerador:=0.5 else C.Acelerador:=0;
  Send;C.Apertou[3]:=True;Send;C.Apertou[3]:=False;
  C.Acelerador:=0.8;if V=vcSubmarine then begin C.Acelerador:=0.2;C.Arfagem:=0.8;end;
  for I:=1 to 30 do Send;
  case V of
   vcHelicopter:Check(Sim.LeEstado.Z>0.2,'helicopter climb');
   vcAirplane:Check((Sim.LeEstado.DistPartida>0.2) and (Sim.LeEstado.Z<0.1),'airplane needs runway/airspeed, cannot hover');
   vcCar,vcBoat:Check((Sim.LeEstado.DistPartida>0.2) and (Sim.LeEstado.Z=0),'surface vehicle must remain on ground/water');
   vcSubmarine:Check((Sim.LeEstado.Z< -1.1) and (Sim.LeEstado.DistPartida>0.2),'submarine dive and forward');
  end;
  EndCase;WriteLn('PASS vehicle category ',VehicleKeys[V],' over actual cockpit adapter');
 end;
 finally Sim.Free;FSetMain.Free;FSetMain:=nil;end;
 except on E:Exception do begin WriteLn(StdErr,E.ClassName,': ',E.Message);Halt(1);end;end;
end.
