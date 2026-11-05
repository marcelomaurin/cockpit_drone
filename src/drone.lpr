program drone;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, opengpsx, mplayercontrollaz, LazSerialPort, sdposeriallaz, laz_acs,
  main, config, About, Camera, map, joystick, funcs, GPS, objetos, setmain,
  protocols, flightplan, tacticalhud, conexaodrone, ConectionCX10W,
  conectionmavlink, conectiontello, conectionopendrone, conectionfq777,
  conectionardrone, conectionesp32drone, rotamavlink, rotavoo
  { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.

