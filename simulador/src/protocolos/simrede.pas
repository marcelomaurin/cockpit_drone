unit simrede;

{ UDP e TCP mínimos sobre a unidade "sockets" do Free Pascal, sem pacotes
  externos (funciona em Windows e Linux).

  TSimUDP  - porta UDP com espera limitada na leitura e envio para qualquer
             endereço (o simulador responde para quem enviou o comando).
  TSimTCPServidor - aceita conexões TCP e descarta o que chega (canais de
             inicialização e vídeo do FQ777-954 / CX-10W). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, sockets, SyncObjs{$IFDEF UNIX}, BaseUnix{$ENDIF};

type
  { A unidade sockets usa cint nos dois sistemas; TSocket só existe no Linux. }
  TSock = LongInt;

  TEndereco = record
    IP: string;
    Porta: Integer;
  end;

  { TSimUDP }

  TSimUDP = class
  private
    FSock: TSock;
    FPortaLocal: Integer;
    FUltimoErro: string;
    function Aberto: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    { Abre a porta local (0 = qualquer). False = porta ocupada. }
    function Abre(APortaLocal: Integer): Boolean;
    procedure Fecha;
    { Bytes lidos; 0 = nada no prazo; -1 = erro. }
    function Recebe(var ABuf; ATamanho, AEsperaMs: Integer; out ADe: TEndereco): Integer;
    function Envia(const ABuf; ATamanho: Integer; const AIP: string; APorta: Integer): Boolean;
    function EnviaTexto(const ATexto, AIP: string; APorta: Integer): Boolean;
    property Ativo: Boolean read Aberto;
    property PortaLocal: Integer read FPortaLocal;
    property UltimoErro: string read FUltimoErro;
  end;

  { TSimTCPServidor }

  TSimTCPServidor = class(TThread)
  private
    FSock: TSock;
    FPorta: Integer;
    FLock: TCriticalSection;
    FClientes: TList;
    FConexoes: Integer;
    FBytes: Int64;
  protected
    procedure Execute; override;
  public
    constructor Create(APorta: Integer);
    destructor Destroy; override;
    function Abre: Boolean;
    procedure Para;
    property Conexoes: Integer read FConexoes;
    property Bytes: Int64 read FBytes;
  end;

const
  SOCK_INVALIDO = TSock(-1);

function IPValido(const AIP: string): string;

implementation

type

  { TClienteTCP: lê e descarta até o outro lado fechar. }

  TClienteTCP = class(TThread)
  private
    FSock: TSock;
    FDono: TSimTCPServidor;
  protected
    procedure Execute; override;
  public
    constructor Create(ADono: TSimTCPServidor; ASock: TSock);
    procedure Fecha;
  end;

procedure DefineEspera(ASock: TSock; AMs: Integer);
{$IFDEF WINDOWS}
var
  T: DWord;
begin
  T := AMs;
  fpsetsockopt(ASock, SOL_SOCKET, SO_RCVTIMEO, @T, SizeOf(T));
end;
{$ELSE}
var
  T: TTimeVal;
begin
  T.tv_sec := AMs div 1000;
  T.tv_usec := (AMs mod 1000) * 1000;
  fpsetsockopt(ASock, SOL_SOCKET, SO_RCVTIMEO, @T, SizeOf(T));
end;
{$ENDIF}

function ErroDePrazo(ACodigo: LongInt): Boolean;
begin
  {$IFDEF WINDOWS}
  Result := (ACodigo = 10060) or (ACodigo = 10035); // WSAETIMEDOUT, WSAEWOULDBLOCK
  {$ELSE}
  Result := (ACodigo = 11) or (ACodigo = 35) or (ACodigo = 4); // EAGAIN (Linux/BSD), EINTR
  {$ENDIF}
end;

procedure FechaSocket(ASock: TSock);
begin
  fpshutdown(ASock, 2);
  CloseSocket(ASock);
end;

function IPValido(const AIP: string): string;
begin
  Result := Trim(AIP);
  if (Result = '') or SameText(Result, 'localhost') then
    Result := '127.0.0.1';
end;

{ TSimUDP }

constructor TSimUDP.Create;
begin
  inherited Create;
  FSock := SOCK_INVALIDO;
end;

destructor TSimUDP.Destroy;
begin
  Fecha;
  inherited Destroy;
end;

function TSimUDP.Aberto: Boolean;
begin
  Result := FSock <> SOCK_INVALIDO;
end;

function TSimUDP.Abre(APortaLocal: Integer): Boolean;
var
  End_: TInetSockAddr;
  Sim: LongInt;
  Tam: TSockLen;
begin
  Fecha;
  Result := False;
  FSock := fpsocket(AF_INET, SOCK_DGRAM, 0);
  if FSock = SOCK_INVALIDO then
  begin
    FUltimoErro := 'não foi possível criar o socket UDP';
    Exit;
  end;
  Sim := 1;
  fpsetsockopt(FSock, SOL_SOCKET, SO_BROADCAST, @Sim, SizeOf(Sim));
  FillChar(End_, SizeOf(End_), 0);
  End_.sin_family := AF_INET;
  End_.sin_port := htons(Word(APortaLocal));
  End_.sin_addr.s_addr := 0; // todas as interfaces
  if fpbind(FSock, @End_, SizeOf(End_)) <> 0 then
  begin
    FUltimoErro := Format('porta UDP %d ocupada', [APortaLocal]);
    CloseSocket(FSock);
    FSock := SOCK_INVALIDO;
    Exit;
  end;
  Tam := SizeOf(End_);
  if fpgetsockname(FSock, @End_, @Tam) = 0 then
    FPortaLocal := ntohs(End_.sin_port)
  else
    FPortaLocal := APortaLocal;
  DefineEspera(FSock, 10);
  Result := True;
end;

procedure TSimUDP.Fecha;
begin
  if Aberto then
  begin
    CloseSocket(FSock);
    FSock := SOCK_INVALIDO;
  end;
end;

function TSimUDP.Recebe(var ABuf; ATamanho, AEsperaMs: Integer; out ADe: TEndereco): Integer;
var
  End_: TInetSockAddr;
  Tam: TSockLen;
begin
  ADe.IP := '';
  ADe.Porta := 0;
  if not Aberto then
    Exit(-1);
  DefineEspera(FSock, Max(1, AEsperaMs));
  Tam := SizeOf(End_);
  FillChar(End_, SizeOf(End_), 0);
  Result := fprecvfrom(FSock, @ABuf, ATamanho, 0, @End_, @Tam);
  if Result <= 0 then
  begin
    // Prazo esgotado: sem dados. No Windows, um envio para porta sem ninguém
    // escutando faz o recvfrom falhar na hora (WSAECONNRESET); espera o prazo
    // para não girar a 100% de CPU.
    if (Result < 0) and not ErroDePrazo(SocketError) then
      Sleep(Max(1, AEsperaMs));
    Result := 0;
    Exit;
  end;
  ADe.IP := NetAddrToStr(End_.sin_addr);
  ADe.Porta := ntohs(End_.sin_port);
end;

function TSimUDP.Envia(const ABuf; ATamanho: Integer; const AIP: string; APorta: Integer): Boolean;
var
  End_: TInetSockAddr;
begin
  Result := False;
  if not Aberto or (APorta <= 0) then
    Exit;
  FillChar(End_, SizeOf(End_), 0);
  End_.sin_family := AF_INET;
  End_.sin_port := htons(Word(APorta));
  End_.sin_addr := StrToNetAddr(IPValido(AIP));
  Result := fpsendto(FSock, @ABuf, ATamanho, 0, @End_, SizeOf(End_)) = ATamanho;
end;

function TSimUDP.EnviaTexto(const ATexto, AIP: string; APorta: Integer): Boolean;
begin
  if ATexto = '' then
    Exit(False);
  Result := Envia(ATexto[1], Length(ATexto), AIP, APorta);
end;

{ TClienteTCP }

constructor TClienteTCP.Create(ADono: TSimTCPServidor; ASock: TSock);
begin
  FDono := ADono;
  FSock := ASock;
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TClienteTCP.Fecha;
begin
  Terminate;
  if FSock <> SOCK_INVALIDO then
    fpshutdown(FSock, 2);
end;

procedure TClienteTCP.Execute;
var
  Buf: array[0..4095] of Byte;
  N: Integer;
begin
  DefineEspera(FSock, 200);
  while not Terminated do
  begin
    N := fprecv(FSock, @Buf[0], SizeOf(Buf), 0);
    if N > 0 then
      Inc(FDono.FBytes, N)
    else if N = 0 then
      Break  // o cockpit fechou a conexão
    else if not ErroDePrazo(SocketError) then
      Break;
  end;
  CloseSocket(FSock);
  FSock := SOCK_INVALIDO;
end;

{ TSimTCPServidor }

constructor TSimTCPServidor.Create(APorta: Integer);
begin
  FPorta := APorta;
  FSock := SOCK_INVALIDO;
  FLock := TCriticalSection.Create;
  FClientes := TList.Create;
  FreeOnTerminate := False;
  inherited Create(True);
end;

destructor TSimTCPServidor.Destroy;
var
  I: Integer;
begin
  Para;
  for I := 0 to FClientes.Count - 1 do
    TClienteTCP(FClientes[I]).Free;
  FClientes.Free;
  FLock.Free;
  inherited Destroy;
end;

function TSimTCPServidor.Abre: Boolean;
var
  End_: TInetSockAddr;
  Sim: LongInt;
begin
  Result := False;
  FSock := fpsocket(AF_INET, SOCK_STREAM, 0);
  if FSock = SOCK_INVALIDO then
    Exit;
  Sim := 1;
  fpsetsockopt(FSock, SOL_SOCKET, SO_REUSEADDR, @Sim, SizeOf(Sim));
  FillChar(End_, SizeOf(End_), 0);
  End_.sin_family := AF_INET;
  End_.sin_port := htons(Word(FPorta));
  End_.sin_addr.s_addr := 0;
  if (fpbind(FSock, @End_, SizeOf(End_)) <> 0) or (fplisten(FSock, 8) <> 0) then
  begin
    CloseSocket(FSock);
    FSock := SOCK_INVALIDO;
    Exit;
  end;
  Start;
  Result := True;
end;

procedure TSimTCPServidor.Para;
var
  I: Integer;
begin
  if Terminated and (FSock = SOCK_INVALIDO) then
    Exit;
  Terminate;
  if FSock <> SOCK_INVALIDO then
  begin
    FechaSocket(FSock);
    FSock := SOCK_INVALIDO;
  end;
  if not Suspended then
    WaitFor;
  FLock.Enter;
  try
    for I := 0 to FClientes.Count - 1 do
    begin
      TClienteTCP(FClientes[I]).Fecha;
      TClienteTCP(FClientes[I]).WaitFor;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSimTCPServidor.Execute;
var
  End_: TInetSockAddr;
  Tam: TSockLen;
  C: TSock;
begin
  while not Terminated do
  begin
    Tam := SizeOf(End_);
    C := fpaccept(FSock, @End_, @Tam);
    if Terminated then
    begin
      if C <> SOCK_INVALIDO then
        CloseSocket(C);
      Break;
    end;
    if C = SOCK_INVALIDO then
    begin
      Sleep(20);
      Continue;
    end;
    Inc(FConexoes);
    FLock.Enter;
    try
      FClientes.Add(TClienteTCP.Create(Self, C));
    finally
      FLock.Leave;
    end;
  end;
end;

end.
