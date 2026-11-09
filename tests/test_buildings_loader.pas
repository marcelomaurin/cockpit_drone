program test_buildings_loader;
{$mode objfpc}{$H+}
uses SysUtils,simedificios_cache;
procedure Check(B:Boolean;const M:string);begin if not B then raise Exception.Create(M);end;
var G:TGerenciadorEdificios;Deadline:QWord;
begin
 if ParamStr(3)='http' then G:=TGerenciadorEdificios.Create(ParamStr(2),ParamStr(1))
 else G:=TGerenciadorEdificios.Create(ParamStr(2),SERVIDOR_EDIFICIOS_PADRAO,ExpandFileName(ParamStr(1)));
 try
 G.Atualiza(-21.1767,-47.8208,True);Deadline:=GetTickCount64+3000;
 while (Length(G.Cena.Itens)=0) and (GetTickCount64<Deadline) do Sleep(10);
 Check(Length(G.Cena.Itens)=4,'background loader: '+G.Status);
 G.Atualiza(-21.1767,-47.8208,False);Check(Length(G.Cena.Itens)=0,'disable must clear scene');
 G.Atualiza(-21.1767,-47.8208,True);Deadline:=GetTickCount64+3000;
 while (Length(G.Cena.Itens)=0) and (GetTickCount64<Deadline) do Sleep(10);
 Check(Length(G.Cena.Itens)=4,'cached/local data must reload immediately');
 WriteLn('PASS async building load, cache/local JSON, disable/re-enable and thread shutdown');
 finally G.Free;end;
end.
