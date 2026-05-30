unit mavlinkproto;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, lNetComponents, lNet, protocols;

type
  TMavlinkProtocol = class;

  THeartbeatThread = class(TThread)
  private
    FProto: TMavlinkProtocol;
  protected
    procedure Execute; override;
  public
    constructor Create(AProto: TMavlinkProtocol);
  end;

  TMavlinkProtocol = class(TBaseProtocol)
  private
    FUdp: TLUDPComponent;
    FHeartbeatTimer: TThread;
    FSystemId: Byte;
    FComponentId: Byte;
    FSequence: Byte;

    procedure UdpReceive(aSocket: TLSocket);
    procedure UdpError(const msg: string; aSocket: TLSocket);
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure Connect(const AHost: string; ATcpPort, AUdpPort: Integer) override;
    procedure Disconnect override;
    procedure SendCommand(AX, AY, AZ, AB1, AB2, AB3, AB4, AB5, AB6: Byte) override;
    procedure SendHeartbeat;
  end;

implementation

constructor THeartbeatThread.Create(AProto: TMavlinkProtocol);
begin
  inherited Create(True);
  FProto := AProto;
  FreeOnTerminate := True;
end;

procedure THeartbeatThread.Execute;
begin
  while not Terminated do
  begin
    if FProto.Active then
      FProto.SendHeartbeat;
    Sleep(1000);
  end;
end;

constructor TMavlinkProtocol.Create;
begin
  inherited Create;
  FUdp := TLUDPComponent.Create(nil);
  FUdp.OnReceive := @UdpReceive;
  FUdp.OnError := @UdpError;

  FSystemId := 255;
  FComponentId := 190;
  FSequence := 0;
end;

destructor TMavlinkProtocol.Destroy;
begin
  Disconnect;
  FUdp.Free;
  inherited Destroy;
end;

procedure TMavlinkProtocol.Connect(const AHost: string; ATcpPort, AUdpPort: Integer);
begin
  FHost := AHost;
  FUdpPort := AUdpPort;
  Disconnect;

  DoStatus('Conectando via MAVLink (UDP)...');
  try
    FUdp.Connect(FHost, FUdpPort);
    FActive := True;
    DoStatus('MAVLink conectado.');
    FHeartbeatTimer := THeartbeatThread.Create(Self);
    FHeartbeatTimer.Start;
  except
    on E: Exception do
      DoError('Erro MAVLink UDP: ' + E.Message);
  end;
end;

procedure TMavlinkProtocol.Disconnect;
begin
  if Assigned(FHeartbeatTimer) then
  begin
    FHeartbeatTimer.Terminate;
    FHeartbeatTimer := nil;
  end;
  if FUdp.Connected then
    FUdp.Disconnect(True);
  FActive := False;
  DoStatus('MAVLink desconectado.');
end;

procedure TMavlinkProtocol.SendHeartbeat;
var
  Packet: array[0..16] of Byte;
  I: Integer;
  Accumulator: Word;
begin
  Packet[0] := $FE; // MAVLink v1 STX
  Packet[1] := 9;   // Payload length
  Packet[2] := FSequence;
  Packet[3] := FSystemId;
  Packet[4] := FComponentId;
  Packet[5] := 0;   // Message ID = 0 (HEARTBEAT)

  // Payload (9 bytes)
  Packet[6] := 0; Packet[7] := 0; Packet[8] := 0; Packet[9] := 0;
  Packet[10] := 2;  // type = MAV_TYPE_QUADROTOR
  Packet[11] := 3;  // autopilot = MAV_AUTOPILOT_ARDUPILOTMEGA
  Packet[12] := 81; // base_mode = MAV_MODE_FLAG_SAFETY_ARMED
  Packet[13] := 4;  // system_status = MAV_STATE_ACTIVE
  Packet[14] := 3;  // mavlink_version

  // Checksum CRC-16 (Mavlink CRC)
  Accumulator := $FFFF;
  for I := 1 to 14 do
    Accumulator := Accumulator xor Packet[I]; // simplified CRC for simulation

  Packet[15] := Accumulator and $FF;
  Packet[16] := (Accumulator >> 8) and $FF;

  if FUdp.Connected then
    FUdp.Send(Packet[0], SizeOf(Packet));

  Inc(FSequence);
end;

procedure TMavlinkProtocol.SendCommand(AX, AY, AZ, AB1, AB2, AB3, AB4, AB5, AB6: Byte);
var
  Packet: array[0..21] of Byte;
  I: Integer;
  Accumulator: Word;
  RcRoll, RcPitch, RcThrottle, RcYaw: Word;
begin
  // MANUAL_CONTROL (#69) simulation
  Packet[0] := $FE;
  Packet[1] := 14; // Payload size
  Packet[2] := FSequence;
  Packet[3] := FSystemId;
  Packet[4] := FComponentId;
  Packet[5] := 69; // MANUAL_CONTROL Msg ID

  // Map 0..255 axes to -1000..1000 range for MAVLink
  RcRoll := Round((Integer(AX) - 127) * 1000 / 127);
  RcPitch := Round((Integer(AY) - 127) * -1000 / 127);
  RcThrottle := Round(Integer(AZ) * 1000 / 255);
  RcYaw := 0;
  if AB1 = 255 then RcYaw := 65136; // -500
  if AB2 = 255 then RcYaw := 500;

  Packet[6] := RcRoll and $FF; Packet[7] := (RcRoll >> 8) and $FF;
  Packet[8] := RcPitch and $FF; Packet[9] := (RcPitch >> 8) and $FF;
  Packet[10] := RcThrottle and $FF; Packet[11] := (RcThrottle >> 8) and $FF;
  Packet[12] := RcYaw and $FF; Packet[13] := (RcYaw >> 8) and $FF;
  Packet[14] := 0; Packet[15] := 0; // buttons mask
  Packet[16] := 0; Packet[17] := 0; Packet[18] := 0; Packet[19] := 0;

  Accumulator := $FFFF;
  for I := 1 to 19 do
    Accumulator := Accumulator xor Packet[I];

  Packet[20] := Accumulator and $FF;
  Packet[21] := (Accumulator >> 8) and $FF;

  if FUdp.Connected then
    FUdp.Send(Packet[0], SizeOf(Packet));

  Inc(FSequence);
end;

procedure TMavlinkProtocol.UdpReceive(aSocket: TLSocket);
var
  Buf: array[0..1023] of Byte;
  L: Integer;
begin
  repeat
    L := aSocket.Get(Buf[0], SizeOf(Buf));
  until L <= 0;
end;

procedure TMavlinkProtocol.UdpError(const msg: string; aSocket: TLSocket);
begin
  DoError('MAVLink UDP Erro: ' + msg);
end;

end.
