unit opendroneproto;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, lNetComponents, lNet, protocols;

type
  TOpendroneProtocol = class(TBaseProtocol)
  private
    FUdp: TLUDPComponent;
    FSequence: Byte;

    procedure UdpReceive(aSocket: TLSocket);
    procedure UdpError(const msg: string; aSocket: TLSocket);
    procedure SendCrtpPacket(APort, AChannel: Byte; const APayload: array of Byte);
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure Connect(const AHost: string; ATcpPort, AUdpPort: Integer) override;
    procedure Disconnect override;
    procedure SendCommand(AX, AY, AZ, AB1, AB2, AB3, AB4, AB5, AB6: Byte) override;
  end;

implementation

constructor TOpendroneProtocol.Create;
begin
  inherited Create;
  FUdp := TLUDPComponent.Create(nil);
  FUdp.OnReceive := @UdpReceive;
  FUdp.OnError := @UdpError;
  FSequence := 0;
end;

destructor TOpendroneProtocol.Destroy;
begin
  Disconnect;
  FUdp.Free;
  inherited Destroy;
end;

procedure TOpendroneProtocol.Connect(const AHost: string; ATcpPort, AUdpPort: Integer);
begin
  FHost := AHost;
  if AUdpPort <= 0 then
    FUdpPort := 2399
  else
    FUdpPort := AUdpPort;
  
  Disconnect;
  DoStatus('Conectando ao ESP32 OpenDrone (UDP)...');
  try
    FUdp.Connect(FHost, FUdpPort);
    FActive := True;
    DoStatus('OpenDrone conectado na porta ' + IntToStr(FUdpPort));
  except
    on E: Exception do
      DoError('Erro OpenDrone UDP: ' + E.Message);
  end;
end;

procedure TOpendroneProtocol.Disconnect;
begin
  if FUdp.Connected then
    FUdp.Disconnect(True);
  FActive := False;
  DoStatus('OpenDrone desconectado.');
end;

procedure TOpendroneProtocol.SendCrtpPacket(APort, AChannel: Byte; const APayload: array of Byte);
var
  Packet: TBytes;
  Header: Byte;
  I: Integer;
  Cksum: Byte;
begin
  if not FUdp.Connected then
    Exit;

  Header := (APort shl 4) or AChannel;
  SetLength(Packet, 1 + Length(APayload) + 1);
  Packet[0] := Header;
  if Length(APayload) > 0 then
    Move(APayload[0], Packet[1], Length(APayload));
    
  Cksum := Header;
  for I := 0 to High(APayload) do
    Cksum := Cksum + APayload[I];
  Packet[High(Packet)] := Cksum;

  FUdp.Send(Packet[0], Length(Packet));
end;

procedure TOpendroneProtocol.SendCommand(AX, AY, AZ, AB1, AB2, AB3, AB4, AB5, AB6: Byte);
var
  Roll, Pitch, Yaw: Single;
  Thrust: Word;
  Payload: array[0..13] of Byte;
begin
  if not FActive then
    Exit;

  // Roll: AX 0..255 -> -30.0 .. 30.0 degrees
  Roll := (Integer(AX) - 127) * 30.0 / 127.0;
  // Pitch: AY 0..255 -> -30.0 .. 30.0 degrees (inverted)
  Pitch := (Integer(AY) - 127) * -30.0 / 127.0;
  // Yaw: AB1/AB2 -> -120.0 .. 120.0 deg/sec
  Yaw := 0.0;
  if AB1 = 255 then Yaw := -120.0;
  if AB2 = 255 then Yaw := 120.0;
  // Thrust: AZ 0..255 -> 0 .. 60000
  Thrust := Round(Integer(AZ) * 60000.0 / 255.0);

  Move(Roll, Payload[0], 4);
  Move(Pitch, Payload[4], 4);
  Move(Yaw, Payload[8], 4);
  Move(Thrust, Payload[12], 2);

  SendCrtpPacket(3, 0, Payload);
end;

procedure TOpendroneProtocol.UdpReceive(aSocket: TLSocket);
var
  Buf: array[0..1023] of Byte;
  L: Integer;
begin
  repeat
    L := aSocket.Get(Buf[0], SizeOf(Buf));
  until L <= 0;
end;

procedure TOpendroneProtocol.UdpError(const msg: string; aSocket: TLSocket);
begin
  DoError('OpenDrone UDP Erro: ' + msg);
end;

end.
