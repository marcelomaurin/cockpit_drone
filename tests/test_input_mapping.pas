program test_input_mapping;
{$mode objfpc}{$H+}
uses SysUtils, Math, funcs, controler;
procedure Check(Ok: Boolean; const MessageText: string);
begin if not Ok then raise Exception.Create(MessageText); end;
var Control: TDroneControler; V: Byte; Failed: Boolean;
begin
  Check(MAPA(0, 65535, 0, 255, 0)=0, 'minimum');
  Check(MAPA(0, 65535, 0, 255, 65535)=255, 'maximum');
  Check(MAPA(0, 65535, 0, 255, 32767)=127, 'center');
  Check(MAPA(0, 65535, 0, 255, -500)=0, 'below minimum must clamp');
  Check(MAPA(0, 65535, 0, 255, 70000)=255, 'above maximum must clamp');
  Check(MAPA(65535, 0, 0, 255, 65535)=0, 'reversed input');
  Check(MAPA(0, 65535, 255, 0, 0)=255, 'inverted output');
  Failed:=False;
  try V:=MAPA(1,1,0,255,1); except on E:EArgumentException do Failed:=True; end;
  Check(Failed, 'zero input span must reject');
  Failed:=False;
  try V:=MAPA(0,65535,0,255,NaN); except on E:EArgumentException do Failed:=True; end;
  Check(Failed, 'NaN must reject');
  Failed:=False;
  try V:=MAPA(0,65535,0,255,Infinity); except on E:EArgumentException do Failed:=True; end;
  Check(Failed, 'infinity must reject');
  Control:=TDroneControler.Create;
  try
    Control.Atualiza(255,255,255,255,0,0,0,0,0);
    Check((Control.Motor1=0) and (Control.Motor4=0), 'inactive motor display');
    Control.Ativo:=True;
    Control.Atualiza(127,127,0,0,0,0,0,0,0);
    Check((Control.Roll=0) and (Control.Pitch=0) and (Control.Throttle=0), 'neutral');
    Check((Control.Motor1=0) and (Control.Motor4=0), 'neutral motor display');
    Control.Atualiza(127,127,128,0,0,0,0,0,0);
    Check((Control.Motor1=128) and (Control.Motor2=128) and
          (Control.Motor3=128) and (Control.Motor4=128), 'symmetric neutral mix');
    Control.Ativo:=False;
    Control.Atualiza(255,255,255,255,0,0,0,0,0);
    Check((Control.Motor1=0) and (Control.Motor4=0), 'inactive reset');
  finally Control.Free; end;
  WriteLn('PASS: input mapping bounds, invalid inputs and controller neutrality');
end.
