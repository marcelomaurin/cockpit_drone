program test_real_map_raster;
{$mode objfpc}{$H+}
uses SysUtils,Math,FPImage,FPReadPNG,FPWritePNG,simgeo,simedificios,simrasterterrain,simcidade3d;
procedure Check(B:Boolean;const M:string);begin if not B then raise Exception.Create(M);end;
var O:TPontoGeo;Scene:TCenaEdificios;Map:TRasterPixels;Pixels:TPixelsCidade;Depth:TProfundidadeCidade;
 Img,Tile:TFPMemoryImage;Reader:TFPReaderPNG;Writer:TFPWriterPNG;Color:TFPColor;
 Cam:TCamera3D;DX,DY,X,Y,I,PX,PY,Houses:Integer;Mpp,OX,OY,Theta,RX,RY,RZ,T,WX,WY:Double;Err:string;
 function Vec(A,B,C:Double):TVetor3D;begin Result.X:=A;Result.Y:=B;Result.Z:=C;end;
begin
 O.Lat:=-21.1767;O.Lon:=-47.8208;SetLength(Map,768*768);Reader:=TFPReaderPNG.Create;Tile:=TFPMemoryImage.Create(0,0);
 try
 for DY:=0 to 2 do for DX:=0 to 2 do begin
  Tile.LoadFromFile(IncludeTrailingPathDelimiter(ParamStr(1))+IntToStr(48123+DX)+'-'+IntToStr(73426+DY)+'.png',Reader);
  for Y:=0 to 255 do for X:=0 to 255 do begin Color:=Tile.Colors[X,Y];
   Map[(DY*256+Y)*768+DX*256+X]:=(LongWord(Color.Red shr 8) shl 16) or (LongWord(Color.Green shr 8) shl 8) or (Color.Blue shr 8);
  end;
 end;
 finally Reader.Free;Tile.Free;end;
 Scene:=CenaDoMapaRaster(Map,768,768,17,48123,73426,O,True);Houses:=0;
 for I:=0 to High(Scene.Itens) do if Scene.Itens[I].Procedural then Inc(Houses);
 Check(Houses>20,'real cached map must generate houses on enclosed land');
 Check(not ValidaArquivoOSM(ParamStr(2),Err),'project JSON must be rejected as OSM');
 WriteLn('PASS real cached OSM tiles: ',Length(Scene.Itens),' buildings, ',Houses,' generated in land blocks; invalid project import rejected');
 SetLength(Pixels,640*360);SetLength(Depth,640*360);Cam.Pos:=Vec(0,0,40);Theta:=DegToRad(30);
 Cam.Frente:=Vec(0,Cos(Theta),-Sin(Theta));Cam.Direita:=Vec(1,0,0);Cam.Cima:=Vec(0,Sin(Theta),Cos(Theta));Cam.Focal:=440;
 GeoParaPixel(O.Lat,O.Lon,17,OX,OY);Mpp:=MetrosPorPixel(O.Lat,17);
 for Y:=0 to 359 do for X:=0 to 639 do begin
  I:=Y*640+X;Pixels[I]:=$FF87B5DE;Depth[I]:=1e30;
  RX:=(X-320)/Cam.Focal;RY:=Cam.Frente.Y-Cam.Cima.Y*(Y-180)/Cam.Focal;
  RZ:=Cam.Frente.Z-Cam.Cima.Z*(Y-180)/Cam.Focal;
  if RZ< -0.00001 then begin T:=-Cam.Pos.Z/RZ;Depth[I]:=T;
   PX:=Floor(OX+RX*T/Mpp)-48123*256;PY:=Floor(OY-RY*T/Mpp)-73426*256;
   Pixels[I]:=$FF71885C;if (PX>=0) and (PY>=0) and (PX<768) and (PY<768) then Pixels[I]:=Map[PY*768+PX] or $FF000000;
  end;
 end;
 DesenhaEdificios(Scene,0,0,Cam,640,360,Pixels,Depth);
 Img:=TFPMemoryImage.Create(640,360);Writer:=TFPWriterPNG.Create;
 try for Y:=0 to 359 do for X:=0 to 639 do begin
  Color.Red:=((Pixels[Y*640+X] shr 16) and 255)*257;Color.Green:=((Pixels[Y*640+X] shr 8) and 255)*257;
  Color.Blue:=(Pixels[Y*640+X] and 255)*257;Color.Alpha:=65535;Img.Colors[X,Y]:=Color;
 end;Img.SaveToFile(ParamStr(3),Writer);finally Writer.Free;Img.Free;end;
end.
