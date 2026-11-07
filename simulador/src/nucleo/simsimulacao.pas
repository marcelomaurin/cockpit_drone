unit simsimulacao;

{ Orquestra a simulação: física a 50 Hz numa linha própria, emulador do
  protocolo do modelo escolhido e falhas injetadas.

  Ordem de travas (evita impasse): a linha da física NUNCA chama o emulador
  segurando a trava da simulação. Ela copia o estado, solta a trava, pede o
  comando ao emulador (que tem a própria trava) e só então trava de novo para
  avançar a física. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, Math, simtipos, simgeo, simfisica, simemulador,
  simprotocolos, simmavlink;

type
  TPontoRastro = record
    X, Y, Z: Double;
  end;
  TPontoRastro_Array = array of TPontoRastro;

  TSimulacao = class;

  { TLinhaFisica }

  TLinhaFisica = class(TThread)
  private
    FSim: TSimulacao;
  protected
    procedure Execute; override;
  public
    constructor Create(ASim: TSimulacao);
  end;

  TOpcoesMavlink = record
    IPCockpit: string;
    PortaCockpit: Integer;
    PortaLocal: Integer;
  end;

  { TSimulacao }

  TSimulacao = class
  private
    FLock: TCriticalSection;
    FFisica: TSimFisica;
    FEmulador: TEmulador;
    FLinha: TLinhaFisica;
    FEstado: TEstadoVoo;
    FFalhas: TFalhas;
    FPausado: Boolean;
    FParam: TParametrosModelo;
    FOrigem: TPontoGeo;
    FRastro: array of TPontoRastro;
    FUltimoRastro: QWord;
    FUltimoComando: TComandoVoo;
    procedure PassoFisica(ADt: Double);
  public
    constructor Create;
    destructor Destroy; override;
    { Cria a física e o emulador do modelo e abre as portas do protocolo. }
    function Liga(const AParam: TParametrosModelo; const AOrigem: TPontoGeo;
      const AMav: TOpcoesMavlink; out AErro: string): Boolean;
    procedure Desliga;
    procedure Reinicia;
    function Ligado: Boolean;
    function LeEstado: TEstadoVoo;
    function LeFalhas: TFalhas;
    procedure DefineFalhas(const AFalhas: TFalhas);
    procedure BateriaFraca;
    { Com o equipamento desligado, a posição informada é o ponto de partida. }
    procedure DefineOrigemParada(const AOrigem: TPontoGeo);
    function Rastro: TPontoRastro_Array;
    function Emulador: TEmulador;
    function UltimoComando: TComandoVoo;
    property Pausado: Boolean read FPausado write FPausado;
    property Param: TParametrosModelo read FParam;
    property Origem: TPontoGeo read FOrigem;
  end;

function ClasseDoProtocolo(const AProtocolo: string): TClasseEmulador;

implementation

function ClasseDoProtocolo(const AProtocolo: string): TClasseEmulador;
begin
  if SameText(AProtocolo, 'tello') then
    Result := TEmuladorTello
  else if SameText(AProtocolo, 'ardrone') then
    Result := TEmuladorARDrone
  else if SameText(AProtocolo, 'fq777') or SameText(AProtocolo, 'cx10w') then
    Result := TEmuladorFQ777
  else if SameText(AProtocolo, 'cdp') then
    Result := TEmuladorCDP
  else if SameText(AProtocolo, 'espdrone') then
    Result := TEmuladorESPDrone
  else if SameText(AProtocolo, 'mavlink') then
    Result := TEmuladorMavlink
  else
    Result := nil;
end;

{ TLinhaFisica }

constructor TLinhaFisica.Create(ASim: TSimulacao);
begin
  FSim := ASim;
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TLinhaFisica.Execute;
const
  PASSO = 0.02;
var
  Ultimo, Agora: QWord;
  Acumulado: Double;
  N: Integer;
begin
  Ultimo := GetTickCount64;
  Acumulado := 0;
  while not Terminated do
  begin
    Sleep(5);
    Agora := GetTickCount64;
    Acumulado := Acumulado + (Agora - Ultimo) / 1000;
    Ultimo := Agora;
    N := 0;
    // Passo fixo de 20 ms; após uma pausa longa não tenta recuperar tudo.
    while (Acumulado >= PASSO) and (N < 10) do
    begin
      FSim.PassoFisica(PASSO);
      Acumulado := Acumulado - PASSO;
      Inc(N);
    end;
    if Acumulado > 0.2 then
      Acumulado := 0;
  end;
end;

{ TSimulacao }

constructor TSimulacao.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FillChar(FFalhas, SizeOf(FFalhas), 0);
  FEstado.NoChao := True;
  FEstado.Bateria := 100;
end;

destructor TSimulacao.Destroy;
begin
  Desliga;
  FLock.Free;
  inherited Destroy;
end;

function TSimulacao.Liga(const AParam: TParametrosModelo; const AOrigem: TPontoGeo;
  const AMav: TOpcoesMavlink; out AErro: string): Boolean;
var
  Classe: TClasseEmulador;
begin
  Desliga;
  Result := False;
  AErro := '';
  Classe := ClasseDoProtocolo(AParam.Protocolo);
  if Classe = nil then
  begin
    AErro := 'protocolo desconhecido: ' + AParam.Protocolo;
    Exit;
  end;
  FParam := AParam;
  FOrigem := AOrigem;
  FFisica := TSimFisica.Create(AParam, AOrigem);
  FEstado := FFisica.Estado;
  SetLength(FRastro, 0);
  FEmulador := Classe.Create(AParam, AOrigem, @LeEstado, @LeFalhas);
  if FEmulador is TEmuladorMavlink then
    with TEmuladorMavlink(FEmulador) do
    begin
      if Trim(AMav.IPCockpit) <> '' then
        IPCockpit := Trim(AMav.IPCockpit);
      if AMav.PortaCockpit > 0 then
        PortaCockpit := AMav.PortaCockpit;
      if AMav.PortaLocal > 0 then
        PortaLocal := AMav.PortaLocal;
    end;
  if not FEmulador.Iniciar(AErro) then
  begin
    FreeAndNil(FEmulador);
    FreeAndNil(FFisica);
    Exit;
  end;
  FLinha := TLinhaFisica.Create(Self);
  Result := True;
end;

procedure TSimulacao.Desliga;
begin
  if Assigned(FLinha) then
  begin
    FLinha.Terminate;
    FLinha.WaitFor;
    FreeAndNil(FLinha);
  end;
  FreeAndNil(FEmulador);
  FreeAndNil(FFisica);
end;

function TSimulacao.Ligado: Boolean;
begin
  Result := Assigned(FEmulador);
end;

procedure TSimulacao.Reinicia;
var
  P: TParametrosModelo;
  O: TPontoGeo;
  M: TOpcoesMavlink;
  Ligava: Boolean;
  Erro: string;
  Mav: TEmuladorMavlink;
begin
  // Recria tudo: física no ponto de partida e emulador zerado.
  Ligava := Ligado;
  P := FParam;
  O := FOrigem;
  M.IPCockpit := '';
  M.PortaCockpit := 0;
  M.PortaLocal := 0;
  if FEmulador is TEmuladorMavlink then
  begin
    Mav := TEmuladorMavlink(FEmulador);
    M.IPCockpit := Mav.IPCockpit;
    M.PortaCockpit := Mav.PortaCockpit;
    M.PortaLocal := Mav.PortaLocal;
  end;
  if Ligava then
    Liga(P, O, M, Erro);
end;

procedure TSimulacao.PassoFisica(ADt: Double);
var
  E: TEstadoVoo;
  F: TFalhas;
  C: TComandoVoo;
  Agora: QWord;
begin
  FLock.Enter;
  try
    if FPausado or not Assigned(FFisica) then
      Exit;
    E := FEstado;
    F := FFalhas;
  finally
    FLock.Leave;
  end;
  // Fora da trava da simulação (veja o comentário da unidade).
  if Assigned(FEmulador) then
    C := FEmulador.MontaComando(E)
  else
    C := ComandoNeutro;
  FLock.Enter;
  try
    FFisica.Passo(ADt, C, F);
    FEstado := FFisica.Estado;
    FUltimoComando := C;
    Agora := GetTickCount64;
    if (Agora - FUltimoRastro >= 500) and not FEstado.NoChao then
    begin
      FUltimoRastro := Agora;
      SetLength(FRastro, Length(FRastro) + 1);
      FRastro[High(FRastro)].X := FEstado.X;
      FRastro[High(FRastro)].Y := FEstado.Y;
      FRastro[High(FRastro)].Z := FEstado.Z;
      if Length(FRastro) > 4000 then
        Delete(FRastro, 0, 1000);
    end;
  finally
    FLock.Leave;
  end;
end;

function TSimulacao.LeEstado: TEstadoVoo;
begin
  FLock.Enter;
  try
    Result := FEstado;
  finally
    FLock.Leave;
  end;
end;

function TSimulacao.LeFalhas: TFalhas;
begin
  FLock.Enter;
  try
    Result := FFalhas;
  finally
    FLock.Leave;
  end;
end;

procedure TSimulacao.DefineFalhas(const AFalhas: TFalhas);
begin
  FLock.Enter;
  try
    FFalhas := AFalhas;
  finally
    FLock.Leave;
  end;
end;

procedure TSimulacao.BateriaFraca;
begin
  FLock.Enter;
  try
    if Assigned(FFisica) then
    begin
      FFisica.DefineBateria(12);
      FEstado := FFisica.Estado;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSimulacao.DefineOrigemParada(const AOrigem: TPontoGeo);
begin
  FLock.Enter;
  try
    if not Assigned(FFisica) then
    begin
      FEstado.Lat := AOrigem.Lat;
      FEstado.Lon := AOrigem.Lon;
      FEstado.X := 0;
      FEstado.Y := 0;
      FEstado.Z := 0;
    end;
  finally
    FLock.Leave;
  end;
end;

function TSimulacao.Rastro: TPontoRastro_Array;
begin
  FLock.Enter;
  try
    Result := Copy(FRastro);
  finally
    FLock.Leave;
  end;
end;

function TSimulacao.Emulador: TEmulador;
begin
  Result := FEmulador;
end;

function TSimulacao.UltimoComando: TComandoVoo;
begin
  FLock.Enter;
  try
    Result := FUltimoComando;
  finally
    FLock.Leave;
  end;
end;

end.
