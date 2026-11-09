unit simrastercache;
{$mode objfpc}{$H+}
interface
uses Classes,SysUtils,Math,SyncObjs,simgeo,simmapa,simedificios,simrasterterrain;
type
 TGerenciadorRaster=class;
 TLinhaRaster=class(TThread)
 private FOwner:TGerenciadorRaster;
 protected procedure Execute;override;
 public constructor Create(Owner:TGerenciadorRaster);
 end;
 TGerenciadorRaster=class
 private FLock:TCriticalSection;FEvent:TEvent;FThread:TLinhaRaster;FMap:TGerenciadorBlocos;
  FKey,FStatus:string;FTx,FTy:Integer;FActive,FPending,FCompletar:Boolean;FOrigin:TPontoGeo;FScene:TCenaEdificios;
 public
  constructor Create(Map:TGerenciadorBlocos;Completar:Boolean=True);
  destructor Destroy;override;
  procedure Atualiza(Lat,Lon:Double;Ativo:Boolean);
  function Cena:TCenaEdificios;
  function Status:string;
 end;
implementation
constructor TLinhaRaster.Create(Owner:TGerenciadorRaster);
begin inherited Create(True);FOwner:=Owner;FreeOnTerminate:=False;Start;end;
constructor TGerenciadorRaster.Create(Map:TGerenciadorBlocos;Completar:Boolean);
begin inherited Create;FMap:=Map;FCompletar:=Completar;FLock:=TCriticalSection.Create;
 FEvent:=TEvent.Create(nil,False,False,'');FStatus:='Construcoes: aguardando mapa';FThread:=TLinhaRaster.Create(Self);end;
destructor TGerenciadorRaster.Destroy;
begin FThread.Terminate;FEvent.SetEvent;FThread.WaitFor;FThread.Free;FEvent.Free;FLock.Free;inherited Destroy;end;
procedure TGerenciadorRaster.Atualiza(Lat,Lon:Double;Ativo:Boolean);
var X,Y:Double;Tx,Ty:Integer;Key:string;
begin
 if IsNan(Lat) or IsNan(Lon) or (Abs(Lat)>85) or (Abs(Lon)>180) then Exit;
 GeoParaPixel(Lat,Lon,17,X,Y);Tx:=Floor(X/256);Ty:=Floor(Y/256);Key:=IntToStr(Tx)+'/'+IntToStr(Ty);
 FLock.Enter;
 try
  FActive:=Ativo;
  if not Ativo then begin FPending:=False;FKey:='';FScene:=Default(TCenaEdificios);FStatus:='Construcoes desligadas';Exit;end;
  if FKey=Key then Exit;
  FKey:=Key;FTx:=Tx;FTy:=Ty;FOrigin.Lat:=Lat;FOrigin.Lon:=Lon;FPending:=True;
 finally FLock.Leave;end;
 FEvent.SetEvent;
end;
function TGerenciadorRaster.Cena:TCenaEdificios;
begin FLock.Enter;try Result:=FScene;finally FLock.Leave;end;end;
function TGerenciadorRaster.Status:string;
begin FLock.Enter;try Result:=FStatus;finally FLock.Leave;end;end;
procedure TLinhaRaster.Execute;
var Tx,Ty,DX,DY,Y,Ready,I:Integer;Key:string;Origin:TPontoGeo;Pixels:TRasterPixels;
 Blocks:array[0..8]of TBloco;Scene:TCenaEdificios;DoWork:Boolean;
begin
 while not Terminated do begin
  FOwner.FEvent.WaitFor(500);if Terminated then Break;
  FOwner.FLock.Enter;
  try DoWork:=FOwner.FPending and FOwner.FActive;Tx:=FOwner.FTx;Ty:=FOwner.FTy;Key:=FOwner.FKey;Origin:=FOwner.FOrigin;
  finally FOwner.FLock.Leave;end;
  if not DoWork then Continue;
  try
   Ready:=0;I:=0;
   for DY:=-1 to 1 do for DX:=-1 to 1 do begin
    Blocks[I]:=FOwner.FMap.Obtem(17,Tx+DX,Ty+DY,True,0);
    if Assigned(Blocks[I]) and Blocks[I].Pronto and (Length(Blocks[I].Pixels)=256*256) then Inc(Ready);
    Inc(I);
   end;
   if Ready<9 then begin
    FOwner.FLock.Enter;try if FOwner.FKey=Key then FOwner.FStatus:=Format('Construcoes: carregando mapa %d/9 blocos',[Ready]);finally FOwner.FLock.Leave;end;Continue;
   end;
   SetLength(Pixels,768*768);I:=0;
   for DY:=0 to 2 do for DX:=0 to 2 do begin
    for Y:=0 to 255 do Move(Blocks[I].Pixels[Y*256],Pixels[(DY*256+Y)*768+DX*256],256*4);Inc(I);
   end;
   Scene:=CenaDoMapaRaster(Pixels,768,768,17,Tx-1,Ty-1,Origin,FOwner.FCompletar);
   FOwner.FLock.Enter;
   try if FOwner.FActive and (FOwner.FKey=Key) then begin
    FOwner.FScene:=Scene;FOwner.FPending:=False;
    FOwner.FStatus:=Format('Construcoes no mapa: %d (alturas simuladas)',[Length(Scene.Itens)]);
   end;finally FOwner.FLock.Leave;end;
  except on E:Exception do begin FOwner.FLock.Enter;
   try if FOwner.FKey=Key then begin FOwner.FStatus:='Construcoes: '+E.Message;FOwner.FPending:=False;end;
   finally FOwner.FLock.Leave;end;end;end;
 end;
end;
end.
