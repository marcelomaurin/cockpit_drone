program test_camera_export;
{$mode objfpc}{$H+}
uses Interfaces,Forms,SysUtils,Classes,Graphics,FPImage,FPReadBMP,FPWritePNG,
 simtipos,simgeo,simmapa,simedificios_cache,simvisao;
procedure Check(B:Boolean;const M:string);begin if not B then raise Exception.Create(M);end;
var Maps:TGerenciadorBlocos;Buildings:TGerenciadorEdificios;View:TVisao;D:TDadosVista;
 Deadline:QWord;Dir,Low,HighView,Empty:string;WithHouses,WithoutHouses:TFPMemoryImage;
 B:TBitmap;Stream:TFileStream;X,Y,Diff:Integer;Writer:TFPWriterPNG;Time:QWord;
procedure WaitBuildings;
begin
 Deadline:=GetTickCount64+5000;
 while (Length(Buildings.Cena.Itens)<2) and (GetTickCount64<Deadline) do Sleep(10);
 Check(Length(Buildings.Cena.Itens)>20,'terrain scene unavailable: '+Buildings.Status);
end;
procedure ToPNG(const Source,Dest:string);
var Img:TFPMemoryImage;P:TFPWriterPNG;
begin Img:=TFPMemoryImage.Create(0,0);P:=TFPWriterPNG.Create;
 try Img.LoadFromFile(Source);Img.SaveToFile(Dest,P);finally P.Free;Img.Free;end;end;
begin
 try
 Application.Initialize;
 Dir:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(2)));ForceDirectories(Dir);
 Low:=Dir+'camera-cockpit-low.bmp';HighView:=Dir+'camera-cockpit-high.bmp';Empty:=Dir+'camera-no-buildings.bmp';
 Maps:=TGerenciadorBlocos.Create(Dir+'map-cache','','http://127.0.0.1:1/{z}/{x}/{y}.png',mfOSM);
 Buildings:=TGerenciadorEdificios.Create(Dir+'building-cache',SERVIDOR_EDIFICIOS_PADRAO,ExpandFileName(ParamStr(1)),True);
 View:=TVisao.Create(Maps,1,Buildings);
 try
 D:=Default(TDadosVista);D.Origem.Lat:=-21.1767;D.Origem.Lon:=-47.8208;
 D.Param:=ModelosPadrao[3];D.Estado.Bateria:=100;D.Estado.Z:=5;D.Estado.Y:=-60;
 Buildings.Atualiza(D.Origem.Lat,D.Origem.Lon,True);WaitBuildings;
 Time:=GetTickCount64;View.GeraQuadroCamera(D,640,360,Low);WriteLn('Actual cockpit camera: ',GetTickCount64-Time,' ms');
 // Load through the same bitmap/stream path used by the cockpit camera.
 B:=TBitmap.Create;Stream:=TFileStream.Create(Low,fmOpenRead or fmShareDenyNone);
 try B.LoadFromStream(Stream);Check((B.Width=640) and (B.Height=360),'invalid cockpit frame');finally Stream.Free;B.Free;end;
 Buildings.Atualiza(D.Origem.Lat,D.Origem.Lon,False);View.GeraQuadroCamera(D,640,360,Empty);
 WithHouses:=TFPMemoryImage.Create(0,0);WithoutHouses:=TFPMemoryImage.Create(0,0);
 try WithHouses.LoadFromFile(Low);WithoutHouses.LoadFromFile(Empty);Diff:=0;
 for Y:=0 to 335 do for X:=0 to 639 do
  if (WithHouses.Colors[X,Y].Red<>WithoutHouses.Colors[X,Y].Red) or
    (WithHouses.Colors[X,Y].Green<>WithoutHouses.Colors[X,Y].Green) or
    (WithHouses.Colors[X,Y].Blue<>WithoutHouses.Colors[X,Y].Blue) then Inc(Diff);
 Check(Diff>2000,'exported camera must contain scene pixels, beyond attribution text');
 finally WithHouses.Free;WithoutHouses.Free;end;
 Buildings.Atualiza(D.Origem.Lat,D.Origem.Lon,True);WaitBuildings;
 D.Estado.Z:=65;D.Param.InclinacaoCameraGraus:=35;
 View.GeraQuadroCamera(D,640,360,HighView);
 ToPNG(Low,Dir+'camera-cockpit-low.png');ToPNG(HighView,Dir+'camera-cockpit-high.png');
 WriteLn('PASS actual camera export, bitmap stream import, 640x360 and ',Diff,' scene pixels');
 finally View.Free;Buildings.Free;Maps.Free;end;
 except on E:Exception do begin WriteLn(StdErr,E.ClassName,': ',E.Message);Halt(1);end;end;
end.
