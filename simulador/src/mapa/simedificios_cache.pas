unit simedificios_cache;
{$mode objfpc}{$H+}
interface
uses Classes,SysUtils,SyncObjs,Math,simgeo,simedificios;
const SERVIDOR_EDIFICIOS_PADRAO = 'https://overpass-api.de/api/interpreter';
type
  TGerenciadorEdificios=class;
  TLinhaEdificios=class(TThread)
  private FDono:TGerenciadorEdificios;
  protected procedure Execute;override;
  public constructor Create(ADono:TGerenciadorEdificios);
  end;
  TGerenciadorEdificios=class
  private
    FLock:TCriticalSection; FEvento:TEvent; FLinha:TLinhaEdificios;
    FPasta,FChave,FStatus,FServidor,FArquivo:string; FErros:Integer; FOrigem:TPontoGeo;
    FPendente,FAtivo,FTerrenos:Boolean; FProximaRede:QWord;
    FCena:TCenaEdificios;
    function Pedido(out Chave:string;out Origem:TPontoGeo):Boolean;
    procedure Publica(const Chave:string;const Cena:TCenaEdificios;const Status:string);
  public
    constructor Create(const Pasta:string;const Servidor:string=SERVIDOR_EDIFICIOS_PADRAO;const Arquivo:string='';ATerrenos:Boolean=True);
    destructor Destroy;override;
    procedure Atualiza(Lat,Lon:Double;Ativo:Boolean);
    function Cena:TCenaEdificios;
    function Status:string;
  end;
implementation
uses fphttpclient,URIParser,simhttp,IniFiles,simurbanismo;
type TRespostaLimitada=class(TMemoryStream)
  function Write(const Buffer;Count:LongInt):LongInt;override;
end;
function TRespostaLimitada.Write(const Buffer;Count:LongInt):LongInt;
begin
  if Size+Count>8*1024*1024 then raise Exception.Create('Limite de edificios excedido');
  Result:=inherited Write(Buffer,Count);
end;
constructor TLinhaEdificios.Create(ADono:TGerenciadorEdificios);
begin FDono:=ADono;FreeOnTerminate:=False;inherited Create(True);Start;end;
constructor TGerenciadorEdificios.Create(const Pasta:string;const Servidor:string;const Arquivo:string;ATerrenos:Boolean);
begin
  inherited Create;FTerrenos:=ATerrenos;FServidor:=Servidor;FArquivo:=Arquivo;FPasta:=IncludeTrailingPathDelimiter(Pasta);ForceDirectories(FPasta);
  FLock:=TCriticalSection.Create;FEvento:=TEvent.Create(nil,False,False,'');
  FStatus:='Edificios: aguardando area';FLinha:=TLinhaEdificios.Create(Self);
end;
destructor TGerenciadorEdificios.Destroy;
begin FLinha.Terminate;FEvento.SetEvent;FLinha.WaitFor;FLinha.Free;FEvento.Free;FLock.Free;inherited Destroy;end;
procedure TGerenciadorEdificios.Atualiza(Lat,Lon:Double;Ativo:Boolean);
var A,B:Integer;Key:string;
begin
  if IsNan(Lat) or IsInfinite(Lat) or IsNan(Lon) or IsInfinite(Lon) or
    (Abs(Lat)>85) or (Abs(Lon)>179.99) then Exit;
  A:=Floor(Lat/0.005);B:=Floor(Lon/0.005);Key:='urban2_'+IntToStr(A)+'_'+IntToStr(B);
  FLock.Enter;
  try
    FAtivo:=Ativo;
    if not Ativo then begin FCena:=Default(TCenaEdificios);FChave:='';FPendente:=False;FStatus:='Edificios 3D desligados';Exit;end;
    if Key=FChave then Exit;
    FChave:=Key;FOrigem.Lat:=(A+0.5)*0.005;FOrigem.Lon:=(B+0.5)*0.005;
    FPendente:=True;FStatus:='Edificios: carregando contornos OSM...';
  finally FLock.Leave;end;
  FEvento.SetEvent;
end;
function TGerenciadorEdificios.Pedido(out Chave:string;out Origem:TPontoGeo):Boolean;
begin
  FLock.Enter;
  try Result:=FPendente and FAtivo;
    if Result and (FArquivo='') and (GetTickCount64<FProximaRede) then
      Result:=FileExists(FPasta+FChave+'.json') and
        ((Now-FileDateToDateTime(FileAge(FPasta+FChave+'.json')))<7);
    if Result then begin Chave:=FChave;Origem:=FOrigem;FPendente:=False;FProximaRede:=GetTickCount64+60000;end;
  finally FLock.Leave;end;
end;
procedure TGerenciadorEdificios.Publica(const Chave:string;const Cena:TCenaEdificios;const Status:string);
begin FLock.Enter;
  try if FAtivo and (Chave=FChave) then begin FCena:=Cena;FStatus:=Status;end;
  finally FLock.Leave;end;
end;
function TGerenciadorEdificios.Cena:TCenaEdificios;
begin FLock.Enter;try Result:=FCena;finally FLock.Leave;end;end;
function TGerenciadorEdificios.Status:string;
begin FLock.Enter;try Result:=FStatus;finally FLock.Leave;end;end;
procedure TLinhaEdificios.Execute;
var Key,FileName,Text,Query,MessageText:string; Origin:TPontoGeo; C:TCenaEdificios;
  HTTP:TFPHTTPClient; Response:TRespostaLimitada; Body:TStringStream;
  FS:TFormatSettings;Cache:TStringList;Cached:TFileStream;UseCache:Boolean;I,Estimated,Requests,Downloaded,Procedural:Integer;Budget:TIniFile;Day:string;SourceName:string;
begin
  FS:=DefaultFormatSettings;FS.DecimalSeparator:='.';
  while not Terminated do begin
    FDono.FEvento.WaitFor(1000);if Terminated then Break;
    if not FDono.Pedido(Key,Origin) then Continue;
    FileName:=FDono.FPasta+Key+'.json';Cache:=TStringList.Create;UseCache:=False;
    try
      SourceName:=FileName;
      if FDono.FArquivo<>'' then SourceName:=FDono.FArquivo;
      UseCache:=(FDono.FArquivo<>'') or (FileExists(FileName) and ((Now-FileDateToDateTime(FileAge(FileName)))<7));
      if UseCache then begin
        Cached:=TFileStream.Create(SourceName,fmOpenRead or fmShareDenyNone);
        try if Cached.Size>8*1024*1024 then raise Exception.Create('Cache muito grande');Cache.LoadFromStream(Cached);finally Cached.Free;end;
        Text:=Cache.Text;
      end else begin
        if not (Pos('https://',LowerCase(FDono.FServidor))=1) and
           not (Pos('http://127.0.0.1:',FDono.FServidor)=1) then raise Exception.Create('Servidor de edificios precisa usar HTTPS');
        Day:=FormatDateTime('yyyy-mm-dd',Now);Budget:=TIniFile.Create(FDono.FPasta+'rede.ini');
        try
          Requests:=Budget.ReadInteger(Day,'consultas',0);Downloaded:=Budget.ReadInteger(Day,'bytes',0);
          if (Requests>=80) or (Downloaded>=8*1024*1024) then raise Exception.Create('Limite diario de consultas atingido; use cache ou arquivo OSM');
          Budget.WriteInteger(Day,'consultas',Requests+1);Budget.UpdateFile;
        finally Budget.Free;end;
        Query:='[out:json][timeout:8];(way["building"]["building"!="no"](around:800,'+
          FloatToStr(Origin.Lat,FS)+','+FloatToStr(Origin.Lon,FS)+');relation["building"]["type"="multipolygon"](around:800,'+
          FloatToStr(Origin.Lat,FS)+','+FloatToStr(Origin.Lon,FS)+');'+
          'way["highway"](around:1000,'+FloatToStr(Origin.Lat,FS)+','+FloatToStr(Origin.Lon,FS)+');'+
          'nwr["landuse"](around:1000,'+FloatToStr(Origin.Lat,FS)+','+FloatToStr(Origin.Lon,FS)+');'+
          'nwr["leisure"](around:1000,'+FloatToStr(Origin.Lat,FS)+','+FloatToStr(Origin.Lon,FS)+');'+
          'nwr["natural"](around:1000,'+FloatToStr(Origin.Lat,FS)+','+FloatToStr(Origin.Lon,FS)+');'+
          'nwr["amenity"="parking"](around:1000,'+FloatToStr(Origin.Lat,FS)+','+FloatToStr(Origin.Lon,FS)+');'+
          'nwr["area:highway"](around:1000,'+FloatToStr(Origin.Lat,FS)+','+FloatToStr(Origin.Lon,FS)+'););out geom;';
        HTTP:=NovoClienteHttp(10000);Response:=TRespostaLimitada.Create;
        Body:=TStringStream.Create('data='+EncodeURLElement(Query));
        try HTTP.AddHeader('User-Agent','CockpitDroneSimulator/0.46 (+https://github.com/marcelomaurin/cockpit_drone)');
          HTTP.AddHeader('Content-Type','application/x-www-form-urlencoded');HTTP.RequestBody:=Body;
          HTTP.Post(FDono.FServidor,Response);
          Budget:=TIniFile.Create(FDono.FPasta+'rede.ini');
          try Budget.WriteInteger(Day,'bytes',Downloaded+Response.Size);Budget.UpdateFile;finally Budget.Free;end;
          SetLength(Text,Response.Size);if Response.Size>0 then Move(Response.Memory^,Text[1],Response.Size);
        finally HTTP.RequestBody:=nil;Body.Free;Response.Free;HTTP.Free;end;
      end;
      C:=LeCenaOSM(Text,Origin);
      if FDono.FTerrenos then GeraConstrucoesNosTerrenos(Text,Origin,C);
      FDono.FErros:=0;
      if not UseCache then begin Cache.Text:=Text;Cache.SaveToFile(FileName+'.tmp');
        if FileExists(FileName) then DeleteFile(FileName);RenameFile(FileName+'.tmp',FileName);end;
      Estimated:=0;for I:=0 to High(C.Itens) do if C.Itens[I].Estimada then Inc(Estimated);
      Procedural:=0;for I:=0 to High(C.Itens) do if C.Itens[I].Procedural then Inc(Procedural);
      MessageText:=Format('Construcoes: %d OSM + %d simuladas (%d alturas estimadas)',[Length(C.Itens)-Procedural,Procedural,Estimated]);
      if FDono.FArquivo<>'' then MessageText:=MessageText+' [arquivo local]';
      if Length(C.Itens)=0 then MessageText:='Edificios: sem contornos cadastrados nesta area';
      FDono.Publica(Key,C,MessageText);
    except on E:Exception do begin
      if UseCache and (FDono.FArquivo='') and FileExists(FileName) then RenameFile(FileName,FileName+'.invalid-'+IntToStr(GetTickCount64));
      FDono.FLock.Enter;
      try
        if FDono.FChave=Key then begin FDono.FStatus:='Edificios indisponiveis: '+E.Message;
          FDono.FErros:=Min(FDono.FErros+1,5);FDono.FPendente:=FDono.FArquivo='';
          FDono.FProximaRede:=GetTickCount64+QWord(Min(3600000,300000*(1 shl (FDono.FErros-1))));end;
      finally FDono.FLock.Leave;end;
    end;end;
    Cache.Free;
  end;
end;
end.
