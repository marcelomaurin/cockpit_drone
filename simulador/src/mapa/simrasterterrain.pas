unit simrasterterrain;
{ Fallback for the standard OSM Carto palette: preserves street/park pixels.
  Building footprints come from brown components; synthetic houses only occupy
  residential fill or small land blocks enclosed by streets, with a setback. }
{$mode objfpc}{$H+}
interface
uses SysUtils,Math,simgeo,simedificios;
type TRasterPixels=array of LongWord;
function CenaDoMapaRaster(const Pixels:TRasterPixels;W,H,Z,TileX,TileY:Integer;
 const Origem:TPontoGeo;CompletarTerrenos:Boolean):TCenaEdificios;
implementation
type TEdge=record X,Y,EX,EY,Next,Dir:Integer;Used:Boolean;end;
 TEdges=array of TEdge;TInts=array of Integer;TByteMask=array of Byte;
function Near(C,Target:LongWord;Tol:Integer):Boolean;
begin Result:=(Abs(Integer((C shr 16) and 255)-Integer((Target shr 16) and 255))<=Tol) and
 (Abs(Integer((C shr 8) and 255)-Integer((Target shr 8) and 255))<=Tol) and (Abs(Integer(C and 255)-Integer(Target and 255))<=Tol);end;
function CenaDoMapaRaster(const Pixels:TRasterPixels;W,H,Z,TileX,TileY:Integer;
 const Origem:TPontoGeo;CompletarTerrenos:Boolean):TCenaEdificios;
var Kind,Seen,Eligible:TByteMask;Queue,Heads:TInts;Edges:TEdges;Rings:TAneisEdificio;
 I,J,K,P,X,Y,N,Q,Area,StartEdge,Current,NextEdge,Best,Score,Steps,Count,MainRing,ResidentialPixels:Integer;
 X0,Y0,X1,Y1,Step,HalfW,HalfH,Margin,GX,GY,Hash,MaxN:Integer;Touched,Residential,Good,Closed:Boolean;
 OriginX,OriginY,Mpp,A,MaxArea:Double;Ring:TAnelEdificio;E:TEdificio;
 function Point(AX,AY:Double):TPontoEdificio;
 begin Result.X:=(TileX*256+AX-OriginX)*Mpp;Result.Y:=(OriginY-TileY*256-AY)*Mpp;end;
 function Index(AX,AY:Integer):Integer;begin Result:=AY*W+AX;end;
 procedure Push(AX,AY:Integer;Mask:Byte);
 var Id:Integer;
 begin if (AX<0) or (AY<0) or (AX>=W) or (AY>=H) then Exit;Id:=Index(AX,AY);
  if (Seen[Id]=0) and (Kind[Id]=Mask) then begin Seen[Id]:=1;Queue[N]:=Id;Inc(N);end;
 end;
 procedure Flood(Seed:Integer;Mask:Byte);
 var V:Integer;
 begin
  N:=0;Q:=0;Touched:=False;Residential:=False;ResidentialPixels:=0;Push(Seed mod W,Seed div W,Mask);
  while Q<N do begin V:=Queue[Q];Inc(Q);X:=V mod W;Y:=V div W;
   if (X=0) or (Y=0) or (X=W-1) or (Y=H-1) then Touched:=True;
   if Near(Pixels[V],$E0DFDF,1) then Inc(ResidentialPixels);
   Push(X-1,Y,Mask);Push(X+1,Y,Mask);Push(X,Y-1,Mask);Push(X,Y+1,Mask);
  end;Residential:=ResidentialPixels>N div 2;
 end;
 procedure AddEdge(AX,AY,BX,BY,D:Integer);
 var C,Key:Integer;
 begin C:=Length(Edges);SetLength(Edges,C+1);Key:=AY*(W+1)+AX;
  Edges[C].X:=AX;Edges[C].Y:=AY;Edges[C].EX:=BX;Edges[C].EY:=BY;Edges[C].Dir:=D;
  Edges[C].Next:=Heads[Key];Heads[Key]:=C;
 end;
 function IsBrown(AX,AY:Integer):Boolean;
 begin Result:=(AX>=0) and (AY>=0) and (AX<W) and (AY<H) and (Kind[Index(AX,AY)]=1);end;
 procedure FinishBuilding;
 var C:Integer;
 begin
  if (Length(E.Contorno)<3) or (Length(Result.Itens)>=3000) then Exit;
  E.MinX:=E.Contorno[0].X;E.MaxX:=E.MinX;E.MinY:=E.Contorno[0].Y;E.MaxY:=E.MinY;
  for C:=1 to High(E.Contorno) do begin E.MinX:=Min(E.MinX,E.Contorno[C].X);E.MaxX:=Max(E.MaxX,E.Contorno[C].X);
   E.MinY:=Min(E.MinY,E.Contorno[C].Y);E.MaxY:=Max(E.MaxY,E.Contorno[C].Y);end;
  SetLength(Result.Itens,Length(Result.Itens)+1);Result.Itens[High(Result.Itens)]:=E;
 end;
begin
 Result:=Default(TCenaEdificios);Result.Origem:=Origem;
 if (W<4) or (H<4) or (W>1024) or (H>1024) or (Length(Pixels)<>W*H) then Exit;
 GeoParaPixel(Origem.Lat,Origem.Lon,Z,OriginX,OriginY);Mpp:=MetrosPorPixel(Origem.Lat,Z);
 SetLength(Kind,W*H);SetLength(Seen,W*H);SetLength(Eligible,W*H);SetLength(Queue,W*H);
 SetLength(Heads,(W+1)*(H+1));for I:=0 to High(Heads) do Heads[I]:=-1;
 for I:=0 to High(Pixels) do begin
  if Near(Pixels[I],$D9D0C9,3) or Near(Pixels[I],$B5A89C,2) then Kind[I]:=1
  else if Near(Pixels[I],$E0DFDF,1) or Near(Pixels[I],$F2EFE9,1) then Kind[I]:=2;
 end;
 for I:=0 to High(Pixels) do if (Kind[I]=1) and (Seen[I]=0) then begin
  Flood(I,1);Area:=N;if (Area<8) or (Area>20000) or Touched then Continue;
  Edges:=nil;Rings:=nil;
  for J:=0 to N-1 do begin P:=Queue[J];X:=P mod W;Y:=P div W;
   if not IsBrown(X,Y-1) then AddEdge(X,Y,X+1,Y,0);
   if not IsBrown(X+1,Y) then AddEdge(X+1,Y,X+1,Y+1,1);
   if not IsBrown(X,Y+1) then AddEdge(X+1,Y+1,X,Y+1,2);
   if not IsBrown(X-1,Y) then AddEdge(X,Y+1,X,Y,3);
  end;
  for StartEdge:=0 to High(Edges) do if not Edges[StartEdge].Used then begin
   Current:=StartEdge;Ring:=nil;Steps:=0;Closed:=False;
   repeat
    Inc(Steps);Edges[Current].Used:=True;
    NextEdge:=-1;Best:=100;K:=Heads[Edges[Current].EY*(W+1)+Edges[Current].EX];
    while K>=0 do begin
     if not Edges[K].Used then begin Score:=(Edges[K].Dir-Edges[Current].Dir+4) mod 4;
      case Score of 1:Score:=0;0:Score:=1;3:Score:=2;else Score:=3;end;
      if Score<Best then begin Best:=Score;NextEdge:=K;end;
     end;K:=Edges[K].Next;
    end;
    if (NextEdge<0) or (Edges[NextEdge].Dir<>Edges[Current].Dir) or (Steps=1) then begin
     Count:=Length(Ring);SetLength(Ring,Count+1);Ring[Count]:=Point(Edges[Current].EX,Edges[Current].EY);
    end;
    if (Edges[Current].EX=Edges[StartEdge].X) and (Edges[Current].EY=Edges[StartEdge].Y) then begin Closed:=True;Break;end;
    Current:=NextEdge;
   until (Current<0) or (Steps>8192);
   if Closed and (Length(Ring)>=3) and (Length(Ring)<=2048) then begin
    SetLength(Rings,Length(Rings)+1);Rings[High(Rings)]:=Ring;
   end;
  end;
  for J:=0 to High(Edges) do Heads[Edges[J].Y*(W+1)+Edges[J].X]:=-1;
  if Length(Rings)=0 then Continue;MainRing:=0;MaxArea:=0;
  for J:=0 to High(Rings) do begin A:=0;
   for K:=0 to High(Rings[J]) do A:=A+Rings[J][K].X*Rings[J][(K+1) mod Length(Rings[J])].Y-Rings[J][(K+1) mod Length(Rings[J])].X*Rings[J][K].Y;
   if Abs(A)>MaxArea then begin MaxArea:=Abs(A);MainRing:=J;end;
  end;
  E:=Default(TEdificio);E.Contorno:=Rings[MainRing];E.Tipo:='house';E.Altura:=6;
  if Area*Mpp*Mpp>200 then begin E.Tipo:='apartments';E.Altura:=15;end;
  for J:=0 to High(Rings) do if (J<>MainRing) and (Length(Rings[J])>=3) then begin
   SetLength(E.Patios,Length(E.Patios)+1);E.Patios[High(E.Patios)]:=Rings[J];end;
  E.Id:='raster/'+IntToStr(Z)+'/'+IntToStr(TileX*256+I mod W)+'/'+IntToStr(TileY*256+I div W);
  E.Estimada:=True;E.Parede:=$C5B79D;E.Telhado:=$A36952;FinishBuilding;
 end;
 if not CompletarTerrenos then Exit;
 for I:=0 to High(Pixels) do if (Kind[I]=2) and (Seen[I]=0) then begin
  Flood(I,2);
  if ((not Touched) or Residential) and (N*Mpp*Mpp>=300) and (N*Mpp*Mpp<=80000) then
   for J:=0 to N-1 do Eligible[Queue[J]]:=1;
 end;
 Step:=Max(12,Round(24/Mpp));HalfW:=Max(2,Round(4/Mpp));HalfH:=Max(2,Round(5/Mpp));Margin:=Max(2,Ceil(3/Mpp));
 Y0:=Step-((TileY*256) mod Step);
 for Y:=Y0 to H-1 do if ((Y-Y0) mod Step)=0 then begin
  X0:=Step-((TileX*256) mod Step);
  for X:=X0 to W-1 do if ((X-X0) mod Step)=0 then begin
   if (X-HalfW-Margin<0) or (Y-HalfH-Margin<0) or (X+HalfW+Margin>=W) or (Y+HalfH+Margin>=H) then Continue;
   Good:=True;
   for J:=Y-HalfH-Margin to Y+HalfH+Margin do begin
    for K:=X-HalfW-Margin to X+HalfW+Margin do if Eligible[Index(K,J)]=0 then begin Good:=False;Break;end;
    if not Good then Break;
   end;
   if not Good then Continue;
   GX:=TileX*256+X;GY:=TileY*256+Y;Hash:=((GX mod 113)*31+(GY mod 97)*17) mod 13;
   E:=Default(TEdificio);SetLength(E.Contorno,4);
   E.Contorno[0]:=Point(X-HalfW,Y-HalfH);E.Contorno[1]:=Point(X+HalfW,Y-HalfH);
   E.Contorno[2]:=Point(X+HalfW,Y+HalfH);E.Contorno[3]:=Point(X-HalfW,Y+HalfH);
   E.Tipo:='house';E.Altura:=5+Hash mod 3;if Hash mod 5=0 then begin E.Tipo:='apartments';E.Altura:=15+(Hash mod 4)*3;end;
   E.Procedural:=True;E.Estimada:=True;E.Id:='raster-terreno/'+IntToStr(GX)+'/'+IntToStr(GY);
   E.Parede:=$C5B79D;E.Telhado:=$A36952;if E.Tipo='apartments' then E.Telhado:=$858C91;
   FinishBuilding;
  end;
 end;
end;
end.
