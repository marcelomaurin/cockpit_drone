unit cx10w;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, lNetComponents, lNet, Graphics, FPImage, FPReadJPEG, IntfGraphics, protocols;

type
  TCheersonCX10WProtocol = class(TBaseProtocol)
  private
    FTcp: TLTCPComponent;
    FUdp: TLUDPComponent;
    FVideoBuffer: TMemoryStream;
    FUltimaImagemDataHora: TDateTime;
    FTotalPacotesTCP: Int64;
    FTotalPacotesUDP: Int64;

    procedure TcpConnect(aSocket: TLSocket);
    procedure TcpReceive(aSocket: TLSocket);
    procedure TcpError(const msg: string; aSocket: TLSocket);
    procedure TcpDisconnect(aSocket: TLSocket);
    procedure UdpReceive(aSocket: TLSocket);
    procedure UdpError(const msg: string; aSocket: TLSocket);

    procedure EnviaTCP(const ABytes: array of Byte; const ADescricao: string);
    procedure EnviaUDP(const ABytes: array of Byte; const ADescricao: string);
    procedure Handshake;
    procedure ProcessaBytesTCP(const AData: TBytes);
    function ExtraiJPEGDoBuffer: Boolean;
    procedure CarregaJpegNoBitmap(const AJpegData: TBytes; ADestino: TBitmap);
    function BuildChecksum(const AData: array of Byte): Byte;
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure Connect(const AHost: string; ATcpPort, AUdpPort: Integer) override;
    procedure Disconnect override;
    procedure SendCommand(AX, AY, AZ, AB1, AB2, AB3, AB4, AB5, AB6: Byte) override;
  end;

implementation

const
  MAGIC_BYTES_CTRL: array[0..105] of Byte = (
    $49, $54, $64, $00, $00, $00, $5D, $00, $00, $00, $81, $85, $FF, $BD, $2A, $29, $5C, $AD, $67, $82, $5C, $57, $BE, $41, $03, $F8, $CA, $E2, $64, $30, $A3, $C1,
    $5E, $40, $DE, $30, $F6, $D6, $95, $E0, $30, $B7, $C2, $E5, $B7, $D6, $5D, $A8, $65, $9E, $B2, $E2, $D5, $E0, $C2, $CB, $6C, $59, $CD, $CB, $66, $1E, $7E, $1E,
    $B0, $CE, $8E, $E8, $DF, $32, $45, $6F, $A8, $42, $EE, $2E, $09, $A3, $9B, $DD, $05, $C8, $30, $A2, $81, $C8, $2A, $9E, $DA, $7F, $D5, $86, $0E, $AF, $AB, $FE,
    $FA, $3C, $7E, $54, $4F, $F2, $8A, $D2, $93, $CD
  );

  MAGIC_BYTES_VIDEO_1A: array[0..105] of Byte = (
    $49, $54, $64, $00, $00, $00, $52, $00, $00, $00, $0F, $32, $81, $95, $45, $2E, $F5, $E1, $A9, $28, $10, $86, $63, $17, $36, $C3, $CA, $E2, $64, $30, $A3, $C1,
    $5E, $40, $DE, $30, $F6, $D6, $95, $E0, $30, $B7, $C2, $E5, $B7, $D6, $5D, $A8, $65, $9E, $B2, $E2, $D5, $E0, $C2, $CB, $6C, $59, $CD, $CB, $66, $1E, $7E, $1E,
    $B0, $CE, $8E, $E8, $DF, $32, $45, $6F, $A8, $42, $B7, $33, $0F, $B7, $C9, $57, $82, $FC, $3D, $67, $E7, $C3, $A6, $67, $28, $DA, $D8, $B5, $98, $48, $C7, $67,
    $0C, $94, $B2, $9B, $54, $D2, $37, $9E, $2E, $7A
  );

  MAGIC_BYTES_VIDEO_1B: array[0..105] of Byte = (
    $49, $54, $64, $00, $00, $00, $52, $00, $00, $00, $54, $B2, $D1, $F6, $63, $48, $C7, $CD, $B6, $E0, $5B, $0D, $1D, $BC, $A8, $1B, $CA, $E2, $64, $30, $A3, $C1,
    $5E, $40, $DE, $30, $F6, $D6, $95, $E0, $30, $B7, $C2, $E5, $B7, $D6, $5D, $A8, $65, $9E, $B2, $E2, $D5, $E0, $C2, $CB, $6C, $59, $CD, $CB, $66, $1E, $7E, $1E,
    $B0, $CE, $8E, $E8, $DF, $32, $45, $6F, $A8, $42, $B7, $33, $0F, $B7, $C9, $57, $82, $FC, $3D, $67, $E7, $C3, $A6, $67, $28, $DA, $D8, $B5, $98, $48, $C7, $67,
    $0C, $94, $B2, $9B, $54, $D2, $37, $9E, $2E, $7A
  );

  MAGIC_BYTES_VIDEO_2: array[0..105] of Byte = (
    $49, $54, $64, $00, $00, $00, $58, $00, $00, $00, $80, $86, $38, $C3, $8D, $13, $50, $FD, $67, $41, $C2, $EE, $36, $89, $A0, $54, $CA, $E2, $64, $30, $A3, $C1,
    $5E, $40, $DE, $30, $F6, $D6, $95, $E0, $30, $B7, $C2, $E5, $B7, $D6, $5D, $A8, $65, $9E, $B2, $E2, $D5, $E0, $C2, $CB, $6C, $59, $CD, $CB, $66, $1E, $7E, $1E,
    $B0, $CE, $8E, $E8, $DF, $32, $45, $6F, $A8, $42, $EB, $20, $BE, $38, $3A, $AB, $05, $A8, $C2, $A7, $1F, $2C, $90, $6D, $93, $F7, $2A, $85, $E7, $35, $6E, $FF,
    $E1, $B8, $F5, $AF, $09, $7F, $91, $47, $F8, $7E
  );

constructor TCheersonCX10WProtocol.Create;
begin
  inherited Create;
  FTcp := TLTCPComponent.Create(nil);
  FTcp.OnConnect := @TcpConnect;
  FTcp.OnReceive := @TcpReceive;
  FTcp.OnError := @TcpError;
  FTcp.OnDisconnect := @TcpDisconnect;

  FUdp := TLUDPComponent.Create(nil);
  FUdp.OnReceive := @UdpReceive;
  FUdp.OnError := @UdpError;

  FVideoBuffer := TMemoryStream.Create;
  FTotalPacotesTCP := 0;
  FTotalPacotesUDP := 0;
end;

destructor TCheersonCX10WProtocol.Destroy;
begin
  Disconnect;
  FTcp.Free;
  FUdp.Free;
  FVideoBuffer.Free;
  inherited Destroy;
end;

procedure TCheersonCX10WProtocol.Connect(const AHost: string; ATcpPort, AUdpPort: Integer);
begin
  FHost := AHost;
  FTcpPort := ATcpPort;
  FUdpPort := AUdpPort;
  Disconnect;

  DoStatus('Conectando via TCP/UDP...');
  try
    FTcp.Connect(FHost, FTcpPort);
    FUdp.Connect(FHost, FUdpPort);
  except
    on E: Exception do
      DoError('Erro na conexão: ' + E.Message);
  end;
end;

procedure TCheersonCX10WProtocol.Disconnect;
begin
  if FTcp.Connected then
    FTcp.Disconnect(True);
  if FUdp.Connected then
    FUdp.Disconnect(True);

  FActive := False;
  FVideoBuffer.Clear;
  DoStatus('Desconectado.');
end;

procedure TCheersonCX10WProtocol.EnviaTCP(const ABytes: array of Byte; const ADescricao: string);
begin
  if FTcp.Connected and (Length(ABytes) > 0) then
  begin
    FTcp.Send(ABytes[0], Length(ABytes));
    DoStatus(ADescricao + ' transmitido via TCP.');
  end;
end;

procedure TCheersonCX10WProtocol.EnviaUDP(const ABytes: array of Byte; const ADescricao: string);
begin
  if FUdp.Connected and (Length(ABytes) > 0) then
    FUdp.Send(ABytes[0], Length(ABytes));
end;

procedure TCheersonCX10WProtocol.Handshake;
begin
  EnviaTCP(MAGIC_BYTES_CTRL, 'Handshake CTRL');
  Sleep(40);
  EnviaTCP(MAGIC_BYTES_VIDEO_1A, 'Handshake VIDEO 1A');
  Sleep(40);
  EnviaTCP(MAGIC_BYTES_VIDEO_1B, 'Handshake VIDEO 1B');
  Sleep(40);
  EnviaTCP(MAGIC_BYTES_VIDEO_2, 'Handshake VIDEO 2');
  DoStatus('Handshake de vídeo concluído.');
end;

function TCheersonCX10WProtocol.BuildChecksum(const AData: array of Byte): Byte;
var
  I: Integer;
begin
  Result := 0;
  if High(AData) < 5 then
    Exit;
  for I := 1 to 5 do
    Result := Result xor AData[I];
end;

procedure TCheersonCX10WProtocol.SendCommand(AX, AY, AZ, AB1, AB2, AB3, AB4, AB5, AB6: Byte);
var
  Packet: array[0..7] of Byte;
  Flags: Byte;
  Yaw: Byte;
begin
  Packet[0] := $CC;
  Packet[1] := AZ; // throttle

  Yaw := 127;
  if (AB1 = 255) and (AB2 = 0) then
    Yaw := 0
  else if (AB2 = 255) and (AB1 = 0) then
    Yaw := 255;

  Packet[2] := Yaw;
  Packet[3] := AY; // pitch
  Packet[4] := AX; // roll

  Flags := 0;
  if AB3 = 255 then Flags := Flags or $01;
  if AB4 = 255 then Flags := Flags or $02;
  if AB5 = 255 then Flags := Flags or $04;
  if AB6 = 255 then Flags := Flags or $08;

  Packet[5] := Flags;
  Packet[6] := BuildChecksum(Packet);
  Packet[7] := $33;

  EnviaUDP(Packet, 'Comando');
end;

procedure TCheersonCX10WProtocol.TcpConnect(aSocket: TLSocket);
begin
  FActive := True;
  DoStatus('Conectado via TCP.');
  Handshake;
end;

procedure TCheersonCX10WProtocol.TcpReceive(aSocket: TLSocket);
var
  Buf: array[0..8191] of Byte;
  L: Integer;
  Data: TBytes;
begin
  repeat
    L := aSocket.Get(Buf[0], SizeOf(Buf));
    if L > 0 then
    begin
      SetLength(Data, L);
      Move(Buf[0], Data[0], L);
      Inc(FTotalPacotesTCP);
      ProcessaBytesTCP(Data);
    end;
  until L <= 0;
end;

procedure TCheersonCX10WProtocol.TcpError(const msg: string; aSocket: TLSocket);
begin
  DoError('Erro TCP: ' + msg);
end;

procedure TCheersonCX10WProtocol.TcpDisconnect(aSocket: TLSocket);
begin
  FActive := False;
  DoStatus('Desconectado via TCP.');
end;

procedure TCheersonCX10WProtocol.UdpReceive(aSocket: TLSocket);
var
  Buf: array[0..2047] of Byte;
  L: Integer;
begin
  repeat
    L := aSocket.Get(Buf[0], SizeOf(Buf));
    if L > 0 then
      Inc(FTotalPacotesUDP);
  until L <= 0;
end;

procedure TCheersonCX10WProtocol.UdpError(const msg: string; aSocket: TLSocket);
begin
  DoError('Erro UDP: ' + msg);
end;

procedure TCheersonCX10WProtocol.ProcessaBytesTCP(const AData: TBytes);
begin
  if (Length(AData) = 0) or (not Assigned(FVideoBuffer)) then
    Exit;

  FVideoBuffer.Position := FVideoBuffer.Size;
  FVideoBuffer.WriteBuffer(AData[0], Length(AData));
  ExtraiJPEGDoBuffer;
end;

function TCheersonCX10WProtocol.ExtraiJPEGDoBuffer: Boolean;
var
  Buf: TBytes;
  I, J, Tamanho: Integer;
  InicioJpeg, FimJpeg: Integer;
  Img: TBytes;
  Restante: TBytes;
begin
  Result := False;

  if (not Assigned(FVideoBuffer)) or (FVideoBuffer.Size < 4) then
    Exit;

  SetLength(Buf, FVideoBuffer.Size);
  FVideoBuffer.Position := 0;
  if Length(Buf) > 0 then
    FVideoBuffer.ReadBuffer(Buf[0], Length(Buf));

  InicioJpeg := -1;
  FimJpeg := -1;

  for I := 0 to High(Buf) - 1 do
  begin
    if (Buf[I] = $FF) and (Buf[I + 1] = $D8) then
    begin
      InicioJpeg := I;
      Break;
    end;
  end;

  if InicioJpeg < 0 then
  begin
    FVideoBuffer.Clear;
    Exit;
  end;

  for J := InicioJpeg + 2 to High(Buf) - 1 do
  begin
    if (Buf[J] = $FF) and (Buf[J + 1] = $D9) then
    begin
      FimJpeg := J + 1;
      Break;
    end;
  end;

  if FimJpeg < 0 then
  begin
    FVideoBuffer.Clear;
    FVideoBuffer.WriteBuffer(Buf[InicioJpeg], Length(Buf) - InicioJpeg);
    Exit;
  end;

  Tamanho := FimJpeg - InicioJpeg + 1;
  SetLength(Img, Tamanho);
  Move(Buf[InicioJpeg], Img[0], Tamanho);

  try
    CarregaJpegNoBitmap(Img, FBitmap);
    DoVideoFrame(FBitmap);
  except
  end;

  if FimJpeg < High(Buf) then
  begin
    SetLength(Restante, High(Buf) - FimJpeg);
    Move(Buf[FimJpeg + 1], Restante[0], Length(Restante));
    FVideoBuffer.Clear;
    if Length(Restante) > 0 then
      FVideoBuffer.WriteBuffer(Restante[0], Length(Restante));
  end
  else
    FVideoBuffer.Clear;

  Result := True;
end;

procedure TCheersonCX10WProtocol.CarregaJpegNoBitmap(const AJpegData: TBytes; ADestino: TBitmap);
var
  MS: TMemoryStream;
  Img: TFPMemoryImage;
  Reader: TFPReaderJPEG;
  IntfImg: TLazIntfImage;
begin
  if (Length(AJpegData) = 0) or (not Assigned(ADestino)) then
    Exit;

  MS := TMemoryStream.Create;
  Img := TFPMemoryImage.Create(0, 0);
  Reader := TFPReaderJPEG.Create;
  IntfImg := TLazIntfImage.Create(0, 0);
  try
    MS.WriteBuffer(AJpegData[0], Length(AJpegData));
    MS.Position := 0;

    Img.LoadFromStream(MS, Reader);
    IntfImg.Assign(Img);
    ADestino.LoadFromIntfImage(IntfImg);
    FUltimaImagemDataHora := Now;
  finally
    IntfImg.Free;
    Reader.Free;
    Img.Free;
    MS.Free;
  end;
end;

end.
