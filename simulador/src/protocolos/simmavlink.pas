unit simmavlink;

{ Emulador MAVLink que se apresenta como ArduCopter (quadricóptero).

  Rede: abre a porta UDP local PortaLocal (padrão 14551) e envia para o
  cockpit em IPCockpit:PortaCockpit (padrão 127.0.0.1:14550), como o SITL.
  O componente TAIDroneMavlink escuta na 14550 e responde para quem falou.

  Envia (MAVLink 1, sistema 1, componente 1):
    HEARTBEAT 1 Hz, SYS_STATUS / GPS_RAW_INT / GLOBAL_POSITION_INT 4 Hz,
    HOME_POSITION 1 Hz e quando pedido, COMMAND_ACK, MISSION_REQUEST_INT,
    MISSION_ACK, MISSION_CURRENT, MISSION_ITEM_REACHED, STATUSTEXT.
  Recebe (MAVLink 1 e 2):
    HEARTBEAT da estação, MANUAL_CONTROL, COMMAND_LONG, MISSION_COUNT,
    MISSION_ITEM_INT.

  Modos ArduCopter: 0 STABILIZE, 2 ALT_HOLD, 3 AUTO, 4 GUIDED, 5 LOITER,
  6 RTL, 9 LAND, 17 BRAKE.

  Falhas: perda de enlace com o drone armado no ar por 5 s -> RTL;
  bateria < 15% -> RTL, < 8% -> LAND; perda de GPS -> LAND. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, simtipos, simgeo, simrede, simemulador;

const
  MAV_PORTA_LOCAL = 14551;
  MAV_PORTA_COCKPIT = 14550;

  MODO_STABILIZE = 0;
  MODO_ALT_HOLD = 2;
  MODO_AUTO = 3;
  MODO_GUIDED = 4;
  MODO_LOITER = 5;
  MODO_RTL = 6;
  MODO_LAND = 9;
  MODO_BRAKE = 17;

type
  TItemMissao = record
    Comando: Word;
    Quadro: Byte;
    P1, P2, P3, P4: Single;
    Lat, Lon: Double;
    Alt: Single;
  end;

  TFaseRTL = (rtlSubindo, rtlIndo, rtlDescendo);

  { TEmuladorMavlink }

  TEmuladorMavlink = class(TEmulador)
  private
    FCanal: Integer;
    FIPCockpit: string;
    FPortaCockpit: Integer;
    FPortaLocal: Integer;
    FSeq: Byte;
    FModo: LongWord;
    FArmado: Boolean;
    FArmadoEm: QWord;
    FManual: array[0..3] of SmallInt;   // x arfagem, y rolagem, z aceleração, r guinada
    FUltimoManual: QWord;
    FUltimoGcs: QWord;
    FProxHb, FProxTel, FProxHome, FProxMissao: QWord;
    FAlvoX, FAlvoY, FAlvoZ: Double;
    FAlvoDefinido: Boolean;
    FVelocidade: Double;
    FFaseRTL: TFaseRTL;
    FMissao: array of TItemMissao;
    FRecebendo: Integer;            // itens esperados (-1 = nenhum envio)
    FProxPedido: Integer;
    FPrazoPedido: QWord;
    FTentativas: Integer;
    FItemAtual: Integer;
    FEsperaAte: QWord;
    FPendenteHome: Boolean;
    FAvisos: TStringList;
    FFailsafeBateria: Integer;
    FAvisouGps: Boolean;
    procedure EnviaMsg(AId, ACrcExtra: Byte; const P: array of Byte; ATam: Integer);
    procedure EnviaHeartbeat;
    procedure EnviaTelemetria(const AE: TEstadoVoo);
    procedure EnviaHome;
    procedure EnviaAck(ACmd: Word; AResultado: Byte);
    procedure EnviaTexto(ASeveridade: Byte; const ATexto: string);
    procedure EnviaPedidoItem(ASeq: Integer);
    procedure EnviaMissaoAck(ATipo: Byte);
    procedure EnviaItemAtual;
    procedure EnviaItemAlcancado(ASeq: Integer);
    procedure Trata(AId: LongWord; const P: TBytes);
    procedure TrataComando(const P: TBytes);
    procedure MudaModo(AModo: LongWord; const AMotivo: string);
    function ModoTexto(AModo: LongWord): string;
    function Armar(out AMotivo: string): Boolean;
    procedure Avisa(const ATexto: string);
    procedure IniciaItem(AIndice: Integer; const AE: TEstadoVoo);
  protected
    function AbreCanais: Boolean; override;
    procedure Processa(ACanal: Integer; const ABuf: TBytes; const ADe: TEndereco); override;
    procedure Periodico(AAgora: QWord); override;
  public
    constructor Create(const AParam: TParametrosModelo; const AOrigem: TPontoGeo;
      ALeEstado: TLeEstado; ALeFalhas: TLeFalhas); override;
    destructor Destroy; override;
    procedure ReiniciaEstado; override;
    function MontaComando(const AE: TEstadoVoo): TComandoVoo; override;
    function Descricao: string; override;
    property IPCockpit: string read FIPCockpit write FIPCockpit;
    property PortaCockpit: Integer read FPortaCockpit write FPortaCockpit;
    property PortaLocal: Integer read FPortaLocal write FPortaLocal;
  end;

function MavCrcExtra(AId: LongWord): Integer;
procedure MavCrcAcc(var ACrc: Word; AByte: Byte);

implementation

const
  SYSID = 1;
  COMPID = 1;
  GCS_SYSID = 255;
  GCS_COMPID = 190;

  CMD_WAYPOINT = 16;
  CMD_LOITER_UNLIM = 17;
  CMD_RTL = 20;
  CMD_LAND = 21;
  CMD_TAKEOFF = 22;
  CMD_SET_MODE = 176;
  CMD_CHANGE_SPEED = 178;
  CMD_MISSION_START = 300;
  CMD_ARM = 400;
  CMD_GET_HOME = 410;
  CMD_REQUEST_MESSAGE = 512;

  RES_ACEITO = 0;
  RES_RECUSADO = 2;
  RES_SEM_SUPORTE = 3;
  RES_FALHOU = 4;

procedure MavCrcAcc(var ACrc: Word; AByte: Byte);
var
  T: Byte;
begin
  T := AByte xor Lo(ACrc);
  T := T xor Byte(T shl 4);
  ACrc := Word((ACrc shr 8) xor (Word(T) shl 8) xor (Word(T) shl 3) xor (Word(T) shr 4));
end;

function MavCrcExtra(AId: LongWord): Integer;
begin
  case AId of
    0: Result := 50;     // HEARTBEAT
    1: Result := 124;    // SYS_STATUS
    24: Result := 24;    // GPS_RAW_INT
    33: Result := 104;   // GLOBAL_POSITION_INT
    42: Result := 28;    // MISSION_CURRENT
    44: Result := 221;   // MISSION_COUNT
    46: Result := 11;    // MISSION_ITEM_REACHED
    47: Result := 153;   // MISSION_ACK
    51: Result := 196;   // MISSION_REQUEST_INT
    66: Result := 148;   // REQUEST_DATA_STREAM
    69: Result := 243;   // MANUAL_CONTROL
    73: Result := 38;    // MISSION_ITEM_INT
    76: Result := 152;   // COMMAND_LONG
    77: Result := 143;   // COMMAND_ACK
    242: Result := 104;  // HOME_POSITION
    253: Result := 83;   // STATUSTEXT
  else
    Result := -1;
  end;
end;

{ TEmuladorMavlink }

constructor TEmuladorMavlink.Create(const AParam: TParametrosModelo; const AOrigem: TPontoGeo;
  ALeEstado: TLeEstado; ALeFalhas: TLeFalhas);
begin
  inherited Create(AParam, AOrigem, ALeEstado, ALeFalhas);
  FIPCockpit := '127.0.0.1';
  FPortaCockpit := MAV_PORTA_COCKPIT;
  FPortaLocal := MAV_PORTA_LOCAL;
  FModo := MODO_LOITER;
  FRecebendo := -1;
  FVelocidade := 5;
  FAvisos := TStringList.Create;
end;

destructor TEmuladorMavlink.Destroy;
begin
  inherited Destroy;
  FAvisos.Free;
end;

function TEmuladorMavlink.AbreCanais: Boolean;
begin
  FCanal := AdicionaCanal(FPortaLocal);
  Result := FCanal >= 0;
end;

function TEmuladorMavlink.Descricao: string;
begin
  Result := Format('MAVLink (ArduCopter): UDP local %d enviando para %s:%d',
    [FPortaLocal, FIPCockpit, FPortaCockpit]);
end;

function TEmuladorMavlink.ModoTexto(AModo: LongWord): string;
begin
  case AModo of
    MODO_STABILIZE: Result := 'STABILIZE';
    MODO_ALT_HOLD: Result := 'ALT_HOLD';
    MODO_AUTO: Result := 'AUTO';
    MODO_GUIDED: Result := 'GUIDED';
    MODO_LOITER: Result := 'LOITER';
    MODO_RTL: Result := 'RTL';
    MODO_LAND: Result := 'LAND';
    MODO_BRAKE: Result := 'BRAKE';
  else
    Result := 'modo ' + IntToStr(AModo);
  end;
end;

procedure TEmuladorMavlink.Avisa(const ATexto: string);
begin
  Log(ATexto);
  FAvisos.Add(ATexto);
end;

procedure TEmuladorMavlink.EnviaMsg(AId, ACrcExtra: Byte; const P: array of Byte; ATam: Integer);
var
  Pkt: array[0..263] of Byte;
  I: Integer;
  Crc: Word;
begin
  Pkt[0] := $FE;
  Pkt[1] := ATam;
  Pkt[2] := FSeq;
  Pkt[3] := SYSID;
  Pkt[4] := COMPID;
  Pkt[5] := AId;
  if ATam > 0 then
    Move(P[0], Pkt[6], ATam);
  Crc := $FFFF;
  for I := 1 to 5 + ATam do
    MavCrcAcc(Crc, Pkt[I]);
  MavCrcAcc(Crc, ACrcExtra);
  Pkt[6 + ATam] := Lo(Crc);
  Pkt[7 + ATam] := Hi(Crc);
  Inc(FSeq);
  Envia(FCanal, Pkt, ATam + 8, FIPCockpit, FPortaCockpit);
end;

procedure TEmuladorMavlink.EnviaHeartbeat;
var
  P: array[0..8] of Byte;
  Base: Byte;
begin
  FillChar(P, SizeOf(P), 0);
  PoeU32(P, 0, FModo);
  P[4] := 2;    // MAV_TYPE_QUADROTOR
  P[5] := 3;    // MAV_AUTOPILOT_ARDUPILOTMEGA
  Base := 1 or 16;  // modo próprio + estabilizado
  if FArmado then
    Base := Base or 128;
  P[6] := Base;
  if FArmado then
    P[7] := 4   // ATIVO
  else
    P[7] := 3;  // EM ESPERA
  P[8] := 3;
  EnviaMsg(0, 50, P, 9);
end;

procedure TEmuladorMavlink.EnviaTelemetria(const AE: TEstadoVoo);
var
  P: array[0..51] of Byte;
  F: TFalhas;
  Fix, Sat: Byte;
  Vel: Double;
begin
  F := Falhas;
  // SYS_STATUS
  FillChar(P, SizeOf(P), 0);
  PoeU16(P, 14, Word(Round(10500 + 2100 * AE.Bateria / 100))); // 3S: 10,5..12,6 V
  PoeU16(P, 16, Word(SmallInt(Round(AE.Empuxo * 2000))));
  P[30] := Byte(ShortInt(Round(AE.Bateria)));
  EnviaMsg(1, 124, P, 31);
  // GPS_RAW_INT
  if F.PerdaGPS then
  begin
    Fix := 0;
    Sat := 0;
  end
  else
  begin
    Fix := 3;
    Sat := 14;
  end;
  FillChar(P, SizeOf(P), 0);
  PoeU32(P, 8, LongWord(LongInt(Round(AE.Lat * 1e7))));
  PoeU32(P, 12, LongWord(LongInt(Round(AE.Lon * 1e7))));
  PoeU32(P, 16, LongWord(LongInt(Round(AE.Z * 1000))));
  if Fix >= 3 then
    PoeU16(P, 20, 80)
  else
    PoeU16(P, 20, 65535);
  PoeU16(P, 22, 120);
  Vel := Hypot(AE.VX, AE.VY);
  PoeU16(P, 24, Word(Round(Vel * 100)));
  PoeU16(P, 26, Word(Round(AE.Rumo * 100)));
  P[28] := Fix;
  P[29] := Sat;
  EnviaMsg(24, 24, P, 30);
  if F.PerdaGPS then
    Exit;
  // GLOBAL_POSITION_INT
  FillChar(P, SizeOf(P), 0);
  PoeU32(P, 0, LongWord(GetTickCount64 and $FFFFFFFF));
  PoeU32(P, 4, LongWord(LongInt(Round(AE.Lat * 1e7))));
  PoeU32(P, 8, LongWord(LongInt(Round(AE.Lon * 1e7))));
  PoeU32(P, 12, LongWord(LongInt(Round(AE.Z * 1000))));
  PoeU32(P, 16, LongWord(LongInt(Round(AE.Z * 1000))));
  PoeU16(P, 20, Word(SmallInt(Round(AE.VY * 100))));  // norte
  PoeU16(P, 22, Word(SmallInt(Round(AE.VX * 100))));  // leste
  PoeU16(P, 24, Word(SmallInt(Round(-AE.VZ * 100)))); // para baixo
  PoeU16(P, 26, Word(Round(AE.Rumo * 100) mod 36000));
  EnviaMsg(33, 104, P, 28);
end;

procedure TEmuladorMavlink.EnviaHome;
var
  P: array[0..51] of Byte;
begin
  FillChar(P, SizeOf(P), 0);
  PoeU32(P, 0, LongWord(LongInt(Round(FOrigem.Lat * 1e7))));
  PoeU32(P, 4, LongWord(LongInt(Round(FOrigem.Lon * 1e7))));
  PoeF32(P, 24, 1); // quatérnio identidade
  EnviaMsg(242, 104, P, 52);
end;

procedure TEmuladorMavlink.EnviaAck(ACmd: Word; AResultado: Byte);
var
  P: array[0..2] of Byte;
begin
  PoeU16(P, 0, ACmd);
  P[2] := AResultado;
  EnviaMsg(77, 143, P, 3);
end;

function SemAcentos(const ATexto: string): string;
const
  DE: array[0..23] of string = ('á','à','ã','â','é','ê','í','ó','ô','õ','ú','ç',
    'Á','À','Ã','Â','É','Ê','Í','Ó','Ô','Õ','Ú','Ç');
  PARA: array[0..23] of string = ('a','a','a','a','e','e','i','o','o','o','u','c',
    'A','A','A','A','E','E','I','O','O','O','U','C');
var
  I: Integer;
begin
  // STATUSTEXT é ASCII: as estações de solo mostram acentos UTF-8 quebrados.
  Result := ATexto;
  for I := 0 to High(DE) do
    Result := StringReplace(Result, DE[I], PARA[I], [rfReplaceAll]);
  Result := StringReplace(Result, '°', ' graus', [rfReplaceAll]);
end;

procedure TEmuladorMavlink.EnviaTexto(ASeveridade: Byte; const ATexto: string);
var
  P: array[0..50] of Byte;
  S: string;
begin
  FillChar(P, SizeOf(P), 0);
  P[0] := ASeveridade;
  S := Copy(SemAcentos(ATexto), 1, 50);
  if S <> '' then
    Move(S[1], P[1], Length(S));
  EnviaMsg(253, 83, P, 51);
end;

procedure TEmuladorMavlink.EnviaPedidoItem(ASeq: Integer);
var
  P: array[0..3] of Byte;
begin
  PoeU16(P, 0, Word(ASeq));
  P[2] := GCS_SYSID;
  P[3] := GCS_COMPID;
  EnviaMsg(51, 196, P, 4);
  FPrazoPedido := Agora + 1000;
end;

procedure TEmuladorMavlink.EnviaMissaoAck(ATipo: Byte);
var
  P: array[0..2] of Byte;
begin
  P[0] := GCS_SYSID;
  P[1] := GCS_COMPID;
  P[2] := ATipo;
  EnviaMsg(47, 153, P, 3);
end;

procedure TEmuladorMavlink.EnviaItemAtual;
var
  P: array[0..1] of Byte;
begin
  PoeU16(P, 0, Word(Max(0, FItemAtual)));
  EnviaMsg(42, 28, P, 2);
end;

procedure TEmuladorMavlink.EnviaItemAlcancado(ASeq: Integer);
var
  P: array[0..1] of Byte;
begin
  PoeU16(P, 0, Word(ASeq));
  EnviaMsg(46, 11, P, 2);
end;

procedure TEmuladorMavlink.MudaModo(AModo: LongWord; const AMotivo: string);
var
  E: TEstadoVoo;
begin
  if AModo = FModo then
    Exit;
  E := Estado;
  FModo := AModo;
  // Modos que seguram a posição partem de onde o drone está.
  FAlvoX := E.X;
  FAlvoY := E.Y;
  FAlvoZ := E.Z;
  FAlvoDefinido := AModo in [MODO_GUIDED, MODO_LOITER, MODO_BRAKE];
  if AModo = MODO_RTL then
    FFaseRTL := rtlSubindo;
  if AMotivo <> '' then
    Avisa('Modo ' + ModoTexto(AModo) + ': ' + AMotivo)
  else
    Avisa('Modo ' + ModoTexto(AModo));
end;

function TEmuladorMavlink.Armar(out AMotivo: string): Boolean;
var
  E: TEstadoVoo;
begin
  Result := False;
  E := Estado;
  AMotivo := '';
  if not E.NoChao then
    AMotivo := 'PreArm: já está no ar'
  else if E.Caiu then
    AMotivo := 'PreArm: veículo danificado, reinicie o simulador'
  else if E.Bateria < 20 then
    AMotivo := 'PreArm: Battery below minimum'
  else if Falhas.PerdaGPS and (FModo in [MODO_LOITER, MODO_GUIDED, MODO_AUTO, MODO_RTL]) then
    AMotivo := 'PreArm: Need 3D Fix'
  else if FModo in [MODO_AUTO, MODO_RTL, MODO_LAND] then
    AMotivo := 'Arm: Mode not armable';
  if AMotivo <> '' then
    Exit;
  FArmado := True;
  FArmadoEm := Agora;
  FFase := fvPousado;
  Result := True;
  Avisa('ARMADO em ' + ModoTexto(FModo));
end;

procedure TEmuladorMavlink.IniciaItem(AIndice: Integer; const AE: TEstadoVoo);
var
  It: TItemMissao;
begin
  FItemAtual := AIndice;
  FEsperaAte := 0;
  if (AIndice < 0) or (AIndice > High(FMissao)) then
    Exit;
  It := FMissao[AIndice];
  case It.Comando of
    CMD_WAYPOINT, CMD_LOITER_UNLIM, CMD_LAND:
      begin
        if (It.Lat <> 0) or (It.Lon <> 0) then
          GeoParaLocal(FOrigem, It.Lat, It.Lon, FAlvoX, FAlvoY)
        else
        begin
          FAlvoX := AE.X;
          FAlvoY := AE.Y;
        end;
        if It.Comando <> CMD_LAND then
          FAlvoZ := It.Alt;
      end;
    CMD_TAKEOFF:
      begin
        FAlvoX := AE.X;
        FAlvoY := AE.Y;
        FAlvoZ := Max(1, It.Alt);
      end;
  end;
  EnviaItemAtual;
end;

procedure TEmuladorMavlink.TrataComando(const P: TBytes);
var
  Cmd: Word;
  P1, P2, P7: Single;
  Res: Byte;
  Motivo: string;
  E: TEstadoVoo;
begin
  P1 := LeF32(P, 0);
  P2 := LeF32(P, 4);
  P7 := LeF32(P, 24);
  Cmd := LeU16(P, 28);
  Res := RES_ACEITO;
  E := Estado;
  case Cmd of
    CMD_ARM:
      if P1 >= 0.5 then
      begin
        if not FArmado and not Armar(Motivo) then
        begin
          Res := RES_FALHOU;
          EnviaTexto(3, Motivo);
          Avisa(Motivo);
        end;
      end
      else if FArmado then
      begin
        if E.NoChao or (Round(P2) = 21196) then
        begin
          FArmado := False;
          FFase := fvPousado;
          Avisa('Desarmado.');
        end
        else
        begin
          Res := RES_RECUSADO;
          EnviaTexto(4, 'Disarm: not landed');
        end;
      end;
    CMD_TAKEOFF:
      if (not FArmado) or (FModo <> MODO_GUIDED) or not E.NoChao then
        Res := RES_FALHOU
      else
      begin
        FAlvoX := E.X;
        FAlvoY := E.Y;
        FAlvoZ := Max(1, P7);
        FAlvoDefinido := True;
        FFase := fvDecolando;
        Avisa(Format('Decolando até %.1f m.', [FAlvoZ]));
      end;
    CMD_LAND:
      MudaModo(MODO_LAND, 'pedido do cockpit');
    CMD_RTL:
      MudaModo(MODO_RTL, 'pedido do cockpit');
    CMD_SET_MODE:
      if (Round(P2) = MODO_AUTO) and (Length(FMissao) < 2) then
        Res := RES_FALHOU
      else if Round(P2) in [MODO_STABILIZE, MODO_ALT_HOLD, MODO_AUTO, MODO_GUIDED,
        MODO_LOITER, MODO_RTL, MODO_LAND, MODO_BRAKE] then
      begin
        MudaModo(Round(P2), 'pedido do cockpit');
        if FModo = MODO_AUTO then
          IniciaItem(1, E);
      end
      else
        Res := RES_SEM_SUPORTE;
    CMD_MISSION_START:
      if (Length(FMissao) < 2) or not FArmado then
        Res := RES_FALHOU
      else
      begin
        MudaModo(MODO_AUTO, 'missão iniciada');
        IniciaItem(1, E);
      end;
    CMD_GET_HOME:
      FPendenteHome := True;
    CMD_REQUEST_MESSAGE:
      if Round(P1) = 242 then
        FPendenteHome := True
      else
        Res := RES_SEM_SUPORTE;
  else
    Res := RES_SEM_SUPORTE;
  end;
  EnviaAck(Cmd, Res);
end;

procedure TEmuladorMavlink.Trata(AId: LongWord; const P: TBytes);
var
  Seq: Integer;
  It: TItemMissao;
begin
  case AId of
    0:
      begin
        if FUltimoGcs = 0 then
          Avisa('Estação de solo (cockpit) encontrada.');
        FUltimoGcs := Agora;
      end;
    69: // MANUAL_CONTROL
      begin
        FManual[0] := LeI16(P, 0);
        FManual[1] := LeI16(P, 2);
        FManual[2] := LeI16(P, 4);
        FManual[3] := LeI16(P, 6);
        FUltimoManual := Agora;
      end;
    76:
      TrataComando(P);
    44: // MISSION_COUNT
      begin
        FRecebendo := LeU16(P, 0);
        SetLength(FMissao, 0);
        FProxPedido := 0;
        FTentativas := 0;
        if FRecebendo = 0 then
        begin
          FRecebendo := -1;
          EnviaMissaoAck(0);
        end
        else
        begin
          Avisa(Format('Recebendo rota com %d itens.', [FRecebendo]));
          EnviaPedidoItem(0);
        end;
      end;
    73: // MISSION_ITEM_INT
      if FRecebendo > 0 then
      begin
        Seq := LeU16(P, 28);
        if Seq <> FProxPedido then
          Exit;
        It.P1 := LeF32(P, 0);
        It.P2 := LeF32(P, 4);
        It.P3 := LeF32(P, 8);
        It.P4 := LeF32(P, 12);
        It.Lat := LeI32(P, 16) / 1e7;
        It.Lon := LeI32(P, 20) / 1e7;
        It.Alt := LeF32(P, 24);
        It.Comando := LeU16(P, 30);
        It.Quadro := P[34];
        SetLength(FMissao, Length(FMissao) + 1);
        FMissao[High(FMissao)] := It;
        Inc(FProxPedido);
        FTentativas := 0;
        if FProxPedido >= FRecebendo then
        begin
          FRecebendo := -1;
          EnviaMissaoAck(0);
          Avisa(Format('Rota aceita (%d itens).', [Length(FMissao)]));
        end
        else
          EnviaPedidoItem(FProxPedido);
      end;
  end;
end;

procedure TEmuladorMavlink.Processa(ACanal: Integer; const ABuf: TBytes; const ADe: TEndereco);
var
  I, N, Tam, Assin, E, Inicio, Cab: Integer;
  Crc: Word;
  Id: LongWord;
  P: TBytes;
begin
  FLock.Enter;
  try
    FPeer := ADe;
    I := 0;
    while I < Length(ABuf) do
    begin
      if (ABuf[I] = $FE) and (I + 8 <= Length(ABuf)) then
      begin
        Tam := ABuf[I + 1];
        Cab := 6;
        Assin := 0;
        if I + 8 + Tam > Length(ABuf) then
          Exit;
        Id := ABuf[I + 5];
      end
      else if (ABuf[I] = $FD) and (I + 12 <= Length(ABuf)) then
      begin
        Tam := ABuf[I + 1];
        Cab := 10;
        Assin := 0;
        if (ABuf[I + 2] and 1) <> 0 then
          Assin := 13;
        if I + 12 + Tam + Assin > Length(ABuf) then
          Exit;
        Id := LongWord(ABuf[I + 7]) or (LongWord(ABuf[I + 8]) shl 8) or
          (LongWord(ABuf[I + 9]) shl 16);
      end
      else
      begin
        Inc(I);
        Continue;
      end;
      E := MavCrcExtra(Id);
      Inicio := I;
      if E < 0 then
      begin
        Inc(I, Cab + 2 + Tam + Assin);
        Continue;
      end;
      Crc := $FFFF;
      for N := 1 to Cab - 1 + Tam do
        MavCrcAcc(Crc, ABuf[Inicio + N]);
      MavCrcAcc(Crc, E);
      if Crc <> (Word(ABuf[Inicio + Cab + Tam]) or (Word(ABuf[Inicio + Cab + Tam + 1]) shl 8)) then
      begin
        Inc(I);
        Continue;
      end;
      // A carga do MAVLink 2 omite os zeros finais: completa com zeros.
      SetLength(P, 256);
      FillChar(P[0], 256, 0);
      if Tam > 0 then
        Move(ABuf[Inicio + Cab], P[0], Tam);
      Trata(Id, P);
      Inc(I, Cab + 2 + Tam + Assin);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TEmuladorMavlink.Periodico(AAgora: QWord);
var
  E: TEstadoVoo;
begin
  FLock.Enter;
  try
    while FAvisos.Count > 0 do
    begin
      EnviaTexto(6, FAvisos[0]);
      FAvisos.Delete(0);
    end;
    if AAgora >= FProxHb then
    begin
      FProxHb := AAgora + 1000;
      EnviaHeartbeat;
    end;
    if AAgora >= FProxTel then
    begin
      FProxTel := AAgora + 250;
      E := Estado;
      EnviaTelemetria(E);
    end;
    if FPendenteHome or (AAgora >= FProxHome) then
    begin
      FProxHome := AAgora + 1000;
      FPendenteHome := False;
      EnviaHome;
    end;
    if (FModo = MODO_AUTO) and (AAgora >= FProxMissao) then
    begin
      FProxMissao := AAgora + 1000;
      EnviaItemAtual;
    end;
    // Rota: repete o pedido de item sem resposta.
    if (FRecebendo > 0) and (AAgora > FPrazoPedido) then
    begin
      Inc(FTentativas);
      if FTentativas > 5 then
      begin
        FRecebendo := -1;
        Avisa('Rota incompleta: tempo esgotado.');
        EnviaMissaoAck(1);
      end
      else
        EnviaPedidoItem(FProxPedido);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TEmuladorMavlink.ReiniciaEstado;
begin
  FLock.Enter;
  try inherited ReiniciaEstado; FArmado:=False; FAlvoDefinido:=False;
    FillChar(FManual,SizeOf(FManual),0); FUltimoManual:=0;
    FFaseRTL:=Low(TFaseRTL); FItemAtual:=-1; FEsperaAte:=0;
  finally FLock.Leave; end;
end;

function TEmuladorMavlink.MontaComando(const AE: TEstadoVoo): TComandoVoo;
var
  T: QWord;
  F: TFalhas;
  It: TItemMissao;
  Dist, AltDif: Double;
  Manual: Boolean;
begin
  FLock.Enter;
  try
    Result := ComandoNeutro;
    T := Agora;
    F := Falhas;
    if AE.Caiu then
    begin
      FArmado := False;
      ComandoDaFase(AE, Result);
      Exit;
    end;
    if not FArmado then
    begin
      FFase := fvPousado;
      Exit;
    end;

    // ---- Proteções ----
    if not AE.NoChao then
    begin
      if (FUltimoGcs > 0) and (T - FUltimoGcs > 5000) and not (FModo in [MODO_RTL, MODO_LAND, MODO_AUTO]) then
        MudaModo(MODO_RTL, 'perda de enlace com a estação');
      if (AE.Bateria < 8) and (FFailsafeBateria < 2) then
      begin
        FFailsafeBateria := 2;
        MudaModo(MODO_LAND, 'bateria crítica');
      end
      else if (AE.Bateria < 15) and (FFailsafeBateria < 1) then
      begin
        FFailsafeBateria := 1;
        MudaModo(MODO_RTL, 'bateria baixa');
      end;
      if F.PerdaGPS and (FModo in [MODO_LOITER, MODO_GUIDED, MODO_AUTO, MODO_RTL, MODO_BRAKE]) then
      begin
        if not FAvisouGps then
          MudaModo(MODO_LAND, 'perda de GPS');
        FAvisouGps := True;
      end;
    end;
    if not F.PerdaGPS then
      FAvisouGps := False;

    // Armado no chão sem decolar por 15 s: desarma sozinho (como o ArduCopter).
    if AE.NoChao and (FFase = fvPousado) and (T - FArmadoEm > 15000) and
      ((FManual[2] < 100) or (T - FUltimoManual > 1000)) then
    begin
      FArmado := False;
      Avisa('Desarmado automaticamente (15 s no chão).');
      Exit;
    end;

    Result.Motores := True;
    if not AE.NoChao then
      FFase := fvVoando
    else if FFase = fvVoando then
    begin
      // Pousou.
      FFase := fvPousado;
      FArmadoEm := T;
      if FModo in [MODO_LAND, MODO_RTL, MODO_AUTO] then
      begin
        FArmado := False;
        Avisa('Pousou e desarmou.');
        if FModo <> MODO_LOITER then
          FModo := MODO_LOITER;
        Result.Motores := False;
        Exit;
      end;
    end;

    Manual := (T - FUltimoManual < 1000);
    case FModo of
      MODO_STABILIZE:
        begin
          Result.ModoH := mhAngulo;
          Result.ModoV := mvEmpuxo;
          Result.Vertical := IfThen(Manual, FManual[2] / 1000, 0);
          Result.Arfagem := IfThen(Manual, FManual[0] / 1000, 0);
          Result.Rolagem := IfThen(Manual, FManual[1] / 1000, 0);
          Result.Guinada := IfThen(Manual, FManual[3] / 1000, 0);
        end;
      MODO_ALT_HOLD, MODO_LOITER:
        begin
          if FModo = MODO_ALT_HOLD then
            Result.ModoH := mhAngulo
          else
            Result.ModoH := mhVelocidade;
          Result.ModoV := mvSubida;
          if Manual then
          begin
            Result.Arfagem := FManual[0] / 1000;
            Result.Rolagem := FManual[1] / 1000;
            Result.Guinada := FManual[3] / 1000;
            // Centro do acelerador (500) mantém a altura; zona morta de 10%.
            Result.Vertical := (FManual[2] - 500) / 500;
            if Abs(Result.Vertical) < 0.1 then
              Result.Vertical := 0;
          end;
          // No chão, só sai com o acelerador acima do centro.
          if AE.NoChao and (Result.Vertical <= 0) then
            Result.Motores := True;
        end;
      MODO_GUIDED, MODO_BRAKE:
        begin
          if not FAlvoDefinido then
          begin
            FAlvoX := AE.X; FAlvoY := AE.Y; FAlvoZ := AE.Z;
            FAlvoDefinido := True;
          end;
          Result.ModoH := mhIrPara;
          Result.ModoV := mvAltura;
          Result.AlvoX := FAlvoX;
          Result.AlvoY := FAlvoY;
          Result.VelAlvo := FVelocidade;
          Result.Vertical := FAlvoZ;
          if AE.NoChao and (FFase <> fvDecolando) and (FAlvoZ < 0.5) then
            Result.Vertical := 0;
        end;
      MODO_LAND:
        begin
          Result.ModoH := mhVelocidade;
          Result.ModoV := mvSubida;
          if AE.Z > 10 then
            Result.Vertical := -0.6
          else
            Result.Vertical := -0.3;
        end;
      MODO_RTL:
        begin
          Result.ModoH := mhIrPara;
          Result.ModoV := mvAltura;
          Result.AlvoX := AE.X;
          Result.AlvoY := AE.Y;
          Result.VelAlvo := FVelocidade;
          Result.Vertical := Max(15, AE.Z);
          case FFaseRTL of
            rtlSubindo:
              if AE.Z >= 14.5 then
                FFaseRTL := rtlIndo;
            rtlIndo:
              begin
                Result.AlvoX := 0;
                Result.AlvoY := 0;
                Result.Vertical := Max(15, FAlvoZ);
                if Hypot(AE.X, AE.Y) < 1.5 then
                  FFaseRTL := rtlDescendo;
              end;
            rtlDescendo:
              begin
                Result.AlvoX := 0;
                Result.AlvoY := 0;
                Result.ModoV := mvSubida;
                if AE.Z > 10 then
                  Result.Vertical := -0.6
                else
                  Result.Vertical := -0.3;
              end;
          end;
          if FFaseRTL = rtlSubindo then
            FAlvoZ := Max(15, AE.Z);
        end;
      MODO_AUTO:
        begin
          if (FItemAtual < 1) or (FItemAtual > High(FMissao)) then
          begin
            MudaModo(MODO_LOITER, 'fim da rota');
            Exit;
          end;
          It := FMissao[FItemAtual];
          Result.ModoH := mhIrPara;
          Result.ModoV := mvAltura;
          Result.AlvoX := FAlvoX;
          Result.AlvoY := FAlvoY;
          Result.VelAlvo := FVelocidade;
          Result.Vertical := FAlvoZ;
          Dist := Hypot(AE.X - FAlvoX, AE.Y - FAlvoY);
          AltDif := Abs(AE.Z - FAlvoZ);
          case It.Comando of
            CMD_CHANGE_SPEED:
              begin
                if It.P2 > 0 then
                  FVelocidade := It.P2;
                IniciaItem(FItemAtual + 1, AE);
              end;
            CMD_TAKEOFF:
              if AE.Z >= FAlvoZ - 0.5 then
              begin
                EnviaItemAlcancado(FItemAtual);
                IniciaItem(FItemAtual + 1, AE);
              end;
            CMD_WAYPOINT:
              if (Dist < Max(1, It.P2)) and (AltDif < 1) then
              begin
                if FEsperaAte = 0 then
                  FEsperaAte := T + QWord(Round(Max(0, It.P1) * 1000));
                if T >= FEsperaAte then
                begin
                  EnviaItemAlcancado(FItemAtual);
                  IniciaItem(FItemAtual + 1, AE);
                end;
              end;
            CMD_LOITER_UNLIM:
              ; // fica no ponto até outro comando
            CMD_LAND:
              if Dist < 1.5 then
              begin
                Result.ModoV := mvSubida;
                Result.Vertical := -0.3;
              end;
            CMD_RTL:
              begin
                EnviaItemAlcancado(FItemAtual);
                MudaModo(MODO_RTL, 'último item da rota');
              end;
          else
            IniciaItem(FItemAtual + 1, AE);
          end;
        end;
    end;
  finally
    FLock.Leave;
  end;
end;

end.
