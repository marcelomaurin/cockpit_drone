program test_infinite_signal;
{$mode objfpc}{$H+}
uses Classes,SysUtils,SyncObjs,simtipos,simgeo,simfisica,simemulador,simrede;
type
  TSharedState=class
  private FLock:TCriticalSection;FState:TEstadoVoo;
  public
    constructor Create;
    destructor Destroy;override;
    procedure Publish(const E:TEstadoVoo);
    function ReadState:TEstadoVoo;
    function ReadFaults:TFalhas;
  end;
  TSignalEcho=class(TEmulador)
  protected
    function AbreCanais:Boolean;override;
    procedure Processa(C:Integer;const B:TBytes;const Peer:TEndereco);override;
  public
    function MontaComando(const E:TEstadoVoo):TComandoVoo;override;
    function Descricao:string;override;
    function Port:Integer;
  end;
constructor TSharedState.Create;begin FLock:=TCriticalSection.Create;end;
destructor TSharedState.Destroy;begin FLock.Free;inherited Destroy;end;
procedure TSharedState.Publish(const E:TEstadoVoo);begin FLock.Enter;try FState:=E;finally FLock.Leave;end;end;
function TSharedState.ReadState:TEstadoVoo;begin FLock.Enter;try Result:=FState;finally FLock.Leave;end;end;
function TSharedState.ReadFaults:TFalhas;begin Result:=Default(TFalhas);end;
function TSignalEcho.AbreCanais:Boolean;begin Result:=AdicionaCanal(0)>=0;end;
procedure TSignalEcho.Processa(C:Integer;const B:TBytes;const Peer:TEndereco);
begin if Length(B)>0 then Envia(C,B[0],Length(B),Peer.IP,Peer.Porta);end;
function TSignalEcho.MontaComando(const E:TEstadoVoo):TComandoVoo;begin Result:=ComandoNeutro;end;
function TSignalEcho.Descricao:string;begin Result:='Signal loopback';end;
function TSignalEcho.Port:Integer;begin Result:=Canal(0).PortaLocal;end;
procedure Check(B:Boolean;const M:string);begin if not B then raise Exception.Create(M);end;
var Models:TListaModelos;P:TParametrosModelo;Origin:TPontoGeo;F:TFalhas;C:TComandoVoo;
 Physics:TSimFisica;State:TSharedState;Echo:TSignalEcho;Client:TSimUDP;ErrorText:string;
 I,J:Integer;Sent,Received:Byte;Peer:TEndereco;
procedure CheckEcho(Expected:Boolean;Value:Byte);
var N:Integer;
begin
 Sent:=Value;Check(Client.Envia(Sent,1,'127.0.0.1',Echo.Port),'send failed');
 N:=Client.Recebe(Received,1,200,Peer);
 if Expected then Check((N=1) and (Received=Sent),'infinite signal must allow both UDP directions')
 else Check(N=0,'normal simulated signal loss must block UDP');
end;
begin
 Models:=ModelosPadrao;Origin:=Default(TPontoGeo);F:=Default(TFalhas);
 Check(Models[IndiceModelo(Models,'cx10w')].AlcanceRadioM=30,'Cheerson range must stay 30 m');
 for J:=0 to High(Models) do begin
   P:=Models[J];Physics:=TSimFisica.Create(P,Origin);
   try
     C:=ComandoNeutro;C.Motores:=True;C.ModoV:=mvAltura;C.Vertical:=3;
     C.ModoH:=mhVelocidade;C.Arfagem:=1;
     for I:=1 to Round((P.AlcanceRadioM*1.5/P.VelMaxMS+12)*50) do Physics.Passo(0.02,C,F);
     Check(Physics.Estado.DistPartida>P.AlcanceRadioM,'must exceed range: '+P.Chave);
     Check(Physics.Estado.SinalPerdido,'normal model range: '+P.Chave);
     F.SinalInfinito:=True;Physics.Passo(0.02,C,F);
     Check(not Physics.Estado.SinalPerdido,'infinite overrides distance: '+P.Chave);
     F.PerdaSinal:=True;Physics.Passo(0.02,C,F);
     Check(not Physics.Estado.SinalPerdido,'infinite overrides injected loss: '+P.Chave);
     F:=Default(TFalhas);
   finally Physics.Free;end;
 end;
 WriteLn('PASS infinite signal on all ',Length(Models),' models; Cheerson normal range stays 30 m');
 P:=Models[IndiceModelo(Models,'cx10w')];Physics:=TSimFisica.Create(P,Origin);
 State:=TSharedState.Create;Echo:=nil;Client:=TSimUDP.Create;
 try
   C:=ComandoNeutro;C.Motores:=True;C.ModoV:=mvAltura;C.Vertical:=3;
   C.ModoH:=mhVelocidade;C.Arfagem:=1;
   for I:=1 to 6000 do Physics.Passo(0.02,C,F);
   Check(Physics.Estado.DistPartida>300,'must travel well beyond normal range');
   Check(Physics.Estado.SinalPerdido,'normal 30 m range must lose signal');
   State.Publish(Physics.Estado);
   Echo:=TSignalEcho.Create(P,Origin,@State.ReadState,@State.ReadFaults);
   Check(Echo.Iniciar(ErrorText),ErrorText);Check(Client.Abre(0),'client UDP');CheckEcho(False,1);
   F.SinalInfinito:=True;Physics.Passo(0.02,C,F);State.Publish(Physics.Estado);
   Check(not Physics.Estado.SinalPerdido,'enable infinite during flight');CheckEcho(True,2);
   F.PerdaSinal:=True;Physics.Passo(0.02,C,F);State.Publish(Physics.Estado);CheckEcho(True,3);
   F.SinalInfinito:=False;Physics.Passo(0.02,C,F);State.Publish(Physics.Estado);CheckEcho(False,4);
   F:=Default(TFalhas);Physics.Reinicia(Origin);C.Arfagem:=0;C.ModoV:=mvSubida;C.Vertical:=1;
   for I:=1 to 3000 do Physics.Passo(0.02,C,F);
   Check((Physics.Estado.Z>30) and Physics.Estado.SinalPerdido,'vertical range must count normally');
   F.SinalInfinito:=True;Physics.Passo(0.02,C,F);State.Publish(Physics.Estado);CheckEcho(True,5);
   WriteLn('PASS normal range, altitude, in-flight toggle and actual UDP receive/transmit beyond range');
 finally Echo.Free;Client.Free;State.Free;Physics.Free;end;
end.
