program test_buildings_3d;
{$mode objfpc}{$H+}
uses SysUtils,Classes,Math,FPImage,FPWritePNG,simgeo,simedificios,simcidade3d;
procedure Check(Ok:Boolean;const Msg:string);begin if not Ok then raise Exception.Create(Msg);end;
function Point(X,Y:Double):TPontoEdificio;begin Result.X:=X;Result.Y:=Y;end;
function Vector(X,Y,Z:Double):TVetor3D;begin Result.X:=X;Result.Y:=Y;Result.Z:=Z;end;
var Scene,Box:TCenaEdificios;Origin:TPontoGeo;SL:TStringList;Cam:TCamera3D;
 Pixels:TPixelsCidade;Depth:TProfundidadeCidade;I,X,Y:Integer;N:LongWord;Time:QWord;
 Img:TFPMemoryImage;Writer:TFPWriterPNG;Color:TFPColor;Theta,T,DX,DY,DZ:Double;
procedure Initialize(W,H:Integer);
begin SetLength(Pixels,W*H);SetLength(Depth,W*H);for I:=0 to High(Pixels) do begin Pixels[I]:=$FF87B5DE;Depth[I]:=10000;end;end;
procedure BoxScene;
begin
 Box:=Default(TCenaEdificios);SetLength(Box.Itens,1);
 with Box.Itens[0] do begin SetLength(Contorno,4);
   Contorno[0]:=Point(-5,10);Contorno[1]:=Point(5,10);Contorno[2]:=Point(5,20);Contorno[3]:=Point(-5,20);
   MinX:=-5;MaxX:=5;MinY:=10;MaxY:=20;Altura:=10;Parede:=$C0B090;Telhado:=$A05040;end;
end;
procedure SaveView(const FileName:string;HighView:Boolean);
const W=640;H=360;
begin
 Initialize(W,H);Cam.Pos:=Vector(0,-20,4);Theta:=0;
 if HighView then begin Cam.Pos.Z:=45;Theta:=DegToRad(25);end;
 Cam.Frente:=Vector(0,Cos(Theta),-Sin(Theta));Cam.Direita:=Vector(1,0,0);Cam.Cima:=Vector(0,Sin(Theta),Cos(Theta));Cam.Focal:=420;
 for Y:=0 to H-1 do for X:=0 to W-1 do begin
   DX:=(X-W/2)/Cam.Focal;DY:=Cam.Frente.Y-Cam.Cima.Y*(Y-H/2)/Cam.Focal;
   DZ:=Cam.Frente.Z-Cam.Cima.Z*(Y-H/2)/Cam.Focal;
   if DZ< -0.0001 then begin T:=-Cam.Pos.Z/DZ;Depth[Y*W+X]:=T;
     if Abs(DX*T)<5 then Pixels[Y*W+X]:=$FF777C80
     else if ((Floor(DX*T/8)+Floor(DY*T/8)) and 1)=0 then Pixels[Y*W+X]:=$FF708E59 else Pixels[Y*W+X]:=$FF7D9B65;
   end;
 end;
 Time:=GetTickCount64;DesenhaEdificios(Scene,0,0,Cam,W,H,Pixels,Depth);
 WriteLn('Rendering ',FileName,': ',GetTickCount64-Time,' ms');
 Img:=TFPMemoryImage.Create(W,H);Writer:=TFPWriterPNG.Create;
 try for Y:=0 to H-1 do for X:=0 to W-1 do begin
   N:=Pixels[Y*W+X];Color.Red:=((N shr 16) and 255)*257;Color.Green:=((N shr 8) and 255)*257;
   Color.Blue:=(N and 255)*257;Color.Alpha:=65535;Img.Colors[X,Y]:=Color;
 end;Img.SaveToFile(FileName,Writer);finally Writer.Free;Img.Free;end;
end;
begin
 Origin.Lat:=-21.1767;Origin.Lon:=-47.8208;SL:=TStringList.Create;
 try SL.LoadFromFile(ParamStr(1));Scene:=LeCenaOSM(SL.Text,Origin);finally SL.Free;end;
 Check(Length(Scene.Itens)=4,'parser must accept houses/apartments/relation without duplicate members');
 Check((Scene.Itens[0].Altura=6) and Scene.Itens[0].Estimada,'levels conversion');
 Check((Scene.Itens[1].Altura=27) and not Scene.Itens[1].Estimada,'explicit height');
 Check(Abs(Scene.Itens[2].Altura-9.144)<0.001,'feet conversion');
 Check(Length(Scene.Itens[3].Patios)=1,'multipolygon courtyard');
 Check(not DentroEdificio(-39,75,Scene.Itens[3]),'courtyard must remain empty');
 Check(DentroEdificio(-44,75,Scene.Itens[3]),'outer building body');
 Check(Scene.Ignorados=1,'open footprint must be rejected');
 BoxScene;Initialize(100,100);Cam.Pos:=Vector(0,0,2);Cam.Frente:=Vector(0,1,0);
 Cam.Direita:=Vector(1,0,0);Cam.Cima:=Vector(0,0,1);Cam.Focal:=50;
 DesenhaEdificios(Box,0,0,Cam,100,100,Pixels,Depth);
 Check(Abs(Depth[50*100+50]-10)<0.01,'front wall must occlude ground/sky');
 Box.Itens[0].Base:=5;Initialize(100,100);DesenhaEdificios(Box,0,0,Cam,100,100,Pixels,Depth);
 Check(Depth[50*100+50]=10000,'min_height must leave a gap');
 Box.Itens[0].Base:=0;SetLength(Box.Itens[0].Patios,1);SetLength(Box.Itens[0].Patios[0],4);
 Box.Itens[0].Patios[0][0]:=Point(-1,14);Box.Itens[0].Patios[0][1]:=Point(1,14);
 Box.Itens[0].Patios[0][2]:=Point(1,16);Box.Itens[0].Patios[0][3]:=Point(-1,16);
 Initialize(100,100);Cam.Pos:=Vector(0,15,20);Cam.Frente:=Vector(0,0,-1);Cam.Cima:=Vector(0,1,0);
 DesenhaEdificios(Box,0,0,Cam,100,100,Pixels,Depth);
 Check(Depth[50*100+50]=10000,'roof must not cover courtyard');
 Check(Abs(Depth[50*100+65]-10)<0.01,'roof outside courtyard');
 SaveView(ParamStr(2),False);SaveView(ParamStr(3),True);
 WriteLn('PASS footprint geometry, height/levels/feet, multipolygons, holes, depth occlusion and min_height');
end.
