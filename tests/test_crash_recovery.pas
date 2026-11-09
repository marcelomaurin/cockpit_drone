program test_crash_recovery;
{$mode objfpc}{$H+}
uses Classes,SysUtils,simtipos,simgeo,simemulador,simsimulacao,simrede;
type
  TFakeEmulator=class(TEmulador)
  private FCommand:TComandoVoo;
  protected
    function AbreCanais:Boolean;override;
    procedure Processa(ACanal:Integer;const Buf:TBytes;const De:simrede.TEndereco);override;
  public
    procedure SetThrottle(Value:Double);
    procedure ReiniciaEstado;override;
    function MontaComando(const E:TEstadoVoo):TComandoVoo;override;
    function Descricao:string;override;
  end;
  TTestSimulation=class(TSimulacao)
  protected function CriaEmulador(const P:TParametrosModelo;const O:TPontoGeo):TEmulador;override;
  end;
procedure Check(Ok:Boolean;const Msg:string);
begin if not Ok then raise Exception.Create(Msg);end;
function TFakeEmulator.AbreCanais:Boolean;begin Result:=True;end;
procedure TFakeEmulator.Processa(ACanal:Integer;const Buf:TBytes;const De:simrede.TEndereco);begin end;
procedure TFakeEmulator.SetThrottle(Value:Double);
begin FLock.Enter;try FCommand:=ComandoNeutro;FCommand.ModoV:=mvEmpuxo;
 FCommand.Motores:=Value>0;FCommand.Vertical:=Value;finally FLock.Leave;end;end;
procedure TFakeEmulator.ReiniciaEstado;
begin inherited ReiniciaEstado;SetThrottle(0);end;
function TFakeEmulator.MontaComando(const E:TEstadoVoo):TComandoVoo;
begin FLock.Enter;try if E.Caiu then ComandoDaFase(E,Result) else Result:=FCommand;
 finally FLock.Leave;end;end;
function TFakeEmulator.Descricao:string;begin Result:='Test protocol, no sockets';end;
function TTestSimulation.CriaEmulador(const P:TParametrosModelo;const O:TPontoGeo):TEmulador;
begin Result:=TFakeEmulator.Create(P,O,@LeEstado,@LeFalhas);end;
var S:TTestSimulation; E:TFakeEmulator; Models:TListaModelos;O:TPontoGeo;M:TOpcoesMavlink;
 ErrorText:string;Deadline:QWord;Cycle:Integer;
begin
 S:=TTestSimulation.Create;Models:=ModelosPadrao;O:=Default(TPontoGeo);M:=Default(TOpcoesMavlink);
 try Check(S.Liga(Models[3],O,M,ErrorText),'simulation failed: '+ErrorText);E:=TFakeEmulator(S.Emulador);
   for Cycle:=1 to 3 do begin
     E.SetThrottle(1);Sleep(500);Check(S.LeEstado.Z>0.3,'must take off');
     E.SetThrottle(0);Deadline:=GetTickCount64+4000;
     while not S.LeEstado.Caiu and (GetTickCount64<Deadline) do Sleep(10);
     Check(S.LeEstado.Caiu,'must reproduce crash');Deadline:=GetTickCount64+3000;
     while S.LeEstado.Caiu and (GetTickCount64<Deadline) do Sleep(10);
     Check(not S.LeEstado.Caiu,'crash lock must clear automatically');
     Check(S.Emulador=E,'recovery must retain protocol connection');
     Check(S.LeEstado.NoChao,'recovered drone must be on ground');
     WriteLn('PASS crash/recovery cycle ',Cycle);
   end;
   E.SetThrottle(1);Sleep(250);S.Pausado:=True;S.Reinicia;Sleep(100);
   Check(not S.Pausado,'restart must clear pause');Check(S.Emulador=E,'restart must keep sockets');
   Check((S.LeEstado.Z=0) and not S.LeEstado.Caiu,'restart must restore flyable state');
   E.SetThrottle(1);Sleep(400);Check(S.LeEstado.Z>0.2,'must fly after restart');
   WriteLn('PASS repeated recovery, pause reset, connection preservation and new flight');
 finally S.Free;end;
end.
