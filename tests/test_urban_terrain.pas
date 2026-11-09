program test_urban_terrain;
{$mode objfpc}{$H+}
uses SysUtils,Classes,Math,fpjson,jsonparser,simgeo,simedificios,simurbanismo;
procedure Check(B:Boolean;const M:string);begin if not B then raise Exception.Create(M);end;
var Text:TStringList;S,T:TCenaEdificios;O,O2:TPontoGeo;I,J,K,N,Houses,Apartments:Integer;
 E:TEdificio;X,Y,Lat,Lon,Lat2,Lon2:Double;Root:TJSONObject;Elements:TJSONArray;
 Road:TViasTerreno;SL:TStringList;
begin
 O.Lat:=-21.1767;O.Lon:=-47.8208;Text:=TStringList.Create;
 try
 Text.LoadFromFile(ParamStr(1));S:=LeCenaOSM(Text.Text,O);Check(Length(S.Itens)=1,'mapped building');
 GeraConstrucoesNosTerrenos(Text.Text,O,S);Check(Length(S.Itens)>20,'must populate empty residential land');
 Houses:=0;Apartments:=0;
 for I:=0 to High(S.Itens) do begin E:=S.Itens[I];if not E.Procedural then Continue;
  if E.Tipo='house' then Inc(Houses) else if E.Tipo='apartments' then Inc(Apartments);
  Check((E.MinX>=-180) and (E.MaxX<=180) and (E.MinY>=-80) and (E.MaxY<=300),'outside residential boundary');
  Check(not ((E.MaxX>=-8) and (E.MinX<=8)),'north/south street and sidewalk invaded');
  Check(not ((E.MaxY>=112) and (E.MinY<=128)),'east/west street and sidewalk invaded');
  for J:=0 to High(E.Contorno) do begin X:=E.Contorno[J].X;Y:=E.Contorno[J].Y;
   Check(not ((X>=-140) and (X<=-90) and (Y>=180) and (Y<=230)),'courtyard invaded');
   Check(Abs(340*(X+180)-170*(Y+40))/Hypot(340,170)>6,'diagonal road setback invaded');
  end;
  Check((E.MaxX<50) or (E.MinX>150) or (E.MaxY<180) or (E.MinY>260),'park invaded');
  for J:=0 to I-1 do Check((E.MaxX+1.99<S.Itens[J].MinX) or (E.MinX-1.99>S.Itens[J].MaxX) or
   (E.MaxY+1.99<S.Itens[J].MinY) or (E.MinY-1.99>S.Itens[J].MaxY),'building overlap');
 end;
 Check((Houses>0) and (Apartments>0),'both houses and apartment buildings expected');
 // Verify world anchoring while the scene origin changes.
 O2:=O;O2.Lat:=O2.Lat+0.0005;O2.Lon:=O2.Lon+0.0005;
 T:=LeCenaOSM(Text.Text,O2);GeraConstrucoesNosTerrenos(Text.Text,O2,T);N:=0;
 for I:=0 to High(S.Itens) do if S.Itens[I].Procedural then
  for J:=0 to High(T.Itens) do if T.Itens[J].Id=S.Itens[I].Id then begin
   LocalParaGeo(O,(S.Itens[I].MinX+S.Itens[I].MaxX)/2,(S.Itens[I].MinY+S.Itens[I].MaxY)/2,Lat,Lon);
   LocalParaGeo(O2,(T.Itens[J].MinX+T.Itens[J].MaxX)/2,(T.Itens[J].MinY+T.Itens[J].MaxY)/2,Lat2,Lon2);
   Check((Abs(Lat-Lat2)<1e-8) and (Abs(Lon-Lon2)<1e-8),'unstable building positions');Inc(N);Break;
  end;
 Check(N>10,'stable scene overlap');
 Root:=TJSONObject(GetJSON(Text.Text));
 try
 Elements:=TJSONArray(Root.Find('elements'));
 for I:=Elements.Count-1 downto 0 do if ((TJSONObject(Elements[I]).Get('id',Int64(0))>=900) and (TJSONObject(Elements[I]).Get('id',Int64(0))<=902)) then Elements.Delete(I);
 T:=LeCenaOSM(Root.AsJSON,O);GeraConstrucoesNosTerrenos(Root.AsJSON,O,T);
 Check(Length(T.Itens)=1,'without roads keep mapped buildings only');
 finally Root.Free;end;
 // A road crossing a complete footprint must fail even with endpoints outside.
 E:=Default(TEdificio);SetLength(E.Contorno,4);E.MinX:=-2;E.MaxX:=2;E.MinY:=10;E.MaxY:=20;
 E.Contorno[0].X:=-2;E.Contorno[0].Y:=10;E.Contorno[1].X:=2;E.Contorno[1].Y:=10;
 E.Contorno[2].X:=2;E.Contorno[2].Y:=20;E.Contorno[3].X:=-2;E.Contorno[3].Y:=20;
 SetLength(Road,1);SetLength(Road[0].Pontos,2);Road[0].RaioLivre:=1;
 Road[0].Pontos[0].X:=-100;Road[0].Pontos[0].Y:=15;Road[0].Pontos[1].X:=100;Road[0].Pontos[1].Y:=15;
 Check(not RuaLivre(E,Road),'crossing road must block construction');
 WriteLn('PASS ',Houses,' houses + ',Apartments,' apartments on land; streets, sidewalks, courtyard, park, mapped footprints and world anchoring');
 finally Text.Free;end;
end.
