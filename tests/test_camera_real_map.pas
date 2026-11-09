program test_camera_real_map;
{$mode objfpc}{$H+}
uses Interfaces,Forms,SysUtils,Classes,Graphics,FPImage,FPReadBMP,FPWritePNG,
 simtipos,simgeo,simmapa,simedificios_cache,simrastercache,simvisao;
procedure Check(B:Boolean;const M:string);begin if not B then raise Exception.Create(M);end;
var Maps:TGerenciadorBlocos;Vector:TGerenciadorEdificios;Raster:TGerenciadorRaster;View:TVisao;
 D:TDadosVista;Deadline:QWord;Dir,BmpPath:string;Img:TFPMemoryImage;Writer:TFPWriterPNG;B:TBitmap;Stream:TFileStream;
begin
 try Application.Initialize;Dir:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));ForceDirectories(Dir);
 Maps:=TGerenciadorBlocos.Create(Dir+'cache','','http://127.0.0.1:1/{z}/{x}/{y}.png',mfOSM);
 Vector:=TGerenciadorEdificios.Create(Dir+'vector',SERVIDOR_EDIFICIOS_PADRAO,ExpandFileName(ParamStr(2)),True);
 Raster:=TGerenciadorRaster.Create(Maps,True);View:=TVisao.Create(Maps,1,Vector,Raster);
 try
  D:=Default(TDadosVista);D.Origem.Lat:=-21.1767;D.Origem.Lon:=-47.8208;D.Estado.Z:=40;
  D.Param:=ModelosPadrao[3];D.Param.InclinacaoCameraGraus:=30;
  Vector.Atualiza(D.Origem.Lat,D.Origem.Lon,True);Raster.Atualiza(D.Origem.Lat,D.Origem.Lon,True);
  Deadline:=GetTickCount64+10000;
  while (Length(Raster.Cena.Itens)=0) and (GetTickCount64<Deadline) do begin Sleep(10);CheckSynchronize;end;
  Check(Length(Raster.Cena.Itens)>100,'real cached-map fallback failed: '+Raster.Status);
  BmpPath:=Dir+'camera-real-map.bmp';View.GeraQuadroCamera(D,640,360,BmpPath);
  B:=TBitmap.Create;Stream:=TFileStream.Create(BmpPath,fmOpenRead or fmShareDenyNone);
  try B.LoadFromStream(Stream);Check((B.Width=640) and (B.Height=360),'camera output import');finally Stream.Free;B.Free;end;
  Img:=TFPMemoryImage.Create(0,0);Writer:=TFPWriterPNG.Create;
  try Img.LoadFromFile(BmpPath);Img.SaveToFile(Dir+'camera-real-map.png',Writer);finally Writer.Free;Img.Free;end;
  WriteLn('PASS real camera export with ',Length(Raster.Cena.Itens),' buildings from cached map despite invalid vector source');
 finally View.Free;Raster.Free;Vector.Free;Maps.Free;end;
 except on E:Exception do begin WriteLn(StdErr,E.ClassName,': ',E.Message);Halt(1);end;end;
end.
