program sim_console;

{ Simulador sem janela, para testes automáticos dos emuladores.
  Uso: sim_console <modelo> <segundos>
  Imprime o estado a cada 0,5 s: fase;z;x;y;rumo;bateria;motores;caiu }

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, simtipos, simgeo, simsimulacao, simemulador;

var
  Sim: TSimulacao;
  Modelos: TListaModelos;
  I, Seg: Integer;
  O: TPontoGeo;
  M: TOpcoesMavlink;
  Erro, Msg: string;
  E: TEstadoVoo;
  Fim: QWord;
begin
  DefaultSystemCodePage := CP_UTF8;
  Modelos := ModelosPadrao;
  I := IndiceModelo(Modelos, ParamStr(1));
  if I < 0 then
  begin
    WriteLn('modelo desconhecido');
    Halt(2);
  end;
  Seg := StrToIntDef(ParamStr(2), 10);
  O.Lat := -21.1767;
  O.Lon := -47.8208;
  M.IPCockpit := '127.0.0.1';
  M.PortaCockpit := 14550;
  M.PortaLocal := 14551;
  Sim := TSimulacao.Create;
  try
    if not Sim.Liga(Modelos[I], O, M, Erro) then
    begin
      WriteLn('ERRO ', Erro);
      Halt(1);
    end;
    WriteLn('LIGADO ', Sim.Emulador.Descricao);
    Flush(Output);
    Fim := GetTickCount64 + QWord(Seg) * 1000;
    while GetTickCount64 < Fim do
    begin
      Sleep(500);
      while Sim.Emulador.ProximaMensagem(Msg) do
        WriteLn('LOG ', Msg);
      E := Sim.LeEstado;
      WriteLn(Format('ESTADO %s;z=%.2f;x=%.2f;y=%.2f;rumo=%.0f;bat=%.1f;mot=%s;caiu=%s;rx=%d;tx=%d',
        [Sim.Emulador.FaseTexto, E.Z, E.X, E.Y, E.Rumo, E.Bateria,
         BoolToStr(E.Motores, True), BoolToStr(E.Caiu, True),
         Sim.Emulador.PacotesRx, Sim.Emulador.PacotesTx]));
      Flush(Output);
    end;
    Sim.Desliga;
  finally
    Sim.Free;
  end;
end.
