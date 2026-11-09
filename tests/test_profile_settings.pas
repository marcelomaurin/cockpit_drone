program test_profile_settings;
{$mode objfpc}{$H+}
uses Interfaces, Forms, SysUtils, StdCtrls, Spin, setmain,
  cockpit_joystick_mapping, cockpit_joystick_config;
procedure Check(Ok:Boolean; const Msg:string);
begin if not Ok then raise Exception.Create(Msg); end;
var Panel:TFlightJoystickPanel; Settings:TSetMain; Folder:string;
begin
  Folder:=GetTempDir(False)+'cockpit-profile-test-'+IntToStr(GetTickCount64);
  ForceDirectories(Folder);
  Panel:=TFlightJoystickPanel.Create(nil);
  try
    Panel.LoadModel(Folder+'/models.ini','Cheerson','CX-10W',0);
    Check(Panel.Settings.Profile=jpAutomatic,'new model should use automatic profile');
    TComboBox(Panel.FindComponent('cbPerfilVoo')).ItemIndex:=jpCustom;
    TComboBox(Panel.FindComponent('cbEixoVoo0')).ItemIndex:=2;
    TCheckBox(Panel.FindComponent('ckInverterVoo0')).Checked:=True;
    TSpinEdit(Panel.FindComponent('edBotaoVoo3')).Value:=4;
    Panel.SaveProfile;
    Panel.LoadModel(Folder+'/models.ini','Ryze','Tello',2);
    Check(Panel.Settings.Profile=jpAutomatic,'Cheerson settings must not leak into Tello');
    Panel.LoadModel(Folder+'/models.ini','Cheerson','CX-10W',0);
    Check((Panel.Settings.Profile=jpCustom) and (Panel.Settings.Axis[0]=1), 'custom axis persistence');
    Check(Panel.Settings.Invert[0],'inversion persistence');
    Check(Panel.Settings.Button[3]=4,'button persistence');
  finally Panel.Free; end;
  Settings:=TSetMain.Create(Folder);
  try
    Settings.CX10W.IP:='172.16.10.1';Settings.CX10W.PortaUDP:=9999;
    Settings.SimulationMode:=True;
    Check(Settings.TargetHost(Settings.CX10W.IP,'fallback')='127.0.0.1','simulation must use loopback');
    Settings.SalvaContexto;
  finally Settings.Free; end;
  Settings:=TSetMain.Create(Folder);
  try
    Check(Settings.SimulationMode,'simulation flag must persist');
    Check((Settings.CX10W.IP='172.16.10.1') and (Settings.CX10W.PortaUDP=9999),'real settings must remain saved');
    Settings.SimulationMode:=False;
    Check(Settings.TargetHost(Settings.CX10W.IP,'fallback')='172.16.10.1','real mode must restore real host');
  finally Settings.Free; end;
  WriteLn('PASS per-model axes/inversion/buttons persistence, model isolation, simulator flag and real-address preservation');
end.
