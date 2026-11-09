unit simvisao;

{ Desenho das vistas do simulador, em software (sem OpenGL).

  - Câmera do drone: cada pixel vira um raio a partir da câmera (altura,
    rumo, arfagem, rolagem e campo de visão do modelo); onde o raio toca o
    chão, a cor vem do bloco de mapa naquele ponto. O nível de detalhe (zoom
    do bloco) é escolhido por linha conforme a distância. Acima do horizonte,
    céu; ao longe, névoa.
  - Terceira pessoa: a mesma imagem com a câmera atrás e acima do drone.
  - Mapa de cima: blocos 2D centrados no drone, com rastro, ponto de partida,
    vizinhos do mundo compartilhado e o círculo de 2 km.

  A imagem é montada numa resolução interna menor e esticada na tela. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Graphics, IntfGraphics, GraphType, LCLType, FPImage,
  simtipos, simgeo, simmapa, simmundo, simsimulacao, simedificios, simedificios_cache, simcidade3d,simrastercache;

type
  TTipoVista = (tvCamera, tvTerceiraPessoa, tvMapa);

  TVetor = TVetor3D;

  { TAmostrador: cor do chão num ponto, com cache de blocos por quadro. }

  TAmostrador = class
  private
    FGer: TGerenciadorBlocos;
    FOx19, FOy19, FMpp19: Double;
    FZoomMax: Integer;
    FChaves: array[0..1023] of Int64;
    FBlocos: array[0..1023] of TBloco;
    FUsadas: array[0..1023] of Boolean;
    FPrioridade: Integer;
    function Bloco(AZ, ATx, ATy: Integer; APedir: Boolean): TBloco;
  public
    constructor Create(AGer: TGerenciadorBlocos);
    procedure NovoQuadro(const AOrigem: TPontoGeo);
    function CorPixel(AZ: Integer; APx, APy: Double): LongWord;
    function CorMetros(AXm, AYm: Double; AZ: Integer): LongWord;
    procedure MetrosParaPixel(AXm, AYm: Double; AZ: Integer; out APx, APy: Double);
    property ZoomMax: Integer read FZoomMax;
    property Prioridade: Integer read FPrioridade write FPrioridade;
  end;

  TDadosVista = record
    Estado: TEstadoVoo;
    Param: TParametrosModelo;
    Origem: TPontoGeo;
    Vizinhos: TVizinhos;
    Marcadores: TVizinhos;
    Rastro: TPontoRastro_Array;
    NoMundo: Boolean;
    RaioMundoM: Integer;
    ZoomMapa: Integer;
    Fase: string;
  end;

  { TVisao }

  TVisao = class
  private
    FAmostrador: TAmostrador;
    FGer: TGerenciadorBlocos;
    FEdificios:TGerenciadorEdificios;
    FRaster:TGerenciadorRaster;
    FImg: TLazIntfImage;
    FBmp: TBitmap;
    FCredito: string;
    procedure Prepara(AW, AH: Integer);
    procedure DesenhaChao(const AD: TDadosVista; ATerceira: Boolean; AW, AH: Integer;
      out AC, AFrente, ADireita, ACima: TVetor; out AFocal: Double);
    procedure DesenhaMapaPixels(const AD: TDadosVista; AW, AH: Integer);
  public
    constructor Create(AGer: TGerenciadorBlocos; APrioridade: Integer = 1; AEdificios:TGerenciadorEdificios=nil;ARaster:TGerenciadorRaster=nil);
    destructor Destroy; override;
    { Desenha a vista no canvas de destino (ARect). AEscala = resolução interna. }
    procedure Desenha(ACanvas: TCanvas; const ARect: TRect; ATipo: TTipoVista;
      const AD: TDadosVista; AEscala: Double);
    property Credito: string read FCredito write FCredito;
    { Salva o último quadro renderizado em arquivo BMP }
    procedure SalvaQuadro(const ACaminho: string);
    procedure GeraQuadroCamera(const AD:TDadosVista;W,H:Integer;const Arquivo:string);
  end;

var
  { Inclinacao fixa da camera do drone para inspecao (graus para baixo);
    negativo usa a camera do modelo. Vale para a vista e para o cockpit. }
  InclinacaoInspecaoGraus: Double = -1;

function Vet(AX, AY, AZ: Double): TVetor; inline;

implementation

const
  COR_SEM_MAPA_A = $00586A4A;
  COR_SEM_MAPA_B = $00667A56;

function Vet(AX, AY, AZ: Double): TVetor;
begin
  Result.X := AX;
  Result.Y := AY;
  Result.Z := AZ;
end;

function Soma(const A, B: TVetor): TVetor; inline;
begin
  Result := Vet(A.X + B.X, A.Y + B.Y, A.Z + B.Z);
end;

function Mult(const A: TVetor; K: Double): TVetor; inline;
begin
  Result := Vet(A.X * K, A.Y * K, A.Z * K);
end;

function Escalar(const A, B: TVetor): Double; inline;
begin
  Result := A.X * B.X + A.Y * B.Y + A.Z * B.Z;
end;

function Mistura(ACor, ANevoa: LongWord; AF: Double): LongWord; inline;
var
  R, G, B: Integer;
begin
  R := Round(((ACor shr 16) and $FF) * (1 - AF) + ((ANevoa shr 16) and $FF) * AF);
  G := Round(((ACor shr 8) and $FF) * (1 - AF) + ((ANevoa shr 8) and $FF) * AF);
  B := Round((ACor and $FF) * (1 - AF) + (ANevoa and $FF) * AF);
  Result := (LongWord(R) shl 16) or (LongWord(G) shl 8) or LongWord(B);
end;

function CorTela(ACor: LongWord): TColor; inline;
begin
  // $00RRGGBB -> TColor ($00BBGGRR)
  Result := TColor(((ACor and $FF) shl 16) or (ACor and $FF00) or ((ACor shr 16) and $FF));
end;

{ TAmostrador }

constructor TAmostrador.Create(AGer: TGerenciadorBlocos);
begin
  inherited Create;
  FGer := AGer;
  FPrioridade := 1;
end;

procedure TAmostrador.NovoQuadro(const AOrigem: TPontoGeo);
begin
  GeoParaPixel(AOrigem.Lat, AOrigem.Lon, 19, FOx19, FOy19);
  FMpp19 := MetrosPorPixel(AOrigem.Lat, 19);
  FZoomMax := FGer.ZoomMaximo;
  FillChar(FUsadas, SizeOf(FUsadas), 0);
end;

function TAmostrador.Bloco(AZ, ATx, ATy: Integer; APedir: Boolean): TBloco;
var
  K: Int64;
  HashValue:QWord;
  H, I: Integer;
begin
  K := (Int64(AZ) shl 56) or (Int64(ATx and $FFFFFFF) shl 28) or Int64(ATy and $FFFFFFF);
  HashValue:=(QWord(K) xor (QWord(K) shr 28) xor (QWord(K) shr 56)) and $FFFFFFFF;
  H := Integer(((HashValue * QWord(2654435761)) shr 7) and 1023);
  for I := 0 to 15 do
  begin
    if not FUsadas[H] then
    begin
      FUsadas[H] := True;
      FChaves[H] := K;
      FBlocos[H] := FGer.Obtem(AZ, ATx, ATy, APedir, FPrioridade);
      Exit(FBlocos[H]);
    end;
    if FChaves[H] = K then
      Exit(FBlocos[H]);
    H := (H + 1) and 1023;
  end;
  Result := FGer.Obtem(AZ, ATx, ATy, APedir, FPrioridade);
end;

procedure TAmostrador.MetrosParaPixel(AXm, AYm: Double; AZ: Integer; out APx, APy: Double);
var
  F: Double;
begin
  F := 1 / (1 shl (19 - AZ));
  APx := (FOx19 + AXm / FMpp19) * F;
  APy := (FOy19 - AYm / FMpp19) * F;
end;

function TAmostrador.CorPixel(AZ: Integer; APx, APy: Double): LongWord;
var
  K, Z, Tx, Ty, Px, Py: Integer;
  B: TBloco;
  F: Double;
begin
  for K := 0 to 6 do
  begin
    Z := AZ - K;
    if Z < ZOOM_MIN then
      Break;
    F := 1 / (1 shl K);
    Px := Floor(APx * F);
    Py := Floor(APy * F);
    Tx := Px shr 8;
    Ty := Py shr 8;
    // Só pede o nível desejado; os de cima servem de reserva enquanto chega.
    B := Bloco(Z, Tx, Ty, K = 0);
    if Assigned(B) then
      Exit(B.Amostra(Px, Py));
  end;
  // Sem bloco nenhum: grade de 10 m para dar noção de movimento.
  Px := Floor(APx / 8);
  Py := Floor(APy / 8);
  if ((Px xor Py) and 1) = 0 then
    Result := COR_SEM_MAPA_A
  else
    Result := COR_SEM_MAPA_B;
end;

function TAmostrador.CorMetros(AXm, AYm: Double; AZ: Integer): LongWord;
var
  Px, Py: Double;
begin
  MetrosParaPixel(AXm, AYm, AZ, Px, Py);
  Result := CorPixel(AZ, Px, Py);
end;

{ TVisao }

constructor TVisao.Create(AGer: TGerenciadorBlocos; APrioridade: Integer; AEdificios:TGerenciadorEdificios;ARaster:TGerenciadorRaster);
begin
  inherited Create;
  FGer := AGer;
  FEdificios:=AEdificios;FRaster:=ARaster;
  FAmostrador := TAmostrador.Create(AGer);
  FAmostrador.Prioridade := APrioridade;
  FBmp := TBitmap.Create;
end;

destructor TVisao.Destroy;
begin
  FImg.Free;
  FBmp.Free;
  FAmostrador.Free;
  inherited Destroy;
end;

procedure TVisao.SalvaQuadro(const ACaminho: string);
var
  Tmp,TextoCredito:string;
begin
  if (FBmp = nil) or (FBmp.Width <= 0) or (FBmp.Height <= 0) then
    Exit;
  Tmp := ACaminho + '.tmp';
  try
    TextoCredito:=FCredito;
    if (Assigned(FEdificios) and (Length(FEdificios.Cena.Itens)>0)) or
       (Assigned(FRaster) and (Length(FRaster.Cena.Itens)>0)) then
      TextoCredito:=TextoCredito+' | OSM + construcoes simuladas/alturas aproximadas';
    if TextoCredito<>'' then begin
      FBmp.Canvas.Font.Size:=7;FBmp.Canvas.Font.Color:=clWhite;FBmp.Canvas.Brush.Color:=clBlack;
      FBmp.Canvas.TextOut(3,Max(0,FBmp.Height-16),TextoCredito);
    end;
  FBmp.SaveToFile(Tmp);
    if FileExists(ACaminho) then
      DeleteFile(ACaminho);
    RenameFile(Tmp, ACaminho);
  except
    // Ignora conflitos momentaneos de concorrencia
  end;
end;

procedure TVisao.GeraQuadroCamera(const AD:TDadosVista;W,H:Integer;const Arquivo:string);
var C,Fr,Di,Ci:TVetor;Focal,Lat,Lon:Double;
begin
  Prepara(W,H);FAmostrador.NovoQuadro(AD.Origem);
  DesenhaChao(AD,False,W,H,C,Fr,Di,Ci,Focal);
  FBmp.LoadFromIntfImage(FImg);
  LocalParaGeo(AD.Origem,AD.Estado.X,AD.Estado.Y,Lat,Lon);
  FCredito:=FGer.Credito(Lat+0.01,Lon-0.01,Lat-0.01,Lon+0.01,16);
  SalvaQuadro(Arquivo);
end;

procedure TVisao.Prepara(AW, AH: Integer);
var
  Desc: TRawImageDescription;
begin
  if Assigned(FImg) and (FImg.Width = AW) and (FImg.Height = AH) then
    Exit;
  FreeAndNil(FImg);
  Desc.Init_BPP32_B8G8R8A8_BIO_TTB(AW, AH);
  FImg := TLazIntfImage.Create(0, 0);
  FImg.DataDescription := Desc;
  FImg.SetSize(AW, AH);
end;

procedure TVisao.DesenhaChao(const AD: TDadosVista; ATerceira: Boolean; AW, AH: Integer;
  out AC, AFrente, ADireita, ACima: TVetor; out AFocal: Double);
var
  E: TEstadoVoo;
  Psi, Teta, Fi, Cx, Cy, T, Dist, Pegada, Rasante, Nevoa, Comp: Double;
  D: TVetor;
  U, V, Z, ZLinha: Integer;
  Linha: PLongWord;
  Cor, Ceu, CeuAlto, Neb: LongWord;
  Px, Py: Double;
  D0, Dv, Du: TVetor;
  Pixels:TPixelsCidade;Depth:TProfundidadeCidade;
  Cena:TCenaEdificios;Cam:TCamera3D;OffsetX,OffsetY:Double;
begin
  SetLength(Pixels,AW*AH);SetLength(Depth,AW*AH);
  E := AD.Estado;
  if AD.Param.Classe='submarine' then E.Z:=E.Z+30;
  Psi := DegToRad(E.Rumo);
  if ATerceira then
  begin
    Teta := DegToRad(18);
    Fi := 0;
    AC := Vet(E.X - 5 * Sin(Psi), E.Y - 5 * Cos(Psi), E.Z + 2.2);
  end
  else
  begin
    // A câmera acompanha a inclinação do drone (nariz para baixo = olha para baixo).
    if InclinacaoInspecaoGraus >= 0 then
      Teta := DegToRad(InclinacaoInspecaoGraus + E.Arfagem)
    else
      Teta := DegToRad(AD.Param.InclinacaoCameraGraus + E.Arfagem);
    Fi := DegToRad(E.Rolagem);
    AC := Vet(E.X, E.Y, E.Z + 0.08);
  end;
  AFrente := Vet(Sin(Psi) * Cos(Teta), Cos(Psi) * Cos(Teta), -Sin(Teta));
  D0 := Vet(Cos(Psi), -Sin(Psi), 0);                              // direita sem rolagem
  D := Vet(Sin(Psi) * Sin(Teta), Cos(Psi) * Sin(Teta), Cos(Teta)); // cima sem rolagem
  ADireita := Soma(Mult(D0, Cos(Fi)), Mult(D, -Sin(Fi)));
  ACima := Soma(Mult(D, Cos(Fi)), Mult(D0, Sin(Fi)));
  AFocal := (AW / 2) / Tan(DegToRad(EnsureRange(AD.Param.CampoVisaoGraus, 30, 120)) / 2);
  Cx := AW / 2;
  Cy := AH / 2;
  Ceu := $0087B5DE;
  CeuAlto := $004A7EC2;
  Neb := $00B9C9D6;
  if AD.Param.Classe='submarine' then begin Ceu:=$001B5B7A;CeuAlto:=$000A2030;Neb:=$00234857;end;

  for V := 0 to AH - 1 do
  begin
    Linha := PLongWord(FImg.GetDataLineStart(V));
    // Raio do pixel (u, v) = frente + direita * du + cima * dv
    Dv := Mult(ACima, -(V - Cy) / AFocal);
    D0 := Soma(AFrente, Dv);
    Du := Mult(ADireita, 1 / AFocal);
    // Nível de detalhe da linha (pelo raio central).
    D := D0;
    ZLinha := FAmostrador.ZoomMax;
    if D.Z < -1e-4 then
    begin
      Comp := Sqrt(Escalar(D, D));
      T := -AC.Z / D.Z;
      Dist := T * Comp;
      Rasante := -D.Z / Comp;
      Pegada := Dist / AFocal / Sqrt(Max(0.02, Rasante));
      ZLinha := ZoomParaMetros(AD.Origem.Lat, Pegada * 0.8, FAmostrador.ZoomMax);
    end;
    for U := 0 to AW - 1 do
    begin
      Depth[V*AW+U]:=1e30;
      D := Soma(D0, Mult(Du, U - Cx));
      if D.Z < -1e-5 then
      begin
        T := -AC.Z / D.Z;
        Depth[V*AW+U]:=T;
        Px := AC.X + D.X * T;
        Py := AC.Y + D.Y * T;
        Dist := T * Sqrt(Escalar(D, D));
        Z := ZLinha;
        if Dist > 5000 then
          Cor := Neb
        else
        begin
          if AD.Param.Classe='submarine' then begin
            if ((Floor(Px/5)+Floor(Py/5)) and 1)=0 then Cor:=$002A5261 else Cor:=$00315E6B;
          end else Cor := FAmostrador.CorMetros(Px, Py, Z);
          Nevoa := EnsureRange((Dist - 900) / 4000, 0, 0.85);
          if Nevoa > 0 then
            Cor := Mistura(Cor, Neb, Nevoa);
        end;
      end
      else
      begin
        // Céu: mais claro perto do horizonte.
        Cor := Mistura(Ceu, CeuAlto, EnsureRange(D.Z * 2.5, 0, 1));
      end;
      Pixels[V*AW+U] := Cor or $FF000000;
    end;
  end;
  if Assigned(FEdificios) and (AD.Param.Classe<>'submarine') then begin
    Cena:=FEdificios.Cena;
    if (Length(Cena.Itens)=0) and Assigned(FRaster) then Cena:=FRaster.Cena;
    if Length(Cena.Itens)>0 then begin
    GeoParaLocal(AD.Origem,Cena.Origem.Lat,Cena.Origem.Lon,OffsetX,OffsetY);
    Cam.Pos:=AC;Cam.Frente:=AFrente;Cam.Direita:=ADireita;Cam.Cima:=ACima;Cam.Focal:=AFocal;
    DesenhaEdificios(Cena,OffsetX,OffsetY,Cam,AW,AH,Pixels,Depth);
    end;
  end;
  for V:=0 to AH-1 do Move(Pixels[V*AW],FImg.GetDataLineStart(V)^,AW*4);
end;

procedure TVisao.DesenhaMapaPixels(const AD: TDadosVista; AW, AH: Integer);
var
  U, V, Z: Integer;
  Cx, Cy: Double;
  Linha: PLongWord;
begin
  Z := EnsureRange(AD.ZoomMapa, ZOOM_MIN, FAmostrador.ZoomMax);
  FAmostrador.MetrosParaPixel(AD.Estado.X, AD.Estado.Y, Z, Cx, Cy);
  for V := 0 to AH - 1 do
  begin
    Linha := PLongWord(FImg.GetDataLineStart(V));
    for U := 0 to AW - 1 do
      Linha[U] := FAmostrador.CorPixel(Z, Cx + U - AW / 2, Cy + V - AH / 2) or $FF000000;
  end;
end;

procedure TVisao.Desenha(ACanvas: TCanvas; const ARect: TRect; ATipo: TTipoVista;
  const AD: TDadosVista; AEscala: Double);
var
  W, H, I, Z, Tam: Integer;
  C, Fr, Di, Ci, Rel: TVetor;
  Focal, Sx, Sy, Xc, Yc, Zc, Cx, Cy, Px, Py, Ox, Oy, Mpp, Psi: Double;
  E: TEstadoVoo;
  Lx, Ly, Qx, Qy: Integer;
  Txt: string;
  Pts: array[0..2] of TPoint;
  Vx, Vy: Double;
  Norte, Sul, Leste, Oeste, La, Lo: Double;

  procedure Projeta(const APonto: TVetor; out AOk: Boolean; out AX, AY, AZ: Double);
  begin
    Rel := Vet(APonto.X - C.X, APonto.Y - C.Y, APonto.Z - C.Z);
    AZ := Escalar(Rel, Fr);
    AOk := AZ > 0.5;
    if not AOk then
      Exit;
    AX := ARect.Left + (W / 2 + Focal * Escalar(Rel, Di) / AZ) * Sx;
    AY := ARect.Top + (H / 2 - Focal * Escalar(Rel, Ci) / AZ) * Sy;
  end;

  procedure TextoSombra(AX, AY: Integer; const ATexto: string);
  begin
    ACanvas.Brush.Style := bsClear;
    ACanvas.Font.Color := clBlack;
    ACanvas.TextOut(AX + 1, AY + 1, ATexto);
    ACanvas.Font.Color := clWhite;
    ACanvas.TextOut(AX, AY, ATexto);
  end;

  procedure DesenhaVizinhos3D;
  var
    K: Integer;
    Ok: Boolean;
    X1, Y1, Z1, Lxm, Lym: Double;
  begin
    for K := 0 to High(AD.Vizinhos) do
    begin
      GeoParaLocal(AD.Origem, AD.Vizinhos[K].Lat, AD.Vizinhos[K].Lon, Lxm, Lym);
      Projeta(Vet(Lxm, Lym, AD.Vizinhos[K].Alt), Ok, X1, Y1, Z1);
      if not Ok then
        Continue;
      Tam := EnsureRange(Round(Focal * Sx * 0.6 / Z1), 3, 60);
      ACanvas.Pen.Color := clYellow;
      ACanvas.Pen.Width := 2;
      ACanvas.Brush.Style := bsClear;
      ACanvas.Ellipse(Round(X1) - Tam, Round(Y1) - Tam div 3, Round(X1) + Tam, Round(Y1) + Tam div 3);
      ACanvas.Line(Round(X1) - Tam, Round(Y1) - Tam div 2, Round(X1) + Tam, Round(Y1) + Tam div 2);
      ACanvas.Line(Round(X1) - Tam, Round(Y1) + Tam div 2, Round(X1) + Tam, Round(Y1) - Tam div 2);
      TextoSombra(Round(X1) + Tam + 3, Round(Y1) - 8,
        Format('%s  %.0f m', [AD.Vizinhos[K].Apelido, AD.Vizinhos[K].DistanciaM]));
    end;
  end;

  procedure DesenhaDronePropio;
  var
    Ok1, Ok2: Boolean;
    A1, B1, A2, B2, Zx, Psi2, BodyZ: Double;
    K: Integer;
    Bracos: array[0..3] of TVetor;
  begin
    Psi2 := DegToRad(E.Rumo);
    BodyZ:=E.Z;
    if AD.Param.Classe='submarine' then BodyZ:=BodyZ+30;
    for K := 0 to 3 do
      Bracos[K] := Vet(E.X + 0.35 * Sin(Psi2 + DegToRad(45 + 90 * K)),
        E.Y + 0.35 * Cos(Psi2 + DegToRad(45 + 90 * K)), BodyZ);
    ACanvas.Pen.Width := 3;
    for K := 0 to 1 do
    begin
      Projeta(Bracos[K], Ok1, A1, B1, Zx);
      Projeta(Bracos[K + 2], Ok2, A2, B2, Zx);
      if Ok1 and Ok2 then
      begin
        if K = 0 then
          ACanvas.Pen.Color := clRed
        else
          ACanvas.Pen.Color := clWhite;
        ACanvas.Line(Round(A1), Round(B1), Round(A2), Round(B2));
      end;
    end;
    ACanvas.Pen.Width := 1;
  end;

begin
  if (ARect.Right - ARect.Left < 8) or (ARect.Bottom - ARect.Top < 8) then
    Exit;
  E := AD.Estado;
  W := Max(64, Round((ARect.Right - ARect.Left) * AEscala));
  H := Max(48, Round((ARect.Bottom - ARect.Top) * AEscala));
  Sx := (ARect.Right - ARect.Left) / W;
  Sy := (ARect.Bottom - ARect.Top) / H;
  Prepara(W, H);
  FAmostrador.NovoQuadro(AD.Origem);
  if ATipo = tvMapa then
    DesenhaMapaPixels(AD, W, H)
  else
    DesenhaChao(AD, ATipo = tvTerceiraPessoa, W, H, C, Fr, Di, Ci, Focal);
  FBmp.LoadFromIntfImage(FImg);
  ACanvas.StretchDraw(ARect, FBmp);
  ACanvas.Font.Size := 9;

  if ATipo = tvMapa then
  begin
    Z := EnsureRange(AD.ZoomMapa, ZOOM_MIN, FAmostrador.ZoomMax);
    FAmostrador.MetrosParaPixel(E.X, E.Y, Z, Cx, Cy);
    Mpp := MetrosPorPixel(AD.Origem.Lat, Z);
    // Rastro
    ACanvas.Pen.Color := clFuchsia;
    ACanvas.Pen.Width := 2;
    for I := 0 to High(AD.Rastro) do
    begin
      FAmostrador.MetrosParaPixel(AD.Rastro[I].X, AD.Rastro[I].Y, Z, Px, Py);
      Lx := ARect.Left + Round((Px - Cx + W / 2) * Sx);
      Ly := ARect.Top + Round((Py - Cy + H / 2) * Sy);
      if I = 0 then
        ACanvas.MoveTo(Lx, Ly)
      else
        ACanvas.LineTo(Lx, Ly);
    end;
    // Ponto de partida
    FAmostrador.MetrosParaPixel(0, 0, Z, Ox, Oy);
    Lx := ARect.Left + Round((Ox - Cx + W / 2) * Sx);
    Ly := ARect.Top + Round((Oy - Cy + H / 2) * Sy);
    ACanvas.Pen.Color := clLime;
    ACanvas.Brush.Style := bsClear;
    ACanvas.Ellipse(Lx - 7, Ly - 7, Lx + 7, Ly + 7);
    TextoSombra(Lx + 9, Ly - 7, 'H');
    // Círculo do mundo compartilhado (2 km)
    if AD.NoMundo then
    begin
      Tam := Round(AD.RaioMundoM / Mpp * Sx);
      Lx := ARect.Left + (ARect.Right - ARect.Left) div 2;
      Ly := ARect.Top + (ARect.Bottom - ARect.Top) div 2;
      ACanvas.Pen.Color := clYellow;
      ACanvas.Pen.Style := psDash;
      ACanvas.Pen.Width := 1;
      ACanvas.Ellipse(Lx - Tam, Ly - Tam, Lx + Tam, Ly + Tam);
      ACanvas.Pen.Style := psSolid;
    end;
    // Vizinhos e marcadores
    for I := 0 to High(AD.Vizinhos) do
    begin
      GeoParaLocal(AD.Origem, AD.Vizinhos[I].Lat, AD.Vizinhos[I].Lon, Vx, Vy);
      FAmostrador.MetrosParaPixel(Vx, Vy, Z, Px, Py);
      Lx := ARect.Left + Round((Px - Cx + W / 2) * Sx);
      Ly := ARect.Top + Round((Py - Cy + H / 2) * Sy);
      ACanvas.Brush.Style := bsSolid;
      ACanvas.Brush.Color := clYellow;
      ACanvas.Pen.Color := clBlack;
      ACanvas.Ellipse(Lx - 5, Ly - 5, Lx + 5, Ly + 5);
      TextoSombra(Lx + 7, Ly - 7, AD.Vizinhos[I].Apelido);
    end;
    for I := 0 to High(AD.Marcadores) do
    begin
      GeoParaLocal(AD.Origem, AD.Marcadores[I].Lat, AD.Marcadores[I].Lon, Vx, Vy);
      FAmostrador.MetrosParaPixel(Vx, Vy, Z, Px, Py);
      Lx := ARect.Left + Round((Px - Cx + W / 2) * Sx);
      Ly := ARect.Top + Round((Py - Cy + H / 2) * Sy);
      ACanvas.Brush.Style := bsSolid;
      ACanvas.Brush.Color := clAqua;
      ACanvas.Pen.Color := clBlack;
      ACanvas.Rectangle(Lx - 4, Ly - 4, Lx + 4, Ly + 4);
      TextoSombra(Lx + 7, Ly - 7, AD.Marcadores[I].Apelido);
    end;
    // O próprio drone: triângulo apontando o rumo.
    Lx := ARect.Left + (ARect.Right - ARect.Left) div 2;
    Ly := ARect.Top + (ARect.Bottom - ARect.Top) div 2;
    Psi := DegToRad(E.Rumo);
    Pts[0] := Point(Lx + Round(12 * Sin(Psi)), Ly - Round(12 * Cos(Psi)));
    Pts[1] := Point(Lx + Round(8 * Sin(Psi + 2.5)), Ly - Round(8 * Cos(Psi + 2.5)));
    Pts[2] := Point(Lx + Round(8 * Sin(Psi - 2.5)), Ly - Round(8 * Cos(Psi - 2.5)));
    ACanvas.Brush.Style := bsSolid;
    ACanvas.Brush.Color := clRed;
    ACanvas.Pen.Color := clWhite;
    ACanvas.Polygon(Pts);
    // Área vista, para o crédito.
    PixelParaGeo(Cx - W / 2, Cy - H / 2, Z, Norte, Oeste);
    PixelParaGeo(Cx + W / 2, Cy + H / 2, Z, Sul, Leste);
  end
  else
  begin
    if ATipo = tvTerceiraPessoa then
      DesenhaDronePropio;
    DesenhaVizinhos3D;
    // Área vista aproximada, para o crédito.
    Z := ZoomParaMetros(AD.Origem.Lat, Max(0.3, E.Z / 200), FAmostrador.ZoomMax);
    LocalParaGeo(AD.Origem, E.X, E.Y, La, Lo);
    Norte := La + 0.01;
    Sul := La - 0.01;
    Leste := Lo + 0.01;
    Oeste := Lo - 0.01;
    // HUD
    TextoSombra(ARect.Left + 8, ARect.Top + 6,
      Format('ALT %.1f m   VEL %.1f m/s   RUMO %03.0f°   BAT %.0f%%',
        [E.Z, Hypot(E.VX, E.VY), E.Rumo, E.Bateria]));
    TextoSombra(ARect.Left + 8, ARect.Top + 22,
      Format('%s   distância da partida %.0f m', [AD.Fase, E.DistPartida]));
    if E.SinalPerdido then
      TextoSombra(ARect.Left + 8, ARect.Top + 38, 'SEM SINAL COM O COCKPIT');
    if E.Caiu then
    begin
      ACanvas.Font.Size := 18;
      TextoSombra(ARect.Left + (ARect.Right - ARect.Left) div 2 - 60,
        ARect.Top + (ARect.Bottom - ARect.Top) div 2 - 16, 'CAIU');
      ACanvas.Font.Size := 9;
    end;
  end;

  // Crédito do mapa sempre visível, canto inferior direito.
  if not ((Z > 0) and (Norte <> 0)) then
    Z := 16;
  FCredito := FGer.Credito(Norte, Sul, Leste, Oeste, Z);
  Txt := FCredito;
  Qx := ARect.Right - ACanvas.TextWidth(Txt) - 8;
  Qy := ARect.Bottom - ACanvas.TextHeight(Txt) - 4;
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := clWhite;
  ACanvas.FillRect(Qx - 4, Qy - 1, ARect.Right - 2, ARect.Bottom - 2);
  ACanvas.Font.Color := clBlack;
  ACanvas.TextOut(Qx, Qy, Txt);
end;

end.
