unit simurbanismo;
{ Procedural scenery belongs to residential land. Roads, setbacks, green/water
  areas and mapped buildings have priority over generated houses. }
{$mode objfpc}{$H+}
interface
uses Classes,SysUtils,Math,fpjson,jsonparser,simgeo,simedificios,simquintais;
type
  TViaTerreno=TViaEdificio;
  TViasTerreno=TViasEdificio;
  TZonaTerreno=record Forma:TEdificio;Permitida:Boolean;Apartamentos:Boolean;end;
  TZonasTerreno=array of TZonaTerreno;
function DistanciaSegmento(const P,A,B:TPontoEdificio):Double;
function RuaLivre(const E:TEdificio;const Vias:TViasTerreno):Boolean;
procedure GeraConstrucoesNosTerrenos(const Texto:string;const Origem:TPontoGeo;var Cena:TCenaEdificios);
implementation
function DistanciaSegmento(const P,A,B:TPontoEdificio):Double;
var DX,DY,T,L:Double;
begin
 DX:=B.X-A.X;DY:=B.Y-A.Y;L:=Sqr(DX)+Sqr(DY);
 if L<1e-12 then Exit(Hypot(P.X-A.X,P.Y-A.Y));
 T:=EnsureRange(((P.X-A.X)*DX+(P.Y-A.Y)*DY)/L,0.0,1.0);
 Result:=Hypot(P.X-A.X-T*DX,P.Y-A.Y-T*DY);
end;
function PontoMaisProximo(const P,A,B:TPontoEdificio):TPontoEdificio;
var DX,DY,T,L:Double;
begin
 DX:=B.X-A.X;DY:=B.Y-A.Y;L:=Sqr(DX)+Sqr(DY);
 if L<1e-12 then Exit(A);
 T:=EnsureRange(((P.X-A.X)*DX+(P.Y-A.Y)*DY)/L,0.0,1.0);
 Result.X:=A.X+T*DX;Result.Y:=A.Y+T*DY;
end;
function Cruzam(const A,B,C,D:TPontoEdificio):Boolean;
var X1,X2,Y1,Y2:Double;
begin
 X1:=(B.X-A.X)*(C.Y-A.Y)-(B.Y-A.Y)*(C.X-A.X);
 X2:=(B.X-A.X)*(D.Y-A.Y)-(B.Y-A.Y)*(D.X-A.X);
 Y1:=(D.X-C.X)*(A.Y-C.Y)-(D.Y-C.Y)*(A.X-C.X);
 Y2:=(D.X-C.X)*(B.Y-C.Y)-(D.Y-C.Y)*(B.X-C.X);
 Result:=((X1>0)<>(X2>0)) and ((Y1>0)<>(Y2>0));
end;
function DistanciaArestas(const A,B,C,D:TPontoEdificio):Double;
begin
 if Cruzam(A,B,C,D) then Exit(0);
 Result:=Min(Min(DistanciaSegmento(A,C,D),DistanciaSegmento(B,C,D)),
   Min(DistanciaSegmento(C,A,B),DistanciaSegmento(D,A,B)));
end;
function RuaLivre(const E:TEdificio;const Vias:TViasTerreno):Boolean;
var I,J,K,N:Integer;A,B:TPontoEdificio;R:Double;
begin
 Result:=False;
 for I:=0 to High(Vias) do for J:=1 to High(Vias[I].Pontos) do begin
   A:=Vias[I].Pontos[J-1];B:=Vias[I].Pontos[J];R:=Vias[I].RaioLivre;
   if (Max(A.X,B.X)+R<E.MinX) or (Min(A.X,B.X)-R>E.MaxX) or
      (Max(A.Y,B.Y)+R<E.MinY) or (Min(A.Y,B.Y)-R>E.MaxY) then Continue;
   if DentroEdificio(A.X,A.Y,E) or DentroEdificio(B.X,B.Y,E) then Exit;
   for K:=0 to High(E.Contorno) do begin N:=(K+1) mod Length(E.Contorno);
     if DistanciaArestas(A,B,E.Contorno[K],E.Contorno[N])<=R then Exit;
   end;
 end;
 Result:=True;
end;
procedure GeraConstrucoesNosTerrenos(const Texto:string;const Origem:TPontoGeo;var Cena:TCenaEdificios);
const PassoLat=0.00005;PassoLon=0.00005; // ~5 m: lotes encostados ao longo da rua
var Root:TJSONData;Elements,Members,Geometry:TJSONArray;Obj,Tags,Member:TJSONObject;
 I,J,K,Q,ILat,ILon,Lat0,Lat1,Lon0,Lon1,Hash,RealCount,Attempts:Integer;
 Zones:TZonasTerreno;Roads:TViasTerreno;Zone:TZonaTerreno;Road:TViaTerreno;
 Outer,Inner:TAneisEdificio;Ring:TAnelEdificio;E:TEdificio;
 Kind,TypeName,Id:string;Width,Best,FX,FY,CX,CY,LX,LY,Lat,Lon:Double;Lot:TEdificio;Lote:TLote;Near:TPontoEdificio;
 FS:TFormatSettings;Allowed,Excluded,Free:Boolean;Center:TPontoEdificio;
 function Tag(const Key:string):string;
 begin if Assigned(Tags) then Result:=Tags.Get(Key,'') else Result:='';end;
 procedure Bounds(var Shape:TEdificio);
 var N:Integer;
 begin
  Shape.MinX:=Shape.Contorno[0].X;Shape.MaxX:=Shape.MinX;
  Shape.MinY:=Shape.Contorno[0].Y;Shape.MaxY:=Shape.MinY;
  for N:=1 to High(Shape.Contorno) do begin
   Shape.MinX:=Min(Shape.MinX,Shape.Contorno[N].X);Shape.MaxX:=Max(Shape.MaxX,Shape.Contorno[N].X);
   Shape.MinY:=Min(Shape.MinY,Shape.Contorno[N].Y);Shape.MaxY:=Max(Shape.MaxY,Shape.Contorno[N].Y);
  end;
 end;
 function Overlap(const A,B:TEdificio):Boolean;
 begin Result:=not ((A.MaxX+2<B.MinX) or (A.MinX-2>B.MaxX) or
   (A.MaxY+2<B.MinY) or (A.MinY-2>B.MaxY));end;
 function Inside(const Building,Area:TEdificio):Boolean;
 var A,B,C,D:Integer;
 begin
  Result:=False;
  for A:=0 to High(Building.Contorno) do
   if not DentroEdificio(Building.Contorno[A].X,Building.Contorno[A].Y,Area) then Exit;
  for A:=0 to High(Building.Contorno) do begin B:=(A+1) mod Length(Building.Contorno);
   for C:=0 to High(Area.Contorno) do begin D:=(C+1) mod Length(Area.Contorno);
    if Cruzam(Building.Contorno[A],Building.Contorno[B],Area.Contorno[C],Area.Contorno[D]) then Exit;
   end;
   for C:=0 to High(Area.Patios) do for D:=0 to High(Area.Patios[C]) do
    if DentroEdificio(Area.Patios[C][D].X,Area.Patios[C][D].Y,Building) or
      Cruzam(Building.Contorno[A],Building.Contorno[B],Area.Patios[C][D],
        Area.Patios[C][(D+1) mod Length(Area.Patios[C])]) then Exit;
  end;
  Result:=True;
 end;
 procedure AddZone(const R:TAnelEdificio);
 var N:Integer;
 begin
  Zone:=Default(TZonaTerreno);Zone.Permitida:=Allowed;
  Zone.Apartamentos:=(Tag('residential')='apartments');Zone.Forma.Contorno:=R;
  for N:=0 to High(Inner) do if PontoNoAnel(Inner[N][0].X,Inner[N][0].Y,R) then begin
   SetLength(Zone.Forma.Patios,Length(Zone.Forma.Patios)+1);Zone.Forma.Patios[High(Zone.Forma.Patios)]:=Inner[N];
  end;
  Bounds(Zone.Forma);SetLength(Zones,Length(Zones)+1);Zones[High(Zones)]:=Zone;
 end;
begin
 // Without road vectors it is impossible to guarantee an unobstructed street.
 if Length(Texto)>8*1024*1024 then Exit;
 Roads:=nil;Zones:=nil;Root:=GetJSON(Texto);FS:=DefaultFormatSettings;FS.DecimalSeparator:='.';
 try
  if not (Root is TJSONObject) then Exit;
  if not (TJSONObject(Root).Find('elements') is TJSONArray) then Exit;
  Elements:=TJSONArray(TJSONObject(Root).Find('elements'));if Elements.Count>15000 then Exit;
  for I:=0 to Elements.Count-1 do if Elements.Items[I] is TJSONObject then begin
   Obj:=TJSONObject(Elements.Items[I]);Tags:=nil;
   if Obj.Find('tags') is TJSONObject then Tags:=TJSONObject(Obj.Find('tags'));
   TypeName:=Obj.Get('type','');Kind:=Tag('highway');
   if (Kind<>'') and (TypeName='way') then begin
    Geometry:=nil;if Obj.Find('geometry') is TJSONArray then Geometry:=TJSONArray(Obj.Find('geometry'));
    Road.Pontos:=LePontosOSM(Geometry,Origem);if Length(Road.Pontos)<2 then Continue;
    if not TryStrToFloat(Tag('width'),Width,FS) or IsNan(Width) or IsInfinite(Width) or (Width<=0) or (Width>100) then begin
      if TryStrToFloat(Tag('lanes'),Width,FS) and (Width>=1) and (Width<=20) then Width:=Width*3.5
      else if (Kind='motorway') or (Kind='trunk') then Width:=18
      else if (Kind='primary') or (Kind='secondary') then Width:=12
      else if (Kind='footway') or (Kind='path') or (Kind='cycleway') or (Kind='steps') then Width:=3
      else Width:=8;
    end;
    Road.RaioLivre:=Width/2+3;SetLength(Roads,Length(Roads)+1);Roads[High(Roads)]:=Road;
   end;
   Allowed:=Tag('landuse')='residential';
   Excluded:=((Tag('landuse')<>'') and not Allowed) or (Tag('leisure')<>'') or
     (Tag('natural')<>'') or (Tag('water')<>'') or (Tag('amenity')='parking') or (Tag('area:highway')<>'');
   if not Allowed and not Excluded then Continue;
   Outer:=nil;Inner:=nil;
   if TypeName='way' then begin
    Geometry:=nil;if Obj.Find('geometry') is TJSONArray then Geometry:=TJSONArray(Obj.Find('geometry'));
    Ring:=LePontosOSM(Geometry,Origem);if FechaAnel(Ring) then AddZone(Ring);
   end else if (TypeName='relation') and (Obj.Find('members') is TJSONArray) then begin
    Members:=TJSONArray(Obj.Find('members'));
    for J:=0 to Members.Count-1 do if Members.Items[J] is TJSONObject then begin
     Member:=TJSONObject(Members.Items[J]);Geometry:=nil;
     if Member.Find('geometry') is TJSONArray then Geometry:=TJSONArray(Member.Find('geometry'));
     Ring:=LePontosOSM(Geometry,Origem);if Length(Ring)<2 then Continue;
     if Member.Get('role','')='inner' then begin SetLength(Inner,Length(Inner)+1);Inner[High(Inner)]:=Ring;end
     else if (Member.Get('role','')='outer') or (Member.Get('role','')='') then begin SetLength(Outer,Length(Outer)+1);Outer[High(Outer)]:=Ring;end;
    end;
    UneAneis(Outer);UneAneis(Inner);for J:=0 to High(Outer) do AddZone(Outer[J]);
   end;
  end;
  Cena.Vias:=Roads;
  if Length(Roads)=0 then Exit;
  RealCount:=Length(Cena.Itens);Attempts:=0;
  for I:=0 to High(Zones) do if Zones[I].Permitida then begin
   LocalParaGeo(Origem,Max(-800,Zones[I].Forma.MinX),Max(-800,Zones[I].Forma.MinY),Lat,Lon);
   Lat0:=Floor(Lat/PassoLat);Lon0:=Floor(Lon/PassoLon);
   LocalParaGeo(Origem,Min(800,Zones[I].Forma.MaxX),Min(800,Zones[I].Forma.MaxY),Lat,Lon);
   Lat1:=Ceil(Lat/PassoLat);Lon1:=Ceil(Lon/PassoLon);
   for ILat:=Lat0 to Lat1 do for ILon:=Lon0 to Lon1 do begin
    Inc(Attempts);if (Attempts>250000) or (Length(Cena.Itens)>=Min(4000,RealCount+1800)) then Exit;
    GeoParaLocal(Origem,(ILat+0.5)*PassoLat,(ILon+0.5)*PassoLon,CX,CY);
    if Hypot(CX,CY)>780 then Continue;
    if not DentroEdificio(CX,CY,Zones[I].Forma) then Continue;
    Center.X:=CX;Center.Y:=CY;Best:=1e30;FX:=0;FY:=1;
    for J:=0 to High(Roads) do for K:=1 to High(Roads[J].Pontos) do begin
     Width:=DistanciaSegmento(Center,Roads[J].Pontos[K-1],Roads[J].Pontos[K]);
     if Width<Best then begin Best:=Width;
       Near:=PontoMaisProximo(Center,Roads[J].Pontos[K-1],Roads[J].Pontos[K]);
       if Width>0.01 then begin FX:=(Near.X-CX)/Width;FY:=(Near.Y-CY)/Width;end;
     end;
    end;
    if Best>90 then Continue; // model blocks along known streets, not arbitrary wilderness
    Hash:=((Abs(ILat) mod 97)*53+(Abs(ILon) mod 193)*31) mod 13;
    Id:='sim/'+IntToStr(ILat)+'/'+IntToStr(ILon);
    // O lote inteiro (muro, quintal e casa) precisa caber no terreno e fora da rua/calcada.
    Lot:=FormaLote(CX,CY,FX,FY);
    if not Inside(Lot,Zones[I].Forma) or not RuaLivre(Lot,Roads) then Continue;
    Free:=True;
    for J:=0 to High(Zones) do if not Zones[J].Permitida and Overlap(Lot,Zones[J].Forma) then begin Free:=False;Break;end;
    if not Free then Continue;
    for J:=0 to High(Cena.Itens) do if Overlap(Lot,Cena.Itens[J]) then begin Free:=False;Break;end;
    if not Free then Continue;
    for J:=0 to High(Cena.Lotes) do if not ((Lot.MaxX+1<Cena.Lotes[J].MinX) or (Lot.MinX-1>Cena.Lotes[J].MaxX) or
      (Lot.MaxY+1<Cena.Lotes[J].MinY) or (Lot.MinY-1>Cena.Lotes[J].MaxY)) then begin Free:=False;Break;end;
    if not Free then Continue;
    Lote:=Default(TLote);
    if Zones[I].Apartamentos or (Hash=0) then begin
     // Predio residencial raro (4 a 6 andares), sem quintal.
     E:=Default(TEdificio);E.Procedural:=True;E.Estimada:=True;E.Id:=Id;E.Tipo:='apartments';
     SetLength(E.Contorno,4);
     for Q:=0 to 3 do begin
      if (Q=0) or (Q=3) then LX:=-6 else LX:=6;
      if Q<2 then LY:=-7 else LY:=7;
      E.Contorno[Q].X:=CX+LX*FY+LY*FX;E.Contorno[Q].Y:=CY-LX*FX+LY*FY;
     end;
     Bounds(E);E.Altura:=12+Abs(ILat+ILon) mod 3*3;E.Parede:=$D4C6AC;E.Telhado:=$858C91;
    end else begin
     MontaLote(Id,CX,CY,FX,FY,Origem,E,Lote);
     if Length(Lote.Id)>0 then begin SetLength(Cena.Lotes,Length(Cena.Lotes)+1);Cena.Lotes[High(Cena.Lotes)]:=Lote;end;
    end;
    SetLength(Cena.Itens,Length(Cena.Itens)+1);Cena.Itens[High(Cena.Itens)]:=E;
   end;
  end;
 finally Root.Free;end;
end;
end.
