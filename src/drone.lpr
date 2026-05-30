program drone;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, opengpsx, mplayercontrollaz, LazSerialPort, sdposeriallaz, laz_acs,
  lnetvisual, main, config, cd10w, About, Camera, map, joystick, ConectionCX10W,
  funcs, GPS, objetos, setmain, protocols, flightplan, tacticalhud,
  cx10w, mavlinkproto, telloproto, opendroneproto,
  conectionmavlink, conectiontello, conectionopendrone
  { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.

