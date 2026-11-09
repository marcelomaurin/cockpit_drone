unit simedificios;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Math, fpjson, jsonparser, simgeo;
type
  TPontoEdificio=record X,Y:Double; end;
  TAnelEdificio=array of TPontoEdificio;
  TAneisEdificio=array of TAnelEdificio;
  TEdificio=record
    Id,Tipo:string;
    Contorno:TAnelEdificio;
    Patios:TAneisEdificio;
    Altura,Base:Double;
    Estimada,Procedural:Boolean;
    Parede,Telhado:LongWord;
    MinX,MinY,MaxX,MaxY:Double;
    { Altura da cumeeira acima das paredes; >0 desenha telhado de quatro aguas
      em contornos retangulares (4 vertices). }
    Cumeeira:Double;
  end;
  TEdificios=array of TEdificio;
  TViaEdificio=record Pontos:TAnelEdificio;RaioLivre:Double;end;
  TViasEdificio=array of TViaEdificio;
  { Objetos de quintal para o treinamento de vigilancia do Aedes aegypti.
    Medidas em metros, eixo local do lote (S = lateral, F = frente para a rua). }
  TTipoObjetoQuintal=(oqVaso,oqPiscina,oqCaixaDagua,oqPneu,oqTanquePeixe,oqBalde);
  TObjetoQuintal=record
    Tipo:TTipoObjetoQuintal;
    X,Y,Z:Double;          // centro no plano da cena; Z = base
    Angulo:Double;         // rumo do eixo F do lote, radianos
    Largura,Comprimento,Altura:Double;
    Criadouro:Boolean;     // agua parada exposta (ponto de risco)
    Cor:LongWord;
  end;
  TObjetosQuintal=array of TObjetoQuintal;
  TPisoLote=record Canto:array[0..3] of TPontoEdificio;Cor:LongWord;end;
  TLote=record
    Id:string;
    Lat,Lon:Double;        // centro do lote, para o gabarito do instrutor
    Canto:array[0..3] of TPontoEdificio; // perimetro do muro
    MuroAltura:Double;
    PortaoInicio,PortaoFim:Double;        // trecho do muro frontal (0..1) com portao
    Pisos:array of TPisoLote;
    Objetos:TObjetosQuintal;
    Criadouros:Integer;
    MinX,MinY,MaxX,MaxY:Double;
  end;
  TLotes=array of TLote;
  TCenaEdificios=record Origem:TPontoGeo; Itens:TEdificios; Vias:TViasEdificio; Ignorados:Integer; Lotes:TLotes; end;
var
  { Gera lotes com quintal e criadouros simulados do Aedes nas casas procedurais. }
  GerarCriadouros:Boolean=True;
function PontoNoAnel(X,Y:Double; const Anel:TAnelEdificio):Boolean;
function DentroEdificio(X,Y:Double; const E:TEdificio):Boolean;
function ValidaArquivoOSM(const Arquivo:string;out Erro:string):Boolean;
function LePontosOSM(A:TJSONArray;const Origem:TPontoGeo):TAnelEdificio;
function FechaAnel(var R:TAnelEdificio):Boolean;
procedure UneAneis(var Rings:TAneisEdificio);
function LeCenaOSM(const Texto:string; const Origem:TPontoGeo):TCenaEdificios;
function AreaAnel(const R:TAnelEdificio):Double;
procedure AlturaPelaArea(var E:TEdificio);
const
  { Proporcoes de referencia: pe-direito residencial de ~2,8 m mais laje. }
  ALTURA_TERREA=3.1;
  ALTURA_SOBRADO=6.0;
  CUMEEIRA_CASA=1.4;
implementation
function AreaAnel(const R:TAnelEdificio):Double;
var Q:Integer;
begin
  Result:=0;
  for Q:=0 to High(R) do Result:=Result+R[Q].X*R[(Q+1) mod Length(R)].Y-R[(Q+1) mod Length(R)].X*R[Q].Y;
  Result:=Abs(Result)/2;
end;
{ Construcao sem altura nem andares no mapa: casas pequenas sao terreas;
  areas medias sao comercio/galpao baixo; grandes, galpao. Nada vira predio
  sem informacao, para nao criar torres onde nao existem. }
procedure AlturaPelaArea(var E:TEdificio);
var A:Double;
begin
  A:=AreaAnel(E.Contorno);
  if A<=260 then begin
    E.Tipo:='house';E.Altura:=ALTURA_TERREA;
    if Length(E.Contorno)=4 then E.Cumeeira:=CUMEEIRA_CASA;
  end else if A<=1500 then begin
    E.Altura:=6;E.Telhado:=$9DA0A2;
  end else begin
    E.Tipo:='warehouse';E.Altura:=8;E.Telhado:=$AEB1B3;
  end;
  E.Estimada:=True;
end;
function ValidaArquivoOSM(const Arquivo:string;out Erro:string):Boolean;
var Stream:TFileStream;Text:TStringList;Root:TJSONData;
begin
 Result:=False;Erro:='';Root:=nil;Text:=TStringList.Create;
 try
  try
   Stream:=TFileStream.Create(Arquivo,fmOpenRead or fmShareDenyNone);
   try if Stream.Size>8*1024*1024 then raise Exception.Create('Arquivo excede 8 MB');Text.LoadFromStream(Stream);finally Stream.Free;end;
   Root:=GetJSON(Text.Text);
   if not (Root is TJSONObject) then raise Exception.Create('Escolha uma exportacao JSON do OpenStreetMap/Overpass');
   if not (TJSONObject(Root).Find('elements') is TJSONArray) then
    raise Exception.Create('Este arquivo nao tem dados de mapa OSM (elements). Planos de voo/projetos nao contem terrenos ou construcoes.');
   Result:=True;
  except on E:Exception do Erro:=E.Message;end;
 finally Root.Free;Text.Free;end;
end;
function PontoNoAnel(X,Y:Double; const Anel:TAnelEdificio):Boolean;
var I,J:Integer;
begin
  Result:=False; J:=High(Anel);
  for I:=0 to High(Anel) do begin
    if ((Anel[I].Y>Y)<>(Anel[J].Y>Y)) and
       (X<(Anel[J].X-Anel[I].X)*(Y-Anel[I].Y)/(Anel[J].Y-Anel[I].Y)+Anel[I].X) then Result:=not Result;
    J:=I;
  end;
end;
function DentroEdificio(X,Y:Double; const E:TEdificio):Boolean;
var I:Integer;
begin
  Result:=PontoNoAnel(X,Y,E.Contorno);
  if Result then for I:=0 to High(E.Patios) do
    if PontoNoAnel(X,Y,E.Patios[I]) then Exit(False);
end;
function Medida(const S:string; out V:Double):Boolean;
var T:string; FS:TFormatSettings; Feet:Boolean;
begin
  T:=LowerCase(Trim(S)); Feet:=False;
  if T.EndsWith('ft') then begin Feet:=True; Delete(T,Length(T)-1,2); end
  else if T.EndsWith('m') then Delete(T,Length(T),1);
  FS:=DefaultFormatSettings; FS.DecimalSeparator:='.';
  Result:=TryStrToFloat(Trim(T),V,FS);
  if Result then begin if Feet then V:=V*0.3048;
    Result:=not IsNan(V) and not IsInfinite(V) and (V>=0) and (V<=1000); end;
end;
function CorTag(const S:string; Default:LongWord):LongWord;
var N:LongWord;
begin
  Result:=Default;
  if (Length(S)=7) and (S[1]='#') and TryStrToDWord('$'+Copy(S,2,6),N) then Result:=N and $FFFFFF
  else case LowerCase(S) of
    'red':Result:=$9B5147; 'white':Result:=$E3DFD4; 'grey','gray':Result:=$999B9E;
    'brown':Result:=$89694C; 'beige':Result:=$C6B995; 'yellow':Result:=$DDCB91;
  end;
end;
  function LePontosOSM(A:TJSONArray;const Origem:TPontoGeo):TAnelEdificio;
  var Q:Integer; P:TJSONObject; Lat,Lon:Double;
  begin
    Result:=nil; if not Assigned(A) or (A.Count<2) or (A.Count>1025) then Exit;
    SetLength(Result,A.Count);
    for Q:=0 to A.Count-1 do begin
      if not (A.Items[Q] is TJSONObject) then Exit(nil);
      P:=TJSONObject(A.Items[Q]); if (P.Find('lat')=nil) or (P.Find('lon')=nil) then Exit(nil);
      Lat:=P.Get('lat',999.0); Lon:=P.Get('lon',999.0);
      if IsNan(Lat) or IsNan(Lon) or IsInfinite(Lat) or IsInfinite(Lon) or
         (Abs(Lat)>85) or (Abs(Lon)>180) then Exit(nil);
      GeoParaLocal(Origem,Lat,Lon,Result[Q].X,Result[Q].Y);
      if (Abs(Result[Q].X)>20000) or (Abs(Result[Q].Y)>20000) then Exit(nil);
    end;
  end;
  function Same(const A,B:TPontoEdificio):Boolean;
  begin Result:=Hypot(A.X-B.X,A.Y-B.Y)<0.05; end;
  function FechaAnel(var R:TAnelEdificio):Boolean;
  var Q:Integer; Area:Double;
  begin
    Result:=False; if (Length(R)<4) or (Length(R)>1025) or not Same(R[0],R[High(R)]) then Exit;
    SetLength(R,Length(R)-1); Area:=0;
    for Q:=0 to High(R) do Area:=Area+R[Q].X*R[(Q+1) mod Length(R)].Y-R[(Q+1) mod Length(R)].X*R[Q].Y;
    Result:=Abs(Area)>2;
  end;
  procedure AddRing(var Rings:TAneisEdificio; const R:TAnelEdificio);
  begin SetLength(Rings,Length(Rings)+1); Rings[High(Rings)]:=R; end;
  procedure UneAneis(var Rings:TAneisEdificio);
  var Segs:TAneisEdificio; R:TAnelEdificio; A,B,C,L:Integer; Found,Reversed:Boolean; Tmp:TPontoEdificio;
  begin
    Segs:=Rings; Rings:=nil;
    while Length(Segs)>0 do begin
      R:=Segs[0]; Delete(Segs,0,1); if Length(R)<2 then Continue;
      Reversed:=False;
      while not Same(R[0],R[High(R)]) do begin
        Found:=False;
        for A:=0 to High(Segs) do if Length(Segs[A])>=2 then begin
          if Same(R[High(R)],Segs[A][0]) then begin
            L:=Length(R); SetLength(R,L+Length(Segs[A])-1);
            for B:=1 to High(Segs[A]) do R[L+B-1]:=Segs[A][B]; Found:=True;
          end else if Same(R[High(R)],Segs[A][High(Segs[A])]) then begin
            L:=Length(R); SetLength(R,L+Length(Segs[A])-1);
            for B:=1 to High(Segs[A]) do R[L+B-1]:=Segs[A][High(Segs[A])-B]; Found:=True;
          end;
          if Found then begin Delete(Segs,A,1); Break; end;
        end;
        if Length(R)>1025 then Break;
        if not Found then begin
          if Reversed then Break;
          for C:=0 to Length(R) div 2-1 do begin Tmp:=R[C];R[C]:=R[High(R)-C];R[High(R)-C]:=Tmp; end;
          Reversed:=True;
        end;
      end;
      if FechaAnel(R) then AddRing(Rings,R);
    end;
  end;

function LeCenaOSM(const Texto:string; const Origem:TPontoGeo):TCenaEdificios;
var Root:TJSONData; Elements:TJSONArray; I,J:Integer; Obj,Tags,Member:TJSONObject;
  Geometry,Members:TJSONArray; Used:TStringList; Outers,Inners:TAneisEdificio;
  E:TEdificio; Levels,Roof,Value:Double; Ring:TAnelEdificio; PorArea:Boolean;
  function Tag(const Name:string):string;
  begin if Assigned(Tags) then Result:=Tags.Get(Name,'') else Result:=''; end;
  procedure AddBuilding(const R:TAnelEdificio);
  var Q:Integer;
  begin
    if (Length(R)<3) or (Length(Result.Itens)>=4000) then Exit;
    E.Contorno:=R; E.Patios:=nil;
    for Q:=0 to High(Inners) do if PontoNoAnel(Inners[Q][0].X,Inners[Q][0].Y,R) then AddRing(E.Patios,Inners[Q]);
    E.MinX:=R[0].X;E.MaxX:=E.MinX;E.MinY:=R[0].Y;E.MaxY:=E.MinY;
    for Q:=1 to High(R) do begin E.MinX:=Min(E.MinX,R[Q].X);E.MaxX:=Max(E.MaxX,R[Q].X);
      E.MinY:=Min(E.MinY,R[Q].Y);E.MaxY:=Max(E.MaxY,R[Q].Y); end;
    if PorArea then AlturaPelaArea(E)
    else if E.Estimada and (E.Altura<=ALTURA_TERREA+0.01) and (Length(R)=4) then E.Cumeeira:=CUMEEIRA_CASA;
    SetLength(Result.Itens,Length(Result.Itens)+1);Result.Itens[High(Result.Itens)]:=E;
  end;
begin
  Result:=Default(TCenaEdificios);Result.Origem:=Origem;
  if Length(Texto)>8*1024*1024 then raise Exception.Create('Dados de edificios excedem 8 MB');
  Root:=GetJSON(Texto); Used:=TStringList.Create;
  try
    if not (Root is TJSONObject) then raise Exception.Create('Resposta OSM invalida');
    if TJSONObject(Root).Get('remark','')<>'' then raise Exception.Create('Consulta OSM incompleta');
    if not (TJSONObject(Root).Find('elements') is TJSONArray) then raise Exception.Create('Elementos OSM ausentes');
    Elements:=TJSONArray(TJSONObject(Root).Find('elements'));
    if Elements.Count>15000 then raise Exception.Create('Muitos elementos OSM');
    Used.Sorted:=True;Used.Duplicates:=dupIgnore;
    for I:=0 to Elements.Count-1 do if Elements.Items[I] is TJSONObject then begin
      Obj:=TJSONObject(Elements.Items[I]);
      if (Obj.Get('type','')='relation') and (Obj.Find('members') is TJSONArray) and
        (Obj.Find('tags') is TJSONObject) and (TJSONObject(Obj.Find('tags')).Get('building','')<>'') then begin
        Members:=TJSONArray(Obj.Find('members'));
        for J:=0 to Members.Count-1 do if Members.Items[J] is TJSONObject then
          Used.Add(TJSONObject(Members.Items[J]).Get('ref',Int64(0)).ToString);
      end;
    end;
    for I:=0 to Elements.Count-1 do if Elements.Items[I] is TJSONObject then begin
      Obj:=TJSONObject(Elements.Items[I]);Tags:=nil;
      if Obj.Find('tags') is TJSONObject then Tags:=TJSONObject(Obj.Find('tags'));
      if (Tag('building')='') or (Tag('building')='no') then Continue;
      E:=Default(TEdificio);E.Id:=Obj.Get('type','')+'/'+Obj.Get('id',Int64(0)).ToString;
      E.Tipo:=Tag('building'); E.Estimada:=not Medida(Tag('height'),E.Altura) or (E.Altura<=0);
      if E.Estimada then begin
        if Medida(Tag('building:levels'),Levels) and (Levels>0) then begin
          Roof:=0;Medida(Tag('roof:height'),Roof); E.Altura:=Levels*3+Roof;
        end else if E.Tipo='apartments' then E.Altura:=15
        else if (E.Tipo='house') or (E.Tipo='detached') or (E.Tipo='terrace') or (E.Tipo='semidetached_house') then E.Altura:=ALTURA_TERREA
        else E.Altura:=-1; // definida pela area do contorno em AddBuilding
      end;
      PorArea:=E.Altura<0;
      if PorArea then E.Altura:=ALTURA_TERREA else E.Altura:=EnsureRange(E.Altura,1.0,1000.0);
      if not Medida(Tag('min_height'),E.Base) then begin
        if Medida(Tag('building:min_level'),Value) then E.Base:=Value*3 else E.Base:=0;
      end;
      if E.Base>=E.Altura then begin Inc(Result.Ignorados);Continue;end;
      E.Parede:=CorTag(Tag('building:colour'),$C5B79D);
      if E.Tipo='apartments' then E.Telhado:=$858C91 else E.Telhado:=$A36952;
      E.Telhado:=CorTag(Tag('roof:colour'),E.Telhado);
      Outers:=nil;Inners:=nil;
      if Obj.Get('type','')='way' then begin
        if Used.IndexOf(Obj.Get('id',Int64(0)).ToString)>=0 then Continue;
        Geometry:=nil; if Obj.Find('geometry') is TJSONArray then Geometry:=TJSONArray(Obj.Find('geometry'));
        Ring:=LePontosOSM(Geometry,Origem); if FechaAnel(Ring) then AddBuilding(Ring) else Inc(Result.Ignorados);
      end else if (Obj.Get('type','')='relation') and (Obj.Find('members') is TJSONArray) then begin
        Members:=TJSONArray(Obj.Find('members'));
        for J:=0 to Members.Count-1 do if Members.Items[J] is TJSONObject then begin
          Member:=TJSONObject(Members.Items[J]);Geometry:=nil;
          if Member.Find('geometry') is TJSONArray then Geometry:=TJSONArray(Member.Find('geometry'));
          Ring:=LePontosOSM(Geometry,Origem);if Length(Ring)<2 then Continue;
          if Member.Get('role','')='inner' then AddRing(Inners,Ring) else if ((Member.Get('role','')='outer') or (Member.Get('role','')='')) then AddRing(Outers,Ring);
        end;
        UneAneis(Outers);UneAneis(Inners);
        if Length(Outers)=0 then Inc(Result.Ignorados);
        for J:=0 to High(Outers) do AddBuilding(Outers[J]);
      end;
    end;
  finally Used.Free;Root.Free;end;
end;
end.
