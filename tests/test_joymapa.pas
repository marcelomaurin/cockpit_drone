program test_joymapa;

{ Testes do mapeamento do joystick (src/joymapa.pas), sem LCL.
  fpc -Fu./src tests/test_joymapa.pas && ./tests/test_joymapa }

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, IniFiles, joymapa;

var
  Falhas: Integer = 0;

procedure Confere(AOk: Boolean; const ANome: string);
begin
  if AOk then
    WriteLn('OK    ', ANome)
  else
  begin
    WriteLn('FALHA ', ANome);
    Inc(Falhas);
  end;
end;

function Eixos(X, Y, Z, R, U, V: Integer): TJoyEixosBrutos;
begin
  Result[0] := X; Result[1] := Y; Result[2] := Z;
  Result[3] := R; Result[4] := U; Result[5] := V;
end;

const
  C = 32767;   // centro bruto
  MX = 65535;

var
  M, Lido: TJoyMapa;
  Cmd: TJoyComando;
  P, Q: TJoyPerfil;
  Erros, Avisos, Arq: string;
  Ini: TMemIniFile;
  Eixo: Integer;
  Inv: Boolean;
begin
  // Padrão = comportamento anterior.
  M := MapaPadrao;
  Cmd := AplicaMapa(M, Eixos(0, MX, MX, C, C, C), 0);
  Confere((Cmd.Rolagem = 0) and (Cmd.Arfagem = 255) and (Cmd.Acelerador = 255),
    'padrão: X, Y e Z brutos passam direto como antes');
  Confere(Cmd.Guinada = JOY_CENTRO, 'padrão: guinada sem eixo fica no centro');
  Confere(not Cmd.TemEixo[jeGuinada], 'padrão: guinada só pelos botões 1/2');
  Cmd := AplicaMapa(M, Eixos(C, C, 0, C, C, C), %000011);
  Confere(Cmd.Botao[jbGiraEsquerda] and Cmd.Botao[jbGiraDireita] and not Cmd.Botao[jbDecolar],
    'padrão: botões 1 e 2 giram');
  Confere(ValidaMapa(M, Erros, Avisos), 'padrão é válido');
  Confere(Pos('PÂNICO', Avisos) > 0, 'padrão avisa que não há pânico no joystick');

  // Conversão e inversão.
  Confere((EixoParaByte(0, False) = 0) and (EixoParaByte(MX, False) = 255) and
    (EixoParaByte(C, False) = 127), 'eixo bruto vira 0..255 com centro 127');
  Confere((EixoParaByte(0, True) = 255) and (EixoParaByte(MX, True) = 0),
    'inverter espelha o eixo');
  Confere((EixoParaByte(-5, False) = 0) and (EixoParaByte(99999, False) = 255),
    'valores fora da faixa são limitados');

  // Modo 2: acelerador no vertical esquerdo, para cima = mínimo bruto = máximo.
  M := MapaPerfil(jpGamepadModo2);
  Cmd := AplicaMapa(M, Eixos(MX, 0, C, 0, MX, C), 0);
  Confere(Cmd.Acelerador = 255, 'modo 2: esquerdo para cima acelera');
  Confere(Cmd.Guinada = 255, 'modo 2: esquerdo para a direita gira à direita');
  Confere(Cmd.Arfagem = 0, 'modo 2: direito para cima vai para a frente');
  Confere(Cmd.Rolagem = 255, 'modo 2: direito para a direita rola à direita');
  Cmd := AplicaMapa(M, Eixos(C, C, C, C, C, C), Cardinal(1) shl 6);
  Confere(Cmd.Botao[jbCorte], 'modo 2: Back (botão 7) é o pânico');
  Confere(ValidaMapa(M, Erros, Avisos) and (Avisos = ''), 'modo 2 é válido e sem avisos');

  M := MapaPerfil(jpGamepadModo1);
  Cmd := AplicaMapa(M, Eixos(C, 0, C, 0, C, C), 0);
  Confere((Cmd.Arfagem = 0) and (Cmd.Acelerador = 255),
    'modo 1: esquerdo para cima = frente, direito para cima = acelerar');

  M := MapaPerfil(jpMancheTorcao);
  Cmd := AplicaMapa(M, Eixos(C, C, 0, MX, C, C), 0);
  Confere((Cmd.Acelerador = 255) and (Cmd.Guinada = 255),
    'manche com torção: alavanca à frente acelera, torção gira');

  // Perfil reconhecido a partir do mapa.
  for Q := Low(Q) to High(Q) do
    Confere(PerfilDoMapa(MapaPerfil(Q), P) and (P = Q), 'perfil reconhecido: ' + NomePerfil(Q));
  M := MapaPadrao;
  M.Botao[jbCorte] := 8;
  Confere(not PerfilDoMapa(M, P), 'mapa alterado é personalizado');
  M := MapaPadrao;
  M.Inverte[jeGuinada] := True; // guinada sem eixo: inverter não conta
  Confere(PerfilDoMapa(M, P) and (P = jpManche), 'inverter sem eixo não muda o perfil');

  // Validação.
  M := MapaPadrao;
  M.Eixo[jeGuinada] := 0;
  Confere(not ValidaMapa(M, Erros, Avisos) and (Pos('mesmo Eixo 1 (X)', Erros) > 0),
    'mesmo eixo em duas funções é recusado');
  M := MapaPadrao;
  M.Botao[jbCorte] := 3;
  Confere(not ValidaMapa(M, Erros, Avisos) and (Pos('mesmo Botão 3', Erros) > 0),
    'mesmo botão em duas funções é recusado');
  M := MapaPadrao;
  M.Botao[jbCorte] := 17;
  Confere(not ValidaMapa(M, Erros, Avisos), 'botão fora da faixa é recusado');
  M := MapaPadrao;
  M.Eixo[jeAcelerador] := JOY_EIXO_NENHUM;
  Confere(ValidaMapa(M, Erros, Avisos) and (Pos('Acelerador sem eixo', Avisos) > 0),
    'acelerador sem eixo é só aviso');
  Cmd := AplicaMapa(M, Eixos(C, C, MX, C, C, C), 0);
  Confere(Cmd.Acelerador = 0, 'acelerador sem eixo fica em zero');

  // Captura por movimento.
  Confere(DetectaEixo(jeRolagem, Eixos(C, C, C, C, C, C), Eixos(MX, C + 900, C, C, C, C), Eixo, Inv)
    and (Eixo = 0) and not Inv, 'captura: rolagem para a direita no X, sem inverter');
  Confere(DetectaEixo(jeArfagem, Eixos(C, C, C, C, C, C), Eixos(C, C, C, 0, C, C), Eixo, Inv)
    and (Eixo = 3) and not Inv, 'captura: arfagem para a frente no R, sem inverter');
  Confere(DetectaEixo(jeAcelerador, Eixos(C, C, MX, C, C, C), Eixos(C, C, 0, C, C, C), Eixo, Inv)
    and (Eixo = 2) and Inv, 'captura: alavanca à frente (valor mínimo) inverte o acelerador');
  Confere(DetectaEixo(jeGuinada, Eixos(C, C, C, C, C, C), Eixos(C, C, C, C, C, 0), Eixo, Inv)
    and (Eixo = 5) and Inv, 'captura: guinada no V ao contrário fica invertida');
  Confere(not DetectaEixo(jeRolagem, Eixos(C, C, C, C, C, C), Eixos(C + 3000, C, C, C, C, C), Eixo, Inv)
    and (Eixo = JOY_EIXO_NENHUM), 'captura: movimento pequeno é ignorado');
  Confere(DetectaBotao(%0001, %0101) = 3, 'captura: botão recém-apertado');
  Confere(DetectaBotao(%0101, %0101) = JOY_BOTAO_NENHUM, 'captura: botão já apertado não conta');

  // Gravação e leitura.
  Arq := GetTempFileName;
  Ini := TMemIniFile.Create(Arq);
  try
    M := MapaPerfil(jpGamepadModo2);
    M.Botao[jbManobra] := 9;
    GravaMapa(Ini, 'JOYSTICK_MAPA', M);
    Lido := MapaPadrao;
    LeMapa(Ini, 'JOYSTICK_MAPA', Lido);
    Confere(MapasIguais(Lido, M), 'mapa gravado é lido igual');
    Lido := MapaPadrao;
    LeMapa(Ini, 'OUTRA_SECAO', Lido);
    Confere(MapasIguais(Lido, MapaPadrao), 'sem a seção, fica o padrão (arquivos antigos)');
    Ini.WriteInteger('JOYSTICK_MAPA', 'BOTAO_CORTE', 1); // conflita com decolar
    Lido := MapaPadrao;
    LeMapa(Ini, 'JOYSTICK_MAPA', Lido);
    Confere(MapasIguais(Lido, MapaPadrao), 'mapa inválido no arquivo é ignorado');
  finally
    Ini.Free;
    DeleteFile(Arq);
  end;

  if Falhas > 0 then
  begin
    WriteLn(Falhas, ' falha(s).');
    Halt(1);
  end;
  WriteLn('Todos os testes do mapeamento passaram.');
end.
