unit simprotocolos;

{ Emuladores dos equipamentos do Cockpit Drone.

  Cada classe responde exatamente no formato que o componente correspondente
  da suíte CHATGPT (pacote openai_drone) usa com o equipamento real:

    TEmuladorTello    - TAIDroneTello    : texto UDP 8889, estado -> 8890
    TEmuladorARDrone  - TAIDroneARDrone  : AT UDP 5556, navdata -> 5554
    TEmuladorFQ777    - TAIDroneFQ777 / TAIDroneCX10W : TCP 8888 + UDP 8895
    TEmuladorCDP      - TAIDroneCDP      : CDP v1 UDP 4210 (firmware ESP32)
    TEmuladorESPDrone - TAIDroneESPDrone : CRTP UDP 2390, resposta -> 2399

  O MAVLink fica em simmavlink.pas.

  Vídeo: nesta versão o simulador não gera fluxo H.264 para o cockpit; as
  imagens da câmera aparecem na janela do simulador. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, StrUtils, simtipos, simgeo, simrede, simemulador;

const
  TELLO_PORTA_COMANDO = 8889;
  TELLO_PORTA_ESTADO = 8890;
  ARDRONE_PORTA_AT = 5556;
  ARDRONE_PORTA_NAVDATA = 5554;
  FQ777_PORTA_TCP = 8888;
  FQ777_PORTA_UDP = 8895;
  CDP_PORTA = 4210;
  ESPDRONE_PORTA_DRONE = 2390;

type

  { TEmuladorTello }

  TEmuladorTello = class(TEmulador)
  private
    FCanal: Integer;
    FSdk: Boolean;
    FRc: array[0..3] of Integer;
    FUltimoComando: QWord;
    FProxEstado: QWord;
  protected
    function AbreCanais: Boolean; override;
    procedure Processa(ACanal: Integer; const ABuf: TBytes; const ADe: TEndereco); override;
    procedure Periodico(AAgora: QWord); override;
  public
    function MontaComando(const AE: TEstadoVoo): TComandoVoo; override;
    function Descricao: string; override;
    class function TextoEstado(const AE: TEstadoVoo): string;
  end;

  { TEmuladorARDrone }

  TEmuladorARDrone = class(TEmulador)
  private
    FCanal: Integer;
    FUltimaSeq: LongWord;
    FVoar: Boolean;
    FEmergencia: Boolean;
    FBitEmergenciaAnterior: Boolean;
    FPcmdAtivo: Boolean;
    FPcmd: array[0..3] of Single;  // rolagem, arfagem, subida, guinada
    FConfigAck: Boolean;
    FUltimoAT: QWord;
    FProxNav: QWord;
    FSeqNav: LongWord;
    procedure TrataLinha(const ALinha: string);
  protected
    function AbreCanais: Boolean; override;
    procedure Processa(ACanal: Integer; const ABuf: TBytes; const ADe: TEndereco); override;
    procedure Periodico(AAgora: QWord); override;
  public
    function MontaComando(const AE: TEstadoVoo): TComandoVoo; override;
    function Descricao: string; override;
  end;

  { TEmuladorFQ777 }

  TEmuladorFQ777 = class(TEmulador)
  private
    FCanal: Integer;
    FTcp: TSimTCPServidor;
    FEixos: array[0..3] of Byte;  // rolagem, arfagem, aceleração, guinada
    FUltimoPacote: QWord;
    FAvisouSinal: Boolean;
  protected
    function AbreCanais: Boolean; override;
    procedure Processa(ACanal: Integer; const ABuf: TBytes; const ADe: TEndereco); override;
    procedure Encerra; override;
  public
    destructor Destroy; override;
    function MontaComando(const AE: TEstadoVoo): TComandoVoo; override;
    function Descricao: string; override;
  end;

  { TEmuladorCDP }

  TEmuladorCDP = class(TEmulador)
  private
    FCanal: Integer;
    FRol, FArf, FGui: SmallInt;
    FAcel: Word;
    FSinais: Byte;
    FUltimoControle: QWord;
    FArmado: Boolean;
    FCorteTravado: Boolean;
    FEstadoCdp: Byte;
    FFimCalibracao: QWord;
    FPerdaInicio: QWord;
    FProxTelemetria: QWord;
    FSeq: Word;
    FContagem, FPorSegundo: Integer;
    FInicioSegundo: QWord;
    function BateriaMv(const AE: TEstadoVoo): Integer;
  protected
    function AbreCanais: Boolean; override;
    procedure Processa(ACanal: Integer; const ABuf: TBytes; const ADe: TEndereco); override;
    procedure Periodico(AAgora: QWord); override;
  public
    function MontaComando(const AE: TEstadoVoo): TComandoVoo; override;
    function Descricao: string; override;
  end;

  { TEmuladorESPDrone }

  TEmuladorESPDrone = class(TEmulador)
  private
    FCanal: Integer;
    FRol, FArf, FGuiTaxa: Single;
    FEmpuxo: Word;
    FDestravado: Boolean;
    FUltimoComando: QWord;
    FProxResposta: QWord;
  protected
    function AbreCanais: Boolean; override;
    procedure Processa(ACanal: Integer; const ABuf: TBytes; const ADe: TEndereco); override;
    procedure Periodico(AAgora: QWord); override;
  public
    function MontaComando(const AE: TEstadoVoo): TComandoVoo; override;
    function Descricao: string; override;
  end;

function Crc16CcittFalse(const B: array of Byte; ATamanho: Integer): Word;

implementation

function Crc16CcittFalse(const B: array of Byte; ATamanho: Integer): Word;
var
  I, J: Integer;
begin
  Result := $FFFF;
  for I := 0 to ATamanho - 1 do
  begin
    Result := Result xor (Word(B[I]) shl 8);
    for J := 0 to 7 do
      if (Result and $8000) <> 0 then
        Result := Word((Result shl 1) xor $1021)
      else
        Result := Word(Result shl 1);
  end;
end;

function Rumo180(AGraus: Double): Double;
begin
  Result := NormalizaGraus(AGraus + 180) - 180;
end;

{ ===================== TEmuladorTello ===================== }

function TEmuladorTello.AbreCanais: Boolean;
begin
  FCanal := AdicionaCanal(TELLO_PORTA_COMANDO);
  Result := FCanal >= 0;
end;

function TEmuladorTello.Descricao: string;
begin
  Result := Format('Tello: comandos UDP %d, estado para a porta %d de quem conectar',
    [TELLO_PORTA_COMANDO, TELLO_PORTA_ESTADO]);
end;

procedure TEmuladorTello.Processa(ACanal: Integer; const ABuf: TBytes; const ADe: TEndereco);
var
  Txt, Resp: string;
  Partes: TStringArray;
  I: Integer;
  E: TEstadoVoo;
begin
  SetString(Txt, PAnsiChar(@ABuf[0]), Length(ABuf));
  Txt := Trim(Txt);
  Resp := 'ok';
  E := Estado;
  FLock.Enter;
  try
    FPeer := ADe;
    FUltimoComando := Agora;
    if AnsiStartsText('rc ', Txt) then
    begin
      Partes := Txt.Split([' '], TStringSplitOptions.ExcludeEmpty);
      for I := 0 to 3 do
        if I + 1 <= High(Partes) then
          FRc[I] := EnsureRange(StrToIntDef(Partes[I + 1], 0), -100, 100);
      Exit; // "rc" não tem resposta
    end;
    if SameText(Txt, 'command') then
    begin
      if not FSdk then
        Log('Cockpit entrou no modo SDK.');
      FSdk := True;
    end
    else if SameText(Txt, 'takeoff') then
    begin
      if E.Bateria < 10 then
        Resp := 'error Not enough battery'
      else if FFase <> fvPousado then
        Resp := 'error'
      else
        Decolar;
    end
    else if SameText(Txt, 'land') then
      Pousar
    else if SameText(Txt, 'emergency') then
      CortarMotores
    else if SameText(Txt, 'battery?') then
      Resp := IntToStr(Round(E.Bateria))
    else if SameText(Txt, 'height?') then
      Resp := IntToStr(Round(E.Z * 10)) + 'dm'
    else if SameText(Txt, 'time?') then
      Resp := IntToStr(Round(E.TempoVooS)) + 's';
    // streamon, streamoff, speed, wifi... : "ok"
  finally
    FLock.Leave;
  end;
  EnviaTexto(FCanal, Resp, ADe.IP, ADe.Porta);
end;

class function TEmuladorTello.TextoEstado(const AE: TEstadoVoo): string;
var
  Psi: Double;
  Vf, Vr: Double;
begin
  Psi := DegToRad(AE.Rumo);
  Vf := AE.VX * Sin(Psi) + AE.VY * Cos(Psi);
  Vr := AE.VX * Cos(Psi) - AE.VY * Sin(Psi);
  Result := Format('pitch:%d;roll:%d;yaw:%d;vgx:%d;vgy:%d;vgz:%d;templ:%d;temph:%d;' +
    'tof:%d;h:%d;bat:%d;baro:%s;time:%d;agx:0.00;agy:0.00;agz:-1000.00;'#13#10,
    [Round(AE.Arfagem), Round(AE.Rolagem), Round(Rumo180(AE.Rumo)),
     Round(Vf * 10), Round(Vr * 10), Round(-AE.VZ * 10), 60, 63,
     Round(AE.Z * 100) + 10, Round(AE.Z * 100), Round(AE.Bateria),
     FormatFloat('0.00', AE.Z), Round(AE.TempoVooS)]);
  Result := StringReplace(Result, ',', '.', [rfReplaceAll]);
end;

procedure TEmuladorTello.Periodico(AAgora: QWord);
var
  Peer: TEndereco;
  Sdk: Boolean;
begin
  if AAgora < FProxEstado then
    Exit;
  FProxEstado := AAgora + 100; // 10 Hz
  FLock.Enter;
  try
    Peer := FPeer;
    Sdk := FSdk;
  finally
    FLock.Leave;
  end;
  if Sdk and (Peer.IP <> '') then
    EnviaTexto(FCanal, TextoEstado(Estado), Peer.IP, TELLO_PORTA_ESTADO);
end;

function TEmuladorTello.MontaComando(const AE: TEstadoVoo): TComandoVoo;
begin
  FLock.Enter;
  try
    // O próprio Tello pousa sozinho após 15 s sem comandos; bateria < 10% pousa.
    if (FFase = fvVoando) and ((Agora - FUltimoComando > 15000) or (AE.Bateria < 10)) then
    begin
      if AE.Bateria < 10 then
        Log('Bateria baixa: o Tello pousa sozinho.')
      else
        Log('15 s sem comandos: o Tello pousa sozinho.');
      Pousar;
    end;
    if ComandoDaFase(AE, Result) then
      Exit;
    // Voando: o Tello segura a posição; o manche pede velocidade.
    Result.Motores := True;
    Result.ModoH := mhVelocidade;
    Result.ModoV := mvSubida;
    Result.Rolagem := FRc[0] / 100;
    Result.Arfagem := FRc[1] / 100;
    Result.Vertical := FRc[2] / 100;
    Result.Guinada := FRc[3] / 100;
  finally
    FLock.Leave;
  end;
end;

{ ===================== TEmuladorARDrone ===================== }

const
  AR_ESTADO_VOANDO = 1 shl 0;
  AR_ESTADO_CMD_ACK = 1 shl 6;
  AR_ESTADO_BATERIA_BAIXA = 1 shl 15;
  AR_ESTADO_WATCHDOG = 1 shl 30;
  AR_ESTADO_EMERGENCIA = LongWord(1) shl 31;
  AR_REF_DECOLAR = $200;
  AR_REF_EMERGENCIA = $100;

function TEmuladorARDrone.AbreCanais: Boolean;
begin
  FCanal := AdicionaCanal(ARDRONE_PORTA_AT);
  Result := FCanal >= 0;
end;

function TEmuladorARDrone.Descricao: string;
begin
  Result := Format('AR.Drone 2.0: comandos AT UDP %d, navdata para a porta %d de quem conectar',
    [ARDRONE_PORTA_AT, ARDRONE_PORTA_NAVDATA]);
end;

function IntParaSingle(const S: string): Single;
var
  L: LongInt;
begin
  L := StrToIntDef(Trim(S), 0);
  Move(L, Result, 4);
  if IsNan(Result) or IsInfinite(Result) then
    Result := 0;
end;

procedure TEmuladorARDrone.TrataLinha(const ALinha: string);
var
  P: Integer;
  Cmd: string;
  Args: TStringArray;
  Seq: LongWord;
  Ref: LongWord;
  Bit: Boolean;
begin
  P := Pos('=', ALinha);
  if P = 0 then
    Exit;
  Cmd := UpperCase(Copy(ALinha, 1, P - 1));
  Args := Copy(ALinha, P + 1, MaxInt).Split([',']);
  if Length(Args) = 0 then
    Exit;
  Seq := StrToQWordDef(Trim(Args[0]), 0);
  // O drone reinicia a numeração com a sequência 1 e ignora comandos antigos.
  if Seq = 1 then
    FUltimaSeq := 0;
  if (Seq <> 0) and (Seq <= FUltimaSeq) then
    Exit;
  FUltimaSeq := Seq;
  FUltimoAT := Agora;

  if Cmd = 'AT*REF' then
  begin
    if Length(Args) < 2 then
      Exit;
    Ref := StrToQWordDef(Trim(Args[1]), 0);
    Bit := (Ref and AR_REF_EMERGENCIA) <> 0;
    if Bit and not FBitEmergenciaAnterior then
    begin
      // O bit de emergência alterna o estado.
      FEmergencia := not FEmergencia;
      if FEmergencia then
        CortarMotores
      else
        Log('Emergência desfeita.');
    end;
    FBitEmergenciaAnterior := Bit;
    FVoar := (Ref and AR_REF_DECOLAR) <> 0;
    if FVoar and not FEmergencia then
      Decolar
    else if not FVoar then
      Pousar;
  end
  else if Cmd = 'AT*PCMD' then
  begin
    if Length(Args) < 6 then
      Exit;
    FPcmdAtivo := StrToIntDef(Trim(Args[1]), 0) and 1 <> 0;
    FPcmd[0] := IntParaSingle(Args[2]);
    FPcmd[1] := IntParaSingle(Args[3]);
    FPcmd[2] := IntParaSingle(Args[4]);
    FPcmd[3] := IntParaSingle(Args[5]);
  end
  else if Cmd = 'AT*CONFIG' then
  begin
    FConfigAck := True;
    if Length(Args) >= 3 then
      Log('Configuração recebida: ' + Trim(Args[1]) + ' = ' + Trim(Args[2]));
  end
  else if Cmd = 'AT*CTRL' then
    FConfigAck := False
  else if Cmd = 'AT*FTRIM' then
    Log('Calibração horizontal (FTRIM) recebida.');
end;

procedure TEmuladorARDrone.Processa(ACanal: Integer; const ABuf: TBytes; const ADe: TEndereco);
var
  Txt: string;
  Linhas: TStringArray;
  I: Integer;
begin
  SetString(Txt, PAnsiChar(@ABuf[0]), Length(ABuf));
  Linhas := Txt.Split([#13, #10], TStringSplitOptions.ExcludeEmpty);
  FLock.Enter;
  try
    if FPeer.IP = '' then
      Log('Cockpit conectado de ' + ADe.IP + '.');
    FPeer := ADe;
    for I := 0 to High(Linhas) do
      TrataLinha(Trim(Linhas[I]));
  finally
    FLock.Leave;
  end;
end;

procedure TEmuladorARDrone.Periodico(AAgora: QWord);
var
  B: array[0..16 + 148 + 8 - 1] of Byte;
  Peer: TEndereco;
  E: TEstadoVoo;
  St, Ctrl, Soma: LongWord;
  I: Integer;
  Psi, Vf, Vr: Double;
begin
  if AAgora < FProxNav then
    Exit;
  FProxNav := AAgora + 66; // ~15 Hz, como no modo "demo"
  E := Estado;
  FLock.Enter;
  try
    Peer := FPeer;
    St := 0;
    if FFase in [fvDecolando, fvVoando, fvPousando] then
      St := St or AR_ESTADO_VOANDO;
    if FConfigAck then
      St := St or AR_ESTADO_CMD_ACK;
    if E.Bateria < 20 then
      St := St or AR_ESTADO_BATERIA_BAIXA;
    if FEmergencia or (FFase = fvCaido) then
      St := St or AR_ESTADO_EMERGENCIA;
    if (FUltimoAT > 0) and (AAgora - FUltimoAT > 2000) then
      St := St or AR_ESTADO_WATCHDOG;
    case FFase of
      fvDecolando: Ctrl := 6;
      fvVoando: if FPcmdAtivo then Ctrl := 3 else Ctrl := 4;
      fvPousando: Ctrl := 8;
    else
      Ctrl := 2;
    end;
  finally
    FLock.Leave;
  end;
  if Peer.IP = '' then
    Exit;
  FillChar(B, SizeOf(B), 0);
  Inc(FSeqNav);
  PoeU32(B, 0, $55667788);
  PoeU32(B, 4, St);
  PoeU32(B, 8, FSeqNav);
  PoeU32(B, 12, 0);
  // Opção 0 (demo), 148 bytes.
  PoeU16(B, 16, 0);
  PoeU16(B, 18, 148);
  PoeU32(B, 20, Ctrl shl 16);
  PoeU32(B, 24, LongWord(Round(E.Bateria)));
  // No AR.Drone a arfagem positiva é nariz para cima (para trás).
  PoeF32(B, 28, -E.Arfagem * 1000);
  PoeF32(B, 32, E.Rolagem * 1000);
  PoeF32(B, 36, Rumo180(E.Rumo) * 1000);
  PoeU32(B, 40, LongWord(LongInt(Round(E.Z * 1000))));
  Psi := DegToRad(E.Rumo);
  Vf := E.VX * Sin(Psi) + E.VY * Cos(Psi);
  Vr := E.VX * Cos(Psi) - E.VY * Sin(Psi);
  PoeF32(B, 44, Vf * 1000);
  PoeF32(B, 48, Vr * 1000);
  PoeF32(B, 52, E.VZ * 1000);
  // Opção de soma de verificação.
  Soma := 0;
  for I := 0 to 16 + 148 - 1 do
    Inc(Soma, B[I]);
  PoeU16(B, 16 + 148, $FFFF);
  PoeU16(B, 16 + 148 + 2, 8);
  PoeU32(B, 16 + 148 + 4, Soma);
  Envia(FCanal, B, SizeOf(B), Peer.IP, ARDRONE_PORTA_NAVDATA);
end;

function TEmuladorARDrone.MontaComando(const AE: TEstadoVoo): TComandoVoo;
begin
  FLock.Enter;
  try
    if (FFase = fvVoando) and (AE.Bateria < 5) then
    begin
      Log('Bateria esgotada: pouso automático.');
      Pousar;
    end;
    if ComandoDaFase(AE, Result) then
    begin
      if (FFase = fvPousado) and FEmergencia and not AE.Caiu then
        Result.Motores := False;
      Exit;
    end;
    Result.Motores := True;
    // Sem comando AT por 2 s (vigia) ou PCMD com f=0: paira no lugar.
    if (not FPcmdAtivo) or (Agora - FUltimoAT > 2000) then
    begin
      Result.ModoH := mhVelocidade;
      Result.ModoV := mvSubida;
      Exit;
    end;
    Result.ModoH := mhAngulo;
    Result.ModoV := mvSubida;
    Result.Rolagem := EnsureRange(FPcmd[0], -1, 1);
    Result.Arfagem := -EnsureRange(FPcmd[1], -1, 1); // + = para trás no AR.Drone
    Result.Vertical := EnsureRange(FPcmd[2], -1, 1);
    Result.Guinada := EnsureRange(FPcmd[3], -1, 1);
  finally
    FLock.Leave;
  end;
end;

{ ===================== TEmuladorFQ777 (também CX-10W) ===================== }

destructor TEmuladorFQ777.Destroy;
begin
  inherited Destroy;
  FTcp.Free;
end;

function TEmuladorFQ777.AbreCanais: Boolean;
begin
  FCanal := AdicionaCanal(FQ777_PORTA_UDP);
  Result := FCanal >= 0;
  if not Result then
    Exit;
  FTcp := TSimTCPServidor.Create(FQ777_PORTA_TCP);
  Result := FTcp.Abre;
  if not Result then
    Log(Format('Porta TCP %d ocupada.', [FQ777_PORTA_TCP]));
end;

procedure TEmuladorFQ777.Encerra;
begin
  if Assigned(FTcp) then
    FTcp.Para;
end;

function TEmuladorFQ777.Descricao: string;
begin
  Result := Format('%s: TCP %d (inicialização e vídeo), comandos UDP %d',
    [FParam.Nome, FQ777_PORTA_TCP, FQ777_PORTA_UDP]);
end;

procedure TEmuladorFQ777.Processa(ACanal: Integer; const ABuf: TBytes; const ADe: TEndereco);
var
  X: Byte;
  I: Integer;
begin
  // [0] $CC [1] rolagem [2] arfagem [3] aceleração [4] guinada [5] sinais [6] XOR [7] $33
  if (Length(ABuf) < 8) or (ABuf[0] <> $CC) or (ABuf[7] <> $33) then
    Exit;
  X := 0;
  for I := 1 to 5 do
    X := X xor ABuf[I];
  if X <> ABuf[6] then
    Exit;
  FLock.Enter;
  try
    if FPeer.IP = '' then
      Log('Comandos chegando de ' + ADe.IP + '.');
    FPeer := ADe;
    FEixos[0] := ABuf[1];
    FEixos[1] := ABuf[2];
    FEixos[2] := ABuf[3];
    FEixos[3] := ABuf[4];
    FUltimoPacote := Agora;
    FAvisouSinal := False;
  finally
    FLock.Leave;
  end;
end;

function TEmuladorFQ777.MontaComando(const AE: TEstadoVoo): TComandoVoo;
var
  Acel: Double;
begin
  FLock.Enter;
  try
    Result := ComandoNeutro;
    if AE.Caiu then
    begin
      ComandoDaFase(AE, Result);
      Exit;
    end;
    Acel := FEixos[2] / 255;
    // Sem pacotes por 1 s o rádio perde o enlace e os motores perdem força.
    if (FUltimoPacote = 0) or (Agora - FUltimoPacote > 1000) then
    begin
      if (FUltimoPacote > 0) and not FAvisouSinal then
      begin
        Log('Sem comandos há 1 s: o drone perde força e desce.');
        FAvisouSinal := True;
      end;
      Acel := Max(0, EMPUXO_PAIRAR * 0.8 * Ord(not AE.NoChao));
      FEixos[0] := 127; FEixos[1] := 127; FEixos[3] := 127;
    end;
    // Brinquedo sem altura automática: aceleração = empuxo.
    Result.Motores := Acel > 0.04;
    Result.ModoH := mhAngulo;
    Result.ModoV := mvEmpuxo;
    Result.Vertical := Acel;
    Result.Rolagem := (FEixos[0] - 127) / 128;
    Result.Arfagem := (FEixos[1] - 127) / 128;
    Result.Guinada := (FEixos[3] - 127) / 128;
    if Result.Motores and AE.NoChao then
      FFase := fvVoando
    else if not Result.Motores then
      FFase := fvPousado;
  finally
    FLock.Leave;
  end;
end;

{ ===================== TEmuladorCDP (drone ESP32) ===================== }

const
  CDP_CONTROLE = $01;
  CDP_CALIBRAR = $02;
  CDP_TELEMETRIA = $81;
  CDP_DESARMADO = 0;
  CDP_ARMADO = 1;
  CDP_PERDA_SINAL = 2;
  CDP_CORTE = 3;
  CDP_CALIBRANDO = 4;

function TEmuladorCDP.AbreCanais: Boolean;
begin
  FCanal := AdicionaCanal(CDP_PORTA);
  Result := FCanal >= 0;
end;

function TEmuladorCDP.Descricao: string;
begin
  Result := Format('Drone ESP32 (CDP v1): UDP %d', [CDP_PORTA]);
end;

function TEmuladorCDP.BateriaMv(const AE: TEstadoVoo): Integer;
begin
  // Uma célula de lítio: 4,2 V cheia, 3,3 V vazia.
  Result := 3300 + Round(9 * AE.Bateria);
end;

procedure TEmuladorCDP.Processa(ACanal: Integer; const ABuf: TBytes; const ADe: TEndereco);
var
  N: Integer;
  Crc: Word;
  Tipo: Byte;
  B: array of Byte;
begin
  N := Length(ABuf);
  if (N < 8) or (ABuf[0] <> $43) or (ABuf[1] <> $44) or (ABuf[2] <> 1) then
    Exit;
  SetLength(B, N);
  Move(ABuf[0], B[0], N);
  Crc := Crc16CcittFalse(B, N - 2);
  if Crc <> (Word(B[N - 2]) or (Word(B[N - 1]) shl 8)) then
    Exit;
  Tipo := B[3];
  FLock.Enter;
  try
    if FPeer.IP = '' then
      Log('Cockpit conectado de ' + ADe.IP + '.');
    FPeer := ADe;
    if (Tipo = CDP_CONTROLE) and (N = 6 + 9 + 2) then
    begin
      FRol := LeI16(ABuf, 6);
      FArf := LeI16(ABuf, 8);
      FGui := LeI16(ABuf, 10);
      FAcel := Min(1000, LeU16(ABuf, 12));
      FSinais := ABuf[14];
      FUltimoControle := Agora;
      Inc(FContagem);
    end
    else if Tipo = CDP_CALIBRAR then
    begin
      if not FArmado then
      begin
        FFimCalibracao := Agora + 2000;
        Log('Calibrando sensores (2 s).');
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TEmuladorCDP.MontaComando(const AE: TEstadoVoo): TComandoVoo;
var
  T: QWord;
  Inclinacao, Rampa: Double;
  Pedido, Corte: Boolean;
begin
  FLock.Enter;
  try
    Result := ComandoNeutro;
    T := Agora;
    Pedido := (FSinais and 1) <> 0;
    Corte := (FSinais and 2) <> 0;
    Inclinacao := Max(Abs(AE.Rolagem), Abs(AE.Arfagem));

    if AE.Caiu then
    begin
      FArmado := False;
      FEstadoCdp := CDP_CORTE;
      ComandoDaFase(AE, Result);
      Exit;
    end;
    if (FFimCalibracao > 0) and (T < FFimCalibracao) then
    begin
      FEstadoCdp := CDP_CALIBRANDO;
      Exit;
    end;
    FFimCalibracao := 0;

    // Regra 3: corte trava até soltar o corte e o pedido de armar.
    if Corte then
    begin
      if FArmado then
        Log('CORTE dos motores.');
      FArmado := False;
      FCorteTravado := True;
    end
    else if FCorteTravado and not Pedido then
      FCorteTravado := False;

    // Regra 4: perda de sinal com o drone armado.
    if FArmado and ((FUltimoControle = 0) or (T - FUltimoControle > 500)) then
    begin
      if FPerdaInicio = 0 then
      begin
        FPerdaInicio := T;
        Log('Perda de sinal: descendo e desarmando em 2 s.');
      end;
      Rampa := 1 - (T - FPerdaInicio) / 2000;
      if Rampa <= 0 then
      begin
        FArmado := False;
        FPerdaInicio := 0;
        FEstadoCdp := CDP_DESARMADO;
        Exit;
      end;
      FEstadoCdp := CDP_PERDA_SINAL;
      Result.Motores := True;
      Result.ModoH := mhAngulo;
      Result.ModoV := mvEmpuxo;
      Result.Vertical := FAcel / 1000 * Rampa;
      Exit;
    end;
    FPerdaInicio := 0;

    if not FArmado then
    begin
      // Regra 1: condições para armar.
      if Pedido and not FCorteTravado and (FAcel <= 50) and (BateriaMv(AE) > 3300) and
        (Inclinacao < 25) then
      begin
        FArmado := True;
        Log('ARMADO.');
      end;
    end
    else if not Pedido then
    begin
      // Regra 2: soltar o pedido desarma na hora.
      FArmado := False;
      Log('Desarmado.');
    end;
    // Regra 5: capotou.
    if FArmado and (Inclinacao > 70) then
    begin
      FArmado := False;
      FCorteTravado := True;
      Log('Inclinação acima de 70°: corte dos motores.');
    end;

    if FCorteTravado then
      FEstadoCdp := CDP_CORTE
    else if FArmado then
      FEstadoCdp := CDP_ARMADO
    else
      FEstadoCdp := CDP_DESARMADO;

    if not FArmado then
      Exit;
    Result.Motores := True;
    Result.ModoH := mhAngulo;
    Result.ModoV := mvEmpuxo;
    Result.Rolagem := FRol / 1000;
    Result.Arfagem := FArf / 1000;
    Result.Guinada := FGui / 1000;
    Result.Vertical := FAcel / 1000;
    // Regra 6: bateria crítica limita a aceleração.
    if BateriaMv(AE) < 3400 then
      Result.Vertical := Min(Result.Vertical, EMPUXO_PAIRAR * 0.95);
    if AE.NoChao then
      FFase := fvPousado
    else
      FFase := fvVoando;
  finally
    FLock.Leave;
  end;
end;

procedure TEmuladorCDP.Periodico(AAgora: QWord);
var
  B: array[0..6 + 17 + 2 - 1] of Byte;
  E: TEstadoVoo;
  Peer: TEndereco;
  Alertas, Est: Byte;
  Crc: Word;
  Rssi: Integer;
  Acel: Word;
begin
  if AAgora - FInicioSegundo >= 1000 then
  begin
    FPorSegundo := FContagem;
    FContagem := 0;
    FInicioSegundo := AAgora;
  end;
  if AAgora < FProxTelemetria then
    Exit;
  FProxTelemetria := AAgora + 100; // 10 Hz
  E := Estado;
  FLock.Enter;
  try
    Peer := FPeer;
    Est := FEstadoCdp;
    if FArmado then
      Acel := FAcel
    else
      Acel := 0;
    Alertas := $02; // sensor OK
    if BateriaMv(E) < 3500 then
      Alertas := Alertas or $01;
    if (not FArmado) and ((FSinais and 1) <> 0) and (FAcel > 50) then
      Alertas := Alertas or $04;
    if Max(Abs(E.Rolagem), Abs(E.Arfagem)) >= 25 then
      Alertas := Alertas or $08;
  finally
    FLock.Leave;
  end;
  if Peer.IP = '' then
    Exit;
  FillChar(B, SizeOf(B), 0);
  Inc(FSeq);
  B[0] := $43; B[1] := $44; B[2] := 1; B[3] := CDP_TELEMETRIA;
  PoeU16(B, 4, FSeq);
  B[6] := Est;
  PoeU16(B, 7, Word(BateriaMv(E)));
  PoeU16(B, 9, Word(SmallInt(Round(E.Rolagem * 100))));
  PoeU16(B, 11, Word(SmallInt(Round(E.Arfagem * 100))));
  PoeU16(B, 13, Word(SmallInt(Round(Rumo180(E.Rumo) * 100))));
  PoeU16(B, 15, Acel);
  Rssi := -35 - Round(E.DistPartida * 0.6);
  B[17] := Byte(ShortInt(EnsureRange(Rssi, -95, -30)));
  PoeU16(B, 18, 500);
  B[20] := Alertas;
  PoeU16(B, 21, Word(FPorSegundo));
  Crc := Crc16CcittFalse(B, SizeOf(B) - 2);
  PoeU16(B, SizeOf(B) - 2, Crc);
  Envia(FCanal, B, SizeOf(B), Peer.IP, Peer.Porta);
end;

{ ===================== TEmuladorESPDrone (CRTP) ===================== }

function TEmuladorESPDrone.AbreCanais: Boolean;
begin
  FCanal := AdicionaCanal(ESPDRONE_PORTA_DRONE);
  Result := FCanal >= 0;
end;

function TEmuladorESPDrone.Descricao: string;
begin
  Result := Format('ESP-Drone (CRTP): UDP %d, respostas para a porta de quem conectar',
    [ESPDRONE_PORTA_DRONE]);
end;

procedure TEmuladorESPDrone.Processa(ACanal: Integer; const ABuf: TBytes; const ADe: TEndereco);
var
  I: Integer;
  Soma: Byte;
begin
  if Length(ABuf) < 2 then
    Exit;
  Soma := 0;
  for I := 0 to High(ABuf) - 1 do
    Soma := Byte(Soma + ABuf[I]);
  if Soma <> ABuf[High(ABuf)] then
    Exit;
  FLock.Enter;
  try
    if FPeer.IP = '' then
      Log('Cockpit conectado de ' + ADe.IP + '.');
    FPeer := ADe;
    if ((ABuf[0] and $F3) = $30) and (Length(ABuf) = 1 + 14 + 1) then
    begin
      FRol := LeF32(ABuf, 1);
      FArf := -LeF32(ABuf, 5);   // o cflib envia a arfagem com o sinal invertido
      FGuiTaxa := LeF32(ABuf, 9);
      FEmpuxo := LeU16(ABuf, 13);
      if IsNan(FRol) then FRol := 0;
      if IsNan(FArf) then FArf := 0;
      if IsNan(FGuiTaxa) then FGuiTaxa := 0;
      // Trava do firmware: só aceita empuxo depois de receber empuxo zero.
      if (FEmpuxo = 0) and not FDestravado then
      begin
        FDestravado := True;
        Log('Empuxo liberado (recebeu zero).');
      end;
      FUltimoComando := Agora;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TEmuladorESPDrone.Periodico(AAgora: QWord);
var
  B: array[0..1] of Byte;
  Peer: TEndereco;
begin
  if AAgora < FProxResposta then
    Exit;
  FProxResposta := AAgora + 100;
  FLock.Enter;
  try
    Peer := FPeer;
  finally
    FLock.Leave;
  end;
  if (Peer.IP = '') or (AAgora - FUltimoComando > 1000) then
    Exit;
  // Pacote vazio do enlace (porta 15): mostra ao cockpit que o drone responde.
  B[0] := $FF;
  B[1] := $FF;
  Envia(FCanal, B, 2, Peer.IP, Peer.Porta);
end;

function TEmuladorESPDrone.MontaComando(const AE: TEstadoVoo): TComandoVoo;
var
  T: QWord;
begin
  FLock.Enter;
  try
    Result := ComandoNeutro;
    if AE.Caiu then
    begin
      ComandoDaFase(AE, Result);
      Exit;
    end;
    T := Agora - FUltimoComando;
    if (not FDestravado) or (FUltimoComando = 0) or (T > 2000) then
      Exit; // vigia do commander: sem comando por 2 s, motores parados
    Result.Motores := FEmpuxo > 0;
    Result.ModoH := mhAngulo;
    Result.ModoV := mvEmpuxo;
    // Pairar do Crazyflie fica perto de 62% do empuxo máximo.
    Result.Vertical := EnsureRange(FEmpuxo / 60000 * (EMPUXO_PAIRAR / 0.62), 0, 1);
    if T > 500 then
    begin
      // Sem comando por 0,5 s: nivela.
      Result.Rolagem := 0;
      Result.Arfagem := 0;
      Result.Guinada := 0;
    end
    else
    begin
      Result.Rolagem := FRol / Max(1, FParam.AnguloMaxGraus);
      Result.Arfagem := FArf / Max(1, FParam.AnguloMaxGraus);
      Result.Guinada := FGuiTaxa / Max(1, FParam.GuinadaMaxGrausS);
    end;
    if Result.Motores then
      FFase := fvVoando
    else
      FFase := fvPousado;
  finally
    FLock.Leave;
  end;
end;

end.
