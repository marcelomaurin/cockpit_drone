unit mavlinkproto;

{ MAVLink para multirrotores com piloto automático ArduPilot (ArduCopter) ou PX4.

  Rede: UDP (padrão 14550). O cockpit escuta na porta configurada e responde
  ao endereço de onde o drone fala (SITL, ponte Wi-Fi ESP8266/ESP32, rádio de
  telemetria com ponte UDP etc.).

  Envia (MAVLink 1, aceito por ArduPilot e PX4):
    HEARTBEAT (como estação de solo), MANUAL_CONTROL, COMMAND_LONG,
    REQUEST_DATA_STREAM, MISSION_COUNT, MISSION_ITEM_INT.
  Lê (MAVLink 1 e 2):
    HEARTBEAT, SYS_STATUS, GPS_RAW_INT, GLOBAL_POSITION_INT, HOME_POSITION,
    MISSION_REQUEST(_INT), MISSION_ACK, MISSION_CURRENT, MISSION_ITEM_REACHED,
    COMMAND_ACK, STATUSTEXT.

  Tick deve ser chamado a cada ~100 ms pela linha principal: envia o sinal de
  vida, controla os prazos do envio da missão, dos comandos e da partida.

  Segurança:
    - o controle manual (MANUAL_CONTROL) é suspenso enquanto a rota está ativa
      ou o drone está num modo autônomo (missão, RTL, pouso...);
    - a partida da rota só ocorre com a missão aceita pelo drone;
    - toda recusa do drone (comando, missão, "PreArm") vira aviso legível. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, lNetComponents, lNet, protocols;

const
  MAV_PORTA_PADRAO = 14550;

  MAV_AUTOPILOT_ARDUPILOT = 3;
  MAV_AUTOPILOT_PX4 = 12;

  // Comandos MAVLink usados na rota
  MAV_CMD_NAV_WAYPOINT = 16;
  MAV_CMD_NAV_LOITER_UNLIM = 17;
  MAV_CMD_NAV_RETURN_TO_LAUNCH = 20;
  MAV_CMD_NAV_LAND = 21;
  MAV_CMD_NAV_TAKEOFF = 22;
  MAV_CMD_DO_SET_MODE = 176;
  MAV_CMD_DO_CHANGE_SPEED = 178;
  MAV_CMD_MISSION_START = 300;
  MAV_CMD_COMPONENT_ARM_DISARM = 400;
  MAV_CMD_GET_HOME_POSITION = 410;
  MAV_CMD_REQUEST_MESSAGE = 512;

  MAV_FRAME_GLOBAL = 0;
  MAV_FRAME_MISSION = 2;
  MAV_FRAME_GLOBAL_RELATIVE_ALT = 3;

type
  TMavTelemetria = record
    Conectado: Boolean;
    SysId, CompId: Byte;
    Autopilot, Tipo: Byte;
    BaseMode: Byte;
    CustomMode: Cardinal;
    Armado: Boolean;
    GpsFix: Integer;        // 0/1 sem fix, 2 = 2D, 3 = 3D, 4+ = DGPS/RTK
    Satelites: Integer;
    Hdop: Double;           // -1 = desconhecido
    PosValida: Boolean;
    Lat, Lon: Double;
    AltRelativa: Double;    // metros acima do ponto de partida
    Rumo: Double;           // graus
    VelSolo: Double;        // m/s
    BateriaPct: Integer;    // -1 = desconhecida
    BateriaV: Double;       // 0 = desconhecida
    ItemAtual: Integer;     // item da missão em execução (-1)
    ItemAlcancado: Integer; // último item alcançado (-1)
    HomeValido: Boolean;
    HomeLat, HomeLon: Double;
  end;

  TMavItemMissao = record
    Comando: Word;
    Frame: Byte;
    P1, P2, P3, P4: Single;
    X, Y: LongInt;          // latitude/longitude * 1e7
    Z: Single;              // altitude (m)
    Ponto: Integer;         // índice do ponto da rota (-1 = item auxiliar)
  end;
  TMavMissao = array of TMavItemMissao;

  TMavEnvioMissao = (meNenhum, meEnviando, meAceita, meFalhou);
  TMavPartida = (mpNenhuma, mpModoGuiado, mpArmando, mpIniciando);

  { TMavlinkProtocol }

  TMavlinkProtocol = class(TBaseProtocol)
  private
    FUdp: TLUDPComponent;
    FSeq: Byte;
    FPeer: string;          // endereço de onde o drone fala (ip:porta)
    FDestinoPadrao: string; // destino antes de ouvir o drone
    FTel: TMavTelemetria;
    FUltimoHeartbeatRx: QWord;
    FUltimoHeartbeatTx: QWord;
    FUltimaPosicao: QWord;
    FUltimoPedidoStreams: QWord;
    FUltimoPedidoHome: QWord;
    FDisconnecting: Boolean;
    FAvisos: TStringList;

    // Envio da missão
    FMissao: TMavMissao;
    FEnvio: TMavEnvioMissao;
    FEnvioTentativas: Integer;
    FEnvioPrazo: QWord;
    FEnvioPedidos: Integer;
    FEnvioMsg: string;

    // Comando com confirmação
    FCmd: Word;
    FCmdP: array[1..7] of Single;
    FCmdTentativas: Integer;
    FCmdPrazo: QWord;
    FCmdAguardando: Boolean;

    // Partida da rota
    FPartida: TMavPartida;
    FPartidaPrazo: QWord;
    FRotaAtiva: Boolean;
    FFoiArmado: Boolean;

    procedure UdpReceive(aSocket: TLSocket);
    procedure UdpError(const msg: string; aSocket: TLSocket);
    procedure Envia(AMsgId, ACrcExtra: Byte; const APayload: array of Byte; ALen: Integer);
    procedure Processa(const B: array of Byte; ALen: Integer; const APeer: string);
    procedure TrataMensagem(AMsgId: LongWord; ASys, AComp: Byte;
      const P: array of Byte; const APeer: string);
    procedure Avisa(const AMsg: string);

    procedure EnviaHeartbeat;
    procedure PedeStreams;
    procedure PedeHome;
    procedure EnviaContagemMissao;
    procedure EnviaItemMissao(ASeq: Word);
    procedure EnviaComandoLong(ACmd: Word; const AP: array of Single; AConfirmacao: Byte);
    procedure Comando(ACmd: Word; P1: Single = 0; P2: Single = 0; P3: Single = 0;
      P4: Single = 0; P5: Single = 0; P6: Single = 0; P7: Single = 0);
    procedure DefineModo(AModoArdu: Cardinal; APx4Principal, APx4Sub: Byte);
    procedure FalhaPartida(const AMotivo: string);
    function GetModoMissao: Boolean;
    function GetModoAutonomo: Boolean;
    function GetMultirrotor: Boolean;
  public
    constructor Create; override;
    destructor Destroy; override;

    { ATcpPort não é usado; AUdpPort = porta UDP (14550). }
    procedure Connect(const AHost: string; ATcpPort, AUdpPort: Integer); override;
    procedure Disconnect; override;
    { Controle manual (X/Y/Z do frmMain, B1/B2 guinada). Ignorado durante a rota
      e nos modos autônomos. }
    procedure SendCommand(AX, AY, AZ, AB1, AB2, AB3, AB4, AB5, AB6: Byte); override;
    procedure Tick;

    { Rota }
    procedure EnviaMissao(const AItens: TMavMissao);
    procedure IniciarMissao;
    procedure Pausar;
    procedure Continuar;
    procedure VoltarPartida;
    procedure Pousar;

    function TextoModo: string;
    function TextoGps: string;
    function ProximoAviso(out AMsg: string): Boolean;

    class function TextoResultadoMissao(ATipo: Integer): string; static;
    class function TextoResultadoComando(AResultado: Integer): string; static;

    property Telemetria: TMavTelemetria read FTel;
    property EnvioMissao: TMavEnvioMissao read FEnvio;
    property EnvioMensagem: string read FEnvioMsg;
    property Missao: TMavMissao read FMissao;
    property Partida: TMavPartida read FPartida;
    property RotaAtiva: Boolean read FRotaAtiva;
    property ModoMissao: Boolean read GetModoMissao;
    property ModoAutonomo: Boolean read GetModoAutonomo;
    property Multirrotor: Boolean read GetMultirrotor;
  end;

implementation

const
  GCS_SYSID = 255;
  GCS_COMPID = 190;

  // Modos do ArduCopter
  ARDU_AUTO = 3;
  ARDU_GUIDED = 4;
  ARDU_LOITER = 5;
  ARDU_RTL = 6;
  ARDU_LAND = 9;
  ARDU_BRAKE = 17;
  ARDU_SMART_RTL = 21;

  // Modos do PX4 (principal / auxiliar)
  PX4_AUTO = 4;
  PX4_AUTO_LOITER = 3;
  PX4_AUTO_MISSION = 4;

  MAV_TYPE_GCS = 6;
  MAV_AUTOPILOT_INVALID = 8;

  PRAZO_ITEM_MS = 2000;
  PRAZO_CMD_MS = 1200;

{ CRC X.25 do MAVLink }

procedure CrcAcc(var Crc: Word; B: Byte); inline;
var
  T: Byte;
begin
  T := B xor Byte(Crc and $FF);
  T := T xor Byte(T shl 4);
  Crc := (Crc shr 8) xor (Word(T) shl 8) xor (Word(T) shl 3) xor (Word(T) shr 4);
end;

{ CRC_EXTRA das mensagens lidas (-1 = mensagem ignorada). }
function CrcExtra(AMsgId: LongWord): Integer;
begin
  case AMsgId of
    0: Result := 50;     // HEARTBEAT
    1: Result := 124;    // SYS_STATUS
    24: Result := 24;    // GPS_RAW_INT
    33: Result := 104;   // GLOBAL_POSITION_INT
    40: Result := 230;   // MISSION_REQUEST
    42: Result := 28;    // MISSION_CURRENT
    46: Result := 11;    // MISSION_ITEM_REACHED
    47: Result := 153;   // MISSION_ACK
    51: Result := 196;   // MISSION_REQUEST_INT
    77: Result := 143;   // COMMAND_ACK
    242: Result := 104;  // HOME_POSITION
    253: Result := 83;   // STATUSTEXT
  else
    Result := -1;
  end;
end;

{ Leitura e escrita little-endian }

function LeU16(const P: array of Byte; O: Integer): Word;
begin
  Result := Word(P[O]) or (Word(P[O + 1]) shl 8);
end;

function LeI16(const P: array of Byte; O: Integer): SmallInt;
begin
  Result := SmallInt(LeU16(P, O));
end;

function LeU32(const P: array of Byte; O: Integer): Cardinal;
begin
  Result := Cardinal(P[O]) or (Cardinal(P[O + 1]) shl 8) or
    (Cardinal(P[O + 2]) shl 16) or (Cardinal(P[O + 3]) shl 24);
end;

function LeI32(const P: array of Byte; O: Integer): LongInt;
begin
  Result := LongInt(LeU32(P, O));
end;

procedure PoeU16(var P: array of Byte; O: Integer; V: Word);
begin
  P[O] := Lo(V);
  P[O + 1] := Hi(V);
end;

procedure PoeU32(var P: array of Byte; O: Integer; V: Cardinal);
begin
  P[O] := V and $FF;
  P[O + 1] := (V shr 8) and $FF;
  P[O + 2] := (V shr 16) and $FF;
  P[O + 3] := (V shr 24) and $FF;
end;

procedure PoeF32(var P: array of Byte; O: Integer; V: Single);
var
  C: Cardinal;
begin
  Move(V, C, 4);
  PoeU32(P, O, C);
end;

function NomeComando(ACmd: Word): string;
begin
  case ACmd of
    MAV_CMD_NAV_RETURN_TO_LAUNCH: Result := 'Voltar ao ponto de partida';
    MAV_CMD_NAV_LAND: Result := 'Pousar';
    MAV_CMD_DO_SET_MODE: Result := 'Mudar modo';
    MAV_CMD_MISSION_START: Result := 'Iniciar missão';
    MAV_CMD_COMPONENT_ARM_DISARM: Result := 'Armar';
  else
    Result := 'Comando ' + IntToStr(ACmd);
  end;
end;

{ TMavlinkProtocol }

constructor TMavlinkProtocol.Create;
begin
  inherited Create;
  FUdp := TLUDPComponent.Create(nil);
  FUdp.OnReceive := @UdpReceive;
  FUdp.OnError := @UdpError;
  FAvisos := TStringList.Create;
  FillChar(FTel, SizeOf(FTel), 0);
  FTel.BateriaPct := -1;
  FTel.Hdop := -1;
  FTel.ItemAtual := -1;
  FTel.ItemAlcancado := -1;
end;

destructor TMavlinkProtocol.Destroy;
begin
  FOnStatus := nil;
  FOnError := nil;
  Disconnect;
  FUdp.Free;
  FAvisos.Free;
  inherited Destroy;
end;

procedure TMavlinkProtocol.Avisa(const AMsg: string);
begin
  FAvisos.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + AMsg);
  while FAvisos.Count > 200 do
    FAvisos.Delete(0);
  DoStatus(AMsg);
end;

function TMavlinkProtocol.ProximoAviso(out AMsg: string): Boolean;
begin
  Result := FAvisos.Count > 0;
  if Result then
  begin
    AMsg := FAvisos[0];
    FAvisos.Delete(0);
  end
  else
    AMsg := '';
end;

procedure TMavlinkProtocol.Connect(const AHost: string; ATcpPort, AUdpPort: Integer);
begin
  Disconnect;
  FHost := Trim(AHost);
  FUdpPort := AUdpPort;
  if FUdpPort <= 0 then
    FUdpPort := MAV_PORTA_PADRAO;

  FillChar(FTel, SizeOf(FTel), 0);
  FTel.BateriaPct := -1;
  FTel.Hdop := -1;
  FTel.ItemAtual := -1;
  FTel.ItemAlcancado := -1;
  FPeer := '';
  if FHost <> '' then
    FDestinoPadrao := FHost + ':' + IntToStr(FUdpPort)
  else
    FDestinoPadrao := '';
  FEnvio := meNenhum;
  FPartida := mpNenhuma;
  FRotaAtiva := False;
  FFoiArmado := False;
  FCmdAguardando := False;
  FUltimoPedidoStreams := 0;
  FUltimoPedidoHome := 0;
  FDisconnecting := False;

  Avisa(Format('MAVLink: escutando UDP %d (drone em %s)...', [FUdpPort, FHost]));
  try
    // Escuta na porta local (o drone ou a ponte enviam para cá) e responde ao
    // endereço de onde o drone falou. Connect do lNet não liga a porta local.
    if not FUdp.Listen(FUdpPort) then
    begin
      DoError('Não foi possível abrir a porta UDP ' + IntToStr(FUdpPort) +
        ' (outro programa, como o Mission Planner, pode estar usando-a).');
      Exit;
    end;
  except
    on E: Exception do
    begin
      DoError('Erro MAVLink UDP: ' + E.Message);
      Exit;
    end;
  end;
  FActive := True;
  EnviaHeartbeat;
  FUltimoHeartbeatTx := GetTickCount64;
end;

procedure TMavlinkProtocol.Disconnect;
begin
  FDisconnecting := True;
  try
    if FUdp.Connected then
      FUdp.Disconnect(True);
  except
  end;
  if FActive then
    Avisa('MAVLink desconectado.');
  FActive := False;
  FTel.Conectado := False;
  FRotaAtiva := False;
  FPartida := mpNenhuma;
  FCmdAguardando := False;
  if FEnvio = meEnviando then
    FEnvio := meFalhou;
  FDisconnecting := False;
end;

procedure TMavlinkProtocol.Envia(AMsgId, ACrcExtra: Byte;
  const APayload: array of Byte; ALen: Integer);
var
  Pkt: array[0..263] of Byte;
  I: Integer;
  Crc: Word;
begin
  if (not FActive) or (not FUdp.Connected) then
    Exit;
  Pkt[0] := $FE;
  Pkt[1] := ALen;
  Pkt[2] := FSeq;
  Pkt[3] := GCS_SYSID;
  Pkt[4] := GCS_COMPID;
  Pkt[5] := AMsgId;
  if ALen > 0 then
    Move(APayload[0], Pkt[6], ALen);
  Crc := $FFFF;
  for I := 1 to 5 + ALen do
    CrcAcc(Crc, Pkt[I]);
  CrcAcc(Crc, ACrcExtra);
  Pkt[6 + ALen] := Lo(Crc);
  Pkt[7 + ALen] := Hi(Crc);
  Inc(FSeq);
  try
    if FPeer <> '' then
      FUdp.Send(Pkt[0], ALen + 8, FPeer)
    else if FDestinoPadrao <> '' then
      FUdp.Send(Pkt[0], ALen + 8, FDestinoPadrao);
  except
  end;
end;

procedure TMavlinkProtocol.EnviaHeartbeat;
var
  P: array[0..8] of Byte;
begin
  FillChar(P, SizeOf(P), 0);
  P[4] := MAV_TYPE_GCS;            // type: estação de solo
  P[5] := MAV_AUTOPILOT_INVALID;   // autopilot
  P[6] := 0;                       // base_mode
  P[7] := 4;                       // system_status: ATIVO
  P[8] := 3;                       // versão do MAVLink
  Envia(0, 50, P, 9);
end;

procedure TMavlinkProtocol.PedeStreams;
var
  P: array[0..5] of Byte;
begin
  // REQUEST_DATA_STREAM (ArduPilot): todos os grupos a 4 Hz.
  PoeU16(P, 0, 4);
  P[2] := FTel.SysId;
  P[3] := FTel.CompId;
  P[4] := 0;   // MAV_DATA_STREAM_ALL
  P[5] := 1;   // iniciar
  Envia(66, 148, P, 6);
  FUltimoPedidoStreams := GetTickCount64;
end;

procedure TMavlinkProtocol.PedeHome;
begin
  // Versões novas usam REQUEST_MESSAGE; antigas, GET_HOME_POSITION.
  EnviaComandoLong(MAV_CMD_REQUEST_MESSAGE, [242, 0, 0, 0, 0, 0, 0], 0);
  EnviaComandoLong(MAV_CMD_GET_HOME_POSITION, [0, 0, 0, 0, 0, 0, 0], 0);
  FUltimoPedidoHome := GetTickCount64;
end;

procedure TMavlinkProtocol.EnviaComandoLong(ACmd: Word; const AP: array of Single;
  AConfirmacao: Byte);
var
  P: array[0..32] of Byte;
  I: Integer;
begin
  FillChar(P, SizeOf(P), 0);
  for I := 0 to 6 do
    if I <= High(AP) then
      PoeF32(P, I * 4, AP[I]);
  PoeU16(P, 28, ACmd);
  P[30] := FTel.SysId;
  P[31] := FTel.CompId;
  P[32] := AConfirmacao;
  Envia(76, 152, P, 33);
end;

procedure TMavlinkProtocol.Comando(ACmd: Word; P1, P2, P3, P4, P5, P6, P7: Single);
begin
  FCmd := ACmd;
  FCmdP[1] := P1; FCmdP[2] := P2; FCmdP[3] := P3; FCmdP[4] := P4;
  FCmdP[5] := P5; FCmdP[6] := P6; FCmdP[7] := P7;
  FCmdTentativas := 1;
  FCmdAguardando := True;
  FCmdPrazo := GetTickCount64 + PRAZO_CMD_MS;
  EnviaComandoLong(ACmd, [P1, P2, P3, P4, P5, P6, P7], 0);
end;

procedure TMavlinkProtocol.DefineModo(AModoArdu: Cardinal; APx4Principal, APx4Sub: Byte);
begin
  if FTel.Autopilot = MAV_AUTOPILOT_PX4 then
    Comando(MAV_CMD_DO_SET_MODE, 1, APx4Principal, APx4Sub)
  else
    Comando(MAV_CMD_DO_SET_MODE, 1, AModoArdu);
end;

function TMavlinkProtocol.GetModoMissao: Boolean;
begin
  if FTel.Autopilot = MAV_AUTOPILOT_PX4 then
    Result := (((FTel.CustomMode shr 16) and $FF) = PX4_AUTO) and
      (((FTel.CustomMode shr 24) and $FF) = PX4_AUTO_MISSION)
  else
    Result := FTel.CustomMode = ARDU_AUTO;
end;

function TMavlinkProtocol.GetModoAutonomo: Boolean;
begin
  if FTel.Autopilot = MAV_AUTOPILOT_PX4 then
    Result := ((FTel.CustomMode shr 16) and $FF) = PX4_AUTO
  else
    case FTel.CustomMode of
      ARDU_AUTO, ARDU_GUIDED, ARDU_RTL, ARDU_LAND, ARDU_BRAKE, ARDU_SMART_RTL:
        Result := True;
    else
      Result := False;
    end;
end;

function TMavlinkProtocol.GetMultirrotor: Boolean;
begin
  // quadri, coaxial, helicóptero, hexa, octo, tri, dodeca
  Result := FTel.Tipo in [2, 3, 4, 13, 14, 15, 29];
end;

function TMavlinkProtocol.TextoModo: string;
var
  Principal, Sub: Byte;
begin
  if not FTel.Conectado then
    Exit('-');
  if FTel.Autopilot = MAV_AUTOPILOT_PX4 then
  begin
    Principal := (FTel.CustomMode shr 16) and $FF;
    Sub := (FTel.CustomMode shr 24) and $FF;
    case Principal of
      1: Result := 'MANUAL';
      2: Result := 'ALTITUDE';
      3: Result := 'POSIÇÃO';
      4:
        case Sub of
          1: Result := 'AUTO PRONTO';
          2: Result := 'DECOLAGEM';
          3: Result := 'PAIRANDO (HOLD)';
          4: Result := 'MISSÃO';
          5: Result := 'RETORNO (RTL)';
          6: Result := 'POUSO';
        else
          Result := 'AUTO ' + IntToStr(Sub);
        end;
      5: Result := 'ACRO';
      6: Result := 'OFFBOARD';
      7: Result := 'ESTABILIZADO';
    else
      Result := 'PX4 ' + IntToStr(Principal);
    end;
  end
  else
    case FTel.CustomMode of
      0: Result := 'STABILIZE';
      1: Result := 'ACRO';
      2: Result := 'ALT_HOLD';
      ARDU_AUTO: Result := 'AUTO (MISSÃO)';
      ARDU_GUIDED: Result := 'GUIDED';
      ARDU_LOITER: Result := 'LOITER (PAIRANDO)';
      ARDU_RTL: Result := 'RTL (RETORNO)';
      7: Result := 'CIRCLE';
      ARDU_LAND: Result := 'LAND (POUSO)';
      16: Result := 'POSHOLD';
      ARDU_BRAKE: Result := 'BRAKE';
      ARDU_SMART_RTL: Result := 'SMART_RTL';
    else
      Result := 'MODO ' + IntToStr(FTel.CustomMode);
    end;
  if FTel.Armado then
    Result := Result + ' / ARMADO'
  else
    Result := Result + ' / desarmado';
end;

function TMavlinkProtocol.TextoGps: string;
begin
  if not FTel.Conectado then
    Exit('-');
  case FTel.GpsFix of
    0, 1: Result := 'sem fix';
    2: Result := 'fix 2D';
    3: Result := 'fix 3D';
    4: Result := 'DGPS';
    5: Result := 'RTK flutuante';
    6: Result := 'RTK fixo';
  else
    Result := 'fix ' + IntToStr(FTel.GpsFix);
  end;
  Result := Result + Format(', %d satélites', [FTel.Satelites]);
  if FTel.Hdop >= 0 then
    Result := Result + Format(', HDOP %.1f', [FTel.Hdop]);
end;

class function TMavlinkProtocol.TextoResultadoMissao(ATipo: Integer): string;
begin
  case ATipo of
    0: Result := 'aceita';
    1: Result := 'erro genérico';
    2: Result := 'sistema de coordenadas não suportado';
    3: Result := 'comando não suportado';
    4: Result := 'sem espaço para a missão';
    5: Result := 'missão inválida';
    6..12: Result := 'parâmetro inválido (' + IntToStr(ATipo - 5) + ')';
    13: Result := 'sequência inválida';
    14: Result := 'recusada pelo drone';
    15: Result := 'operação cancelada';
  else
    Result := 'código ' + IntToStr(ATipo);
  end;
end;

class function TMavlinkProtocol.TextoResultadoComando(AResultado: Integer): string;
begin
  case AResultado of
    0: Result := 'aceito';
    1: Result := 'recusado temporariamente';
    2: Result := 'negado';
    3: Result := 'não suportado';
    4: Result := 'falhou';
    5: Result := 'em andamento';
    6: Result := 'cancelado';
  else
    Result := 'código ' + IntToStr(AResultado);
  end;
end;

{ Recepção }

procedure TMavlinkProtocol.UdpReceive(aSocket: TLSocket);
var
  Buf: array[0..4095] of Byte;
  L: Integer;
  Peer: string;
begin
  repeat
    L := aSocket.Get(Buf[0], SizeOf(Buf));
    if L > 0 then
    begin
      Peer := aSocket.PeerAddress + ':' + IntToStr(aSocket.PeerPort);
      Processa(Buf, L, Peer);
    end;
  until L <= 0;
end;

procedure TMavlinkProtocol.Processa(const B: array of Byte; ALen: Integer;
  const APeer: string);
var
  I, N, Tam, Assin, E: Integer;
  Crc: Word;
  MsgId: LongWord;
  P: array[0..255] of Byte;
begin
  I := 0;
  while I < ALen do
  begin
    if (B[I] = $FE) and (I + 8 <= ALen) then
    begin
      // MAVLink 1: FE tam seq sys comp id carga crc
      Tam := B[I + 1];
      if I + 8 + Tam > ALen then
        Exit;
      MsgId := B[I + 5];
      E := CrcExtra(MsgId);
      if E < 0 then
      begin
        Inc(I, 8 + Tam);
        Continue;
      end;
      Crc := $FFFF;
      for N := 1 to 5 + Tam do
        CrcAcc(Crc, B[I + N]);
      CrcAcc(Crc, E);
      if Crc <> (Word(B[I + 6 + Tam]) or (Word(B[I + 7 + Tam]) shl 8)) then
      begin
        Inc(I);
        Continue;
      end;
      FillChar(P, SizeOf(P), 0);
      if Tam > 0 then
        Move(B[I + 6], P[0], Tam);
      TrataMensagem(MsgId, B[I + 3], B[I + 4], P, APeer);
      Inc(I, 8 + Tam);
    end
    else if (B[I] = $FD) and (I + 12 <= ALen) then
    begin
      // MAVLink 2: FD tam incompat compat seq sys comp id(3) carga crc [assinatura]
      Tam := B[I + 1];
      Assin := 0;
      if (B[I + 2] and 1) <> 0 then
        Assin := 13;
      if I + 12 + Tam + Assin > ALen then
        Exit;
      MsgId := LongWord(B[I + 7]) or (LongWord(B[I + 8]) shl 8) or (LongWord(B[I + 9]) shl 16);
      E := CrcExtra(MsgId);
      if E < 0 then
      begin
        Inc(I, 12 + Tam + Assin);
        Continue;
      end;
      Crc := $FFFF;
      for N := 1 to 9 + Tam do
        CrcAcc(Crc, B[I + N]);
      CrcAcc(Crc, E);
      if Crc <> (Word(B[I + 10 + Tam]) or (Word(B[I + 11 + Tam]) shl 8)) then
      begin
        Inc(I);
        Continue;
      end;
      // No MAVLink 2 os zeros finais da carga são omitidos: P já está zerado.
      FillChar(P, SizeOf(P), 0);
      if Tam > 0 then
        Move(B[I + 10], P[0], Tam);
      TrataMensagem(MsgId, B[I + 5], B[I + 6], P, APeer);
      Inc(I, 12 + Tam + Assin);
    end
    else
      Inc(I);
  end;
end;

procedure TMavlinkProtocol.TrataMensagem(AMsgId: LongWord; ASys, AComp: Byte;
  const P: array of Byte; const APeer: string);
var
  Tipo, Auto, Base: Byte;
  Custom: Cardinal;
  EraArmado, EraModoMissao: Boolean;
  ModoAnterior: Cardinal;
  V, Res: Integer;
  Cmd, Seq: Word;
  Txt: string;
  I: Integer;
  VX, VY: Double;
begin
  if AMsgId = 0 then
  begin
    // HEARTBEAT: só aceita o primeiro piloto automático visto (ignora outras
    // estações de solo e periféricos sem piloto automático).
    Tipo := P[4];
    Auto := P[5];
    if (Tipo = MAV_TYPE_GCS) or (Auto = MAV_AUTOPILOT_INVALID) then
      Exit;
    if (FTel.SysId <> 0) and ((ASys <> FTel.SysId) or (AComp <> FTel.CompId)) then
      Exit;

    FPeer := APeer;
    FUltimoHeartbeatRx := GetTickCount64;
    Custom := LeU32(P, 0);
    Base := P[6];
    EraArmado := FTel.Armado;
    EraModoMissao := ModoMissao;
    ModoAnterior := FTel.CustomMode;

    if not FTel.Conectado then
    begin
      FTel.SysId := ASys;
      FTel.CompId := AComp;
      FTel.Tipo := Tipo;
      FTel.Autopilot := Auto;
      FTel.CustomMode := Custom;
      FTel.BaseMode := Base;
      FTel.Armado := (Base and 128) <> 0;
      FTel.Conectado := True;
      if Auto = MAV_AUTOPILOT_ARDUPILOT then
        Txt := 'ArduPilot'
      else if Auto = MAV_AUTOPILOT_PX4 then
        Txt := 'PX4'
      else
        Txt := 'piloto automático ' + IntToStr(Auto);
      Avisa(Format('Drone encontrado: %s, sistema %d (%s). Modo %s.',
        [Txt, ASys, APeer, TextoModo]));
      if not Multirrotor then
        Avisa('Atenção: este veículo não é um multirrotor; a rota é feita para multirrotores.');
      PedeStreams;
      PedeHome;
      Exit;
    end;

    FTel.Tipo := Tipo;
    FTel.Autopilot := Auto;
    FTel.CustomMode := Custom;
    FTel.BaseMode := Base;
    FTel.Armado := (Base and 128) <> 0;

    if FTel.Armado and not EraArmado then
    begin
      FFoiArmado := True;
      Avisa('Drone ARMADO.');
    end
    else if EraArmado and not FTel.Armado then
    begin
      Avisa('Drone desarmado.');
      if FRotaAtiva and FFoiArmado then
      begin
        FRotaAtiva := False;
        Avisa('Rota encerrada (drone pousado e desarmado).');
      end;
      FFoiArmado := False;
    end;
    if Custom <> ModoAnterior then
      Avisa('Modo: ' + TextoModo);
    if ModoMissao and not EraModoMissao and (FPartida = mpIniciando) then
    begin
      FPartida := mpNenhuma;
      Avisa('Rota em execução.');
    end;
    Exit;
  end;

  // Demais mensagens: só do drone já identificado.
  if (FTel.SysId = 0) or (ASys <> FTel.SysId) then
    Exit;

  case AMsgId of
    1: // SYS_STATUS
      begin
        V := LeU16(P, 14);
        if V <> 65535 then
          FTel.BateriaV := V / 1000;
        FTel.BateriaPct := ShortInt(P[30]);
      end;
    24: // GPS_RAW_INT
      begin
        FTel.GpsFix := P[28];
        FTel.Satelites := P[29];
        V := LeU16(P, 20);
        if V <> 65535 then
          FTel.Hdop := V / 100
        else
          FTel.Hdop := -1;
      end;
    33: // GLOBAL_POSITION_INT
      begin
        FTel.Lat := LeI32(P, 4) / 1e7;
        FTel.Lon := LeI32(P, 8) / 1e7;
        FTel.AltRelativa := LeI32(P, 16) / 1000;
        VX := LeI16(P, 20) / 100;
        VY := LeI16(P, 22) / 100;
        FTel.VelSolo := Sqrt(Sqr(VX) + Sqr(VY));
        V := LeU16(P, 26);
        if V <> 65535 then
          FTel.Rumo := V / 100;
        FTel.PosValida := (FTel.Lat <> 0) or (FTel.Lon <> 0);
        FUltimaPosicao := GetTickCount64;
      end;
    242: // HOME_POSITION
      begin
        FTel.HomeLat := LeI32(P, 0) / 1e7;
        FTel.HomeLon := LeI32(P, 4) / 1e7;
        if (FTel.HomeLat <> 0) or (FTel.HomeLon <> 0) then
        begin
          if not FTel.HomeValido then
            Avisa(Format('Ponto de partida do drone: %.6f, %.6f',
              [FTel.HomeLat, FTel.HomeLon]));
          FTel.HomeValido := True;
        end;
      end;
    42: // MISSION_CURRENT
      FTel.ItemAtual := LeU16(P, 0);
    46: // MISSION_ITEM_REACHED
      FTel.ItemAlcancado := LeU16(P, 0);
    40, 51: // MISSION_REQUEST / MISSION_REQUEST_INT
      if (FEnvio = meEnviando) and (P[2] = GCS_SYSID) then
      begin
        Seq := LeU16(P, 0);
        if Seq < Length(FMissao) then
        begin
          EnviaItemMissao(Seq);
          Inc(FEnvioPedidos);
          FEnvioPrazo := GetTickCount64 + PRAZO_ITEM_MS;
        end;
      end;
    47: // MISSION_ACK
      if (FEnvio = meEnviando) and (P[0] = GCS_SYSID) and (P[3] = 0) then
      begin
        Res := P[2];
        if Res = 0 then
        begin
          FEnvio := meAceita;
          FEnvioMsg := Format('Rota aceita pelo drone (%d itens).', [Length(FMissao)]);
        end
        else
        begin
          FEnvio := meFalhou;
          FEnvioMsg := 'O drone recusou a rota: ' + TextoResultadoMissao(Res) + '.';
        end;
        Avisa(FEnvioMsg);
      end;
    77: // COMMAND_ACK
      begin
        Cmd := LeU16(P, 0);
        Res := P[2];
        if FCmdAguardando and (Cmd = FCmd) and (Res <> 5) then
        begin
          FCmdAguardando := False;
          if Res <> 0 then
            Avisa(NomeComando(Cmd) + ': ' + TextoResultadoComando(Res) + '.');
        end;
        case FPartida of
          mpModoGuiado:
            if (Cmd = MAV_CMD_DO_SET_MODE) and (Res <> 0) and (Res <> 5) then
              FalhaPartida('o drone não aceitou o modo GUIDED');
          mpArmando:
            if (Cmd = MAV_CMD_COMPONENT_ARM_DISARM) and (Res <> 0) and (Res <> 5) then
              FalhaPartida('o drone não armou (veja as mensagens "PreArm")');
          mpIniciando:
            if Cmd = MAV_CMD_MISSION_START then
            begin
              if Res = 0 then
              begin
                FPartida := mpNenhuma;
                Avisa('Rota iniciada pelo drone.');
              end
              else if Res <> 5 then
                FalhaPartida('o drone recusou o início da missão');
            end;
        end;
      end;
    253: // STATUSTEXT
      begin
        Txt := '';
        for I := 1 to 50 do
        begin
          if P[I] = 0 then
            Break;
          Txt := Txt + Chr(P[I]);
        end;
        if Txt <> '' then
          Avisa('Drone: ' + Txt);
      end;
  end;
end;

procedure TMavlinkProtocol.UdpError(const msg: string; aSocket: TLSocket);
begin
  if not FDisconnecting then
    DoError('MAVLink UDP: ' + msg);
end;

{ Controle manual }

procedure TMavlinkProtocol.SendCommand(AX, AY, AZ, AB1, AB2, AB3, AB4, AB5, AB6: Byte);
var
  P: array[0..10] of Byte;
  Pitch, Roll, Thr, Yaw: SmallInt;
begin
  if (not FActive) or (not FTel.Conectado) then
    Exit;
  // Rota ou modo autônomo: as entradas manuais não podem interferir.
  if FRotaAtiva or ModoAutonomo or (FPartida <> mpNenhuma) then
    Exit;

  { No frmMain X cresce para a ESQUERDA e Y para a FRENTE.
    MANUAL_CONTROL: x = arfagem (+ frente), y = rolagem (+ direita),
    z = aceleração 0..1000, r = guinada (+ direita). }
  Pitch := EnsureRange(Round((Integer(AY) - 127) * 1000 / 127), -1000, 1000);
  Roll := EnsureRange(Round((127 - Integer(AX)) * 1000 / 127), -1000, 1000);
  Thr := EnsureRange(Round(Integer(AZ) * 1000 / 255), 0, 1000);
  Yaw := 0;
  if (AB1 = 255) and (AB2 <> 255) then
    Yaw := -500
  else if (AB2 = 255) and (AB1 <> 255) then
    Yaw := 500;

  PoeU16(P, 0, Word(Pitch));
  PoeU16(P, 2, Word(Roll));
  PoeU16(P, 4, Word(Thr));
  PoeU16(P, 6, Word(Yaw));
  PoeU16(P, 8, 0);          // botões
  P[10] := FTel.SysId;      // alvo
  Envia(69, 243, P, 11);
end;

{ Missão }

procedure TMavlinkProtocol.EnviaContagemMissao;
var
  P: array[0..3] of Byte;
begin
  PoeU16(P, 0, Length(FMissao));
  P[2] := FTel.SysId;
  P[3] := FTel.CompId;
  Envia(44, 221, P, 4);
end;

procedure TMavlinkProtocol.EnviaItemMissao(ASeq: Word);
var
  P: array[0..36] of Byte;
  It: TMavItemMissao;
begin
  It := FMissao[ASeq];
  FillChar(P, SizeOf(P), 0);
  PoeF32(P, 0, It.P1);
  PoeF32(P, 4, It.P2);
  PoeF32(P, 8, It.P3);
  PoeF32(P, 12, It.P4);
  PoeU32(P, 16, Cardinal(It.X));
  PoeU32(P, 20, Cardinal(It.Y));
  PoeF32(P, 24, It.Z);
  PoeU16(P, 28, ASeq);
  PoeU16(P, 30, It.Comando);
  P[32] := FTel.SysId;
  P[33] := FTel.CompId;
  P[34] := It.Frame;
  P[35] := 0;   // current
  P[36] := 1;   // autocontinue
  Envia(73, 38, P, 37);
end;

procedure TMavlinkProtocol.EnviaMissao(const AItens: TMavMissao);
begin
  if not FTel.Conectado then
  begin
    FEnvio := meFalhou;
    FEnvioMsg := 'Sem conexão com o drone.';
    Avisa(FEnvioMsg);
    Exit;
  end;
  if FRotaAtiva or FTel.Armado then
  begin
    FEnvio := meFalhou;
    FEnvioMsg := 'Não é possível trocar a rota com o drone armado.';
    Avisa(FEnvioMsg);
    Exit;
  end;
  FMissao := Copy(AItens);
  FEnvio := meEnviando;
  FEnvioTentativas := 1;
  FEnvioPedidos := 0;
  FEnvioMsg := 'Enviando rota...';
  FEnvioPrazo := GetTickCount64 + PRAZO_ITEM_MS;
  Avisa(Format('Enviando rota ao drone (%d itens)...', [Length(FMissao)]));
  EnviaContagemMissao;
end;

procedure TMavlinkProtocol.FalhaPartida(const AMotivo: string);
begin
  FPartida := mpNenhuma;
  FRotaAtiva := False;
  Avisa('Rota NÃO iniciada: ' + AMotivo + '.');
end;

procedure TMavlinkProtocol.IniciarMissao;
begin
  if FEnvio <> meAceita then
  begin
    Avisa('Envie a rota ao drone antes de iniciar.');
    Exit;
  end;
  FRotaAtiva := True;
  FTel.ItemAlcancado := -1;
  if FTel.Armado then
  begin
    // Já armado (no ar ou no chão): só inicia a missão.
    FPartida := mpIniciando;
    FPartidaPrazo := GetTickCount64 + 6000;
    Comando(MAV_CMD_MISSION_START, 0, 0);
  end
  else if FTel.Autopilot = MAV_AUTOPILOT_PX4 then
  begin
    FPartida := mpArmando;
    FPartidaPrazo := GetTickCount64 + 6000;
    Avisa('Armando o drone...');
    Comando(MAV_CMD_COMPONENT_ARM_DISARM, 1);
  end
  else
  begin
    // ArduCopter não arma em AUTO: arma em GUIDED e depois inicia a missão.
    FPartida := mpModoGuiado;
    FPartidaPrazo := GetTickCount64 + 4000;
    Avisa('Preparando partida (modo GUIDED)...');
    DefineModo(ARDU_GUIDED, 0, 0);
  end;
end;

procedure TMavlinkProtocol.Pausar;
begin
  Avisa('Pausando: o drone vai pairar no lugar.');
  DefineModo(ARDU_LOITER, PX4_AUTO, PX4_AUTO_LOITER);
end;

procedure TMavlinkProtocol.Continuar;
begin
  FRotaAtiva := True;
  Avisa('Retomando a rota.');
  DefineModo(ARDU_AUTO, PX4_AUTO, PX4_AUTO_MISSION);
end;

procedure TMavlinkProtocol.VoltarPartida;
begin
  FPartida := mpNenhuma;
  Avisa('Voltando ao ponto de partida (RTL).');
  Comando(MAV_CMD_NAV_RETURN_TO_LAUNCH);
end;

procedure TMavlinkProtocol.Pousar;
begin
  FPartida := mpNenhuma;
  Avisa('Pousando no local atual.');
  Comando(MAV_CMD_NAV_LAND, 0, 0, 0, NaN, NaN, NaN, 0);
end;

{ Tick }

procedure TMavlinkProtocol.Tick;
var
  Agora: QWord;
  I: Integer;
  P: array[0..6] of Single;
begin
  if not FActive then
    Exit;
  Agora := GetTickCount64;

  if Agora - FUltimoHeartbeatTx >= 1000 then
  begin
    EnviaHeartbeat;
    FUltimoHeartbeatTx := Agora;
  end;

  if FTel.Conectado and (Agora - FUltimoHeartbeatRx > 3000) then
  begin
    FTel.Conectado := False;
    Avisa('Sem sinal do drone há 3 s.');
  end;

  if FTel.Conectado then
  begin
    // Telemetria parada (ou nunca pedida com sucesso): pede de novo.
    if (Agora - FUltimaPosicao > 3000) and (Agora - FUltimoPedidoStreams > 5000) then
      PedeStreams;
    if (not FTel.HomeValido) and FTel.PosValida and (Agora - FUltimoPedidoHome > 5000) then
      PedeHome;
  end;

  // Envio da missão: o drone pede item a item; sem pedido no prazo, recomeça.
  if (FEnvio = meEnviando) and (Agora > FEnvioPrazo) then
  begin
    if FEnvioTentativas >= 5 then
    begin
      FEnvio := meFalhou;
      FEnvioMsg := 'O drone não respondeu ao envio da rota.';
      Avisa(FEnvioMsg);
    end
    else
    begin
      Inc(FEnvioTentativas);
      FEnvioPrazo := Agora + PRAZO_ITEM_MS;
      if FEnvioPedidos = 0 then
        EnviaContagemMissao;   // a contagem se perdeu: reenvia
    end;
  end;

  // Comando sem confirmação: reenvia até 3 vezes.
  if FCmdAguardando and (Agora > FCmdPrazo) then
  begin
    if FCmdTentativas >= 3 then
    begin
      FCmdAguardando := False;
      Avisa(NomeComando(FCmd) + ': sem resposta do drone.');
    end
    else
    begin
      for I := 0 to 6 do
        P[I] := FCmdP[I + 1];
      EnviaComandoLong(FCmd, P, FCmdTentativas);
      Inc(FCmdTentativas);
      FCmdPrazo := Agora + PRAZO_CMD_MS;
    end;
  end;

  // Partida da rota
  case FPartida of
    mpModoGuiado:
      if FTel.CustomMode = ARDU_GUIDED then
      begin
        FPartida := mpArmando;
        FPartidaPrazo := Agora + 6000;
        Avisa('Armando o drone...');
        Comando(MAV_CMD_COMPONENT_ARM_DISARM, 1);
      end
      else if Agora > FPartidaPrazo then
        FalhaPartida('o drone não entrou no modo GUIDED');
    mpArmando:
      if FTel.Armado then
      begin
        FPartida := mpIniciando;
        FPartidaPrazo := Agora + 6000;
        Avisa('Iniciando a rota...');
        Comando(MAV_CMD_MISSION_START, 0, 0);
      end
      else if Agora > FPartidaPrazo then
        FalhaPartida('o drone não armou (veja as mensagens "PreArm")');
    mpIniciando:
      if ModoMissao then
      begin
        FPartida := mpNenhuma;
        Avisa('Rota em execução.');
      end
      else if Agora > FPartidaPrazo then
        FalhaPartida('o drone não entrou no modo de missão');
  end;
end;

end.
