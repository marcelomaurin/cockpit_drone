unit simcidade3d;
{$mode objfpc}{$H+}
interface
uses Math,simedificios;
type
  TVetor3D=record X,Y,Z:Double;end;
  TCamera3D=record Pos,Frente,Direita,Cima:TVetor3D;Focal:Double;end;
  TPixelsCidade=array of LongWord;
  TProfundidadeCidade=array of Double;
procedure DesenhaEdificios(const Cena:TCenaEdificios; OffsetX,OffsetY:Double;
  const Cam:TCamera3D; W,H:Integer;var Pixels:TPixelsCidade;var Depth:TProfundidadeCidade);
implementation
type
  TVert=record X,Y,Z,U,V:Double;end;
  TFace=array[0..8] of TVert;
function Shade(C:LongWord; F:Double):LongWord;
begin Result:=(LongWord(Round(((C shr 16) and 255)*F)) shl 16) or
 (LongWord(Round(((C shr 8) and 255)*F)) shl 8) or LongWord(Round((C and 255)*F));end;
procedure DesenhaEdificios(const Cena:TCenaEdificios; OffsetX,OffsetY:Double;
  const Cam:TCamera3D; W,H:Integer;var Pixels:TPixelsCidade;var Depth:TProfundidadeCidade);
var E:TEdificio; I,J:Integer; Face:TFace; L,Light:Double;RoadSurface:Boolean;
  function Vertex(X,Y,Z,U,V:Double):TVert;
  var DX,DY,DZ:Double;
  begin DX:=X+OffsetX-Cam.Pos.X;DY:=Y+OffsetY-Cam.Pos.Y;DZ:=Z-Cam.Pos.Z;
    Result.X:=DX*Cam.Direita.X+DY*Cam.Direita.Y+DZ*Cam.Direita.Z;
    Result.Y:=DX*Cam.Cima.X+DY*Cam.Cima.Y+DZ*Cam.Cima.Z;
    Result.Z:=DX*Cam.Frente.X+DY*Cam.Frente.Y+DZ*Cam.Frente.Z;
    Result.U:=U;Result.V:=V;
  end;
  procedure Triangle(A,B,C:TVert;Roof:Boolean;Color:LongWord);
  var X0,Y0,X1,Y1,X2,Y2,Den,WA,WB,WC,IZ,T,U,V,FX,FY,Fog:Double;
    X,Y,Left,Right,Top,Bottom,P:Integer;OutColor:LongWord;
  begin
    X0:=W/2+Cam.Focal*A.X/A.Z;Y0:=H/2-Cam.Focal*A.Y/A.Z;
    X1:=W/2+Cam.Focal*B.X/B.Z;Y1:=H/2-Cam.Focal*B.Y/B.Z;
    X2:=W/2+Cam.Focal*C.X/C.Z;Y2:=H/2-Cam.Focal*C.Y/C.Z;
    if (Max(X0,Max(X1,X2))<0) or (Min(X0,Min(X1,X2))>=W) or
       (Max(Y0,Max(Y1,Y2))<0) or (Min(Y0,Min(Y1,Y2))>=H) then Exit;
    Left:=Floor(Max(0,Min(X0,Min(X1,X2))));Right:=Ceil(Min(W-1,Max(X0,Max(X1,X2))));
    Top:=Floor(Max(0,Min(Y0,Min(Y1,Y2))));Bottom:=Ceil(Min(H-1,Max(Y0,Max(Y1,Y2))));
    Den:=(Y1-Y2)*(X0-X2)+(X2-X1)*(Y0-Y2);if Abs(Den)<1e-8 then Exit;
    for Y:=Top to Bottom do for X:=Left to Right do begin
      FX:=X+0.5;FY:=Y+0.5;
      WA:=((Y1-Y2)*(FX-X2)+(X2-X1)*(FY-Y2))/Den;
      WB:=((Y2-Y0)*(FX-X2)+(X0-X2)*(FY-Y2))/Den;WC:=1-WA-WB;
      if (WA< -1e-8) or (WB< -1e-8) or (WC< -1e-8) then Continue;
      IZ:=WA/A.Z+WB/B.Z+WC/C.Z;if IZ<=0 then Continue;
      T:=1/IZ;P:=Y*W+X;if T>=Depth[P] then Continue;
      U:=(WA*A.U/A.Z+WB*B.U/B.Z+WC*C.U/C.Z)*T;
      V:=(WA*A.V/A.Z+WB*B.V/B.Z+WC*C.V/C.Z)*T;
      if Roof and not RoadSurface and not DentroEdificio(U,V,E) then Continue;
      OutColor:=Color;
      if not Roof and (V>E.Base+0.7) then begin
        FX:=Frac(Abs(U)/3.0);FY:=Frac((V-E.Base)/3.0);
        if (FX>0.18) and (FX<0.70) and (FY>0.30) and (FY<0.78) then OutColor:=Shade($62899D,Light);
      end;
      Fog:=EnsureRange((T-900)/4000,0.0,0.85);
      if Fog>0 then OutColor:=(LongWord(Round(((OutColor shr 16) and 255)*(1-Fog)+185*Fog)) shl 16) or
        (LongWord(Round(((OutColor shr 8) and 255)*(1-Fog)+201*Fog)) shl 8) or
        LongWord(Round((OutColor and 255)*(1-Fog)+214*Fog));
      Pixels[P]:=OutColor or $FF000000;Depth[P]:=T;
    end;
  end;
  procedure Polygon(const Input:TFace; Count:Integer;Roof:Boolean;Color:LongWord);
  var Clipped:TFace; A,B,P:TVert; N,Q:Integer; T:Double;InA,InB:Boolean;
  begin
    N:=0;A:=Input[Count-1];InA:=A.Z>=0.05;
    for Q:=0 to Count-1 do begin B:=Input[Q];InB:=B.Z>=0.05;
      if InA<>InB then begin
        T:=(0.05-A.Z)/(B.Z-A.Z); P.X:=A.X+(B.X-A.X)*T;P.Y:=A.Y+(B.Y-A.Y)*T;P.Z:=0.05;
        P.U:=A.U+(B.U-A.U)*T;P.V:=A.V+(B.V-A.V)*T;
        Clipped[N]:=P;Inc(N);
      end;
      if InB then begin Clipped[N]:=B;Inc(N);end;
      A:=B;InA:=InB;
    end;
    for Q:=1 to N-2 do Triangle(Clipped[0],Clipped[Q],Clipped[Q+1],Roof,Color);
  end;
  procedure Walls(const Ring:TAnelEdificio);
  var Q,R:Integer;DX,DY:Double;
  begin
    for Q:=0 to High(Ring) do begin R:=(Q+1) mod Length(Ring);
      DX:=Ring[R].X-Ring[Q].X;DY:=Ring[R].Y-Ring[Q].Y;L:=Hypot(DX,DY);if L<0.01 then Continue;
      Light:=0.60+0.32*Abs((DX*0.6-DY*0.8)/L);
      Face[0]:=Vertex(Ring[Q].X,Ring[Q].Y,E.Base,0,E.Base);
      Face[1]:=Vertex(Ring[R].X,Ring[R].Y,E.Base,L,E.Base);
      Face[2]:=Vertex(Ring[R].X,Ring[R].Y,E.Altura,L,E.Altura);
      Face[3]:=Vertex(Ring[Q].X,Ring[Q].Y,E.Altura,0,E.Altura);
      Polygon(Face,4,False,Shade(E.Parede,Light));
    end;
  end;
  procedure Roads;
  var Pass,Q,R:Integer;A,B:TPontoEdificio;NX,NY,Width,Z:Double;Color:LongWord;
  begin
    RoadSurface:=True;
    for Pass:=0 to 1 do for Q:=0 to High(Cena.Vias) do
      for R:=1 to High(Cena.Vias[Q].Pontos) do begin
        A:=Cena.Vias[Q].Pontos[R-1];B:=Cena.Vias[Q].Pontos[R];
        L:=Hypot(B.X-A.X,B.Y-A.Y);if L<0.01 then Continue;
        Width:=Cena.Vias[Q].RaioLivre;Z:=0.012;Color:=$ABA99F;
        if Pass=1 then begin Width:=Max(0.5,Width-3);Z:=0.025;Color:=$73787D;end;
        NX:=-(B.Y-A.Y)/L*Width;NY:=(B.X-A.X)/L*Width;
        Face[0]:=Vertex(A.X+NX,A.Y+NY,Z,0,0);
        Face[1]:=Vertex(B.X+NX,B.Y+NY,Z,0,0);
        Face[2]:=Vertex(B.X-NX,B.Y-NY,Z,0,0);
        Face[3]:=Vertex(A.X-NX,A.Y-NY,Z,0,0);
        Polygon(Face,4,True,Color);
      end;
    RoadSurface:=False;
  end;

begin
  if (Length(Pixels)<>W*H) or (Length(Depth)<>W*H) then Exit;
  RoadSurface:=False;Roads;
  for I:=0 to High(Cena.Itens) do begin E:=Cena.Itens[I];
    if Hypot((E.MinX+E.MaxX)/2+OffsetX-Cam.Pos.X,(E.MinY+E.MaxY)/2+OffsetY-Cam.Pos.Y)>1400 then Continue;
    Walls(E.Contorno);
    for J:=0 to High(E.Patios) do Walls(E.Patios[J]);
    Face[0]:=Vertex(E.MinX,E.MinY,E.Altura,E.MinX,E.MinY);
    Face[1]:=Vertex(E.MaxX,E.MinY,E.Altura,E.MaxX,E.MinY);
    Face[2]:=Vertex(E.MaxX,E.MaxY,E.Altura,E.MaxX,E.MaxY);
    Face[3]:=Vertex(E.MinX,E.MaxY,E.Altura,E.MinX,E.MaxY);
    Polygon(Face,4,True,E.Telhado);
  end;
end;
end.
