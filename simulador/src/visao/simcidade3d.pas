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
var E:TEdificio; I,J:Integer; Face:TFace; L,Light:Double;RoadSurface:Boolean;Lote:TLote;
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
  { Superficie plana qualquer (sem recorte pelo contorno). }
  procedure Surface(const P:array of TVert;Color:LongWord);
  var Q:Integer;F:TFace;
  begin
    if Length(P)>8 then Exit;
    for Q:=0 to High(P) do F[Q]:=P[Q];
    RoadSurface:=True;Polygon(F,Length(P),True,Color);RoadSurface:=False;
  end;
  function Light3(AX,AY,AZ,BX,BY,BZ,CX,CY,CZ:Double):Double;
  var NX,NY,NZ,NL:Double;
  begin
    NX:=(BY-AY)*(CZ-AZ)-(BZ-AZ)*(CY-AY);NY:=(BZ-AZ)*(CX-AX)-(BX-AX)*(CZ-AZ);NZ:=(BX-AX)*(CY-AY)-(BY-AY)*(CX-AX);
    NL:=Sqrt(NX*NX+NY*NY+NZ*NZ);if NL<1e-9 then Exit(0.8);
    Result:=EnsureRange(0.55+0.45*Abs(NX*0.35-NY*0.45+NZ*0.82)/NL,0.45,1.0);
  end;
  procedure Tri3(AX,AY,AZ,BX,BY,BZ,CX,CY,CZ:Double;Color:LongWord);
  begin
    Surface([Vertex(AX,AY,AZ,0,0),Vertex(BX,BY,BZ,0,0),Vertex(CX,CY,CZ,0,0)],
      Shade(Color,Light3(AX,AY,AZ,BX,BY,BZ,CX,CY,CZ)));
  end;
  procedure Quad3(AX,AY,AZ,BX,BY,BZ,CX,CY,CZ,DX,DY,DZ:Double;Color:LongWord);
  begin
    Surface([Vertex(AX,AY,AZ,0,0),Vertex(BX,BY,BZ,0,0),Vertex(CX,CY,CZ,0,0),Vertex(DX,DY,DZ,0,0)],
      Shade(Color,Light3(AX,AY,AZ,BX,BY,BZ,CX,CY,CZ)));
  end;
  { Telhado de quatro aguas sobre contorno retangular. }
  procedure HipRoof;
  var P:array[0..3] of TPontoEdificio;A,B,CX,CY,UX,UY,K,H,Z:Double;R0,R1:TPontoEdificio;S:Integer;
  begin
    for S:=0 to 3 do P[S]:=E.Contorno[S];
    A:=Hypot(P[1].X-P[0].X,P[1].Y-P[0].Y);B:=Hypot(P[2].X-P[1].X,P[2].Y-P[1].Y);
    if B>A then begin // gira para que P0-P1 seja o lado maior
      R0:=P[0];P[0]:=P[1];P[1]:=P[2];P[2]:=P[3];P[3]:=R0;K:=A;A:=B;B:=K;
    end;
    if (A<0.5) or (B<0.5) then Exit;
    CX:=(P[0].X+P[1].X+P[2].X+P[3].X)/4;CY:=(P[0].Y+P[1].Y+P[2].Y+P[3].Y)/4;
    UX:=(P[1].X-P[0].X)/A;UY:=(P[1].Y-P[0].Y)/A;K:=(A-B)/2;
    R0.X:=CX-UX*K;R0.Y:=CY-UY*K;R1.X:=CX+UX*K;R1.Y:=CY+UY*K;
    H:=E.Altura;Z:=E.Altura+E.Cumeeira;
    Quad3(P[0].X,P[0].Y,H,P[1].X,P[1].Y,H,R1.X,R1.Y,Z,R0.X,R0.Y,Z,E.Telhado);
    Quad3(P[2].X,P[2].Y,H,P[3].X,P[3].Y,H,R0.X,R0.Y,Z,R1.X,R1.Y,Z,E.Telhado);
    Tri3(P[1].X,P[1].Y,H,P[2].X,P[2].Y,H,R1.X,R1.Y,Z,E.Telhado);
    Tri3(P[3].X,P[3].Y,H,P[0].X,P[0].Y,H,R0.X,R0.Y,Z,E.Telhado);
  end;
  { Caixa orientada: centro (X,Y), eixo F = (FX,FY), S = (FY,-FX). }
  procedure Box(X,Y,FX,FY,Larg,Comp,Z0,Z1:Double;Side,Top:LongWord);
  var C:array[0..3] of TPontoEdificio;Q,R:Integer;SX,SY,HS,HF:Double;
  begin
    SX:=FY;SY:=-FX;HS:=Larg/2;HF:=Comp/2;
    C[0].X:=X-HS*SX-HF*FX;C[0].Y:=Y-HS*SY-HF*FY;C[1].X:=X+HS*SX-HF*FX;C[1].Y:=Y+HS*SY-HF*FY;
    C[2].X:=X+HS*SX+HF*FX;C[2].Y:=Y+HS*SY+HF*FY;C[3].X:=X-HS*SX+HF*FX;C[3].Y:=Y-HS*SY+HF*FY;
    if Z1-Z0>0.001 then for Q:=0 to 3 do begin R:=(Q+1) mod 4;
      Quad3(C[Q].X,C[Q].Y,Z0,C[R].X,C[R].Y,Z0,C[R].X,C[R].Y,Z1,C[Q].X,C[Q].Y,Z1,Side);end;
    Surface([Vertex(C[0].X,C[0].Y,Z1,0,0),Vertex(C[1].X,C[1].Y,Z1,0,0),Vertex(C[2].X,C[2].Y,Z1,0,0),
      Vertex(C[3].X,C[3].Y,Z1,0,0)],Top);
  end;
  { Cilindro aproximado por octogono. }
  procedure Cylinder(X,Y,Raio,Z0,Z1:Double;Side,Top:LongWord;ComTopo:Boolean=True);
  var Q,R:Integer;PX,PY:array[0..7] of Double;
  begin
    for Q:=0 to 7 do begin PX[Q]:=X+Raio*Cos(Q*Pi/4+Pi/8);PY[Q]:=Y+Raio*Sin(Q*Pi/4+Pi/8);end;
    if Z1-Z0>0.001 then for Q:=0 to 7 do begin R:=(Q+1) mod 8;
      Quad3(PX[Q],PY[Q],Z0,PX[R],PY[R],Z0,PX[R],PY[R],Z1,PX[Q],PY[Q],Z1,Side);end;
    if ComTopo then
      Surface([Vertex(PX[0],PY[0],Z1,0,0),Vertex(PX[1],PY[1],Z1,0,0),Vertex(PX[2],PY[2],Z1,0,0),
        Vertex(PX[3],PY[3],Z1,0,0),Vertex(PX[4],PY[4],Z1,0,0),Vertex(PX[5],PY[5],Z1,0,0),
        Vertex(PX[6],PY[6],Z1,0,0),Vertex(PX[7],PY[7],Z1,0,0)],Top);
  end;
  procedure DrawObject(const O:TObjetoQuintal);
  const AguaParada=$3A4A45;AguaVerde=$5B7A2E;AguaLimpa=$3AA7D0;
  var FX,FY:Double;K:Integer;
  begin
    FX:=Cos(O.Angulo);FY:=Sin(O.Angulo);
    case O.Tipo of
      oqVaso:begin
        if O.Criadouro then Cylinder(O.X,O.Y,0.30,0,0.05,$9C5A3A,AguaParada);
        Cylinder(O.X,O.Y,0.18,0,O.Altura,O.Cor,$5A3D2B);
        Cylinder(O.X,O.Y,0.22,O.Altura,O.Altura+0.28,$4F7F35,$5E9440);
      end;
      oqPiscina:begin
        Box(O.X,O.Y,FX,FY,O.Largura+1.2,O.Comprimento+1.2,0,0.045,$D8D2C4,$D8D2C4);
        if O.Criadouro then Box(O.X,O.Y,FX,FY,O.Largura,O.Comprimento,0,0.055,AguaVerde,AguaVerde)
        else Box(O.X,O.Y,FX,FY,O.Largura,O.Comprimento,0,0.055,AguaLimpa,AguaLimpa);
      end;
      oqCaixaDagua:begin
        if O.Criadouro then begin
          Cylinder(O.X,O.Y,O.Largura/2,0,O.Altura,O.Cor,O.Cor,False);
          Cylinder(O.X,O.Y,O.Largura/2-0.06,O.Altura-0.12,O.Altura-0.11,AguaParada,AguaParada);
          Cylinder(O.X,O.Y,O.Largura/2,O.Altura-0.01,O.Altura,O.Cor,O.Cor,False);
          // tampa largada ao lado
          Cylinder(O.X-FY*1.0,O.Y+FX*1.0,O.Largura/2+0.05,0,0.06,$3C7DC4,$3C7DC4);
        end else begin
          Cylinder(O.X,O.Y,O.Largura/2,0,O.Altura,O.Cor,O.Cor);
          Cylinder(O.X,O.Y,O.Largura/2+0.05,O.Altura,O.Altura+0.08,$3C7DC4,$3C7DC4);
        end;
      end;
      oqPneu:begin
        Cylinder(O.X,O.Y,O.Largura/2,0,O.Altura,O.Cor,O.Cor);
        Cylinder(O.X,O.Y,O.Largura/4,O.Altura,O.Altura+0.005,AguaParada,AguaParada);
      end;
      oqTanquePeixe:begin
        Box(O.X,O.Y,FX,FY,O.Largura,O.Comprimento,0,O.Altura,O.Cor,O.Cor);
        if O.Criadouro then Box(O.X,O.Y,FX,FY,O.Largura-0.24,O.Comprimento-0.24,O.Altura,O.Altura+0.01,AguaVerde,AguaVerde)
        else begin
          Box(O.X,O.Y,FX,FY,O.Largura-0.24,O.Comprimento-0.24,O.Altura,O.Altura+0.01,$2F7F86,$2F7F86);
          for K:=0 to 3 do
            Box(O.X+FX*(K*0.45-0.65)+FY*((K mod 2)*0.4-0.2),O.Y+FY*(K*0.45-0.65)-FX*((K mod 2)*0.4-0.2),
              FX,FY,0.12,0.28,O.Altura+0.01,O.Altura+0.02,$F08A24,$F08A24);
        end;
      end;
      oqBalde:begin
        if O.Criadouro then begin
          Cylinder(O.X,O.Y,O.Largura/2,0,O.Altura,O.Cor,O.Cor,False);
          Cylinder(O.X,O.Y,O.Largura/2-0.02,O.Altura-0.06,O.Altura-0.05,AguaParada,AguaParada);
        end else Cylinder(O.X,O.Y,O.Largura/2-0.03,0,O.Altura,O.Cor,O.Cor);
      end;
    end;
  end;
  procedure DrawLot;
  var Q,R:Integer;A,B,G0,G1:TPontoEdificio;Dist:Double;
  begin
    Dist:=Hypot((Lote.MinX+Lote.MaxX)/2+OffsetX-Cam.Pos.X,(Lote.MinY+Lote.MaxY)/2+OffsetY-Cam.Pos.Y);
    if Dist>700 then Exit;
    for Q:=0 to High(Lote.Pisos) do with Lote.Pisos[Q] do
      Surface([Vertex(Canto[0].X,Canto[0].Y,0.03,0,0),Vertex(Canto[1].X,Canto[1].Y,0.03,0,0),
        Vertex(Canto[2].X,Canto[2].Y,0.03,0,0),Vertex(Canto[3].X,Canto[3].Y,0.03,0,0)],Cor);
    // Muro: canto 2->3 e a frente; o portao ocupa o trecho [PortaoInicio,PortaoFim] a partir do canto 2.
    for Q:=0 to 3 do begin R:=(Q+1) mod 4;A:=Lote.Canto[Q];B:=Lote.Canto[R];
      if Q=2 then begin
        G0.X:=A.X+(B.X-A.X)*Lote.PortaoInicio;G0.Y:=A.Y+(B.Y-A.Y)*Lote.PortaoInicio;
        G1.X:=A.X+(B.X-A.X)*Lote.PortaoFim;G1.Y:=A.Y+(B.Y-A.Y)*Lote.PortaoFim;
        Quad3(G0.X,G0.Y,0,G1.X,G1.Y,0,G1.X,G1.Y,Lote.MuroAltura-0.1,G0.X,G0.Y,Lote.MuroAltura-0.1,$5A5F66);
        Quad3(G1.X,G1.Y,0,B.X,B.Y,0,B.X,B.Y,Lote.MuroAltura,G1.X,G1.Y,Lote.MuroAltura,$BDB6A8);
      end else
        Quad3(A.X,A.Y,0,B.X,B.Y,0,B.X,B.Y,Lote.MuroAltura,A.X,A.Y,Lote.MuroAltura,$BDB6A8);
    end;
    if Dist>320 then Exit;
    for Q:=0 to High(Lote.Objetos) do DrawObject(Lote.Objetos[Q]);
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
    if (E.Cumeeira>0) and (Length(E.Contorno)=4) and (Length(E.Patios)=0) then HipRoof
    else begin
    Face[0]:=Vertex(E.MinX,E.MinY,E.Altura,E.MinX,E.MinY);
    Face[1]:=Vertex(E.MaxX,E.MinY,E.Altura,E.MaxX,E.MinY);
    Face[2]:=Vertex(E.MaxX,E.MaxY,E.Altura,E.MaxX,E.MaxY);
    Face[3]:=Vertex(E.MinX,E.MaxY,E.Altura,E.MinX,E.MaxY);
    Polygon(Face,4,True,E.Telhado);
    end;
  end;
  for I:=0 to High(Cena.Lotes) do begin Lote:=Cena.Lotes[I];DrawLot;end;
end;
end.
