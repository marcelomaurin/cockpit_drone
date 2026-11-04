unit esp32droneproto;

{ Protocolo CDP v1 — drone ESP32 com o firmware da pasta firmware/esp32_drone.
  Especificação completa em firmware/esp32_drone/PROTOCOLO.md.

  Rede: ponto de acesso "CockpitDrone-XXXX", IP 192.168.4.1, UDP 4210.
  Pacote: 'C' 'D' versão tipo seq(u16) dados... CRC-16/CCITT-FALSE (u16).
    0x01 CONTROLE   (cockpit -> drone, a cada 30 ms)
         rolagem, arfagem, guinada: i16 -1000..1000; aceleração u16 0..1000;
         sinalizadores: bit0 = armar, bit1 = CORTE
    0x02 CALIBRAR   (só desarmado)
    0x81 TELEMETRIA (drone -> cockpit, 10 Hz)

  O firmware só arma com a aceleração no mínimo, corta os motores ao perder
  o sinal por 500 ms (descida de 2 s) e trava após um CORTE. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, lNetComponents, lNet, protocols;

const
  ESP32_DEFAULT_HOST = '192.168.4.1';
  ESP32_DEFAULT_PORT = 4210;

  CDP_ESTADO_DESARMADO = 0;
  CDP_ESTADO_ARMADO = 1;
  CDP_ESTADO_PERDA_SINAL = 2;
  CDP_ESTADO_CORTE = 3;
  CDP_ESTADO_CALIBRANDO = 4;
  CDP_ESTADO_ERRO_SENSOR = 5;

  CDP_ALERTA_BATERIA_BAIXA = $01;
  CDP_ALERTA_SENSOR_OK = $02;
  CDP_ALERTA_ACEL_TRAVADO = $04;
  CDP_ALERTA_INCLINADO = $08;

type
  TESP32Telemetria = record
    Valida: Boolean;
    Estado: Byte;
    BateriaMv: Integer;
    Rolagem, Arfagem, Rumo: Double; // graus
    Acelerador: Integer;            // 0..1000
    RSSI: Integer;                  // dBm
    LacoHz: Integer;
    Alertas: Byte;
    ControlesPorSegundo: Integer;
    Recebida: TDateTime;
  end;

  { TESP32DroneProtocol }

  TESP32DroneProtocol = class(TBaseProtocol)
  private
    FUdp: TLUDPComponent;
    FSeq: Word;
    FArmar: Boolean;
    FCorteTicks: Integer;
    FCalibrar: Boolean;
    FRoll, FPitch, FYaw: SmallInt;
    FThrottle: Word;
    FB3Anterior, FB4Anterior: Boolean;
    FTelemetria: TESP32Telemetria;
    FPacotesTelemetria: Int64;
    FComandos: Int64;
    FOnTelemetria: TNotifyEvent;
    FDisconnecting: Boolean;

    procedure UdpReceive(aSocket: TLSocket);
    procedure UdpError(const msg: string; aSocket: TLSocket);
    procedure EnviaPacote(ATipo: Byte; const ADados: array of Byte; ATamanho: Integer);
    procedure EnviaControle;
    procedure Interpreta(const ABuf: array of Byte; ALen: Integer);
  public
    constructor Create; override;
    destructor Destroy; override;

    { ATcpPort não é usado; AUdpPort = porta do drone (4210). }
    procedure Connect(const AHost: string; ATcpPort, AUdpPort: Integer); override;
    procedure Disconnect; override;
    { X/Y/Z do frmMain, B1/B2 guinada, B3 armar, B4 desarmar (borda de subida). }
    procedure SendCommand(AX, AY, AZ, AB1, AB2, AB3, AB4, AB5, AB6: Byte); override;
    { Chamado a cada ~30 ms: envia o pacote de controle (também sinal de vida). }
    procedure Tick;

    procedure Armar;
    procedure Desarmar;
    { Mata os motores na hora. Para voltar: soltar o corte e armar de novo. }
    procedure Corte;
    procedure Calibrar;

    class function CRC16(const AData: array of Byte; ACount: Integer): Word; static;
    class function EstadoTexto(AEstado: Byte): string; static;

    property Armado: Boolean read FArmar;
    property Telemetria: TESP32Telemetria read FTelemetria;
    property PacotesTelemetria: Int64 read FPacotesTelemetria;
    property Comandos: Int64 read FComandos;
    property OnTelemetria: TNotifyEvent read FOnTelemetria write FOnTelemetria;
  end;

implementation

const
  CDP_MAGIA0 = $43;
  CDP_MAGIA1 = $44;
  CDP_VERSAO = 1;
  CDP_CONTROLE = $01;
  CDP_CALIBRAR = $02;
  CDP_TELEMETRIA = $81;
  CDP_CABECALHO = 6;
  SINAL_ARMAR = $01;
  SINAL_CORTE = $02;

function LeS16(const B: array of Byte; P: Integer): SmallInt; inline;
begin
  Result := SmallInt(Word(B[P]) or (Word(B[P + 1]) shl 8));
end;

function LeU16(const B: array of Byte; P: Integer): Word; inline;
begin
  Result := Word(B[P]) or (Word(B[P + 1]) shl 8);
end;

{ TESP32DroneProtocol }

constructor TESP32DroneProtocol.Create;
begin
  inherited Create;
  FUdp := TLUDPComponent.Create(nil);
  FUdp.OnReceive := @UdpReceive;
  FUdp.OnError := @UdpError;
  FHost := ESP32_DEFAULT_HOST;
  FUdpPort := ESP32_DEFAULT_PORT;
end;

destructor TESP32DroneProtocol.Destroy;
begin
  FOnStatus := nil;
  FOnError := nil;
  FOnTelemetria := nil;
  Disconnect;
  FUdp.Free;
  inherited Destroy;
end;

class function TESP32DroneProtocol.CRC16(const AData: array of Byte;
  ACount: Integer): Word;
var
  I, J: Integer;
begin
  Result := $FFFF;
  for I := 0 to ACount - 1 do
  begin
    Result := Result xor (Word(AData[I]) shl 8);
    for J := 1 to 8 do
      if (Result and $8000) <> 0 then
        Result := Word((Result shl 1) xor $1021)
      else
        Result := Word(Result shl 1);
  end;
end;

class function TESP32DroneProtocol.EstadoTexto(AEstado: Byte): string;
begin
  case AEstado of
    CDP_ESTADO_DESARMADO: Result := 'desarmado';
    CDP_ESTADO_ARMADO: Result := 'ARMADO';
    CDP_ESTADO_PERDA_SINAL: Result := 'perda de sinal (descendo)';
    CDP_ESTADO_CORTE: Result := 'CORTE';
    CDP_ESTADO_CALIBRANDO: Result := 'calibrando';
    CDP_ESTADO_ERRO_SENSOR: Result := 'erro no sensor';
  else
    Result := 'desconhecido (' + IntToStr(AEstado) + ')';
  end;
end;

procedure TESP32DroneProtocol.Connect(const AHost: string; ATcpPort,
  AUdpPort: Integer);
begin
  Disconnect;
  FHost := Trim(AHost);
  if FHost = '' then
    FHost := ESP32_DEFAULT_HOST;
  FUdpPort := AUdpPort;
  if FUdpPort <= 0 then
    FUdpPort := ESP32_DEFAULT_PORT;

  FArmar := False;
  FCorteTicks := 0;
  FCalibrar := False;
  FRoll := 0; FPitch := 0; FYaw := 0; FThrottle := 0;
  FB3Anterior := True; // ignora botões já apertados ao conectar
  FB4Anterior := True;
  FillChar(FTelemetria, SizeOf(FTelemetria), 0);
  FDisconnecting := False;

  DoStatus(Format('Conectando ao drone ESP32 em %s:%d (UDP)...', [FHost, FUdpPort]));
  try
    if not FUdp.Connect(FHost, FUdpPort) then
    begin
      DoError('Não foi possível abrir a porta UDP ' + IntToStr(FUdpPort) + '.');
      Exit;
    end;
  except
    on E: Exception do
    begin
      DoError('Erro na conexão: ' + E.Message);
      Exit;
    end;
  end;
  FActive := True;
  EnviaControle;
  DoStatus('Canal aberto. Aguardando telemetria do drone...');
end;

procedure TESP32DroneProtocol.Disconnect;
var
  I: Integer;
begin
  FDisconnecting := True;
  try
    if FActive and FUdp.Connected then
    begin
      // Desarma e zera a aceleração antes de soltar o canal.
      FArmar := False;
      FThrottle := 0;
      FRoll := 0; FPitch := 0; FYaw := 0;
      for I := 1 to 5 do
      begin
        EnviaControle;
        Sleep(20);
      end;
    end;
    if FUdp.Connected then
      FUdp.Disconnect(True);
  except
  end;
  FActive := False;
  FArmar := False;
  FDisconnecting := False;
end;

procedure TESP32DroneProtocol.EnviaPacote(ATipo: Byte; const ADados: array of Byte;
  ATamanho: Integer);
var
  P: array of Byte;
  N: Integer;
  C: Word;
begin
  if not FUdp.Connected then
    Exit;
  ATamanho := EnsureRange(ATamanho, 0, Length(ADados));
  N := CDP_CABECALHO + ATamanho + 2;
  SetLength(P, N);
  P[0] := CDP_MAGIA0;
  P[1] := CDP_MAGIA1;
  P[2] := CDP_VERSAO;
  P[3] := ATipo;
  Inc(FSeq);
  P[4] := Lo(FSeq);
  P[5] := Hi(FSeq);
  if ATamanho > 0 then
    Move(ADados[0], P[CDP_CABECALHO], ATamanho);
  C := CRC16(P, N - 2);
  P[N - 2] := Lo(C);
  P[N - 1] := Hi(C);
  if FUdp.Send(P[0], N) = N then
    Inc(FComandos);
end;

procedure TESP32DroneProtocol.EnviaControle;
var
  D: array[0..8] of Byte;
  Sinais: Byte;
begin
  D[0] := Lo(Word(FRoll));   D[1] := Hi(Word(FRoll));
  D[2] := Lo(Word(FPitch));  D[3] := Hi(Word(FPitch));
  D[4] := Lo(Word(FYaw));    D[5] := Hi(Word(FYaw));
  D[6] := Lo(FThrottle);     D[7] := Hi(FThrottle);
  Sinais := 0;
  if FArmar then
    Sinais := Sinais or SINAL_ARMAR;
  if FCorteTicks > 0 then
    Sinais := Sinais or SINAL_CORTE;
  D[8] := Sinais;
  EnviaPacote(CDP_CONTROLE, D, Length(D));
end;

procedure TESP32DroneProtocol.SendCommand(AX, AY, AZ, AB1, AB2, AB3, AB4, AB5,
  AB6: Byte);
begin
  { No frmMain X cresce para a ESQUERDA e Y para a FRENTE.
    No CDP: rolagem + = direita, arfagem + = frente. }
  FRoll := EnsureRange(Round((127 - Integer(AX)) * 1000 / 127), -1000, 1000);
  FPitch := EnsureRange(Round((Integer(AY) - 127) * 1000 / 127), -1000, 1000);
  FThrottle := EnsureRange(Round(Integer(AZ) * 1000 / 255), 0, 1000);
  FYaw := 0;
  if (AB1 = 255) and (AB2 <> 255) then
    FYaw := -600
  else if (AB2 = 255) and (AB1 <> 255) then
    FYaw := 600;

  if (AB3 = 255) and not FB3Anterior then
    Armar
  else if (AB4 = 255) and not FB4Anterior then
    Desarmar;
  FB3Anterior := AB3 = 255;
  FB4Anterior := AB4 = 255;
end;

procedure TESP32DroneProtocol.Tick;
const
  SEM: array[0..0] of Byte = (0);
begin
  if not FActive then
    Exit;
  if FCalibrar then
  begin
    FCalibrar := False;
    EnviaPacote(CDP_CALIBRAR, SEM, 0);
  end;
  EnviaControle;
  if FCorteTicks > 0 then
    Dec(FCorteTicks);
end;

procedure TESP32DroneProtocol.Armar;
begin
  if FTelemetria.Valida and ((FTelemetria.Alertas and CDP_ALERTA_ACEL_TRAVADO) <> 0) then
    DoStatus('Para armar, leve a aceleração ao mínimo (tecla Q).');
  FCorteTicks := 0;
  FArmar := True;
  DoStatus('Pedido de armar enviado.');
end;

procedure TESP32DroneProtocol.Desarmar;
begin
  FArmar := False;
  DoStatus('Desarmado.');
end;

procedure TESP32DroneProtocol.Corte;
begin
  FArmar := False;
  FCorteTicks := 15; // ~0,5 s de corte; depois o firmware espera um novo armar
  DoStatus('CORTE: motores desligados.');
end;

procedure TESP32DroneProtocol.Calibrar;
begin
  if FArmar then
  begin
    DoStatus('Calibração só com o drone desarmado.');
    Exit;
  end;
  FCalibrar := True;
  DoStatus('Calibrando: mantenha o drone parado e nivelado.');
end;

procedure TESP32DroneProtocol.Interpreta(const ABuf: array of Byte; ALen: Integer);
var
  Anterior: Byte;
  Primeira: Boolean;
begin
  if (ALen <> CDP_CABECALHO + 17 + 2) or (ABuf[0] <> CDP_MAGIA0) or
    (ABuf[1] <> CDP_MAGIA1) or (ABuf[2] <> CDP_VERSAO) or (ABuf[3] <> CDP_TELEMETRIA) then
    Exit;
  if CRC16(ABuf, ALen - 2) <> LeU16(ABuf, ALen - 2) then
    Exit;

  Primeira := not FTelemetria.Valida;
  Anterior := FTelemetria.Estado;
  with FTelemetria do
  begin
    Valida := True;
    Estado := ABuf[6];
    BateriaMv := LeU16(ABuf, 7);
    Rolagem := LeS16(ABuf, 9) / 100;
    Arfagem := LeS16(ABuf, 11) / 100;
    Rumo := LeS16(ABuf, 13) / 100;
    Acelerador := LeU16(ABuf, 15);
    RSSI := ShortInt(ABuf[17]);
    LacoHz := LeU16(ABuf, 18);
    Alertas := ABuf[20];
    ControlesPorSegundo := LeU16(ABuf, 21);
    Recebida := Now;
  end;
  Inc(FPacotesTelemetria);

  if Primeira then
    DoStatus('Telemetria recebida: drone ' + EstadoTexto(FTelemetria.Estado) + '.')
  else if FTelemetria.Estado <> Anterior then
    DoStatus('Drone: ' + EstadoTexto(FTelemetria.Estado) + '.');

  // O firmware desarmou sozinho (perda de sinal, capotou, corte): acompanha.
  if FArmar and (Anterior = CDP_ESTADO_ARMADO) and
    (FTelemetria.Estado in [CDP_ESTADO_DESARMADO, CDP_ESTADO_CORTE, CDP_ESTADO_ERRO_SENSOR]) then
    FArmar := False;

  if Assigned(FOnTelemetria) then
    FOnTelemetria(Self);
end;

procedure TESP32DroneProtocol.UdpReceive(aSocket: TLSocket);
var
  Buf: array[0..511] of Byte;
  L: Integer;
begin
  repeat
    L := aSocket.Get(Buf[0], SizeOf(Buf));
    if L > 0 then
      Interpreta(Buf, L);
  until L <= 0;
end;

procedure TESP32DroneProtocol.UdpError(const msg: string; aSocket: TLSocket);
begin
  if not FDisconnecting then
    DoError('UDP: ' + msg + ' (verifique se o PC está na rede Wi-Fi do drone).');
end;

end.
