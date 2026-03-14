unit objetos;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, fpjson, jsonparser;

type
  { TObjetoMapa }
  TObjetoMapa = class
  private
    FNome: string;
    FLatitude: Double;
    FLongitude: Double;
    FIcone: string;
    FVisivel: Boolean;
  public
    constructor Create; overload;
    constructor Create(const ANome: string; ALatitude, ALongitude: Double;
      const AIcone: string; AVisivel: Boolean = True); overload;

    function ToJSON: TJSONObject;
    procedure FromJSON(AJSON: TJSONObject);

    property Nome: string read FNome write FNome;
    property Latitude: Double read FLatitude write FLatitude;
    property Longitude: Double read FLongitude write FLongitude;
    property Icone: string read FIcone write FIcone;
    property Visivel: Boolean read FVisivel write FVisivel;
  end;

  { TObjetosMapa }
  TObjetosMapa = class
  private
    FLista: TObjectList;
    function GetCount: Integer;
    function GetItem(AIndex: Integer): TObjetoMapa;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Limpar;
    procedure CriarPadrao;
    function Adicionar(const ANome: string; ALatitude, ALongitude: Double;
      const AIcone: string; AVisivel: Boolean = True): Integer;
    function Inserir(AIndex: Integer; const ANome: string; ALatitude, ALongitude: Double;
      const AIcone: string; AVisivel: Boolean = True): Integer;
    procedure Excluir(AIndex: Integer);
    procedure SalvarArquivo(const AArquivo: string);
    procedure CarregarArquivo(const AArquivo: string);

    function BuscarPorNome(const ANome: string): Integer;

    property Count: Integer read GetCount;
    property Itens[AIndex: Integer]: TObjetoMapa read GetItem; default;
  end;

implementation

{ TObjetoMapa }

constructor TObjetoMapa.Create;
begin
  inherited Create;
  FNome := '';
  FLatitude := 0;
  FLongitude := 0;
  FIcone := '';
  FVisivel := True;
end;

constructor TObjetoMapa.Create(const ANome: string; ALatitude, ALongitude: Double;
  const AIcone: string; AVisivel: Boolean);
begin
  inherited Create;
  FNome := ANome;
  FLatitude := ALatitude;
  FLongitude := ALongitude;
  FIcone := AIcone;
  FVisivel := AVisivel;
end;

function TObjetoMapa.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('nome', FNome);
  Result.Add('latitude', FLatitude);
  Result.Add('longitude', FLongitude);
  Result.Add('icone', FIcone);
  Result.Add('visivel', FVisivel);
end;

procedure TObjetoMapa.FromJSON(AJSON: TJSONObject);
begin
  if not Assigned(AJSON) then
    Exit;

  FNome := AJSON.Get('nome', '');
  FLatitude := AJSON.Get('latitude', 0.0);
  FLongitude := AJSON.Get('longitude', 0.0);
  FIcone := AJSON.Get('icone', '');
  FVisivel := AJSON.Get('visivel', True);
end;

{ TObjetosMapa }

constructor TObjetosMapa.Create;
begin
  inherited Create;
  FLista := TObjectList.Create(True);
end;

destructor TObjetosMapa.Destroy;
begin
  FreeAndNil(FLista);
  inherited Destroy;
end;

function TObjetosMapa.GetCount: Integer;
begin
  Result := FLista.Count;
end;

function TObjetosMapa.GetItem(AIndex: Integer): TObjetoMapa;
begin
  if (AIndex < 0) or (AIndex >= FLista.Count) then
    Result := nil
  else
    Result := TObjetoMapa(FLista[AIndex]);
end;

procedure TObjetosMapa.Limpar;
begin
  FLista.Clear;
end;

procedure TObjetosMapa.CriarPadrao;
begin
  Limpar;

  { vetor[0] = Jardinópolis/SP }
  Adicionar('Jardinópolis/SP', -21.0178, -47.7639, 'jardinopolis.png', True);
end;

function TObjetosMapa.Adicionar(const ANome: string; ALatitude, ALongitude: Double;
  const AIcone: string; AVisivel: Boolean): Integer;
begin
  Result := FLista.Add(
    TObjetoMapa.Create(ANome, ALatitude, ALongitude, AIcone, AVisivel)
  );
end;

function TObjetosMapa.Inserir(AIndex: Integer; const ANome: string; ALatitude,
  ALongitude: Double; const AIcone: string; AVisivel: Boolean): Integer;
var
  Obj: TObjetoMapa;
begin
  Obj := TObjetoMapa.Create(ANome, ALatitude, ALongitude, AIcone, AVisivel);

  if AIndex < 0 then
    AIndex := 0;

  if AIndex > FLista.Count then
    AIndex := FLista.Count;

  FLista.Insert(AIndex, Obj);
  Result := AIndex;
end;

procedure TObjetosMapa.Excluir(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= FLista.Count) then
    Exit;

  FLista.Delete(AIndex);
end;

procedure TObjetosMapa.SalvarArquivo(const AArquivo: string);
var
  Arr: TJSONArray;
  Obj: TJSONObject;
  I: Integer;
  S: TStringList;
begin
  Arr := TJSONArray.Create;
  S := TStringList.Create;
  try
    for I := 0 to FLista.Count - 1 do
    begin
      Obj := Itens[I].ToJSON;
      Arr.Add(Obj);
    end;

    S.Text := Arr.FormatJSON;
    S.SaveToFile(AArquivo);
  finally
    S.Free;
    Arr.Free;
  end;
end;

procedure TObjetosMapa.CarregarArquivo(const AArquivo: string);
var
  Parser: TJSONParser;
  Data: TJSONData;
  Arr: TJSONArray;
  ObjJSON: TJSONObject;
  Obj: TObjetoMapa;
  I: Integer;
  S: TStringList;
begin
  if not FileExists(AArquivo) then
  begin
    CriarPadrao;
    Exit;
  end;

  Limpar;

  S := TStringList.Create;
  try
    S.LoadFromFile(AArquivo);

    Parser := TJSONParser.Create(S.Text);
    try
      Data := Parser.Parse;
      try
        if Data.JSONType <> jtArray then
          Exit;

        Arr := TJSONArray(Data);

        for I := 0 to Arr.Count - 1 do
        begin
          if Arr.Items[I].JSONType = jtObject then
          begin
            ObjJSON := TJSONObject(Arr.Items[I]);
            Obj := TObjetoMapa.Create;
            Obj.FromJSON(ObjJSON);
            FLista.Add(Obj);
          end;
        end;

        if FLista.Count = 0 then
          CriarPadrao;

      finally
        Data.Free;
      end;
    finally
      Parser.Free;
    end;
  finally
    S.Free;
  end;
end;

function TObjetosMapa.BuscarPorNome(const ANome: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FLista.Count - 1 do
  begin
    if SameText(Itens[I].Nome, ANome) then
      Exit(I);
  end;
end;

end.
