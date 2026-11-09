program test_xbox_cheerson;
{$mode objfpc}{$H+}
uses Interfaces, Classes, SysUtils, Math, aijoystick, joystick, controler,
  cockpit_joystick_mapping, aidronecx10w, aidronefq777,
  simtipos, simgeo, simfisica, simemulador, simprotocolos, simrede;
type
  TFakeXbox=class(TAIJoystick)
  public Sample:TAIJoystickState; Present:Boolean;
  protected
    procedure ScanDevices; override;
    function ReadDevice(const ID:string; out S:TAIJoystickState):Boolean; override;
  end;
  TPacketCX=class(TAIDroneCX10W)
    function Packet:TFQ777ControlPacket;
  end;
  TCheersonEmulator=class(TEmuladorFQ777)
    procedure Feed(const P:TFQ777ControlPacket);
  end;
procedure TFakeXbox.ScanDevices;
begin SetLength(FDevices,0); end;
function TFakeXbox.ReadDevice(const ID:string; out S:TAIJoystickState):Boolean;
begin S:=Sample; S.Connected:=Present; S.DeviceID:=ID;
  Result:=Present and (ID='xinput:0'); end;
function TPacketCX.Packet:TFQ777ControlPacket;
var TimedOut:Boolean;
begin Result:=CurrentPacket(TimedOut); end;
procedure TCheersonEmulator.Feed(const P:TFQ777ControlPacket);
var B:TBytes; Peer:TEndereco;
begin SetLength(B,SizeOf(P)); Move(P[0],B[0],SizeOf(P));
  Peer.IP:='127.0.0.1'; Peer.Porta:=12345; Processa(0,B,Peer); end;
procedure Check(Ok:Boolean; const Msg:string);
begin if not Ok then raise Exception.Create(Msg); end;
var Fake:TFakeXbox; Joy:TJoystickController; Control:TDroneControler;
  CX:TPacketCX; Emu:TCheersonEmulator; Physics:TSimFisica;
  Models:TListaModelos; Origin:TPontoGeo; Faults:TFalhas;
  P:TFQ777ControlPacket; Cmd:TComandoVoo; S:TFlightJoystickSettings;
  A:TFlightAxes; X,Y,Z:Byte; Yaw:Double; HasYaw,Failed:Boolean; I:Integer;
procedure SendSample;
var J:TJoystickState;
begin
  Check(Joy.UpdateState,'Xbox sample missing'); J:=Joy.State;
  X:=J.X;Y:=J.Y;
  if Abs(Integer(X)-127)<=12 then X:=127;
  if Abs(Integer(Y)-127)<=12 then Y:=127;
  Control.Atualiza(Byte(EnsureRange(254-Integer(X),0,255)),
    Byte(EnsureRange(254-Integer(Y),0,255)),J.Z,
    J.Buttons.B1,J.Buttons.B2,J.Buttons.B3,J.Buttons.B4,J.Buttons.B5,J.Buttons.B6,J.Yaw);
  CX.SetSticks(Control.Rolagem,Control.Arfagem,Control.Guinada,Control.Acelerador);
  P:=CX.Packet;
end;
begin
  Fake:=TFakeXbox.Create(nil); Fake.Present:=True;
  Joy:=TJoystickController.Create(nil,Fake); Control:=TDroneControler.Create;
  CX:=TPacketCX.Create(nil); Models:=ModelosPadrao;
  Origin:=Default(TPontoGeo); Faults:=Default(TFalhas);
  Physics:=TSimFisica.Create(Models[IndiceModelo(Models,'cx10w')],Origin);
  Emu:=TCheersonEmulator.Create(Models[IndiceModelo(Models,'cx10w')],Origin,nil,nil);
  try
    Control.Ativo:=True;
    CX.Host:='127.0.0.1'; CX.TcpPort:=1; CX.VideoEnabled:=False;
    CX.ConnectTimeoutMs:=100; CX.Connect;
    // Reproduce the old combined Z-axis at rest: half throttle never unlocks.
    CX.SetSticks(0,0,0,127/255); P:=CX.Packet;
    Check(P[3]=0,'Cheerson must reject a first nonzero throttle');
    Check(Joy.ConfigureDevice(0),'selected controller');
    Check(Joy.Activate,'native Xbox must work without a generic joystick');
    SendSample; Check(P[3]=0,'centered Mode 2 sticks must not unlock initial throttle');
    // Default Mode 2: lower left stick to minimum before increasing thrust.
    Fake.Sample.Axes[1]:=-1; SendSample;
    Check((Joy.State.Z=0) and (P[3]=0),'Mode 2 minimum must be zero');
    Fake.Sample.Axes[1]:=0; SendSample;
    Check((P[3]>=127) and (P[3]<=128),'Mode 2 center should be half thrust');
    Fake.Sample.Axes[1]:=0.7;
    for I:=1 to 100 do begin SendSample; Emu.Feed(P);
      Cmd:=Emu.MontaComando(Physics.Estado); Physics.Passo(0.02,Cmd,Faults); end;
    Check(Physics.Estado.Z>0.5,'Xbox -> controller -> Cheerson packet -> simulator must climb');
    WriteLn('PASS Mode 2 Cheerson climb: ',Physics.Estado.Z:0:2,' m');
    Cmd:=ComandoNeutro;
    for I:=1 to 500 do begin Physics.Passo(0.02,Cmd,Faults);if Physics.Estado.Caiu then Break;end;
    Check(Physics.Estado.Caiu,'must reproduce Cheerson crash');
    Emu.MontaComando(Physics.Estado);Emu.ReiniciaEstado;Physics.RecuperaQueda;
    SendSample;Emu.Feed(P);Cmd:=Emu.MontaComando(Physics.Estado);
    Check(not Cmd.Motores,'held high throttle after crash must remain blocked');
    Fake.Sample.Axes[1]:=-1;SendSample;Emu.Feed(P);
    Fake.Sample.Axes[1]:=0.7;
    for I:=1 to 100 do begin SendSample;Emu.Feed(P);Cmd:=Emu.MontaComando(Physics.Estado);Physics.Passo(0.02,Cmd,Faults);end;
    Check(Physics.Estado.Z>0.5,'Cheerson must fly again after recovery and low throttle');
    WriteLn('PASS Cheerson crash, recovery, minimum-throttle gate and second takeoff');

    Fake.Sample.Axes[0]:=1; SendSample;
    Check(Control.Guinada>0.9,'left X must command right yaw');
    Fake.Sample.Axes[0]:=0; Fake.Sample.Axes[2]:=1; SendSample;
    Check(Control.Rolagem>0.9,'right X must roll right');
    Fake.Sample.Axes[2]:=0; Fake.Sample.Axes[3]:=1; SendSample;
    Check(Control.Arfagem>0.9,'right Y up must command forward');
    S:=DefaultFlightJoystickSettings; S.Profile:=jpXboxRT; Joy.Settings:=S;
    Fake.Sample:=Default(TAIJoystickState); Fake.Sample.Axes[4]:=1; SendSample;
    Check(Joy.State.Z=0,'LT must not raise RT throttle');
    Fake.Sample.Axes[5]:=1; SendSample; Check(P[3]=255,'RT must reach full thrust');
    S:=EffectiveFlightJoystickSettings(S,True); S.Profile:=jpCustom;
    S.Axis[3]:=4; S.Invert[3]:=True; S.Button[3]:=4; Joy.Settings:=S;
    Fake.Sample.Axes[4]:=1; Fake.Sample.Controls[4]:=True; SendSample;
    Check(Joy.State.Z=0,'custom reversed throttle');
    Check(Joy.State.Buttons.B3=255,'custom action button');
    Fake.Present:=False;
    Check(not Joy.UpdateState,'disconnect must fail polling');
    Check((Joy.State.Z=0) and not Joy.Available,'disconnect must clear throttle');
    Check(not Joy.UpdateState,'disconnect must not fall back to another device');
    Fake.Present:=True; Fake.Sample.Axes[4]:=0;
    Check(not Joy.UpdateState,'reconnection requires an explicit activation');
    Check(Joy.Activate,'explicit restart with a valid sample');
    Fake.Sample.Axes[4]:=NaN;
    Check(not Joy.UpdateState,'invalid sample must be rejected');
    Check(Joy.State.Z=0,'invalid sample throttle cleared');
    Check(not Joy.ConfigureDevice(9),'invalid controller slot');
    Check(not Joy.Active,'invalid slot must stop input');
    A:=Default(TFlightAxes); S:=DefaultFlightJoystickSettings;
    S.Profile:=jpCustom; S.Axis[0]:=99; Failed:=False;
    try MapFlightJoystick(A,True,S,X,Y,Z,Yaw,HasYaw);
    except on E:EArgumentException do Failed:=True; end;
    Check(Failed,'invalid custom axis must fail closed');
    WriteLn('PASS directions, analog yaw, independent RT/LT, remap, buttons, disconnect and invalid input');
  finally Emu.Free; Physics.Free; CX.Free; Control.Free; Joy.Free; Fake.Free; end;
end.
