program test_criadouros;
{ Quintais de treinamento do Aedes: proporcoes das casas, lotes, objetos,
  determinismo, opcao desligada e gabarito. Gera vistas de camera de drone.
  Uso: test_criadouros <pasta osm_tiles17> <pasta de saida> }
{$mode objfpc}{$H+}
uses SysUtils,Classes,Math,FPImage,FPReadPNG,FPWritePNG,simgeo,simedificios,simrasterterrain,
  simcidade3d,simquintais;
procedure Check(B:Boolean;const M:string);begin if not B then raise Exception.Create(M);end;
var O:TPontoGeo;Scene,Again,Off:TCenaEdificios;Map:TRasterPixels;Img,Tile:TFPMemoryImage;
  Reader:TFPReaderPNG;Color:TFPColor;DX,DY,X,Y,I,J,K,Lotes,Risco,Itens:Integer;
  OX,OY,Mpp:Double;L:TLote;Ob:TObjetoQuintal;Casa:TEdificio;Tipos:array[TTipoObjetoQuintal] of Integer;
  TiposRisco:array[TTipoObjetoQuintal] of Integer;T:TTipoObjetoQuintal;Saida:string;SL:TStringList;
function Vec(A,B,C:Double):TVetor3D;begin Result.X:=A;Result.Y:=B;Result.Z:=C;end;
function DentroLote(PX,PY:Double;const Lt:TLote):Boolean;
var R:TAnelEdificio;Q:Integer;
begin SetLength(R,4);for Q:=0 to 3 do R[Q]:=Lt.Canto[Q];Result:=PontoNoAnel(PX,PY,R);end;
function CasaDoLote(const Lt:TLote):TEdificio;
var Q:Integer;
begin
  Result:=Default(TEdificio);
  for Q:=0 to High(Scene.Itens) do if Scene.Itens[Q].Id=Lt.Id then Exit(Scene.Itens[Q]);
end;
procedure Render(const Lt:TLote;const Arquivo:string;Altura,Distancia,Inclinacao:Double);
const W=960;H=540;
var Pixels:TPixelsCidade;Depth:TProfundidadeCidade;Cam:TCamera3D;CX,CY,FX,FY,Th,RX,RY,RZ,TT,Fx2,Fy2:Double;
  PX,PY,P,Q:Integer;N:LongWord;Png:TFPMemoryImage;Wr:TFPWriterPNG;C:TFPColor;
begin
  SetLength(Pixels,W*H);SetLength(Depth,W*H);
  CX:=(Lt.Canto[0].X+Lt.Canto[2].X)/2;CY:=(Lt.Canto[0].Y+Lt.Canto[2].Y)/2;
  // olha do fundo do quintal para a casa, por cima do muro dos fundos
  FX:=(Lt.Canto[3].X-Lt.Canto[0].X)/20;FY:=(Lt.Canto[3].Y-Lt.Canto[0].Y)/20;
  Th:=DegToRad(Inclinacao);
  Cam.Pos:=Vec(CX-FX*Distancia,CY-FY*Distancia,Altura);
  Cam.Frente:=Vec(FX*Cos(Th),FY*Cos(Th),-Sin(Th));Cam.Direita:=Vec(FY,-FX,0);
  Cam.Cima:=Vec(FX*Sin(Th),FY*Sin(Th),Cos(Th));Cam.Focal:=(W/2)/Tan(DegToRad(82)/2);
  for PY:=0 to H-1 do for PX:=0 to W-1 do begin
    P:=PY*W+PX;Pixels[P]:=$FF87B5DE;Depth[P]:=1e30;
    Fx2:=(PX-W/2)/Cam.Focal;Fy2:=-(PY-H/2)/Cam.Focal;
    RX:=Cam.Frente.X+Cam.Direita.X*Fx2+Cam.Cima.X*Fy2;RY:=Cam.Frente.Y+Cam.Direita.Y*Fx2+Cam.Cima.Y*Fy2;
    RZ:=Cam.Frente.Z+Cam.Cima.Z*Fy2;
    if RZ< -0.00001 then begin TT:=-Cam.Pos.Z/RZ;Depth[P]:=TT;
      Q:=Floor(OX+(Cam.Pos.X+RX*TT)/Mpp)-48123*256;K:=Floor(OY-(Cam.Pos.Y+RY*TT)/Mpp)-73426*256;
      Pixels[P]:=$FF71885C;if (Q>=0) and (K>=0) and (Q<768) and (K<768) then Pixels[P]:=Map[K*768+Q] or $FF000000;
    end;
  end;
  DesenhaEdificios(Scene,0,0,Cam,W,H,Pixels,Depth);
  Png:=TFPMemoryImage.Create(W,H);Wr:=TFPWriterPNG.Create;
  try for PY:=0 to H-1 do for PX:=0 to W-1 do begin
    N:=Pixels[PY*W+PX];C.Red:=((N shr 16) and 255)*257;C.Green:=((N shr 8) and 255)*257;
    C.Blue:=(N and 255)*257;C.Alpha:=65535;Png.Colors[PX,PY]:=C;
  end;Png.SaveToFile(Arquivo,Wr);finally Wr.Free;Png.Free;end;
end;
function Acha(Tp:TTipoObjetoQuintal;Risco:Boolean):Integer;
var Q,R:Integer;Ob:TObjetoQuintal;Lt:TLote;
begin
  Result:=-1;
  for Q:=0 to High(Scene.Lotes) do for R:=0 to High(Scene.Lotes[Q].Objetos) do begin
    Ob:=Scene.Lotes[Q].Objetos[R];Lt:=Scene.Lotes[Q];
    // prefere objetos no quintal dos fundos (visiveis por tras da casa)
    if (Ob.Tipo=Tp) and (Ob.Criadouro=Risco) and
      (Hypot(Ob.X-(Lt.Canto[0].X+Lt.Canto[1].X)/2,Ob.Y-(Lt.Canto[0].Y+Lt.Canto[1].Y)/2)<
       Hypot(Ob.X-(Lt.Canto[2].X+Lt.Canto[3].X)/2,Ob.Y-(Lt.Canto[2].Y+Lt.Canto[3].Y)/2)) then Exit(Q);
  end;
end;
begin
  O.Lat:=-21.1767;O.Lon:=-47.8208;SetLength(Map,768*768);Saida:=IncludeTrailingPathDelimiter(ParamStr(2));
  Reader:=TFPReaderPNG.Create;Tile:=TFPMemoryImage.Create(0,0);
  try
    for DY:=0 to 2 do for DX:=0 to 2 do begin
      Tile.LoadFromFile(IncludeTrailingPathDelimiter(ParamStr(1))+IntToStr(48123+DX)+'-'+IntToStr(73426+DY)+'.png',Reader);
      for Y:=0 to 255 do for X:=0 to 255 do begin Color:=Tile.Colors[X,Y];
        Map[(DY*256+Y)*768+DX*256+X]:=(LongWord(Color.Red shr 8) shl 16) or (LongWord(Color.Green shr 8) shl 8) or (Color.Blue shr 8);
      end;
    end;
  finally Reader.Free;Tile.Free;end;
  GeoParaPixel(O.Lat,O.Lon,17,OX,OY);Mpp:=MetrosPorPixel(O.Lat,17);

  GerarCriadouros:=True;
  Scene:=CenaDoMapaRaster(Map,768,768,17,48123,73426,O,True);
  ContaLotes(Scene,Lotes,Risco,Itens);
  Check(Lotes>=60,'expected a neighbourhood of lots, got '+IntToStr(Lotes));
  Check((Risco>=Lotes div 6) and (Risco<=Lotes*2 div 3),Format('share with breeding sites out of range: %d/%d',[Risco,Lotes]));
  // Proporcoes: nada passa de sobrado sem informacao de altura no mapa.
  for I:=0 to High(Scene.Itens) do begin
    Check(Scene.Itens[I].Altura<=8.01,'raster building too tall: '+Scene.Itens[I].Id);
    if Scene.Itens[I].Procedural then
      Check((Abs(Scene.Itens[I].Altura-ALTURA_TERREA)<0.01) or (Abs(Scene.Itens[I].Altura-ALTURA_SOBRADO)<0.01),'house height');
  end;
  FillChar(Tipos,SizeOf(Tipos),0);FillChar(TiposRisco,SizeOf(TiposRisco),0);
  for I:=0 to High(Scene.Lotes) do begin L:=Scene.Lotes[I];Casa:=CasaDoLote(L);
    Check(Casa.Id=L.Id,'every lot has its house');
    K:=0;
    for J:=0 to High(L.Objetos) do begin Ob:=L.Objetos[J];Inc(Tipos[Ob.Tipo]);
      if Ob.Criadouro then begin Inc(TiposRisco[Ob.Tipo]);Inc(K);end;
      Check(DentroLote(Ob.X,Ob.Y,L),'object outside its lot');
      Check(not DentroEdificio(Ob.X,Ob.Y,Casa),'object inside the house');
      Check(not ((Ob.Tipo=oqPneu) and not Ob.Criadouro),'tyres outdoors always hold water');
    end;
    Check(K=L.Criadouros,'breeding-site count');
    for J:=0 to I-1 do Check((L.MaxX<Scene.Lotes[J].MinX) or (L.MinX>Scene.Lotes[J].MaxX) or
      (L.MaxY<Scene.Lotes[J].MinY) or (L.MinY>Scene.Lotes[J].MaxY),'lots overlap');
  end;
  for T:=Low(T) to High(T) do Check(Tipos[T]>0,'missing object type '+IntToStr(Ord(T)));
  for T:=Low(T) to High(T) do Check(TiposRisco[T]>0,'missing breeding-site variant '+IntToStr(Ord(T)));
  // Determinismo: a mesma regiao sempre gera os mesmos quintais.
  Again:=CenaDoMapaRaster(Map,768,768,17,48123,73426,O,True);
  Check(Length(Again.Lotes)=Length(Scene.Lotes),'deterministic lot count');
  for I:=0 to High(Scene.Lotes) do
    Check((Again.Lotes[I].Id=Scene.Lotes[I].Id) and (Again.Lotes[I].Criadouros=Scene.Lotes[I].Criadouros) and
      (Length(Again.Lotes[I].Objetos)=Length(Scene.Lotes[I].Objetos)),'deterministic yards');
  // Opcao desligada: casas continuam, sem quintais.
  GerarCriadouros:=False;Off:=CenaDoMapaRaster(Map,768,768,17,48123,73426,O,True);GerarCriadouros:=True;
  Check((Length(Off.Lotes)=0) and (Length(Off.Itens)=Length(Scene.Itens)),'disabled option keeps houses only');
  // Gabarito
  SalvaGabarito(Scene,Saida+'gabarito_criadouros.csv');
  SL:=TStringList.Create;
  try SL.LoadFromFile(Saida+'gabarito_criadouros.csv');
    Check(SL.Count=Lotes+1,'gabarito rows');
    Check(Pos('lote;latitude;longitude;situacao',SL[0])=1,'gabarito header');
    J:=0;for I:=1 to SL.Count-1 do if Pos(';COM CRIADOURO;',SL[I])>0 then Inc(J);
    Check(J=Risco,'gabarito positives');
  finally SL.Free;end;
  // Vistas de camera para conferencia visual.
  I:=Acha(oqPiscina,True);if I>=0 then Render(Scene.Lotes[I],Saida+'quintal-piscina-verde.png',11,15,50);
  I:=Acha(oqPiscina,False);if I>=0 then Render(Scene.Lotes[I],Saida+'quintal-piscina-tratada.png',11,15,50);
  I:=Acha(oqCaixaDagua,True);if I>=0 then Render(Scene.Lotes[I],Saida+'quintal-caixa-destampada.png',11,15,50);
  I:=Acha(oqPneu,True);if I>=0 then Render(Scene.Lotes[I],Saida+'quintal-pneus.png',11,15,50);
  I:=Acha(oqTanquePeixe,True);if I>=0 then Render(Scene.Lotes[I],Saida+'quintal-tanque-abandonado.png',11,15,50);
  I:=Acha(oqTanquePeixe,False);if I>=0 then Render(Scene.Lotes[I],Saida+'quintal-tanque-peixes.png',11,15,50);
  I:=Acha(oqVaso,True);if I>=0 then Render(Scene.Lotes[I],Saida+'quintal-vasos.png',11,15,50);
  I:=Acha(oqBalde,True);if I>=0 then Render(Scene.Lotes[I],Saida+'quintal-baldes.png',11,15,50);
  I:=Acha(oqPiscina,True);if I>=0 then Render(Scene.Lotes[I],Saida+'bairro-alto.png',45,60,35);
  WriteLn(Format('PASS %d lots, %d with breeding sites (%d items); %d houses; types: vaso %d/%d, piscina %d/%d, '+
    'caixa %d/%d, pneu %d/%d, tanque %d/%d, balde %d/%d (risco/total); deterministic, option off, gabarito',
    [Lotes,Risco,Itens,Length(Scene.Itens),TiposRisco[oqVaso],Tipos[oqVaso],TiposRisco[oqPiscina],Tipos[oqPiscina],
     TiposRisco[oqCaixaDagua],Tipos[oqCaixaDagua],TiposRisco[oqPneu],Tipos[oqPneu],
     TiposRisco[oqTanquePeixe],Tipos[oqTanquePeixe],TiposRisco[oqBalde],Tipos[oqBalde]]));
end.
