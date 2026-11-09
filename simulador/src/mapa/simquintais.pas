unit simquintais;
{ Lotes residenciais de treinamento para a vigilancia do Aedes aegypti.

  Cada casa procedural ganha um lote com muro, frente para a rua, garagem
  lateral e quintal nos fundos. Parte dos quintais recebe recipientes com agua
  parada (criadouros) e parte recebe os mesmos objetos em situacao segura
  (piscina tratada, caixa tampada, balde emborcado...), para que o aluno
  aprenda a diferenciar. A escolha e deterministica pelo identificador do lote:
  o mesmo bairro sempre mostra os mesmos quintais, e o instrutor pode conferir
  pelo gabarito.

  Medidas de referencia (metros): lote 13 x 20, casa 8 x 9,5 com pe-direito
  de ~3 m e telhado de quatro aguas, muro de 1,8 m, piscina residencial
  5 x 2,8, caixa d'agua de 1000 L (1,4 m de diametro), pneu de aro 14
  (0,6 m), vaso de 0,35 m. }
{$mode objfpc}{$H+}
interface
uses SysUtils,Classes,Math,simgeo,simedificios;
const
  LOTE_LARGURA=13.0;
  LOTE_PROFUNDIDADE=20.0;
{ Monta casa e lote. (CX,CY) e o centro do lote; (FX,FY) e o vetor unitario
  que aponta do fundo para a rua. }
procedure MontaLote(const Id:string;CX,CY,FX,FY:Double;const Origem:TPontoGeo;
  out Casa:TEdificio;out Lote:TLote);
{ Retangulo do lote como TEdificio, com limites calculados, para testes de
  sobreposicao com ruas, terrenos e outras construcoes. }
function FormaLote(CX,CY,FX,FY:Double):TEdificio;
function HashTexto(const S:string):LongWord;
function DescricaoObjeto(const O:TObjetoQuintal):string;
function ResumoLote(const L:TLote):string;
procedure ContaLotes(const Cena:TCenaEdificios;out Lotes,ComCriadouro,Itens:Integer);
procedure SalvaGabarito(const Cena:TCenaEdificios;const Arquivo:string);
implementation
{$PUSH}{$Q-}{$R-}
function HashTexto(const S:string):LongWord;
var I:Integer;
begin
  Result:=2166136261;
  for I:=1 to Length(S) do Result:=(Result xor Ord(S[I]))*16777619;
  if Result=0 then Result:=1;
end;
{$POP}
procedure Limites(var E:TEdificio);
var N:Integer;
begin
  E.MinX:=E.Contorno[0].X;E.MaxX:=E.MinX;E.MinY:=E.Contorno[0].Y;E.MaxY:=E.MinY;
  for N:=1 to High(E.Contorno) do begin
    E.MinX:=Min(E.MinX,E.Contorno[N].X);E.MaxX:=Max(E.MaxX,E.Contorno[N].X);
    E.MinY:=Min(E.MinY,E.Contorno[N].Y);E.MaxY:=Max(E.MaxY,E.Contorno[N].Y);
  end;
end;
function FormaLote(CX,CY,FX,FY:Double):TEdificio;
const HS=LOTE_LARGURA/2;HF=LOTE_PROFUNDIDADE/2;
var SX,SY:Double;
begin
  Result:=Default(TEdificio);SX:=FY;SY:=-FX;SetLength(Result.Contorno,4);
  Result.Contorno[0].X:=CX-HS*SX-HF*FX;Result.Contorno[0].Y:=CY-HS*SY-HF*FY;
  Result.Contorno[1].X:=CX+HS*SX-HF*FX;Result.Contorno[1].Y:=CY+HS*SY-HF*FY;
  Result.Contorno[2].X:=CX+HS*SX+HF*FX;Result.Contorno[2].Y:=CY+HS*SY+HF*FY;
  Result.Contorno[3].X:=CX-HS*SX+HF*FX;Result.Contorno[3].Y:=CY-HS*SY+HF*FY;
  Limites(Result);
end;
procedure MontaLote(const Id:string;CX,CY,FX,FY:Double;const Origem:TPontoGeo;
  out Casa:TEdificio;out Lote:TLote);
const
  Paredes:array[0..5] of LongWord=($E8DCC2,$D9C7A0,$C9D3C0,$E6C9A8,$D7D9DC,$CDB894);
  Telhas:array[0..2] of LongWord=($A65A3E,$8E4B35,$B0694A);
var Semente:LongWord;SX,SY,Ang:Double;Piscina:Boolean;I,N:Integer;
  {$PUSH}{$Q-}{$R-}
  function Rnd:LongWord;
  begin
    Semente:=Semente xor (Semente shl 13);Semente:=Semente xor (Semente shr 17);
    Semente:=Semente xor (Semente shl 5);Result:=Semente;
  end;
  {$POP}
  function Chance(P:Double):Boolean;begin Result:=(Rnd mod 1000)<Round(P*1000);end;
  function Ponto(S,F:Double):TPontoEdificio;
  begin Result.X:=CX+S*SX+F*FX;Result.Y:=CY+S*SY+F*FY;end;
  procedure Piso(S0,F0,S1,F1:Double;Cor:LongWord);
  var P:TPisoLote;
  begin
    P.Canto[0]:=Ponto(S0,F0);P.Canto[1]:=Ponto(S1,F0);P.Canto[2]:=Ponto(S1,F1);P.Canto[3]:=Ponto(S0,F1);
    P.Cor:=Cor;SetLength(Lote.Pisos,Length(Lote.Pisos)+1);Lote.Pisos[High(Lote.Pisos)]:=P;
  end;
  procedure Objeto(T:TTipoObjetoQuintal;S,F,Z,Larg,Comp,Alt:Double;Risco:Boolean;Cor:LongWord);
  var O:TObjetoQuintal;P:TPontoEdificio;
  begin
    P:=Ponto(S,F);O:=Default(TObjetoQuintal);O.Tipo:=T;O.X:=P.X;O.Y:=P.Y;O.Z:=Z;O.Angulo:=Ang;
    O.Largura:=Larg;O.Comprimento:=Comp;O.Altura:=Alt;O.Criadouro:=Risco;O.Cor:=Cor;
    SetLength(Lote.Objetos,Length(Lote.Objetos)+1);Lote.Objetos[High(Lote.Objetos)]:=O;
    if Risco then Inc(Lote.Criadouros);
  end;
  procedure Vasos;
  var K,Qtd:Integer;Risco,Frente:Boolean;F,S:Double;
  begin
    Qtd:=3+Integer(Rnd mod 4);Risco:=Chance(0.30);Frente:=Chance(0.5);
    for K:=0 to Qtd-1 do begin
      if Frente then begin S:=-5.6+K*0.9;F:=8.9;end else begin S:=-5.5;F:=-9.0+K*0.85;end;
      Objeto(oqVaso,S,F,0,0.36,0.36,0.34,Risco and (K mod 2=0),$B5653A);
    end;
  end;
  procedure Pneus;
  var K,Qtd:Integer;
  begin
    Qtd:=2+Integer(Rnd mod 3);
    for K:=0 to Qtd-1 do
      Objeto(oqPneu,4.3+0.15*(K mod 2)-0.65*(K div 2),-4.4-0.7*(K mod 2),0,0.62,0.62,0.2,True,$1E1E1E);
  end;
  procedure Baldes;
  const Cores:array[0..3] of LongWord=($C0392B,$E1B12C,$2E6DB4,$3A9D5D);
  var K,Qtd:Integer;Risco:Boolean;
  begin
    Qtd:=2+Integer(Rnd mod 2);Risco:=Chance(0.40);
    for K:=0 to Qtd-1 do
      Objeto(oqBalde,1.4+K*0.6,-8.8,0,0.3,0.3,0.32,Risco,Cores[Rnd mod 4]);
  end;
begin
  Casa:=Default(TEdificio);Lote:=Default(TLote);
  Semente:=HashTexto(Id);SX:=FY;SY:=-FX;Ang:=ArcTan2(FY,FX);
  // Casa: 8 m de frente por 9,5 m, recuo frontal de 3,5 m; garagem lateral.
  Casa.Id:=Id;Casa.Tipo:='house';Casa.Procedural:=True;Casa.Estimada:=True;
  SetLength(Casa.Contorno,4);
  Casa.Contorno[0]:=Ponto(-6,-3);Casa.Contorno[1]:=Ponto(2,-3);
  Casa.Contorno[2]:=Ponto(2,6.5);Casa.Contorno[3]:=Ponto(-6,6.5);
  Limites(Casa);
  Casa.Altura:=ALTURA_TERREA;if Chance(0.12) then Casa.Altura:=ALTURA_SOBRADO;
  Casa.Cumeeira:=CUMEEIRA_CASA;
  Casa.Parede:=Paredes[Rnd mod 6];Casa.Telhado:=Telhas[Rnd mod 3];
  if not GerarCriadouros then Exit;
  // Lote, muro e pisos.
  Lote.Id:=Id;LocalParaGeo(Origem,CX,CY,Lote.Lat,Lote.Lon);
  Lote.Canto[0]:=Ponto(-6.5,-10);Lote.Canto[1]:=Ponto(6.5,-10);
  Lote.Canto[2]:=Ponto(6.5,10);Lote.Canto[3]:=Ponto(-6.5,10);
  Lote.MuroAltura:=1.8;Lote.PortaoInicio:=0.0;Lote.PortaoFim:=4.5/LOTE_LARGURA;
  Lote.MinX:=Min(Min(Lote.Canto[0].X,Lote.Canto[1].X),Min(Lote.Canto[2].X,Lote.Canto[3].X));
  Lote.MaxX:=Max(Max(Lote.Canto[0].X,Lote.Canto[1].X),Max(Lote.Canto[2].X,Lote.Canto[3].X));
  Lote.MinY:=Min(Min(Lote.Canto[0].Y,Lote.Canto[1].Y),Min(Lote.Canto[2].Y,Lote.Canto[3].Y));
  Lote.MaxY:=Max(Max(Lote.Canto[0].Y,Lote.Canto[1].Y),Max(Lote.Canto[2].Y,Lote.Canto[3].Y));
  if Chance(0.5) then Piso(-6.5,-10,6.5,-3,$6F8F4E) else Piso(-6.5,-10,6.5,-3,$B4AFA4);
  Piso(2,-3,6.5,10,$A9A59C);
  Piso(-6.5,6.5,2,10,$7A9A52);
  // Objetos do quintal.
  Piscina:=Chance(0.16);
  if Piscina then
    Objeto(oqPiscina,-2.3,-6.6,0,5.0,2.8,0,Chance(0.35),0)
  else if Chance(0.12) then
    Objeto(oqTanquePeixe,-4.2,-7.9,0,1.6,2.4,0.7,Chance(0.5),$9A968C);
  if Chance(0.30) then Objeto(oqCaixaDagua,4.9,-8.6,0,1.4,1.4,0.95,Chance(0.30),$2E6EB5);
  if Chance(0.50) then Vasos;
  if Chance(0.08) then Pneus;
  if Chance(0.30) then Baldes;
  N:=0;for I:=0 to High(Lote.Objetos) do if Lote.Objetos[I].Criadouro then Inc(N);
  Lote.Criadouros:=N;
end;
function DescricaoObjeto(const O:TObjetoQuintal):string;
begin
  case O.Tipo of
    oqVaso:if O.Criadouro then Result:='vaso com prato com agua' else Result:='vaso sem prato';
    oqPiscina:if O.Criadouro then Result:='piscina sem tratamento (agua verde)' else Result:='piscina tratada';
    oqCaixaDagua:if O.Criadouro then Result:='caixa d''agua destampada' else Result:='caixa d''agua tampada';
    oqPneu:Result:='pneu exposto com agua';
    oqTanquePeixe:if O.Criadouro then Result:='tanque de peixes abandonado (agua verde, sem peixes)' else Result:='tanque de peixes com peixes';
    oqBalde:if O.Criadouro then Result:='balde destampado com agua' else Result:='balde emborcado';
  else Result:='objeto';
  end;
end;
function ResumoLote(const L:TLote):string;
var Nomes:TStringList;I:Integer;
begin
  Nomes:=TStringList.Create;
  try
    Nomes.Sorted:=True;Nomes.Duplicates:=dupAccept;
    for I:=0 to High(L.Objetos) do Nomes.Add(DescricaoObjeto(L.Objetos[I]));
    Result:='';I:=0;
    while I<Nomes.Count do begin
      if Result<>'' then Result:=Result+', ';
      if (I+1<Nomes.Count) and (Nomes[I+1]=Nomes[I]) then begin
        Result:=Result+Nomes[I];
        while (I+1<Nomes.Count) and (Nomes[I+1]=Nomes[I]) do Inc(I);
        Result:=Result+' (varios)';
      end else Result:=Result+Nomes[I];
      Inc(I);
    end;
    if Result='' then Result:='quintal sem recipientes';
  finally Nomes.Free;end;
end;
procedure ContaLotes(const Cena:TCenaEdificios;out Lotes,ComCriadouro,Itens:Integer);
var I:Integer;
begin
  Lotes:=Length(Cena.Lotes);ComCriadouro:=0;Itens:=0;
  for I:=0 to High(Cena.Lotes) do if Cena.Lotes[I].Criadouros>0 then begin
    Inc(ComCriadouro);Inc(Itens,Cena.Lotes[I].Criadouros);end;
end;
procedure SalvaGabarito(const Cena:TCenaEdificios;const Arquivo:string);
var SL:TStringList;I:Integer;FS:TFormatSettings;L:TLote;Situacao:string;
begin
  FS:=DefaultFormatSettings;FS.DecimalSeparator:='.';
  SL:=TStringList.Create;
  try
    SL.Add('lote;latitude;longitude;situacao;itens_com_agua_parada;quintal');
    for I:=0 to High(Cena.Lotes) do begin
      L:=Cena.Lotes[I];
      if L.Criadouros>0 then Situacao:='COM CRIADOURO' else Situacao:='sem criadouro';
      SL.Add(Format('%s;%.6f;%.6f;%s;%d;%s',[L.Id,L.Lat,L.Lon,Situacao,L.Criadouros,ResumoLote(L)],FS));
    end;
    SL.SaveToFile(Arquivo);
  finally SL.Free;end;
end;
end.
