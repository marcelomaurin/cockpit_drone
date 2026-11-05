unit ardroneproto;

{ Protocolo do Parrot AR.Drone 2.0 (SDK oficial da Parrot)
  --------------------------------------------------------
  Rede do drone (ponto de acesso "ardrone2_xxxxxx"): IP 192.168.1.1.
    UDP 5556 - comandos AT em texto (AT*REF, AT*PCMD, AT*FTRIM, AT*CONFIG...)
    UDP 5554 - telemetria (navdata): estado, bateria, atitude, altura, velocidade
    TCP 5555 - vídeo H.264 da câmera frontal em quadros PaVE

  Comandos:
    AT*REF=seq,valor      decolar (bit 9), pousar, emergência (bit 8 alterna)
    AT*PCMD=seq,f,r,p,g,y movimento: f=1 usa os valores, f=0 paira no lugar;
                          r/p/g/y são reais -1..1 enviados como o inteiro de
                          32 bits com o mesmo padrão de bits (padrão do SDK).
                          rolagem + = direita, arfagem + = para TRÁS,
                          g = velocidade vertical (+ sobe), y = giro (+ direita).
  O drone espera comandos continuamente: sem nada por 2 s ele entra em
  "watchdog" e paira; por isso Tick deve ser chamado a cada ~30 ms.

  Segurança:
    - eixos centralizados = PCMD com f=0 (pairar), nunca "último comando";
    - ao desconectar, envia o comando de pouso antes de fechar;
    - Emergencia corta os motores na hora (use só em caso de perigo). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, lNetComponents, lNet, protocols;

const
  ARDRONE_DEFAULT_HOST = '192.168.1.1';
  ARDRONE_PORT_AT = 5556;
  ARDRONE_PORT_NAVDATA = 5554;
  ARDRONE_PORT_VIDEO = 5555;

  ARDRONE_REF_BASE = $11540000;
  ARDRONE_REF_TAKEOFF = $200;
  ARDRONE_REF_EMERGENCY = $100;

  // Bits do estado (navdata)
  ARDRONE_STATE_FLY = 1 shl 0;
  ARDRONE_STATE_COMMAND_ACK = 1 shl 6;
  ARDRONE_STATE_NAVDATA_DEMO = 1 shl 10;
  ARDRONE_STATE_NAVDATA_BOOTSTRAP = 1 shl 11;
  ARDRONE_STATE_VBAT_LOW = 1 shl 15;
  ARDRONE_STATE_CUTOUT = 1 shl 22;
  ARDRONE_STATE_COM_WATCHDOG = 1 shl 30;
  ARDRONE_STATE_EMERGENCY = Cardinal(1) shl 31;

type
  TARDroneVideoDataEvent = procedure(Sender: TObject; AData: PByte;
    ACount: Integer) of object;

  { Telemetria (pacote "demo" da navdata). }
  TARDroneNavdata = record
    Valida: Boolean;
    Estado: Cardinal;
    Sequencia: Cardinal;
    Bateria: Integer;       // %
    Arfagem: Double;        // graus (theta)
    Rolagem: Double;        // graus (phi)
    Rumo: Double;           // graus (psi)
    Altura: Double;         // metros
    VelX, VelY, VelZ: Double; // m/s
    Recebida: TDateTime;
  end;

  { TARDroneProtocol }

  TARDroneProtocol = class(TBaseProtocol)
  private
    FAt: TLUDPComponent;
    FNav: TLUDPComponent;
    FVideo: TLTCPComponent;

    FSeq: Cardinal;
    FVoar: Boolean;
    FEmergenciaTicks: Integer;
    FTrimPendente: Boolean;
    FConfigs: TStringList;
    FConfigEspera: Integer;
    FUltimoGatilhoNav: QWord;

    FRoll, FPitch, FGaz, FYaw: Single;
    FMover: Boolean;

    FNavdata: TARDroneNavdata;
    FNavPacotes: Int64;
    FComandos: Int64;

    FVideoEnabled: Boolean;
    FVideoConnected: Boolean;
    FVideoBuf: TBytes;
    FVideoLen: Integer;
    FBytesVideo: Int64;

    FOnVideoData: TARDroneVideoDataEvent;
    FOnNavdata: TNotifyEvent;
    FDisconnecting: Boolean;
    FB3Anterior, FB4Anterior: Boolean;
    FSensibilidade: Single;

    function NextSeq: Cardinal;
    procedure SendAT(const ACmd: string);
    procedure SendNavTrigger;
    procedure NavReceive(aSocket: TLSocket);
    procedure NavError(const msg: string; aSocket: TLSocket);
    procedure AtError(const msg: string; aSocket: TLSocket);
    procedure ParseNavdata(const ABuf: array of Byte; ALen: Integer);

    procedure VideoConnect(aSocket: TLSocket);
    procedure VideoReceive(aSocket: TLSocket);
    procedure VideoError(const msg: string; aSocket: TLSocket);
    procedure VideoDisconnect(aSocket: TLSocket);
    procedure ProcessaPaVE;
  public
    constructor Create; override;
    destructor Destroy; override;

    { ATcpPort = vídeo (5555), AUdpPort = comandos AT (5556). }
    procedure Connect(const AHost: string; ATcpPort, AUdpPort: Integer); override;
    procedure Disconnect; override;
    { Compatível com os outros protocolos: X/Y/Z do frmMain, B1/B2 guinada,
      B3 decolar, B4 pousar (na borda de subida). }
    procedure SendCommand(AX, AY, AZ, AB1, AB2, AB3, AB4, AB5, AB6: Byte); override;

    { Chamado a cada ~30 ms: envia REF + PCMD e mantém a telemetria viva. }
    procedure Tick;

    procedure Decolar;
    procedure Pousar;
    { Corta os motores imediatamente; se já estiver em emergência, rearma. }
    procedure Emergencia;
    { Calibração horizontal: só com o drone parado numa superfície plana. }
    procedure CalibrarPlano;
    { Valores -1..1. Zero em tudo = pairar. }
    procedure Mover(ARoll, APitch, AGaz, AYaw: Single);
    procedure Pairar;
    procedure Configura(const AChave, AValor: string);

    class function FloatToAT(AValue: Single): LongInt; static;

    property Navdata: TARDroneNavdata read FNavdata;
    property NavPacotes: Int64 read FNavPacotes;
    property Comandos: Int64 read FComandos;
    property Voando: Boolean read FVoar;
    { Fração do comando máximo usada pelo manche (0.1..1). Não afeta a subida. }
    property Sensibilidade: Single read FSensibilidade write FSensibilidade;
    property VideoEnabled: Boolean read FVideoEnabled write FVideoEnabled;
    property VideoConnected: Boolean read FVideoConnected;
    property BytesVideo: Int64 read FBytesVideo;
    property OnVideoData: TARDroneVideoDataEvent read FOnVideoData write FOnVideoData;
    property OnNavdata: TNotifyEvent read FOnNavdata write FOnNavdata;
  end;

implementation

const
  NAVDATA_HEADER = $55667788;
  NAV_TAG_DEMO = 0;
  NAV_TAG_CHECKSUM = $FFFF;
  PAVE_MIN_HEADER = 12;
  VIDEO_BUF_MAX = 2 * 1024 * 1024;
  ZONA_MORTA = 0.06;

function LeU16(const B: array of Byte; P: Integer): Word; inline;
begin
  Result := Word(B[P]) or (Word(B[P + 1]) shl 8);
end;

function LeU32(const B: array of Byte; P: Integer): Cardinal; inline;
begin
  Result := Cardinal(B[P]) or (Cardinal(B[P + 1]) shl 8) or
    (Cardinal(B[P + 2]) shl 16) or (Cardinal(B[P + 3]) shl 24);
end;

function LeF32(const B: array of Byte; P: Integer): Single; inline;
var
  C: Cardinal;
begin
  C := LeU32(B, P);
  Move(C, Result, SizeOf(Result));
end;

{ TARDroneProtocol }

constructor TARDroneProtocol.Create;
begin
  inherited Create;

  FAt := TLUDPComponent.Create(nil);
  FAt.OnError := @AtError;

  FNav := TLUDPComponent.Create(nil);
  FNav.OnReceive := @NavReceive;
  FNav.OnError := @NavError;

  FVideo := TLTCPComponent.Create(nil);
  FVideo.OnConnect := @VideoConnect;
  FVideo.OnReceive := @VideoReceive;
  FVideo.OnError := @VideoError;
  FVideo.OnDisconnect := @VideoDisconnect;

  FConfigs := TStringList.Create;
  FVideoEnabled := True;
  FSensibilidade := 0.5;
  FHost := ARDRONE_DEFAULT_HOST;
  FTcpPort := ARDRONE_PORT_VIDEO;
  FUdpPort := ARDRONE_PORT_AT;
  SetLength(FVideoBuf, 256 * 1024);
end;

destructor TARDroneProtocol.Destroy;
begin
  FOnStatus := nil;
  FOnError := nil;
  FOnVideoData := nil;
  FOnNavdata := nil;
  Disconnect;
  FVideo.Free;
  FNav.Free;
  FAt.Free;
  FConfigs.Free;
  inherited Destroy;
end;

class function TARDroneProtocol.FloatToAT(AValue: Single): LongInt;
begin
  Move(AValue, Result, SizeOf(Result));
end;

function TARDroneProtocol.NextSeq: Cardinal;
begin
  Inc(FSeq);
  Result := FSeq;
end;

procedure TARDroneProtocol.SendAT(const ACmd: string);
begin
  if FAt.Connected and (ACmd <> '') then
    if FAt.SendMessage(ACmd) > 0 then
      Inc(FComandos);
end;

procedure TARDroneProtocol.SendNavTrigger;
const
  GATILHO: array[0..3] of Byte = ($01, $00, $00, $00);
begin
  // Enviado da porta local 5554 para a 5554 do drone: ele responde para cá.
  if FNav.Connected then
    FNav.Send(GATILHO[0], SizeOf(GATILHO), FHost + ':' + IntToStr(ARDRONE_PORT_NAVDATA));
  FUltimoGatilhoNav := GetTickCount64;
end;

procedure TARDroneProtocol.Connect(const AHost: string; ATcpPort,
  AUdpPort: Integer);
begin
  Disconnect;

  FHost := Trim(AHost);
  if FHost = '' then
    FHost := ARDRONE_DEFAULT_HOST;
  FTcpPort := ATcpPort;
  if FTcpPort <= 0 then
    FTcpPort := ARDRONE_PORT_VIDEO;
  FUdpPort := AUdpPort;
  if FUdpPort <= 0 then
    FUdpPort := ARDRONE_PORT_AT;

  FSeq := 0;
  FVoar := False;
  FMover := False;
  FEmergenciaTicks := 0;
  FTrimPendente := False;
  FConfigEspera := 0;
  FillChar(FNavdata, SizeOf(FNavdata), 0);
  FVideoLen := 0;
  FDisconnecting := False;
  FB3Anterior := True; // ignora botões que já estavam apertados ao conectar
  FB4Anterior := True;

  DoStatus(Format('Conectando ao AR.Drone em %s...', [FHost]));
  try
    // Comandos: só envio (porta local qualquer).
    if not FAt.Connect(FHost, FUdpPort) then
    begin
      DoError('Não foi possível abrir a porta de comandos UDP ' + IntToStr(FUdpPort) + '.');
      Exit;
    end;
    // Telemetria: escuta na porta local 5554, como o SDK oficial (o Connect do
    // lNet não liga a porta local, e o drone envia a telemetria para a 5554).
    if not FNav.Listen(ARDRONE_PORT_NAVDATA) then
      DoStatus('Telemetria indisponível (porta UDP 5554 ocupada?).');
  except
    on E: Exception do
    begin
      DoError('Erro na conexão: ' + E.Message);
      Exit;
    end;
  end;

  FActive := True;
  // Recomeça a numeração: o drone aceita a sequência 1 como reinício.
  SendAT(Format('AT*PCMD=%d,0,0,0,0,0'#13, [NextSeq]));
  SendNavTrigger;
  Configura('general:navdata_demo', 'TRUE');

  if FVideoEnabled then
  begin
    DoStatus('Abrindo vídeo (TCP ' + IntToStr(FTcpPort) + ')...');
    if not FVideo.Connect(FHost, FTcpPort) then
      DoStatus('Vídeo indisponível.');
  end;

  DoStatus('Canal de comandos ativo. Aguardando telemetria...');
end;

procedure TARDroneProtocol.Disconnect;
var
  I: Integer;
begin
  FDisconnecting := True;
  try
    if FActive and FAt.Connected then
    begin
      // Pouso antes de soltar o canal de comando.
      for I := 1 to 5 do
      begin
        SendAT(Format('AT*PCMD=%d,0,0,0,0,0'#13'AT*REF=%d,%d'#13,
          [NextSeq, NextSeq, ARDRONE_REF_BASE]));
        Sleep(30);
      end;
    end;
    if FVideo.Connected then
      FVideo.Disconnect(True);
    if FNav.Connected then
      FNav.Disconnect(True);
    if FAt.Connected then
      FAt.Disconnect(True);
  except
  end;
  FActive := False;
  FVoar := False;
  FVideoConnected := False;
  FVideoLen := 0;
  FConfigs.Clear;
  FDisconnecting := False;
end;

procedure TARDroneProtocol.Configura(const AChave, AValor: string);
begin
  FConfigs.Add(Format('"%s","%s"', [AChave, AValor]));
end;

procedure TARDroneProtocol.Decolar;
begin
  if FNavdata.Valida and ((FNavdata.Estado and ARDRONE_STATE_EMERGENCY) <> 0) then
  begin
    DoStatus('Drone em emergência: use o botão de emergência para rearmar antes de decolar.');
    Exit;
  end;
  if FNavdata.Valida and ((FNavdata.Estado and ARDRONE_STATE_VBAT_LOW) <> 0) then
  begin
    DoStatus('Bateria baixa: decolagem recusada.');
    Exit;
  end;
  FMover := False;
  FVoar := True;
  DoStatus('Decolando...');
end;

procedure TARDroneProtocol.Pousar;
begin
  FVoar := False;
  FMover := False;
  DoStatus('Pousando...');
end;

procedure TARDroneProtocol.Emergencia;
begin
  FVoar := False;
  FMover := False;
  // O bit 8 alterna o estado: alguns comandos seguidos garantem a recepção.
  FEmergenciaTicks := 8;
  if FNavdata.Valida and ((FNavdata.Estado and ARDRONE_STATE_EMERGENCY) <> 0) then
    DoStatus('Rearmando após emergência...')
  else
    DoStatus('EMERGÊNCIA: motores cortados.');
end;

procedure TARDroneProtocol.CalibrarPlano;
begin
  if FVoar or (FNavdata.Valida and ((FNavdata.Estado and ARDRONE_STATE_FLY) <> 0)) then
  begin
    DoStatus('Calibração só com o drone pousado.');
    Exit;
  end;
  FTrimPendente := True;
  DoStatus('Calibração horizontal enviada.');
end;

procedure TARDroneProtocol.Mover(ARoll, APitch, AGaz, AYaw: Single);

  function Ajusta(V: Single): Single;
  begin
    V := EnsureRange(V, -1, 1);
    if Abs(V) < ZONA_MORTA then
      V := 0;
    Result := V;
  end;

begin
  FRoll := Ajusta(ARoll);
  FPitch := Ajusta(APitch);
  FGaz := Ajusta(AGaz);
  FYaw := Ajusta(AYaw);
  FMover := (FRoll <> 0) or (FPitch <> 0) or (FGaz <> 0) or (FYaw <> 0);
end;

procedure TARDroneProtocol.Pairar;
begin
  Mover(0, 0, 0, 0);
end;

procedure TARDroneProtocol.SendCommand(AX, AY, AZ, AB1, AB2, AB3, AB4, AB5,
  AB6: Byte);
const
  YAW_BOTAO = 0.6;
var
  Yaw: Single;
begin
  { No frmMain X cresce para a ESQUERDA e Y para a FRENTE.
    No AR.Drone: rolagem + = direita; arfagem + = para trás; gaz + = sobe. }
  Yaw := 0;
  if (AB1 = 255) and (AB2 <> 255) then
    Yaw := -YAW_BOTAO
  else if (AB2 = 255) and (AB1 <> 255) then
    Yaw := YAW_BOTAO;

  Mover((127 - Integer(AX)) / 128 * FSensibilidade,
    (127 - Integer(AY)) / 128 * FSensibilidade,
    (Integer(AZ) - 127) / 128, Yaw * FSensibilidade);

  // Só na borda de subida: botão (ou tecla) mantido não repete o comando.
  if (AB3 = 255) and not FB3Anterior then
    Decolar
  else if (AB4 = 255) and not FB4Anterior then
    Pousar;
  FB3Anterior := AB3 = 255;
  FB4Anterior := AB4 = 255;
end;

procedure TARDroneProtocol.Tick;
var
  Cmd: string;
  Ref: Cardinal;
  Estado: Cardinal;
begin
  if not FActive then
    Exit;

  Cmd := '';
  Estado := FNavdata.Estado;

  // Telemetria parada: o drone precisa de um novo gatilho.
  if GetTickCount64 - FUltimoGatilhoNav > 1000 then
    if (not FNavdata.Valida) or (Now - FNavdata.Recebida > 1 / 86400) then
      SendNavTrigger;

  if FNavdata.Valida and ((Estado and ARDRONE_STATE_COM_WATCHDOG) <> 0) then
    Cmd := Cmd + Format('AT*COMWDG=%d'#13, [NextSeq]);

  // Configurações: uma por vez, com confirmação (AT*CTRL=5 limpa o ACK).
  if FConfigEspera > 0 then
    Dec(FConfigEspera)
  else if FConfigs.Count > 0 then
  begin
    Cmd := Cmd + Format('AT*CONFIG=%d,%s'#13'AT*CTRL=%d,5,0'#13,
      [NextSeq, FConfigs[0], NextSeq]);
    FConfigs.Delete(0);
    FConfigEspera := 4;
  end;

  if FTrimPendente then
  begin
    Cmd := Cmd + Format('AT*FTRIM=%d,'#13, [NextSeq]);
    FTrimPendente := False;
  end;

  Ref := ARDRONE_REF_BASE;
  if FEmergenciaTicks > 0 then
  begin
    Ref := Ref or ARDRONE_REF_EMERGENCY;
    Dec(FEmergenciaTicks);
  end
  else if FVoar then
    Ref := Ref or ARDRONE_REF_TAKEOFF;
  Cmd := Cmd + Format('AT*REF=%d,%d'#13, [NextSeq, Ref]);

  if FMover and FVoar then
    Cmd := Cmd + Format('AT*PCMD=%d,1,%d,%d,%d,%d'#13,
      [NextSeq, FloatToAT(FRoll), FloatToAT(FPitch), FloatToAT(FGaz), FloatToAT(FYaw)])
  else
    Cmd := Cmd + Format('AT*PCMD=%d,0,0,0,0,0'#13, [NextSeq]);

  SendAT(Cmd);
end;

{ Telemetria }

procedure TARDroneProtocol.NavReceive(aSocket: TLSocket);
var
  Buf: array[0..4095] of Byte;
  L: Integer;
begin
  repeat
    L := aSocket.Get(Buf[0], SizeOf(Buf));
    if L > 0 then
      ParseNavdata(Buf, L);
  until L <= 0;
end;

procedure TARDroneProtocol.ParseNavdata(const ABuf: array of Byte; ALen: Integer);
var
  P, Tag, Tam: Integer;
  Anterior: Cardinal;
  Primeira: Boolean;
begin
  if (ALen < 16) or (LeU32(ABuf, 0) <> NAVDATA_HEADER) then
    Exit;

  Primeira := not FNavdata.Valida;
  Anterior := FNavdata.Estado;
  FNavdata.Estado := LeU32(ABuf, 4);
  FNavdata.Sequencia := LeU32(ABuf, 8);
  FNavdata.Valida := True;
  FNavdata.Recebida := Now;
  Inc(FNavPacotes);

  P := 16;
  while P + 4 <= ALen do
  begin
    Tag := LeU16(ABuf, P);
    Tam := LeU16(ABuf, P + 2);
    if (Tam < 4) or (P + Tam > ALen) then
      Break;
    if Tag = NAV_TAG_CHECKSUM then
      Break;
    if (Tag = NAV_TAG_DEMO) and (Tam >= 4 + 36) then
    begin
      FNavdata.Bateria := Integer(LeU32(ABuf, P + 8));
      FNavdata.Arfagem := LeF32(ABuf, P + 12) / 1000;
      FNavdata.Rolagem := LeF32(ABuf, P + 16) / 1000;
      FNavdata.Rumo := LeF32(ABuf, P + 20) / 1000;
      FNavdata.Altura := LongInt(LeU32(ABuf, P + 24)) / 1000;
      FNavdata.VelX := LeF32(ABuf, P + 28) / 1000;
      FNavdata.VelY := LeF32(ABuf, P + 32) / 1000;
      FNavdata.VelZ := LeF32(ABuf, P + 36) / 1000;
    end;
    Inc(P, Tam);
  end;

  if Primeira then
    DoStatus('Telemetria recebida.');

  // Ainda em modo de inicialização: pede de novo o modo "demo".
  if ((FNavdata.Estado and ARDRONE_STATE_NAVDATA_BOOTSTRAP) <> 0) and
    (FConfigs.IndexOf('"general:navdata_demo","TRUE"') < 0) then
    Configura('general:navdata_demo', 'TRUE');

  if ((FNavdata.Estado and ARDRONE_STATE_EMERGENCY) <> 0) and
    ((Anterior and ARDRONE_STATE_EMERGENCY) = 0) then
  begin
    FVoar := False;
    DoStatus('Drone em modo de EMERGÊNCIA (motores parados).');
  end;

  if ((FNavdata.Estado and ARDRONE_STATE_VBAT_LOW) <> 0) and
    ((Anterior and ARDRONE_STATE_VBAT_LOW) = 0) then
    DoStatus('Bateria baixa: pouse o drone.');

  if Assigned(FOnNavdata) then
    FOnNavdata(Self);
end;

procedure TARDroneProtocol.NavError(const msg: string; aSocket: TLSocket);
begin
  if not FDisconnecting then
    DoStatus('Telemetria: ' + msg);
end;

procedure TARDroneProtocol.AtError(const msg: string; aSocket: TLSocket);
begin
  if not FDisconnecting then
    DoError('Comandos: ' + msg + ' (verifique se o PC está na rede Wi-Fi do AR.Drone).');
end;

{ Vídeo: quadros PaVE com carga H.264 }

procedure TARDroneProtocol.VideoConnect(aSocket: TLSocket);
begin
  FVideoConnected := True;
  FVideoLen := 0;
  DoStatus('Canal de vídeo aberto.');
end;

procedure TARDroneProtocol.VideoReceive(aSocket: TLSocket);
var
  Buf: array[0..32767] of Byte;
  L: Integer;
begin
  repeat
    L := aSocket.Get(Buf[0], SizeOf(Buf));
    if L > 0 then
    begin
      if FVideoLen + L > Length(FVideoBuf) then
      begin
        if FVideoLen + L > VIDEO_BUF_MAX then
          FVideoLen := 0; // fluxo dessincronizado: recomeça
        if FVideoLen + L > Length(FVideoBuf) then
          SetLength(FVideoBuf, FVideoLen + L);
      end;
      Move(Buf[0], FVideoBuf[FVideoLen], L);
      Inc(FVideoLen, L);
      ProcessaPaVE;
    end;
  until L <= 0;
end;

procedure TARDroneProtocol.ProcessaPaVE;
var
  P, I, Cabecalho, Carga: Integer;
begin
  P := 0;
  while FVideoLen - P >= PAVE_MIN_HEADER do
  begin
    if not ((FVideoBuf[P] = Ord('P')) and (FVideoBuf[P + 1] = Ord('a')) and
      (FVideoBuf[P + 2] = Ord('V')) and (FVideoBuf[P + 3] = Ord('E'))) then
    begin
      // Procura a próxima assinatura "PaVE".
      I := P + 1;
      while (I <= FVideoLen - 4) and not ((FVideoBuf[I] = Ord('P')) and
        (FVideoBuf[I + 1] = Ord('a')) and (FVideoBuf[I + 2] = Ord('V')) and
        (FVideoBuf[I + 3] = Ord('E'))) do
        Inc(I);
      P := I;
      Continue;
    end;

    Cabecalho := LeU16(FVideoBuf, P + 6);
    Carga := Integer(LeU32(FVideoBuf, P + 8));
    if (Cabecalho < PAVE_MIN_HEADER) or (Carga <= 0) or (Carga > VIDEO_BUF_MAX) then
    begin
      Inc(P); // cabeçalho inválido: procura o próximo
      Continue;
    end;
    if FVideoLen - P < Cabecalho + Carga then
      Break; // quadro incompleto: espera mais dados

    Inc(FBytesVideo, Carga);
    if Assigned(FOnVideoData) then
      FOnVideoData(Self, @FVideoBuf[P + Cabecalho], Carga);
    Inc(P, Cabecalho + Carga);
  end;

  if P > 0 then
  begin
    if P < FVideoLen then
      Move(FVideoBuf[P], FVideoBuf[0], FVideoLen - P);
    Dec(FVideoLen, P);
  end;
end;

procedure TARDroneProtocol.VideoError(const msg: string; aSocket: TLSocket);
begin
  FVideoConnected := False;
  if not FDisconnecting then
    DoStatus('Vídeo: ' + msg);
end;

procedure TARDroneProtocol.VideoDisconnect(aSocket: TLSocket);
begin
  FVideoConnected := False;
  if not FDisconnecting then
    DoStatus('Canal de vídeo fechado pelo drone.');
end;

end.
