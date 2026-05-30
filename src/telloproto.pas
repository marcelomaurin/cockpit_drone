unit telloproto;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, lNetComponents, lNet, protocols;

type
  TTelloProtocol = class;

  TKeepAliveThread = class(TThread)
  private
    FProto: TTelloProtocol;
  protected
    procedure Execute; override;
  public
    constructor Create(AProto: TTelloProtocol);
  end;

  TTelloProtocol = class(TBaseProtocol)
  private
    FUdp: TLUDPComponent;
    FLastRcCommand: string;
    FKeepAliveTimer: TThread;

    procedure UdpReceive(aSocket: TLSocket);
    procedure UdpError(const msg: string; aSocket: TLSocket);
    procedure SendRawCommand(const ACmd: string);
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure Connect(const AHost: string; ATcpPort, AUdpPort: Integer) override;
    procedure Disconnect override;
    procedure SendCommand(AX, AY, AZ, AB1, AB2, AB3, AB4, AB5, AB6: Byte) override;
  end;

implementation

constructor TKeepAliveThread.Create(AProto: TTelloProtocol);
begin
  inherited Create(True);
  FProto := AProto;
  FreeOnTerminate := True;
end;

procedure TKeepAliveThread.Execute;
begin
  while not Terminated do
  begin
    if FProto.Active then
      FProto.SendRawCommand('command');
    Sleep(4000);
  end;
end;

constructor TTelloProtocol.Create;
begin
  inherited Create;
  FUdp := TLUDPComponent.Create(nil);
  FUdp.OnReceive := @UdpReceive;
  FUdp.OnError := @UdpError;
  FLastRcCommand := '';
end;

destructor TTelloProtocol.Destroy;
begin
  Disconnect;
  FUdp.Free;
  inherited Destroy;
end;

procedure TTelloProtocol.Connect(const AHost: string; ATcpPort, AUdpPort: Integer);
begin
  FHost := AHost;
  FUdpPort := 8889; // Standard DJI Tello commands port
  Disconnect;

  DoStatus('Conectando ao DJI Tello (UDP)...');
  try
    FUdp.Connect(FHost, FUdpPort);
    FActive := True;
    DoStatus('Conectado ao Tello.');

    SendRawCommand('command');
    Sleep(50);
    SendRawCommand('streamon');

    FKeepAliveTimer := TKeepAliveThread.Create(Self);
    FKeepAliveTimer.Start;
  except
    on E: Exception do
      DoError('Erro Tello UDP: ' + E.Message);
  end;
end;

procedure TTelloProtocol.Disconnect;
begin
  if Assigned(FKeepAliveTimer) then
  begin
    FKeepAliveTimer.Terminate;
    FKeepAliveTimer := nil;
  end;
  if FActive then
    SendRawCommand('streamoff');

  if FUdp.Connected then
    FUdp.Disconnect(True);
  FActive := False;
  DoStatus('Tello desconectado.');
end;

procedure TTelloProtocol.SendRawCommand(const ACmd: string);
var
  AData: TBytes;
begin
  if FUdp.Connected and (ACmd <> '') then
  begin
    AData := BytesOf(ACmd + #10);
    FUdp.Send(AData[0], Length(AData));
  end;
end;

procedure TTelloProtocol.SendCommand(AX, AY, AZ, AB1, AB2, AB3, AB4, AB5, AB6: Byte);
var
  Cmd: string;
  A, B, C, D: Integer;
begin
  // Map 0..255 inputs to Tello rc command (-100..100)
  A := Round((Integer(AX) - 127) * 100 / 127); // roll
  B := Round((Integer(AY) - 127) * -100 / 127); // pitch (inverted)
  C := Round((Integer(AZ) - 127) * 100 / 127); // throttle
  D := 0; // yaw
  if AB1 = 255 then D := -40;
  if AB2 = 255 then D := 40;

  Cmd := Format('rc %d %d %d %d', [A, B, C, D]);
  if Cmd <> FLastRcCommand then
  begin
    SendRawCommand(Cmd);
    FLastRcCommand := Cmd;
  end;
end;

procedure TTelloProtocol.UdpReceive(aSocket: TLSocket);
var
  Buf: array[0..1023] of Byte;
  L: Integer;
begin
  repeat
    L := aSocket.Get(Buf[0], SizeOf(Buf));
  until L <= 0;
end;

procedure TTelloProtocol.UdpError(const msg: string; aSocket: TLSocket);
begin
  DoError('Tello UDP Erro: ' + msg);
end;

end.
