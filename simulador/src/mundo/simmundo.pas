unit simmundo;

{ Cliente do servidor de mundo compartilhado (PHP, JSON).

  Protocolo (docs/protocolo_mundo.md):
    entrar    -> recebe token, id, raio e intervalo
    atualizar -> envia posição (Authorization: Bearer <token>) e recebe só os
                 vizinhos e eventos a até 2 km
    evento    -> mensagem, sinal ou marcador para os vizinhos
    sair      -> invalida o token

  Roda numa linha própria; a posição vem do simulador por TLeEstado.
  Token vencido (HTTP 401): entra de novo sozinho. Servidor fora do ar: o voo
  continua, os vizinhos somem e o cliente tenta de novo a cada 2 s. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, Math, fphttpclient, opensslsockets, fpjson, jsonparser, simhttp,
  simtipos, simemulador;

type
  TVizinho = record
    Id: string;
    Apelido: string;
    Modelo: string;
    Lat, Lon, Alt: Double;
    Rumo, Velocidade: Double;
    Estado: string;
    DistanciaM: Double;
  end;
  TVizinhos = array of TVizinho;

  TEstadoMundo = (emDesligado, emEntrando, emConectado, emSemConexao);

  { TClienteMundo }

  TClienteMundo = class(TThread)
  private
    FUrl: string;
    FApelido: string;
    FModelo: string;
    FLeEstado: TLeEstado;
    FLock: TCriticalSection;
    FToken: string;
    FId: string;
    FRaio: Integer;
    FIntervalo: Integer;
    FUltimoEvento: Int64;
    FVizinhos: TVizinhos;
    FMensagens: TStringList;
    FSaida: TStringList;          // eventos JSON a enviar
    FEstado: TEstadoMundo;
    FUltimoErro: string;
    FMarcadores: TVizinhos;       // eventos "marcador" recebidos (posição + rótulo)
    function Chama(const ACorpo: TJSONObject; AComToken: Boolean; out AStatus: Integer;
      out AResposta: TJSONObject): Boolean;
    function ChamaTexto(const ACorpo: string; AComToken: Boolean; out AStatus: Integer;
      out AResposta: TJSONObject): Boolean;
    function Entra: Boolean;
    procedure Atualiza;
    procedure EnviaEventos;
    procedure Sai;
    procedure Mensagem(const ATexto: string);
    procedure DefineEstado(AEstado: TEstadoMundo; const AErro: string = '');
  protected
    procedure Execute; override;
  public
    constructor Create(const AUrl, AApelido, AModelo: string; ALeEstado: TLeEstado);
    destructor Destroy; override;
    procedure Parar;
    function Vizinhos: TVizinhos;
    function Marcadores: TVizinhos;
    function ProximaMensagem(out ATexto: string): Boolean;
    procedure EnviaMensagem(const ATexto: string);
    procedure EnviaSinal;
    procedure EnviaMarcador(ALat, ALon: Double; const ARotulo: string);
    function EstadoTexto: string;
    property Id: string read FId;
    property Raio: Integer read FRaio;
  end;

implementation

{ TClienteMundo }

constructor TClienteMundo.Create(const AUrl, AApelido, AModelo: string; ALeEstado: TLeEstado);
var
  U: string;
begin
  U := Trim(AUrl);
  if (U <> '') and (Pos('.php', LowerCase(U)) = 0) then
  begin
    if U[Length(U)] <> '/' then
      U := U + '/';
    U := U + 'api.php';
  end;
  FUrl := U;
  FApelido := Trim(AApelido);
  FModelo := AModelo;
  FLeEstado := ALeEstado;
  FLock := TCriticalSection.Create;
  FMensagens := TStringList.Create;
  FSaida := TStringList.Create;
  FRaio := 2000;
  FIntervalo := 500;
  FreeOnTerminate := False;
  inherited Create(False);
end;

destructor TClienteMundo.Destroy;
begin
  Parar;
  FSaida.Free;
  FMensagens.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TClienteMundo.Parar;
begin
  if not Finished then
  begin
    Terminate;
    WaitFor;
  end;
end;

procedure TClienteMundo.Mensagem(const ATexto: string);
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

function TClienteMundo.ProximaMensagem(out ATexto: string): Boolean;
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

procedure TClienteMundo.DefineEstado(AEstado: TEstadoMundo; const AErro: string);
begin
  FLock.Enter;
  try
    FEstado := AEstado;
    FUltimoErro := AErro;
    if AEstado <> emConectado then
      SetLength(FVizinhos, 0);
  finally
    FLock.Leave;
  end;
end;

function TClienteMundo.EstadoTexto: string;
begin
  FLock.Enter;
  try
    case FEstado of
      emDesligado: Result := 'fora do mundo';
      emEntrando: Result := 'entrando...';
      emConectado: Result := Format('no mundo (%d vizinhos a até %d m)', [Length(FVizinhos), FRaio]);
      emSemConexao: Result := 'sem conexão: ' + FUltimoErro;
    end;
  finally
    FLock.Leave;
  end;
end;

function TClienteMundo.Vizinhos: TVizinhos;
begin
  FLock.Enter;
  try
    Result := Copy(FVizinhos);
  finally
    FLock.Leave;
  end;
end;

function TClienteMundo.Marcadores: TVizinhos;
begin
  FLock.Enter;
  try
    Result := Copy(FMarcadores);
  finally
    FLock.Leave;
  end;
end;

procedure TClienteMundo.EnviaMensagem(const ATexto: string);
var
  O: TJSONObject;
begin
  if Trim(ATexto) = '' then
    Exit;
  O := TJSONObject.Create(['versao', 1, 'acao', 'evento', 'tipo', 'mensagem',
    'conteudo', Copy(Trim(ATexto), 1, 200)]);
  try
    FLock.Enter;
    try
      FSaida.Add(O.AsJSON);
    finally
      FLock.Leave;
    end;
  finally
    O.Free;
  end;
end;

procedure TClienteMundo.EnviaSinal;
var
  O: TJSONObject;
begin
  O := TJSONObject.Create(['versao', 1, 'acao', 'evento', 'tipo', 'sinal', 'conteudo', 'luzes']);
  try
    FLock.Enter;
    try
      FSaida.Add(O.AsJSON);
    finally
      FLock.Leave;
    end;
  finally
    O.Free;
  end;
end;

procedure TClienteMundo.EnviaMarcador(ALat, ALon: Double; const ARotulo: string);
var
  O: TJSONObject;
begin
  O := TJSONObject.Create(['versao', 1, 'acao', 'evento', 'tipo', 'marcador',
    'conteudo', TJSONObject.Create(['lat', ALat, 'lon', ALon, 'rotulo', Copy(ARotulo, 1, 40)])]);
  try
    FLock.Enter;
    try
      FSaida.Add(O.AsJSON);
    finally
      FLock.Leave;
    end;
  finally
    O.Free;
  end;
end;

function TClienteMundo.Chama(const ACorpo: TJSONObject; AComToken: Boolean;
  out AStatus: Integer; out AResposta: TJSONObject): Boolean;
begin
  Result := ChamaTexto(ACorpo.AsJSON, AComToken, AStatus, AResposta);
end;

function TClienteMundo.ChamaTexto(const ACorpo: string; AComToken: Boolean;
  out AStatus: Integer; out AResposta: TJSONObject): Boolean;
var
  Cli: TFPHTTPClient;
  Corpo: TStringStream;
  Txt: string;
  J: TJSONData;
begin
  Result := False;
  AResposta := nil;
  AStatus := 0;
  Cli := NovoClienteHttp(10000);
  Corpo := TStringStream.Create(ACorpo);
  try
    Cli.IOTimeout := 5000;
    Cli.ConnectTimeout := 5000;
    Cli.AddHeader('Content-Type', 'application/json; charset=utf-8');
    Cli.AddHeader('User-Agent', 'CockpitDroneSimulador/1.0');
    if AComToken then
      Cli.AddHeader('Authorization', 'Bearer ' + FToken);
    Cli.RequestBody := Corpo;
    try
      Txt := Cli.Post(FUrl);
    except
      on E: Exception do
      begin
        FUltimoErro := E.Message;
        Exit;
      end;
    end;
    AStatus := Cli.ResponseStatusCode;
    try
      J := GetJSON(Txt);
    except
      FUltimoErro := Format('resposta inválida (HTTP %d)', [AStatus]);
      Exit;
    end;
    if J is TJSONObject then
    begin
      AResposta := TJSONObject(J);
      Result := True;
    end
    else
      J.Free;
  finally
    Corpo.Free;
    Cli.Free;
  end;
end;

function TClienteMundo.Entra: Boolean;
var
  E: TEstadoVoo;
  Req, Resp: TJSONObject;
  St: Integer;
begin
  Result := False;
  DefineEstado(emEntrando);
  E := FLeEstado();
  Req := TJSONObject.Create(['versao', 1, 'acao', 'entrar', 'apelido', FApelido,
    'modelo', FModelo, 'posicao', TJSONObject.Create(['lat', E.Lat, 'lon', E.Lon, 'alt', E.Z])]);
  try
    if not Chama(Req, False, St, Resp) then
    begin
      DefineEstado(emSemConexao, FUltimoErro);
      Exit;
    end;
    try
      if (St <> 200) or not Resp.Get('ok', False) then
      begin
        DefineEstado(emSemConexao, Resp.Get('mensagem', Format('HTTP %d', [St])));
        Exit;
      end;
      FToken := Resp.Get('token', '');
      FId := Resp.Get('id', '');
      FRaio := Resp.Get('raio_m', 2000);
      FIntervalo := EnsureRange(Resp.Get('intervalo_ms', 500), 200, 5000);
      // Recebe só os eventos a partir da entrada.
      FUltimoEvento := Resp.Get('ultimo_evento', Int64(0));
      Result := FToken <> '';
      if Result then
      begin
        DefineEstado(emConectado);
        Mensagem(Format('Entrou no mundo como "%s" (%s).', [FApelido, FId]));
      end;
    finally
      Resp.Free;
    end;
  finally
    Req.Free;
  end;
end;

procedure TClienteMundo.Atualiza;
var
  E: TEstadoVoo;
  Req, Resp, V, P, Ev: TJSONObject;
  Arr: TJSONArray;
  St, I: Integer;
  Lista: TVizinhos;
  Marc: TVizinhos;
  Estado, Tipo, De: string;
  Seq: Int64;
  Cont: TJSONData;
begin
  E := FLeEstado();
  if E.Caiu then
    Estado := 'caiu'
  else if E.NoChao then
    Estado := 'parado'
  else
    Estado := 'voando';
  Req := TJSONObject.Create(['versao', 1, 'acao', 'atualizar',
    'posicao', TJSONObject.Create(['lat', E.Lat, 'lon', E.Lon, 'alt', RoundTo(E.Z, -1)]),
    'rumo', Round(E.Rumo) mod 360, 'velocidade', RoundTo(Hypot(E.VX, E.VY), -1),
    'estado', Estado, 'bateria', Round(E.Bateria), 'ultimo_evento', FUltimoEvento]);
  try
    if not Chama(Req, True, St, Resp) then
    begin
      DefineEstado(emSemConexao, FUltimoErro);
      Exit;
    end;
    try
      if St = 401 then
      begin
        Mensagem('Token vencido: entrando de novo.');
        FToken := '';
        Exit;
      end;
      if (St <> 200) or not Resp.Get('ok', False) then
      begin
        DefineEstado(emSemConexao, Resp.Get('mensagem', Format('HTTP %d', [St])));
        Exit;
      end;
      SetLength(Lista, 0);
      Arr := Resp.Get('vizinhos', TJSONArray(nil));
      if Assigned(Arr) then
        for I := 0 to Arr.Count - 1 do
          if Arr.Items[I] is TJSONObject then
          begin
            V := TJSONObject(Arr.Items[I]);
            SetLength(Lista, Length(Lista) + 1);
            with Lista[High(Lista)] do
            begin
              Id := V.Get('id', '');
              Apelido := V.Get('apelido', '');
              Modelo := V.Get('modelo', '');
              P := V.Get('posicao', TJSONObject(nil));
              if Assigned(P) then
              begin
                Lat := P.Get('lat', 0.0);
                Lon := P.Get('lon', 0.0);
                Alt := P.Get('alt', 0.0);
              end;
              Rumo := V.Get('rumo', 0.0);
              Velocidade := V.Get('velocidade', 0.0);
              Estado := V.Get('estado', '');
              DistanciaM := V.Get('distancia_m', 0.0);
            end;
          end;
      Marc := Marcadores;
      Arr := Resp.Get('eventos', TJSONArray(nil));
      if Assigned(Arr) then
        for I := 0 to Arr.Count - 1 do
          if Arr.Items[I] is TJSONObject then
          begin
            Ev := TJSONObject(Arr.Items[I]);
            Seq := Ev.Get('seq', Int64(0));
            if Seq > FUltimoEvento then
              FUltimoEvento := Seq;
            Tipo := Ev.Get('tipo', '');
            De := Ev.Get('apelido', Ev.Get('de', '?'));
            Cont := Ev.Find('conteudo');
            if Tipo = 'mensagem' then
            begin
              if Assigned(Cont) then
                Mensagem(De + ': ' + Cont.AsString);
            end
            else if Tipo = 'sinal' then
              Mensagem(De + ' piscou as luzes.')
            else if (Tipo = 'marcador') and (Cont is TJSONObject) then
            begin
              SetLength(Marc, Length(Marc) + 1);
              with Marc[High(Marc)] do
              begin
                Apelido := TJSONObject(Cont).Get('rotulo', '');
                Lat := TJSONObject(Cont).Get('lat', 0.0);
                Lon := TJSONObject(Cont).Get('lon', 0.0);
                Id := De;
              end;
              if Length(Marc) > 30 then
                Delete(Marc, 0, 1);
              Mensagem(De + ' marcou um ponto: ' + TJSONObject(Cont).Get('rotulo', ''));
            end;
          end;
      FLock.Enter;
      try
        FVizinhos := Lista;
        FMarcadores := Marc;
        FEstado := emConectado;
      finally
        FLock.Leave;
      end;
    finally
      Resp.Free;
    end;
  finally
    Req.Free;
  end;
end;

procedure TClienteMundo.EnviaEventos;
var
  Itens: TStringList;
  I, St: Integer;
  Req, Resp: TJSONObject;
  J: TJSONData;
begin
  Itens := TStringList.Create;
  try
    FLock.Enter;
    try
      Itens.Assign(FSaida);
      FSaida.Clear;
    finally
      FLock.Leave;
    end;
    for I := 0 to Itens.Count - 1 do
    begin
      J := GetJSON(Itens[I]);
      try
        Req := TJSONObject(J);
        // Envia o texto original (reprocessar o JSON pode trocar a codificação).
        if ChamaTexto(Itens[I], True, St, Resp) then
        begin
          if St <> 200 then
            Mensagem('Evento recusado: ' + Resp.Get('mensagem', IntToStr(St)))
          else if Req.Get('tipo', '') = 'mensagem' then
            Mensagem(Format('Você: %s (%d vizinhos receberam)',
              [Req.Get('conteudo', ''), Resp.Get('entregue_a', 0)]));
          Resp.Free;
        end;
      finally
        J.Free;
      end;
    end;
  finally
    Itens.Free;
  end;
end;

procedure TClienteMundo.Sai;
var
  Req, Resp: TJSONObject;
  St: Integer;
begin
  if FToken = '' then
    Exit;
  Req := TJSONObject.Create(['versao', 1, 'acao', 'sair']);
  try
    if Chama(Req, True, St, Resp) then
      Resp.Free;
  finally
    Req.Free;
  end;
  FToken := '';
  Mensagem('Saiu do mundo.');
end;

procedure TClienteMundo.Execute;
var
  Prox: QWord;
begin
  Prox := 0;
  while not Terminated do
  begin
    if GetTickCount64 < Prox then
    begin
      Sleep(20);
      Continue;
    end;
    if FToken = '' then
    begin
      if not Entra then
      begin
        Prox := GetTickCount64 + 2000;
        Continue;
      end;
    end;
    Prox := GetTickCount64 + QWord(FIntervalo);
    Atualiza;
    if FToken <> '' then
      EnviaEventos;
  end;
  Sai;
  DefineEstado(emDesligado);
end;

end.
