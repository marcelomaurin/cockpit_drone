program mundo_console;

{ Dois clientes do mundo compartilhado (o mesmo código do simulador):
  A no ponto inicial e B a 1.990 m ao norte. A manda uma mensagem; B deve
  ver A como vizinho e receber a mensagem.
  Uso: mundo_console <url do api.php> }

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, simtipos, simgeo, simmundo;

type
  TFonte = class
    E: TEstadoVoo;
    function Le: TEstadoVoo;
  end;

function TFonte.Le: TEstadoVoo;
begin
  Result := E;
end;

var
  FA, FB: TFonte;
  A, B: TClienteMundo;
  V: TVizinhos;
  S: string;
  I: Integer;
  Recebeu: Boolean;
begin
  DefaultSystemCodePage := CP_UTF8;
  FA := TFonte.Create;
  FB := TFonte.Create;
  FA.E.Lat := -21.1767; FA.E.Lon := -47.8208; FA.E.Z := 12; FA.E.Bateria := 90;
  FB.E := FA.E;
  FB.E.Lat := FA.E.Lat + 1990 / METROS_POR_GRAU_LAT;
  A := TClienteMundo.Create(ParamStr(1), 'Ana', 'tello', @FA.Le);
  B := TClienteMundo.Create(ParamStr(1), 'Bruno', 'ardrone', @FB.Le);
  Sleep(2500);
  A.EnviaMensagem('Olá do Tello!');
  Recebeu := False;
  for I := 1 to 20 do
  begin
    Sleep(250);
    while B.ProximaMensagem(S) do
    begin
      WriteLn('B: ', S);
      if Pos('Olá do Tello!', S) > 0 then
        Recebeu := True;
    end;
    while A.ProximaMensagem(S) do
      WriteLn('A: ', S);
  end;
  V := B.Vizinhos;
  WriteLn('B ve ', Length(V), ' vizinho(s)');
  if Length(V) > 0 then
    WriteLn(Format('  %s %s a %.0f m alt %.1f', [V[0].Apelido, V[0].Modelo, V[0].DistanciaM, V[0].Alt]));
  WriteLn('estado A: ', A.EstadoTexto);
  // Afasta B para 2.010 m: deve sumir.
  FB.E.Lat := FA.E.Lat + 2010 / METROS_POR_GRAU_LAT;
  Sleep(1500);
  WriteLn('B a 2010 m ve ', Length(B.Vizinhos), ' vizinho(s)');
  A.Free;
  B.Free;
  if Recebeu and (Length(V) = 1) then
    WriteLn('RESULTADO OK')
  else
    WriteLn('RESULTADO FALHOU');
end.
