unit cx10w;

{ Protocolo Wi-Fi do Cheerson CX-10W
  ----------------------------------
  Rede do drone (ponto de acesso do próprio drone, "Cheerson-CX-10W-xxxx"):
    IP 172.16.10.1, TCP 8888 (inicialização e vídeo), UDP 8895 (comando).

  Sequência de conexão:
    1. TCP de controle  -> pacote mágico CTRL (106 bytes); fica aberto.
    2. TCP de vídeo 1   -> pacotes mágicos VIDEO 1A e 1B; fica aberto e é
                           apenas esvaziado.
    3. TCP de vídeo 2   -> pacote mágico VIDEO 2; por esta conexão o drone
                           envia o vídeo em H.264 bruto (códigos de início
                           00 00 00 01), entremeado com respostas de 106 bytes
                           iniciadas por 'ITd', que são descartadas.
    4. UDP, a cada 50 ms, o pacote de comando de 8 bytes:
         [0] $CC  [1] rolagem  [2] arfagem  [3] aceleração  [4] guinada
         [5] sinalizadores  [6] XOR dos bytes 1..5  [7] $33
       Rolagem/arfagem/guinada: 0..255, centro 127 (0 = esquerda/trás).
       Aceleração: 0..255, 0 = motores parados.

  O vídeo NÃO é JPEG: os bytes H.264 saem pelo evento OnVideoData, para serem
  entregues a um decodificador (TAIH264Decoder).

  Segurança:
    - a aceleração só é liberada depois que o comando chega ao mínimo pela
      primeira vez após a conexão (evita disparar os motores ao ligar);
    - a perda do vídeo nunca derruba o canal de comando;
    - ao desconectar, envia aceleração zero com os eixos centralizados. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, lNetComponents, lNet, protocols;

const
  CX10W_DEFAULT_HOST = '172.16.10.1';
  CX10W_DEFAULT_TCP_PORT = 8888;
  CX10W_DEFAULT_UDP_PORT = 8895;
  CX10W_AXIS_CENTER = 127;
  CX10W_PACKET_SIZE = 8;
  { Aceleração máxima aceita para liberar o acelerador após conectar. }
  CX10W_THROTTLE_ARM_LIMIT = 16;

type
  TCX10WPacket = array[0..CX10W_PACKET_SIZE - 1] of Byte;

  TCX10WVideoDataEvent = procedure(Sender: TObject; AData: PByte;
    ACount: Integer) of object;

  { TCheersonCX10WProtocol }

  TCheersonCX10WProtocol = class(TBaseProtocol)
  private
    FCtrl: TLTCPComponent;
    FVideo1: TLTCPComponent;
    FVideo2: TLTCPComponent;
    FUdp: TLUDPComponent;

    FVideoEnabled: Boolean;
    FVideoConnected: Boolean;
    FVideoSynced: Boolean;
    FCarry: array[0..2] of Byte;
    FCarryLen: Integer;

    FThrottleArmed: Boolean;
    FArmWarned: Boolean;
    FDisconnecting: Boolean;

    FLastPacket: TCX10WPacket;
    FTotalPacotesTCP: Int64;
    FTotalPacotesUDP: Int64;
    FTotalComandos: Int64;
    FTotalBytesVideo: Int64;

    FOnVideoData: TCX10WVideoDataEvent;

    procedure CtrlConnect(aSocket: TLSocket);
    procedure CtrlReceive(aSocket: TLSocket);
    procedure CtrlError(const msg: string; aSocket: TLSocket);
    procedure CtrlDisconnect(aSocket: TLSocket);

    procedure Video1Connect(aSocket: TLSocket);
    procedure Video2Connect(aSocket: TLSocket);
    procedure Video1Receive(aSocket: TLSocket);
    procedure Video2Receive(aSocket: TLSocket);
    procedure VideoError(const msg: string; aSocket: TLSocket);
    procedure VideoDisconnect(aSocket: TLSocket);

    procedure UdpReceive(aSocket: TLSocket);
    procedure UdpError(const msg: string; aSocket: TLSocket);

    function SendAll(ASocket: TLTCPComponent; const ABytes: array of Byte): Boolean;
    procedure SendPacket(const APacket: TCX10WPacket);
    procedure StartVideo;
    procedure StopVideo;
    procedure ProcessVideoChunk(AData: PByte; ACount: Integer);
    function DrainSocket(aSocket: TLSocket; ADeliver: Boolean): Boolean;
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure Connect(const AHost: string; ATcpPort, AUdpPort: Integer); override;
    procedure Disconnect; override;
    { AX = rolagem, AY = arfagem, AZ = aceleração (valores do frmMain);
      AB1/AB2 = guinada, AB3..AB6 = sinalizadores $01, $02, $04, $08. }
    procedure SendCommand(AX, AY, AZ, AB1, AB2, AB3, AB4, AB5, AB6: Byte); override;
    { Envia aceleração zero com os eixos centralizados (corte dos motores). }
    procedure SendNeutral;

    class function BuildPacket(ARoll, APitch, AThrottle, AYaw,
      AFlags: Byte): TCX10WPacket; static;
    class function IsDroneReply(AData: PByte; ACount: Integer): Boolean; static;
    class function PacketToHex(const APacket: TCX10WPacket): string; static;

    property VideoEnabled: Boolean read FVideoEnabled write FVideoEnabled;
    property VideoConnected: Boolean read FVideoConnected;
    property ThrottleArmed: Boolean read FThrottleArmed;
    property LastPacket: TCX10WPacket read FLastPacket;
    property TotalPacotesTCP: Int64 read FTotalPacotesTCP;
    property TotalPacotesUDP: Int64 read FTotalPacotesUDP;
    property TotalComandos: Int64 read FTotalComandos;
    property TotalBytesVideo: Int64 read FTotalBytesVideo;
    property OnVideoData: TCX10WVideoDataEvent read FOnVideoData write FOnVideoData;
  end;

implementation

const
  REPLY_SIZE = 106;

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

{ TCheersonCX10WProtocol }

constructor TCheersonCX10WProtocol.Create;
begin
  inherited Create;

  FCtrl := TLTCPComponent.Create(nil);
  FCtrl.OnConnect := @CtrlConnect;
  FCtrl.OnReceive := @CtrlReceive;
  FCtrl.OnError := @CtrlError;
  FCtrl.OnDisconnect := @CtrlDisconnect;

  FVideo1 := TLTCPComponent.Create(nil);
  FVideo1.OnConnect := @Video1Connect;
  FVideo1.OnReceive := @Video1Receive;
  FVideo1.OnError := @VideoError;
  FVideo1.OnDisconnect := @VideoDisconnect;

  FVideo2 := TLTCPComponent.Create(nil);
  FVideo2.OnConnect := @Video2Connect;
  FVideo2.OnReceive := @Video2Receive;
  FVideo2.OnError := @VideoError;
  FVideo2.OnDisconnect := @VideoDisconnect;

  FUdp := TLUDPComponent.Create(nil);
  FUdp.OnReceive := @UdpReceive;
  FUdp.OnError := @UdpError;

  FHost := CX10W_DEFAULT_HOST;
  FTcpPort := CX10W_DEFAULT_TCP_PORT;
  FUdpPort := CX10W_DEFAULT_UDP_PORT;
  FVideoEnabled := True;
  FLastPacket := BuildPacket(CX10W_AXIS_CENTER, CX10W_AXIS_CENTER, 0,
    CX10W_AXIS_CENTER, 0);
end;

destructor TCheersonCX10WProtocol.Destroy;
begin
  // Sem eventos para o formulário durante a destruição.
  FOnStatus := nil;
  FOnError := nil;
  FOnVideoFrame := nil;
  FOnVideoData := nil;

  Disconnect;
  FVideo2.Free;
  FVideo1.Free;
  FCtrl.Free;
  FUdp.Free;
  inherited Destroy;
end;

class function TCheersonCX10WProtocol.BuildPacket(ARoll, APitch, AThrottle,
  AYaw, AFlags: Byte): TCX10WPacket;
begin
  Result[0] := $CC;
  Result[1] := ARoll;
  Result[2] := APitch;
  Result[3] := AThrottle;
  Result[4] := AYaw;
  Result[5] := AFlags;
  Result[6] := ARoll xor APitch xor AThrottle xor AYaw xor AFlags;
  Result[7] := $33;
end;

class function TCheersonCX10WProtocol.IsDroneReply(AData: PByte;
  ACount: Integer): Boolean;
begin
  Result := (ACount = REPLY_SIZE) and (AData[0] = $49) and (AData[1] = $54) and
    (AData[2] = $64);
end;

class function TCheersonCX10WProtocol.PacketToHex(const APacket: TCX10WPacket): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(APacket) do
  begin
    if I > 0 then
      Result := Result + ' ';
    Result := Result + IntToHex(APacket[I], 2);
  end;
end;

function TCheersonCX10WProtocol.SendAll(ASocket: TLTCPComponent;
  const ABytes: array of Byte): Boolean;
begin
  Result := Assigned(ASocket) and ASocket.Connected and (Length(ABytes) > 0) and
    (ASocket.Send(ABytes[0], Length(ABytes)) = Length(ABytes));
end;

procedure TCheersonCX10WProtocol.Connect(const AHost: string; ATcpPort,
  AUdpPort: Integer);
begin
  Disconnect;

  FHost := Trim(AHost);
  if FHost = '' then
    FHost := CX10W_DEFAULT_HOST;
  FTcpPort := ATcpPort;
  if FTcpPort <= 0 then
    FTcpPort := CX10W_DEFAULT_TCP_PORT;
  FUdpPort := AUdpPort;
  if FUdpPort <= 0 then
    FUdpPort := CX10W_DEFAULT_UDP_PORT;

  FDisconnecting := False;
  FThrottleArmed := False;
  FArmWarned := False;
  FTotalComandos := 0;

  DoStatus(Format('Conectando ao CX-10W em %s (TCP %d, UDP %d)...',
    [FHost, FTcpPort, FUdpPort]));
  try
    if not FUdp.Connect(FHost, FUdpPort) then
    begin
      DoError('Não foi possível abrir o UDP ' + IntToStr(FUdpPort) + '.');
      Exit;
    end;
    if not FCtrl.Connect(FHost, FTcpPort) then
      DoError('Não foi possível iniciar a conexão TCP de controle.');
  except
    on E: Exception do
      DoError('Erro na conexão: ' + E.Message);
  end;
end;

procedure TCheersonCX10WProtocol.Disconnect;
var
  I: Integer;
begin
  FDisconnecting := True;
  try
    // Corta os motores antes de soltar o canal de comando.
    if FActive and FUdp.Connected then
      for I := 1 to 5 do
      begin
        SendNeutral;
        Sleep(20);
      end;

    StopVideo;

    if FCtrl.Connected then
      FCtrl.Disconnect(True);
    if FUdp.Connected then
      FUdp.Disconnect(True);
  except
  end;

  FActive := False;
  FThrottleArmed := False;
  FDisconnecting := False;
end;

procedure TCheersonCX10WProtocol.StartVideo;
begin
  if (not FVideoEnabled) or FVideo1.Connected then
    Exit;
  FVideoSynced := False;
  FCarryLen := 0;
  DoStatus('Abrindo canal de vídeo...');
  if not FVideo1.Connect(FHost, FTcpPort) then
    DoStatus('Vídeo indisponível: falha ao abrir o canal 1.');
end;

procedure TCheersonCX10WProtocol.StopVideo;
begin
  try
    if FVideo2.Connected then
      FVideo2.Disconnect(True);
    if FVideo1.Connected then
      FVideo1.Disconnect(True);
  except
  end;
  FVideoConnected := False;
  FVideoSynced := False;
  FCarryLen := 0;
end;

procedure TCheersonCX10WProtocol.SendPacket(const APacket: TCX10WPacket);
begin
  if not FUdp.Connected then
    Exit;
  if FUdp.Send(APacket[0], CX10W_PACKET_SIZE) = CX10W_PACKET_SIZE then
  begin
    FLastPacket := APacket;
    Inc(FTotalComandos);
  end;
end;

procedure TCheersonCX10WProtocol.SendNeutral;
begin
  SendPacket(BuildPacket(CX10W_AXIS_CENTER, CX10W_AXIS_CENTER, 0,
    CX10W_AXIS_CENTER, 0));
end;

procedure TCheersonCX10WProtocol.SendCommand(AX, AY, AZ, AB1, AB2, AB3, AB4,
  AB5, AB6: Byte);
var
  Roll, Pitch, Throttle, Yaw, Flags: Byte;
begin
  if (not FActive) or FDisconnecting then
    Exit;

  { No frmMain, X e Y crescem com o manche para a ESQUERDA e para CIMA.
    No CX-10W, 255 = direita / frente. Por isso a rolagem é invertida. }
  Roll := 255 - AX;
  Pitch := AY;

  { Trava de segurança: só libera a aceleração depois que o comando passa
    pelo mínimo uma vez após a conexão. }
  if not FThrottleArmed then
  begin
    if AZ <= CX10W_THROTTLE_ARM_LIMIT then
    begin
      FThrottleArmed := True;
      DoStatus('Acelerador liberado.');
    end
    else if not FArmWarned then
    begin
      FArmWarned := True;
      DoStatus('Acelerador travado: leve a aceleração ao mínimo para liberar.');
    end;
  end;
  if FThrottleArmed then
    Throttle := AZ
  else
    Throttle := 0;

  Yaw := CX10W_AXIS_CENTER;
  if (AB1 = 255) and (AB2 <> 255) then
    Yaw := 0
  else if (AB2 = 255) and (AB1 <> 255) then
    Yaw := 255;

  Flags := 0;
  if AB3 = 255 then Flags := Flags or $01;
  if AB4 = 255 then Flags := Flags or $02;
  if AB5 = 255 then Flags := Flags or $04;
  if AB6 = 255 then Flags := Flags or $08;

  SendPacket(BuildPacket(Roll, Pitch, Throttle, Yaw, Flags));
end;

function TCheersonCX10WProtocol.DrainSocket(aSocket: TLSocket;
  ADeliver: Boolean): Boolean;
var
  Buf: array[0..16383] of Byte;
  L: Integer;
begin
  Result := False;
  repeat
    L := aSocket.Get(Buf[0], SizeOf(Buf));
    if L > 0 then
    begin
      Result := True;
      if ADeliver then
        ProcessVideoChunk(@Buf[0], L);
    end;
  until L <= 0;
end;

{ Canal de controle }

procedure TCheersonCX10WProtocol.CtrlConnect(aSocket: TLSocket);
begin
  if not SendAll(FCtrl, MAGIC_BYTES_CTRL) then
  begin
    DoError('Falha ao enviar o pacote de inicialização do CX-10W.');
    Exit;
  end;
  FActive := True;
  DoStatus('Canal de controle ativo. Comandos por UDP ' + IntToStr(FUdpPort) + '.');
  SendNeutral;
  StartVideo;
end;

procedure TCheersonCX10WProtocol.CtrlReceive(aSocket: TLSocket);
begin
  // Respostas do canal de controle não carregam dados úteis: descartadas.
  if DrainSocket(aSocket, False) then
    Inc(FTotalPacotesTCP);
end;

procedure TCheersonCX10WProtocol.CtrlError(const msg: string; aSocket: TLSocket);
begin
  FActive := False;
  if not FDisconnecting then
    DoError('Controle: ' + msg + ' (verifique se o PC está na rede Wi-Fi do CX-10W).');
end;

procedure TCheersonCX10WProtocol.CtrlDisconnect(aSocket: TLSocket);
begin
  FActive := False;
  if not FDisconnecting then
    DoError('Canal de controle fechado pelo drone.');
end;

{ Canais de vídeo }

procedure TCheersonCX10WProtocol.Video1Connect(aSocket: TLSocket);
begin
  if SendAll(FVideo1, MAGIC_BYTES_VIDEO_1A) and SendAll(FVideo1, MAGIC_BYTES_VIDEO_1B) then
  begin
    if not FVideo2.Connect(FHost, FTcpPort) then
      DoStatus('Vídeo indisponível: falha ao abrir o canal 2.');
  end
  else
    DoStatus('Vídeo indisponível: falha na inicialização do canal 1.');
end;

procedure TCheersonCX10WProtocol.Video2Connect(aSocket: TLSocket);
begin
  if SendAll(FVideo2, MAGIC_BYTES_VIDEO_2) then
  begin
    FVideoConnected := True;
    DoStatus('Canal de vídeo aberto. Aguardando imagem H.264...');
  end
  else
    DoStatus('Vídeo indisponível: falha na inicialização do canal 2.');
end;

procedure TCheersonCX10WProtocol.Video1Receive(aSocket: TLSocket);
begin
  // O canal 1 só precisa ser mantido aberto e esvaziado.
  if DrainSocket(aSocket, False) then
    Inc(FTotalPacotesTCP);
end;

procedure TCheersonCX10WProtocol.Video2Receive(aSocket: TLSocket);
begin
  // O canal 2 transporta o vídeo H.264.
  if DrainSocket(aSocket, True) then
    Inc(FTotalPacotesTCP);
end;

procedure TCheersonCX10WProtocol.VideoError(const msg: string; aSocket: TLSocket);
begin
  FVideoConnected := False;
  // A perda do vídeo não derruba o comando de voo.
  if not FDisconnecting then
    DoStatus('Vídeo: ' + msg);
end;

procedure TCheersonCX10WProtocol.VideoDisconnect(aSocket: TLSocket);
begin
  FVideoConnected := False;
  FVideoSynced := False;
  if not FDisconnecting then
    DoStatus('Canal de vídeo fechado pelo drone.');
end;

procedure TCheersonCX10WProtocol.ProcessVideoChunk(AData: PByte; ACount: Integer);
var
  Tmp: array of Byte;
  I, Total: Integer;
begin
  if ACount <= 0 then
    Exit;

  if IsDroneReply(AData, ACount) then
    Exit;

  if FVideoSynced then
  begin
    Inc(FTotalBytesVideo, ACount);
    if Assigned(FOnVideoData) then
      FOnVideoData(Self, AData, ACount);
    Exit;
  end;

  // Procura o primeiro código de início 00 00 00 01, mesmo dividido entre blocos.
  Total := FCarryLen + ACount;
  SetLength(Tmp, Total);
  if FCarryLen > 0 then
    Move(FCarry[0], Tmp[0], FCarryLen);
  Move(AData^, Tmp[FCarryLen], ACount);

  for I := 0 to Total - 4 do
    if (Tmp[I] = 0) and (Tmp[I + 1] = 0) and (Tmp[I + 2] = 0) and (Tmp[I + 3] = 1) then
    begin
      FVideoSynced := True;
      FCarryLen := 0;
      DoStatus('Vídeo sincronizado.');
      Inc(FTotalBytesVideo, Total - I);
      if Assigned(FOnVideoData) then
        FOnVideoData(Self, @Tmp[I], Total - I);
      Exit;
    end;

  if Total >= 3 then
    FCarryLen := 3
  else
    FCarryLen := Total;
  Move(Tmp[Total - FCarryLen], FCarry[0], FCarryLen);
end;

{ UDP }

procedure TCheersonCX10WProtocol.UdpReceive(aSocket: TLSocket);
begin
  if DrainSocket(aSocket, False) then
    Inc(FTotalPacotesUDP);
end;

procedure TCheersonCX10WProtocol.UdpError(const msg: string; aSocket: TLSocket);
begin
  if not FDisconnecting then
    DoError('UDP: ' + msg);
end;

end.
