unit simmapa;

{ Blocos de mapa para o chão do simulador.

  Fontes:
    TFonteGoogle - Map Tiles API do Google, blocos 2D de satélite. Precisa de
                   chave de API do usuário. Cria a sessão (createSession),
                   renova antes de vencer e lê o texto de direitos autorais
                   da área vista (viewport).
    TFonteOSM    - OpenStreetMap (mapa de ruas; o OSM não tem satélite).
                   User-Agent próprio e fixo, crédito sempre visível.

  Regras de uso respeitadas (políticas das duas fontes):
    - só busca o que está na tela; nada de baixar áreas antes ou uso sem
      internet;
    - o cache em disco respeita Cache-Control (max-age) e revalida com ETag;
      no OpenStreetMap, sem cabeçalho de prazo, guarda no mínimo 7 dias;
    - crédito exibido o tempo todo.

  TGerenciadorBlocos escolhe a fonte (auto / google / osm). No modo auto usa
  o Google e troca sozinho para o OpenStreetMap quando o Google falha (sem
  chave, chave recusada, cota, erro de sessão ou falhas seguidas nos
  blocos); a cada 5 minutos tenta o Google de novo. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, Math, DateUtils, StrUtils, Contnrs,
  fphttpclient, opensslsockets, fpjson, jsonparser, simhttp,
  FPImage, FPReadJPEG, FPReadPNG, simgeo;

const
  USER_AGENT_SIMULADOR = 'CockpitDroneSimulador/1.0 (+https://maurinsoft.com.br)';
  MAX_BLOCOS_MEMORIA = 320;
  LINHAS_DOWNLOAD = 4;

type
  TModoFonte = (mfAuto, mfGoogle, mfOSM);
  TPixels = array of LongWord;   // $00RRGGBB, 256 x 256

  { TBloco }

  TBloco = class
  public
    Z, X, Y: Integer;
    Pixels: TPixels;
    Pronto: Boolean;
    Falhou: Boolean;
    TentarDepois: QWord;
    UltimoUso: QWord;
    NoDisco: Boolean;          // há cópia no cache em disco: atendido primeiro
    Prioridade: Integer;       // vista principal > quadro pequeno
    function Amostra(APx, APy: Integer): LongWord; inline;
  end;

  { TFonteBlocos }

  TFonteBlocos = class
  protected
    FUltimoErro: string;
  public
    function Nome: string; virtual; abstract;
    function Pasta: string; virtual; abstract;
    function ZoomMaximo: Integer; virtual; abstract;
    { Prepara a fonte (sessão). False = indisponível; motivo em UltimoErro. }
    function Prepara: Boolean; virtual;
    function Url(AZ, AX, AY: Integer): string; virtual; abstract;
    procedure ConfiguraCliente(ACli: TFPHTTPClient); virtual;
    { Prazo padrão de cache em segundos quando a resposta não informa. }
    function PrazoPadraoS: Integer; virtual;
    { Texto de crédito para a área vista. }
    function Credito(ANorte, ASul, ALeste, AOeste: Double; AZoom: Integer): string; virtual; abstract;
    property UltimoErro: string read FUltimoErro;
  end;

  { TFonteGoogle }

  TFonteGoogle = class(TFonteBlocos)
  private
    FChave: string;
    FSessao: string;
    FValidade: Int64;          // segundos desde 1970 (UTC)
    FLock: TCriticalSection;
    FCredito: string;
    FCreditoTick: QWord;
    FCreditoChave: string;
  public
    constructor Create(const AChave: string);
    destructor Destroy; override;
    function Nome: string; override;
    function Pasta: string; override;
    function ZoomMaximo: Integer; override;
    function Prepara: Boolean; override;
    function Url(AZ, AX, AY: Integer): string; override;
    function PrazoPadraoS: Integer; override;
    { Só devolve o texto guardado (não usa a rede). }
    function Credito(ANorte, ASul, ALeste, AOeste: Double; AZoom: Integer): string; override;
    { Consulta o texto de direitos da área (rede; chamar fora da linha principal). }
    procedure AtualizaCredito(ANorte, ASul, ALeste, AOeste: Double; AZoom: Integer);
    function PrecisaCredito(ANorte, ASul, ALeste, AOeste: Double; AZoom: Integer): Boolean;
  end;

  { TFonteOSM }

  TFonteOSM = class(TFonteBlocos)
  private
    FServidor: string;
  public
    constructor Create(const AServidor: string);
    function Nome: string; override;
    function Pasta: string; override;
    function ZoomMaximo: Integer; override;
    function Url(AZ, AX, AY: Integer): string; override;
    procedure ConfiguraCliente(ACli: TFPHTTPClient); override;
    function PrazoPadraoS: Integer; override;
    function Credito(ANorte, ASul, ALeste, AOeste: Double; AZoom: Integer): string; override;
  end;

  TGerenciadorBlocos = class;

  { TLinhaDownload }

  TLinhaDownload = class(TThread)
  private
    FDono: TGerenciadorBlocos;
  protected
    procedure Execute; override;
  public
    constructor Create(ADono: TGerenciadorBlocos);
  end;

  { TGerenciadorBlocos }

  TGerenciadorBlocos = class
  private
    FLock: TCriticalSection;
    FBlocos: TFPHashObjectList;
    FFila: TList;                 // TBloco pendentes (último pedido primeiro)
    FLinhas: array[0..LINHAS_DOWNLOAD - 1] of TLinhaDownload;
    FFonte: TFonteBlocos;
    FGoogle: TFonteGoogle;
    FOSM: TFonteOSM;
    FModo: TModoFonte;
    FPastaCache: string;
    FFalhasSeguidas: Integer;
    FProximaTentativaGoogle: QWord;
    FBaixados: Int64;
    FDoCache: Int64;
    FMensagens: TStringList;
    FGeracao: Integer;
    FSemMapa: Boolean;
    FTrocaPendente: TFonteBlocos;
    FMotivoTroca: string;
    FCreditoPendente: Boolean;
    FCredN, FCredS, FCredL, FCredO: Double;
    FCredZ: Integer;
    function TrataCredito: Boolean;
    function Chave(AZ, AX, AY: Integer): string;
    function ProximoPedido(out ABloco: TBloco; out AZ, AX, AY: Integer; out AFonte: TFonteBlocos;
      out AGeracao: Integer): Boolean;
    procedure Concluido(ABloco: TBloco; const APix: TPixels; AOk: Boolean; AGeracao: Integer;
      ADoCache: Boolean);
    procedure TrocaFonte(ANova: TFonteBlocos; const AMotivo: string);
    procedure LimpaMemoria;
    procedure Avisa(const ATexto: string);
    procedure Baixa(ABloco: TBloco; AZ, AX, AY: Integer; AFonte: TFonteBlocos; AGeracao: Integer);
  public
    constructor Create(const APastaCache, AChaveGoogle, AServidorOSM: string; AModo: TModoFonte);
    destructor Destroy; override;
    { Bloco pronto ou nil (nesse caso o pedido entra na fila). }
    function Obtem(AZ, AX, AY: Integer; APedir: Boolean = True; APrioridade: Integer = 1): TBloco;
    { Chamar de tempos em tempos (linha principal): volta ao Google no modo auto. }
    procedure Manutencao;
    function ProximaMensagem(out ATexto: string): Boolean;
    function NomeFonte: string;
    function ZoomMaximo: Integer;
    function Credito(ANorte, ASul, ALeste, AOeste: Double; AZoom: Integer): string;
    function EhSatelite: Boolean;
    property Baixados: Int64 read FBaixados;
    property DoCache: Int64 read FDoCache;
    property SemMapa: Boolean read FSemMapa;
  end;

function ModoFonteDeTexto(const ATexto: string): TModoFonte;
function ModoFonteParaTexto(AModo: TModoFonte): string;

implementation

function ModoFonteDeTexto(const ATexto: string): TModoFonte;
begin
  if SameText(ATexto, 'google') then
    Result := mfGoogle
  else if SameText(ATexto, 'osm') then
    Result := mfOSM
  else
    Result := mfAuto;
end;

function ModoFonteParaTexto(AModo: TModoFonte): string;
begin
  case AModo of
    mfGoogle: Result := 'google';
    mfOSM: Result := 'osm';
  else
    Result := 'auto';
  end;
end;

function AgoraUnix: Int64;
begin
  Result := DateTimeToUnix(LocalTimeToUniversal(Now));
end;

{ TBloco }

function TBloco.Amostra(APx, APy: Integer): LongWord;
begin
  Result := Pixels[(APy and 255) * 256 + (APx and 255)];
end;

{ TFonteBlocos }

function TFonteBlocos.Prepara: Boolean;
begin
  Result := True;
end;

procedure TFonteBlocos.ConfiguraCliente(ACli: TFPHTTPClient);
begin
  ACli.AddHeader('User-Agent', USER_AGENT_SIMULADOR);
end;

function TFonteBlocos.PrazoPadraoS: Integer;
begin
  Result := 0;
end;

{ TFonteGoogle }

constructor TFonteGoogle.Create(const AChave: string);
begin
  inherited Create;
  FChave := Trim(AChave);
  FLock := TCriticalSection.Create;
end;

destructor TFonteGoogle.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

function TFonteGoogle.Nome: string;
begin
  Result := 'Google (satélite)';
end;

function TFonteGoogle.Pasta: string;
begin
  Result := 'google';
end;

function TFonteGoogle.ZoomMaximo: Integer;
begin
  Result := 19;
end;

function TFonteGoogle.PrazoPadraoS: Integer;
begin
  Result := 0; // sem cabeçalho de prazo: não guarda em disco
end;

function TFonteGoogle.Prepara: Boolean;
var
  Cli: TFPHTTPClient;
  Corpo: TStringStream;
  Resp: string;
  J: TJSONData;
begin
  Result := False;
  if FChave = '' then
  begin
    FUltimoErro := 'sem chave de API do Google';
    Exit;
  end;
  FLock.Enter;
  try
    if (FSessao <> '') and (FValidade - AgoraUnix > 3600) then
      Exit(True);
  finally
    FLock.Leave;
  end;
  Cli := NovoClienteHttp(6000);
  Corpo := TStringStream.Create('{"mapType":"satellite","language":"pt-BR","region":"BR"}');
  try
    Cli.IOTimeout := 10000;
    Cli.ConnectTimeout := 10000;
    Cli.AddHeader('Content-Type', 'application/json');
    Cli.AddHeader('User-Agent', USER_AGENT_SIMULADOR);
    Cli.RequestBody := Corpo;
    try
      Resp := Cli.Post('https://tile.googleapis.com/v1/createSession?key=' + FChave);
    except
      on E: Exception do
      begin
        FUltimoErro := 'sessão do Google: ' + E.Message;
        Exit;
      end;
    end;
    if Cli.ResponseStatusCode <> 200 then
    begin
      FUltimoErro := Format('sessão do Google recusada (HTTP %d)', [Cli.ResponseStatusCode]);
      Exit;
    end;
    try
      J := GetJSON(Resp);
    except
      FUltimoErro := 'resposta inválida do Google';
      Exit;
    end;
    try
      if not (J is TJSONObject) then
        Exit;
      FLock.Enter;
      try
        FSessao := TJSONObject(J).Get('session', '');
        FValidade := StrToInt64Def(TJSONObject(J).Get('expiry', '0'), AgoraUnix + 86400);
        Result := FSessao <> '';
      finally
        FLock.Leave;
      end;
      if not Result then
        FUltimoErro := 'o Google não devolveu sessão';
    finally
      J.Free;
    end;
  finally
    Corpo.Free;
    Cli.Free;
  end;
end;

function TFonteGoogle.Url(AZ, AX, AY: Integer): string;
begin
  FLock.Enter;
  try
    Result := Format('https://tile.googleapis.com/v1/2dtiles/%d/%d/%d?session=%s&key=%s',
      [AZ, AX, AY, FSessao, FChave]);
  finally
    FLock.Leave;
  end;
end;

function ChaveArea(ANorte, ASul, ALeste, AOeste: Double; AZoom: Integer): string;
var
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Result := Format('%d/%.2f/%.2f', [AZoom, (ANorte + ASul) / 2, (ALeste + AOeste) / 2], FS);
end;

function TFonteGoogle.Credito(ANorte, ASul, ALeste, AOeste: Double; AZoom: Integer): string;
begin
  FLock.Enter;
  try
    Result := Trim('Google Maps  ' + FCredito);
  finally
    FLock.Leave;
  end;
end;

function TFonteGoogle.PrecisaCredito(ANorte, ASul, ALeste, AOeste: Double; AZoom: Integer): Boolean;
begin
  FLock.Enter;
  try
    Result := (FSessao <> '') and (ChaveArea(ANorte, ASul, ALeste, AOeste, AZoom) <> FCreditoChave) and
      (GetTickCount64 - FCreditoTick > 10000);
  finally
    FLock.Leave;
  end;
end;

procedure TFonteGoogle.AtualizaCredito(ANorte, ASul, ALeste, AOeste: Double; AZoom: Integer);
var
  Cli: TFPHTTPClient;
  Resp, K, Sess: string;
  J: TJSONData;
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  K := ChaveArea(ANorte, ASul, ALeste, AOeste, AZoom);
  FLock.Enter;
  try
    Sess := FSessao;
    FCreditoTick := GetTickCount64;
  finally
    FLock.Leave;
  end;
  if Sess = '' then
    Exit;
  Cli := NovoClienteHttp(6000);
  try
    Cli.IOTimeout := 5000;
    Cli.ConnectTimeout := 5000;
    Cli.AddHeader('User-Agent', USER_AGENT_SIMULADOR);
    try
      Resp := Cli.Get(Format('https://tile.googleapis.com/tile/v1/viewport?session=%s&key=%s' +
        '&zoom=%d&north=%.6f&south=%.6f&east=%.6f&west=%.6f',
        [Sess, FChave, AZoom, EnsureRange(ANorte, -89.9, 89.9), EnsureRange(ASul, -89.9, 89.9),
         EnsureRange(ALeste, -179.9, 179.9), EnsureRange(AOeste, -179.9, 179.9)], FS));
      J := GetJSON(Resp);
      try
        if J is TJSONObject then
        begin
          FLock.Enter;
          try
            FCredito := TJSONObject(J).Get('copyright', FCredito);
            FCreditoChave := K;
          finally
            FLock.Leave;
          end;
        end;
      finally
        J.Free;
      end;
    except
      // sem rede: mantém o último texto
    end;
  finally
    Cli.Free;
  end;
end;

{ TFonteOSM }

constructor TFonteOSM.Create(const AServidor: string);
begin
  inherited Create;
  FServidor := Trim(AServidor);
  if FServidor = '' then
    FServidor := 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
end;

function TFonteOSM.Nome: string;
begin
  Result := 'OpenStreetMap (ruas)';
end;

function TFonteOSM.Pasta: string;
begin
  Result := 'osm';
end;

function TFonteOSM.ZoomMaximo: Integer;
begin
  Result := 19;
end;

function TFonteOSM.Url(AZ, AX, AY: Integer): string;
begin
  Result := StringReplace(FServidor, '{z}', IntToStr(AZ), []);
  Result := StringReplace(Result, '{x}', IntToStr(AX), []);
  Result := StringReplace(Result, '{y}', IntToStr(AY), []);
end;

procedure TFonteOSM.ConfiguraCliente(ACli: TFPHTTPClient);
begin
  // Política do OSM: identificação clara e fixa; nomes genéricos são bloqueados.
  ACli.AddHeader('User-Agent', USER_AGENT_SIMULADOR);
end;

function TFonteOSM.PrazoPadraoS: Integer;
begin
  Result := 7 * 24 * 3600;
end;

function TFonteOSM.Credito(ANorte, ASul, ALeste, AOeste: Double; AZoom: Integer): string;
begin
  Result := '© OpenStreetMap contributors (openstreetmap.org/copyright)';
end;

{ TLinhaDownload }

constructor TLinhaDownload.Create(ADono: TGerenciadorBlocos);
begin
  FDono := ADono;
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TLinhaDownload.Execute;
var
  B: TBloco;
  F: TFonteBlocos;
  G, Z, X, Y: Integer;
begin
  while not Terminated do
  begin
    if (FDono.FLinhas[0] = Self) and FDono.TrataCredito then
      Continue;
    if FDono.ProximoPedido(B, Z, X, Y, F, G) then
      FDono.Baixa(B, Z, X, Y, F, G)
    else
      Sleep(30);
  end;
end;

{ TGerenciadorBlocos }

constructor TGerenciadorBlocos.Create(const APastaCache, AChaveGoogle, AServidorOSM: string;
  AModo: TModoFonte);
var
  I: Integer;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FBlocos := TFPHashObjectList.Create(True);
  FFila := TList.Create;
  FMensagens := TStringList.Create;
  FPastaCache := IncludeTrailingPathDelimiter(APastaCache);
  FGoogle := TFonteGoogle.Create(AChaveGoogle);
  FOSM := TFonteOSM.Create(AServidorOSM);
  FModo := AModo;
  case AModo of
    mfOSM:
      FFonte := FOSM;
    mfGoogle:
      begin
        FFonte := FGoogle;
        if not FGoogle.Prepara then
        begin
          Avisa('Google indisponível: ' + FGoogle.UltimoErro + '. Sem mapa (fonte fixada no Google).');
          FSemMapa := True;
        end;
      end;
  else
    if FGoogle.Prepara then
      FFonte := FGoogle
    else
    begin
      FFonte := FOSM;
      Avisa('Google indisponível (' + FGoogle.UltimoErro + '): usando o OpenStreetMap.');
      FProximaTentativaGoogle := GetTickCount64 + 5 * 60 * 1000;
    end;
  end;
  Avisa('Fonte de mapa: ' + FFonte.Nome);
  for I := 0 to High(FLinhas) do
    FLinhas[I] := TLinhaDownload.Create(Self);
end;

destructor TGerenciadorBlocos.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FLinhas) do
    FLinhas[I].Terminate;
  for I := 0 to High(FLinhas) do
  begin
    FLinhas[I].WaitFor;
    FLinhas[I].Free;
  end;
  FFila.Free;
  FBlocos.Free;
  FGoogle.Free;
  FOSM.Free;
  FMensagens.Free;
  FLock.Free;
  inherited Destroy;
end;

function TGerenciadorBlocos.Chave(AZ, AX, AY: Integer): string;
begin
  Result := IntToStr(AZ) + '/' + IntToStr(AX) + '/' + IntToStr(AY);
end;

procedure TGerenciadorBlocos.Avisa(const ATexto: string);
begin
  FLock.Enter;
  try
    FMensagens.Add(ATexto);
  finally
    FLock.Leave;
  end;
end;

function TGerenciadorBlocos.ProximaMensagem(out ATexto: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FMensagens.Count > 0;
    if Result then
    begin
      ATexto := FMensagens[0];
      FMensagens.Delete(0);
    end;
  finally
    FLock.Leave;
  end;
end;

function TGerenciadorBlocos.NomeFonte: string;
begin
  if FSemMapa then
    Result := 'sem mapa'
  else
    Result := FFonte.Nome;
end;

function TGerenciadorBlocos.ZoomMaximo: Integer;
begin
  Result := FFonte.ZoomMaximo;
end;

function TGerenciadorBlocos.EhSatelite: Boolean;
begin
  Result := (FFonte = FGoogle) and not FSemMapa;
end;

function TGerenciadorBlocos.Credito(ANorte, ASul, ALeste, AOeste: Double; AZoom: Integer): string;
begin
  if FSemMapa then
    Exit('sem mapa');
  Result := FFonte.Credito(ANorte, ASul, ALeste, AOeste, AZoom);
  // A consulta de direitos do Google vai para a linha de download.
  if (FFonte = FGoogle) and FGoogle.PrecisaCredito(ANorte, ASul, ALeste, AOeste, AZoom) then
  begin
    FLock.Enter;
    try
      FCreditoPendente := True;
      FCredN := ANorte; FCredS := ASul; FCredL := ALeste; FCredO := AOeste; FCredZ := AZoom;
    finally
      FLock.Leave;
    end;
  end;
end;

function TGerenciadorBlocos.TrataCredito: Boolean;
var
  N, S, L, O: Double;
  Z: Integer;
begin
  FLock.Enter;
  try
    Result := FCreditoPendente;
    FCreditoPendente := False;
    N := FCredN; S := FCredS; L := FCredL; O := FCredO; Z := FCredZ;
  finally
    FLock.Leave;
  end;
  if Result then
    FGoogle.AtualizaCredito(N, S, L, O, Z);
end;

procedure TGerenciadorBlocos.LimpaMemoria;
begin
  FFila.Clear;
  FBlocos.Clear;
end;

procedure TGerenciadorBlocos.TrocaFonte(ANova: TFonteBlocos; const AMotivo: string);
begin
  // Só marca: a troca (que descarta os blocos) acontece em Manutencao, na
  // linha principal, entre um quadro e outro.
  if ANova = FFonte then
    Exit;
  FTrocaPendente := ANova;
  FMotivoTroca := AMotivo;
  Inc(FGeracao); // downloads em andamento serão ignorados
end;

procedure TGerenciadorBlocos.Manutencao;
begin
  FLock.Enter;
  try
    if Assigned(FTrocaPendente) then
    begin
      FFonte := FTrocaPendente;
      FTrocaPendente := nil;
      LimpaMemoria;
      FFalhasSeguidas := 0;
      FMensagens.Add('Fonte de mapa: ' + FFonte.Nome + ' (' + FMotivoTroca + ').');
    end;
  finally
    FLock.Leave;
  end;
  if (FModo <> mfAuto) or (FFonte = FGoogle) or (FProximaTentativaGoogle = 0) or
    (GetTickCount64 < FProximaTentativaGoogle) then
    Exit;
  FProximaTentativaGoogle := GetTickCount64 + 5 * 60 * 1000;
  if FGoogle.Prepara then
  begin
    FLock.Enter;
    try
      TrocaFonte(FGoogle, 'Google respondeu de novo');
    finally
      FLock.Leave;
    end;
    Manutencao;
  end;
end;

function TGerenciadorBlocos.Obtem(AZ, AX, AY: Integer; APedir: Boolean; APrioridade: Integer): TBloco;
var
  K: string;
  B: TBloco;
  N, I: Integer;
begin
  Result := nil;
  if FSemMapa or (AZ < 0) then
    Exit;
  N := 1 shl AZ;
  if (AY < 0) or (AY >= N) then
    Exit;
  AX := ((AX mod N) + N) mod N;
  K := Chave(AZ, AX, AY);
  FLock.Enter;
  try
    B := TBloco(FBlocos.Find(K));
    if Assigned(B) then
    begin
      B.UltimoUso := GetTickCount64;
      if APrioridade > B.Prioridade then
        B.Prioridade := APrioridade;
      if B.Pronto then
        Exit(B);
      if B.Falhou and APedir and (GetTickCount64 > B.TentarDepois) then
      begin
        B.Falhou := False;
        FFila.Add(B);
      end;
      Exit;
    end;
    if not APedir then
      Exit;
    B := TBloco.Create;
    B.Z := AZ;
    B.X := AX;
    B.Y := AY;
    B.UltimoUso := GetTickCount64;
    B.Prioridade := APrioridade;
    B.NoDisco := FileExists(Format('%s%s%s%d%s%d%s%d.img', [FPastaCache, FFonte.Pasta,
      PathDelim, AZ, PathDelim, AX, PathDelim, AY]));
    FBlocos.Add(K, B);
    FFila.Add(B);
    // Fila limitada: sai o pedido que ninguém pede há mais tempo (saiu da tela).
    while FFila.Count > 400 do
    begin
      N := 0;
      for I := 1 to FFila.Count - 1 do
        if TBloco(FFila[I]).UltimoUso < TBloco(FFila[N]).UltimoUso then
          N := I;
      B := TBloco(FFila[N]);
      FFila.Delete(N);
      FBlocos.Remove(B);
    end;
  finally
    FLock.Leave;
  end;
end;

function TGerenciadorBlocos.ProximoPedido(out ABloco: TBloco; out AZ, AX, AY: Integer;
  out AFonte: TFonteBlocos; out AGeracao: Integer): Boolean;
var
  I, Mais: Integer;
  B: TBloco;
  Velho: QWord;
begin
  FLock.Enter;
  try
    Result := FFila.Count > 0;
    if not Result then
      Exit;
    // Ordem: cópia em disco primeiro (não espera a rede), depois a vista
    // principal, depois o pedido feito mais recentemente (está na tela agora).
    Mais := FFila.Count - 1;
    for I := FFila.Count - 2 downto 0 do
    begin
      B := TBloco(FFila[I]);
      with TBloco(FFila[Mais]) do
        if (Ord(B.NoDisco) > Ord(NoDisco)) or
          ((B.NoDisco = NoDisco) and (B.Prioridade > Prioridade)) or
          ((B.NoDisco = NoDisco) and (B.Prioridade = Prioridade) and (B.UltimoUso > UltimoUso)) then
          Mais := I;
    end;
    ABloco := TBloco(FFila[Mais]);
    FFila.Delete(Mais);
    AZ := ABloco.Z;
    AX := ABloco.X;
    AY := ABloco.Y;
    AFonte := FFonte;
    AGeracao := FGeracao;
    // Limite de memória: tira os blocos prontos usados há mais tempo.
    while FBlocos.Count > MAX_BLOCOS_MEMORIA do
    begin
      Mais := -1;
      Velho := High(QWord);
      for I := 0 to FBlocos.Count - 1 do
      begin
        B := TBloco(FBlocos[I]);
        // Só blocos fora da tela há 5 s: a linha principal pode estar usando os outros.
        if (B.Pronto or B.Falhou) and (B.UltimoUso < Velho) and (B <> ABloco) and
          (GetTickCount64 - B.UltimoUso > 5000) then
        begin
          Velho := B.UltimoUso;
          Mais := I;
        end;
      end;
      if Mais < 0 then
        Break;
      FBlocos.Delete(Mais);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TGerenciadorBlocos.Concluido(ABloco: TBloco; const APix: TPixels; AOk: Boolean;
  AGeracao: Integer; ADoCache: Boolean);
begin
  FLock.Enter;
  try
    if AGeracao <> FGeracao then
      Exit; // a fonte mudou enquanto baixava: o bloco pode já ter sido descartado
    if AOk then
    begin
      ABloco.Pixels := APix;
      ABloco.Pronto := True;
      FFalhasSeguidas := 0;
      if ADoCache then
        Inc(FDoCache)
      else
        Inc(FBaixados);
    end
    else
    begin
      ABloco.Falhou := True;
      ABloco.TentarDepois := GetTickCount64 + 30000;
      Inc(FFalhasSeguidas);
      if (FModo = mfAuto) and (FFonte = FGoogle) and (FFalhasSeguidas >= 5) then
      begin
        TrocaFonte(FOSM, 'falhas seguidas nos blocos do Google');
        FProximaTentativaGoogle := GetTickCount64 + 5 * 60 * 1000;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function DecodificaImagem(AStream: TStream; var APixels: TPixels): Boolean;
var
  Img: TFPMemoryImage;
  Leitor: TFPCustomImageReader;
  Sig: array[0..3] of Byte;
  X, Y: Integer;
  C: TFPColor;
begin
  Result := False;
  AStream.Position := 0;
  if AStream.Read(Sig, 4) < 4 then
    Exit;
  AStream.Position := 0;
  if (Sig[0] = $89) and (Sig[1] = $50) then
    Leitor := TFPReaderPNG.Create
  else if (Sig[0] = $FF) and (Sig[1] = $D8) then
    Leitor := TFPReaderJPEG.Create
  else
    Exit;
  Img := TFPMemoryImage.Create(0, 0);
  try
    try
      Img.LoadFromStream(AStream, Leitor);
    except
      Exit;
    end;
    if (Img.Width < 256) or (Img.Height < 256) then
      Exit;
    SetLength(APixels, 256 * 256);
    for Y := 0 to 255 do
      for X := 0 to 255 do
      begin
        C := Img.Colors[X * Img.Width div 256, Y * Img.Height div 256];
        APixels[Y * 256 + X] := (LongWord(C.Red shr 8) shl 16) or
          (LongWord(C.Green shr 8) shl 8) or LongWord(C.Blue shr 8);
      end;
    Result := True;
  finally
    Img.Free;
    Leitor.Free;
  end;
end;

function PrazoCache(const ACabecalho: string; APadrao: Integer; out ANaoGuardar: Boolean): Integer;
var
  S: string;
  P, Q: Integer;
begin
  Result := APadrao;
  ANaoGuardar := False;
  S := LowerCase(ACabecalho);
  if Pos('no-store', S) > 0 then
  begin
    ANaoGuardar := True;
    Exit(0);
  end;
  P := Pos('max-age=', S);
  if P > 0 then
  begin
    Inc(P, 8);
    Q := P;
    while (Q <= Length(S)) and (S[Q] in ['0'..'9']) do
      Inc(Q);
    Result := StrToIntDef(Copy(S, P, Q - P), APadrao);
    // OSM: sem condição de ler o prazo, mínimo de 7 dias; com prazo, segue o prazo.
  end;
end;

procedure TGerenciadorBlocos.Baixa(ABloco: TBloco; AZ, AX, AY: Integer; AFonte: TFonteBlocos;
  AGeracao: Integer);
var
  Arq, ArqMeta, ETag, CacheCtl: string;
  Meta: TStringList;
  Expira: Int64;
  Cli: TFPHTTPClient;
  Dados: TMemoryStream;
  Pix: TPixels;
  Ok, NaoGuardar, VeioDoCache: Boolean;
  Prazo: Integer;
begin
  Ok := False;
  VeioDoCache := False;
  Pix := nil;
  Arq := Format('%s%s%s%d%s%d%s%d.img', [FPastaCache, AFonte.Pasta, PathDelim,
    AZ, PathDelim, AX, PathDelim, AY]);
  ArqMeta := ChangeFileExt(Arq, '.meta');
  ETag := '';
  Expira := 0;
  Meta := TStringList.Create;
  Dados := TMemoryStream.Create;
  try
    // 1. Cache em disco ainda no prazo: sem rede.
    if FileExists(Arq) and FileExists(ArqMeta) then
    begin
      try
        Meta.LoadFromFile(ArqMeta);
        Expira := StrToInt64Def(Meta.Values['expira'], 0);
        ETag := Meta.Values['etag'];
        if Expira > AgoraUnix then
        begin
          Dados.LoadFromFile(Arq);
          Ok := DecodificaImagem(Dados, Pix);
          VeioDoCache := Ok;
        end;
      except
        Ok := False;
      end;
    end;

    // 2. Rede (com revalidação por ETag quando há cópia vencida).
    if not Ok then
    begin
      Cli := NovoClienteHttp(6000);
      try
        Cli.IOTimeout := 15000;
        Cli.ConnectTimeout := 10000;
        AFonte.ConfiguraCliente(Cli);
        if (ETag <> '') and FileExists(Arq) then
          Cli.AddHeader('If-None-Match', ETag);
        Dados.Clear;
        try
          Cli.HTTPMethod('GET', AFonte.Url(AZ, AX, AY), Dados, [200, 304]);
        except
          Concluido(ABloco, nil, False, AGeracao, False);
          Exit;
        end;
        CacheCtl := Cli.GetHeader(Cli.ResponseHeaders, 'Cache-Control');
        Prazo := PrazoCache(CacheCtl, AFonte.PrazoPadraoS, NaoGuardar);
        if Cli.ResponseStatusCode = 304 then
        begin
          Dados.Clear;
          Dados.LoadFromFile(Arq);
          Ok := DecodificaImagem(Dados, Pix);
          VeioDoCache := Ok;
        end
        else
        begin
          Ok := DecodificaImagem(Dados, Pix);
          ETag := Cli.GetHeader(Cli.ResponseHeaders, 'ETag');
          if Ok and not NaoGuardar and (Prazo > 0) then
          begin
            ForceDirectories(ExtractFilePath(Arq));
            try
              Dados.SaveToFile(Arq);
            except
            end;
          end;
        end;
        if Ok and not NaoGuardar and (Prazo > 0) then
        begin
          Meta.Clear;
          Meta.Values['expira'] := IntToStr(AgoraUnix + Prazo);
          Meta.Values['etag'] := ETag;
          try
            Meta.SaveToFile(ArqMeta);
          except
          end;
        end;
      finally
        Cli.Free;
      end;
    end;
    Concluido(ABloco, Pix, Ok, AGeracao, VeioDoCache);
  finally
    Dados.Free;
    Meta.Free;
  end;
end;

end.
