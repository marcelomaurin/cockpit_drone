program test_config_046;
{$mode objfpc}{$H+}
uses Interfaces,Forms,SysUtils,StdCtrls,config,setmain,cockpit_rc_config,vehicle_rc_profile,rc_wire_protocol;
type TErrorCatcher=class
 procedure Error(Sender:TObject;E:Exception);
end;
procedure TErrorCatcher.Error(Sender:TObject;E:Exception);
begin WriteLn(StdErr,E.ClassName,': ',E.Message);DumpExceptionBackTrace(StdErr);Halt(1);end;
procedure Check(B:Boolean;const M:string);begin if not B then raise Exception.Create(M);end;
var F:Tfrmconfig;P:TRCConfigPanel;C:TComboBox;Dir:string;Catcher:TErrorCatcher;
begin
 try Application.Initialize;Catcher:=TErrorCatcher.Create;Application.OnException:=@Catcher.Error;Dir:=GetTempDir+'cockpit-config046-'+IntToStr(GetTickCount64);ForceDirectories(Dir);
 FSetMain:=TSetMain.Create(Dir);
 try FSetMain.DroneProtocolo:=11;FSetMain.RCSelected[rcSBUS]:=vcSubmarine;
 WriteLn('Creating configuration');Flush(Output);F:=Tfrmconfig.Create(nil);WriteLn('Created configuration');Flush(Output);
 try Check(F.cbProtocol.ItemIndex=11,'protocol selection reset');
 Check(Pos('Submarino',F.cbModelo.Text)>0,'saved vehicle class reset');
 P:=TRCConfigPanel(F.FindComponent('rcConfigPanel'));Check(Assigned(P),'RC panel missing');
 C:=TComboBox(P.FindComponent('rcVehicleClass'));Check(Assigned(C),'category selector missing');
 C.ItemIndex:=Ord(vcAirplane);C.OnChange(C);
 Check(FSetMain.RCSelected[rcSBUS]=vcAirplane,'vehicle category not changed');
 Check(Pos('Aviao',F.cbModelo.Text)>0,'catalog must follow RC category');
 finally F.Free;end;
 FSetMain.SalvaContexto;FreeAndNil(FSetMain);FSetMain:=TSetMain.Create(Dir);
 WriteLn('Creating configuration');Flush(Output);F:=Tfrmconfig.Create(nil);WriteLn('Created configuration');Flush(Output);
 try Check(F.cbProtocol.ItemIndex=11,'protocol lost after reload');
 Check(FSetMain.RCSelected[rcSBUS]=vcAirplane,'vehicle lost after reload');
 Check(Pos('Aviao',F.cbModelo.Text)>0,'saved catalog/vehicle mismatch after reload');
 finally F.Free;end;
 finally FreeAndNil(FSetMain);end;
 WriteLn('PASS real configuration form: RC catalog, category change, model synchronization and restart persistence');
 except on E:Exception do begin WriteLn(StdErr,E.Message);Halt(1);end;end;
end.
