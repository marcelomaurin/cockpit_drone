unit simemulador;

{ Base dos emuladores de protocolo.

  Cada emulador é uma linha própria que:
    1. abre as portas que o equipamento real abre (AbreCanais);
    2. recebe os pacotes do cockpit e guarda os comandos (Processa);
    3. envia a telemetria no ritmo do equipamento real (Periodico);
    4. traduz o comando guardado num TComandoVoo para a física (MontaComando,
       chamado pela linha da física a 50 Hz).

  Falhas aplicadas aqui, iguais para todos os modelos:
    - sinal perdido (fora do alcance ou falha injetada): pacotes recebidos são
      descartados e nada é enviado;
    - atraso de rede: cada pacote recebido só é processado depois do atraso.

  A fase de voo comum (pousado, decolando, voando, pousando, corte, caído)
  fica na base; o modo "voando" é montado por cada protocolo. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, Math, simtipos, simgeo, simrede;

type
  TFaseVoo = (fvPousado, fvDecolando, fvVoando, fvPousando, fvCorte, fvCaido);

  TLeEstado = function: TEstadoVoo of object;
  TLeFalhas = function: TFalhas of object;

  TPacoteAtrasado = record
    Canal: Integer;
    Dados: TBytes;
    De: TEndereco;
    Prazo: QWord;
  end;

  { TEmulador }

  TEmulador = class(TThread)
  private
    FCanais: array of TSimUDP;
    FMensagens: TStringList;
    FFila: array of TPacoteAtrasado;
    FLeEstado: TLeEstado;
    FLeFalhas: TLeFalhas;
    FPacotesRx, FPacotesTx: Int64;
    FUltimoRx: QWord;
    procedure ProcessaFila(AAgora: QWord);
  protected
    FLock: TCriticalSection;
    FParam: TParametrosModelo;
    FOrigem: TPontoGeo;
    FFase: TFaseVoo;
    FPeer: TEndereco;              // último endereço que falou com o simulador
    function AdicionaCanal(APorta: Integer): Integer;
    function Canal(AIndice: Integer): TSimUDP;
    function Envia(ACanal: Integer; const ABuf; ATamanho: Integer; const AIP: string;
      APorta: Integer): Boolean;
    function EnviaTexto(ACanal: Integer; const ATexto, AIP: string; APorta: Integer): Boolean;
    procedure Log(const ATexto: string);
    function Estado: TEstadoVoo;
    function Falhas: TFalhas;
    function Agora: QWord;
    { Fases comuns. True = comando montado (fase diferente de "voando"). }
    function ComandoDaFase(const AE: TEstadoVoo; out ACmd: TComandoVoo): Boolean;
    procedure Decolar;
    procedure Pousar;
    procedure CortarMotores;

    function AbreCanais: Boolean; virtual; abstract;
    procedure Processa(ACanal: Integer; const ABuf: TBytes; const ADe: TEndereco); virtual; abstract;
    procedure Periodico(AAgora: QWord); virtual;
    procedure Encerra; virtual;
    procedure Execute; override;
  public
    constructor Create(const AParam: TParametrosModelo; const AOrigem: TPontoGeo;
      ALeEstado: TLeEstado; ALeFalhas: TLeFalhas); virtual;
    destructor Destroy; override;
    function Iniciar(out AErro: string): Boolean;
    procedure Parar;
    { Chamado pela linha da física. }
    function MontaComando(const AE: TEstadoVoo): TComandoVoo; virtual; abstract;
    { Texto das portas abertas, para o painel. }
    procedure ReiniciaEstado; virtual;
    function Descricao: string; virtual; abstract;
    function ProximaMensagem(out ATexto: string): Boolean;
    function FaseTexto: string;
    property PacotesRx: Int64 read FPacotesRx;
    property PacotesTx: Int64 read FPacotesTx;
    property UltimoRx: QWord read FUltimoRx;
    property Fase: TFaseVoo read FFase;
  end;

  TClasseEmulador = class of TEmulador;

{ Leitura e escrita little-endian em TBytes. }
function LeU16(const B: TBytes; P: Integer): Word;
function LeI16(const B: TBytes; P: Integer): SmallInt;
function LeU32(const B: TBytes; P: Integer): LongWord;
function LeI32(const B: TBytes; P: Integer): LongInt;
function LeF32(const B: TBytes; P: Integer): Single;
procedure PoeU16(var B: array of Byte; P: Integer; V: Word);
procedure PoeU32(var B: array of Byte; P: Integer; V: LongWord);
procedure PoeF32(var B: array of Byte; P: Integer; V: Single);

implementation

function LeU16(const B: TBytes; P: Integer): Word;
begin
  if P + 1 >= Length(B) then
    Exit(0);
  Result := Word(B[P]) or (Word(B[P + 1]) shl 8);
end;

function LeI16(const B: TBytes; P: Integer): SmallInt;
begin
  Result := SmallInt(LeU16(B, P));
end;

function LeU32(const B: TBytes; P: Integer): LongWord;
begin
  if P + 3 >= Length(B) then
    Exit(0);
  Result := LongWord(B[P]) or (LongWord(B[P + 1]) shl 8) or
    (LongWord(B[P + 2]) shl 16) or (LongWord(B[P + 3]) shl 24);
end;

function LeI32(const B: TBytes; P: Integer): LongInt;
begin
  Result := LongInt(LeU32(B, P));
end;

function LeF32(const B: TBytes; P: Integer): Single;
var
  V: LongWord;
begin
  V := LeU32(B, P);
  Move(V, Result, 4);
end;

procedure PoeU16(var B: array of Byte; P: Integer; V: Word);
begin
  B[P] := Lo(V);
  B[P + 1] := Hi(V);
end;

procedure PoeU32(var B: array of Byte; P: Integer; V: LongWord);
begin
  B[P] := V and $FF;
  B[P + 1] := (V shr 8) and $FF;
  B[P + 2] := (V shr 16) and $FF;
  B[P + 3] := (V shr 24) and $FF;
end;

procedure PoeF32(var B: array of Byte; P: Integer; V: Single);
var
  L: LongWord;
begin
  Move(V, L, 4);
  PoeU32(B, P, L);
end;

{ TEmulador }

constructor TEmulador.Create(const AParam: TParametrosModelo; const AOrigem: TPontoGeo;
  ALeEstado: TLeEstado; ALeFalhas: TLeFalhas);
begin
  FParam := AParam;
  FOrigem := AOrigem;
  FLeEstado := ALeEstado;
  FLeFalhas := ALeFalhas;
  FLock := TCriticalSection.Create;
  FMensagens := TStringList.Create;
  FFase := fvPousado;
  FreeOnTerminate := False;
  inherited Create(True);
end;

destructor TEmulador.Destroy;
var
  I: Integer;
begin
  Parar;
  for I := 0 to High(FCanais) do
    FCanais[I].Free;
  FMensagens.Free;
  FLock.Free;
  inherited Destroy;
end;

function TEmulador.Iniciar(out AErro: string): Boolean;
begin
  AErro := '';
  Result := AbreCanais;
  if not Result then
  begin
    if (Length(FCanais) > 0) and (FCanais[High(FCanais)].UltimoErro <> '') then
      AErro := FCanais[High(FCanais)].UltimoErro
    else
      AErro := 'não foi possível abrir as portas do protocolo';
    Exit;
  end;
  Start;
end;

procedure TEmulador.Parar;
begin
  if not Suspended and not Finished then
  begin
    Terminate;
    WaitFor;
  end;
end;

function TEmulador.AdicionaCanal(APorta: Integer): Integer;
var
  U: TSimUDP;
begin
  U := TSimUDP.Create;
  SetLength(FCanais, Length(FCanais) + 1);
  FCanais[High(FCanais)] := U;
  Result := High(FCanais);
  if not U.Abre(APorta) then
    Result := -1;
end;

function TEmulador.Canal(AIndice: Integer): TSimUDP;
begin
  Result := FCanais[AIndice];
end;

function TEmulador.Envia(ACanal: Integer; const ABuf; ATamanho: Integer;
  const AIP: string; APorta: Integer): Boolean;
begin
  Result := False;
  if Estado.SinalPerdido then
    Exit;
  Result := FCanais[ACanal].Envia(ABuf, ATamanho, AIP, APorta);
  if Result then
    Inc(FPacotesTx);
end;

function TEmulador.EnviaTexto(ACanal: Integer; const ATexto, AIP: string; APorta: Integer): Boolean;
begin
  if ATexto = '' then
    Exit(False);
  Result := Envia(ACanal, ATexto[1], Length(ATexto), AIP, APorta);
end;

procedure TEmulador.Log(const ATexto: string);
begin
  FLock.Enter;
  try
    FMensagens.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + ATexto);
    while FMensagens.Count > 200 do
      FMensagens.Delete(0);
  finally
    FLock.Leave;
  end;
end;

function TEmulador.ProximaMensagem(out ATexto: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FMensagens.Count > 0;
    if Result then
    begin
      ATexto := FMensagens[0];
      FMensagens.Delete(0);
    end
    else
      ATexto := '';
  finally
    FLock.Leave;
  end;
end;

function TEmulador.Estado: TEstadoVoo;
begin
  Result := FLeEstado();
end;

function TEmulador.Falhas: TFalhas;
begin
  Result := FLeFalhas();
end;

function TEmulador.Agora: QWord;
begin
  Result := GetTickCount64;
end;

procedure TEmulador.ReiniciaEstado;
begin
  FLock.Enter;
  try FFase:=fvPousado;
    Log('Equipamento simulado recuperado. Baixe a aceleracao e repita a decolagem/armamento.');
  finally FLock.Leave; end;
end;

function TEmulador.FaseTexto: string;
begin
  case FFase of
    fvPousado: Result := 'pousado';
    fvDecolando: Result := 'decolando';
    fvVoando: Result := 'voando';
    fvPousando: Result := 'pousando';
    fvCorte: Result := 'motores cortados';
    fvCaido: Result := 'CAIU';
  end;
end;

procedure TEmulador.Decolar;
begin
  if FFase in [fvPousado] then
  begin
    FFase := fvDecolando;
    Log('Decolando.');
  end;
end;

procedure TEmulador.Pousar;
begin
  if FFase in [fvDecolando, fvVoando] then
  begin
    FFase := fvPousando;
    Log('Pousando.');
  end;
end;

procedure TEmulador.CortarMotores;
begin
  if FFase <> fvCaido then
  begin
    FFase := fvCorte;
    Log('Motores cortados.');
  end;
end;

function TEmulador.ComandoDaFase(const AE: TEstadoVoo; out ACmd: TComandoVoo): Boolean;
begin
  ACmd := ComandoNeutro;
  if AE.Caiu and (FFase <> fvCaido) then
  begin
    FFase := fvCaido;
    Log('O equipamento CAIU (toque no chão acima de 2 m/s). A simulacao permite nova tentativa apos a recuperacao.');
  end;
  Result := True;
  case FFase of
    fvPousado, fvCaido:
      ACmd.Motores := False;
    fvCorte:
      begin
        ACmd.Motores := False;
        if AE.NoChao then
          FFase := fvPousado;
      end;
    fvDecolando:
      begin
        ACmd.Motores := True;
        ACmd.ModoH := mhVelocidade;
        ACmd.ModoV := mvAltura;
        ACmd.Vertical := Max(0.5, FParam.AlturaDecolagemM);
        if AE.Z >= ACmd.Vertical - 0.1 then
        begin
          FFase := fvVoando;
          Log(Format('No ar, pairando a %.1f m.', [AE.Z]));
        end;
      end;
    fvPousando:
      begin
        ACmd.Motores := True;
        ACmd.ModoH := mhVelocidade;
        ACmd.ModoV := mvSubida;
        if AE.Z > 3 then
          ACmd.Vertical := -1
        else
          ACmd.Vertical := -0.5;
        if AE.NoChao and (AE.TempoVooS > 0) then
        begin
          FFase := fvPousado;
          ACmd.Motores := False;
          Log('Pousou.');
        end;
      end;
  else
    Result := False;
  end;
end;

procedure TEmulador.Periodico(AAgora: QWord);
begin
end;

procedure TEmulador.Encerra;
begin
end;

procedure TEmulador.ProcessaFila(AAgora: QWord);
var
  I, J: Integer;
begin
  I := 0;
  while I <= High(FFila) do
    if FFila[I].Prazo <= AAgora then
    begin
      Processa(FFila[I].Canal, FFila[I].Dados, FFila[I].De);
      for J := I to High(FFila) - 1 do
        FFila[J] := FFila[J + 1];
      SetLength(FFila, Length(FFila) - 1);
    end
    else
      Inc(I);
end;

procedure TEmulador.Execute;
var
  Buf: array[0..4095] of Byte;
  N, I, Espera: Integer;
  De: TEndereco;
  Dados: TBytes;
  F: TFalhas;
  E: TEstadoVoo;
begin
  Log('Equipamento ligado: ' + Descricao);
  while not Terminated do
  begin
    if Length(FCanais) > 1 then
      Espera := 0
    else
      Espera := 8;
    for I := 0 to High(FCanais) do
    begin
      if not FCanais[I].Ativo then
        Continue;
      N := FCanais[I].Recebe(Buf, SizeOf(Buf), Espera, De);
      if N <= 0 then
        Continue;
      E := Estado;
      if E.SinalPerdido then
        Continue; // sem enlace: o pacote nunca chegou ao drone
      Inc(FPacotesRx);
      FUltimoRx := GetTickCount64;
      SetLength(Dados, N);
      Move(Buf[0], Dados[0], N);
      F := Falhas;
      if F.AtrasoMs > 0 then
      begin
        SetLength(FFila, Length(FFila) + 1);
        FFila[High(FFila)].Canal := I;
        FFila[High(FFila)].Dados := Dados;
        FFila[High(FFila)].De := De;
        FFila[High(FFila)].Prazo := GetTickCount64 + QWord(F.AtrasoMs);
      end
      else
        Processa(I, Dados, De);
    end;
    ProcessaFila(GetTickCount64);
    Periodico(GetTickCount64);
    if Espera=0 then Sleep(2);
  end;
  Encerra;
  for I := 0 to High(FCanais) do
    FCanais[I].Fecha;
  Log('Equipamento desligado.');
end;

end.
