unit joymapa;

{ Mapeamento configurável do joystick para os comandos do cockpit.

  Lógica pura (sem LCL nem componente de joystick), para poder ser testada
  fora do Windows. Quem lê o dispositivo é o joystick.pas; quem mostra e
  edita é a aba "Comandos do Joystick" do config.pas.

  Convenção dos valores entregues ao cockpit (bytes 0..255, centro 127),
  a mesma da leitura bruta que o frmMain já usava:
    Rolagem    0 = esquerda      255 = direita
    Arfagem    0 = frente        255 = trás
    Guinada    0 = gira à esq.   255 = gira à dir.
    Acelerador 0 = mínimo        255 = máximo
  "Inverter" espelha o eixo (255 - valor) quando o dispositivo entrega o
  sentido oposto (comum no acelerador dos manches de voo e no eixo vertical
  dos controles de videogame).

  O componente TSdpoJoystick (Windows, winmm) entrega 6 eixos de 0 a 65535
  (X, Y, Z, R, U, V) e até 16 botões. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, IniFiles;

const
  JOY_EIXOS = 6;                 // X, Y, Z, R, U, V
  JOY_BOTOES = 16;
  JOY_EIXO_NENHUM = -1;
  JOY_BOTAO_NENHUM = 0;          // botões numerados de 1 a JOY_BOTOES
  JOY_BRUTO_MAX = 65535;
  JOY_CENTRO = 127;
  { Captura por movimento: desvio mínimo para aceitar, em fração de meio
    curso (do centro até um extremo). }
  JOY_CAPTURA_MINIMO = 0.30;

  NOMES_EIXO: array[0..JOY_EIXOS - 1] of string = ('X', 'Y', 'Z', 'R', 'U', 'V');

type
  TJoyFuncEixo = (jeRolagem, jeArfagem, jeGuinada, jeAcelerador);
  TJoyFuncBotao = (jbGiraEsquerda, jbGiraDireita, jbDecolar, jbPousar,
    jbPairar, jbManobra, jbCorte);

  TJoyPerfil = (jpManche, jpMancheTorcao, jpGamepadModo2, jpGamepadModo1);

  TJoyMapa = record
    Eixo: array[TJoyFuncEixo] of Integer;      // JOY_EIXO_NENHUM ou 0..5
    Inverte: array[TJoyFuncEixo] of Boolean;
    Botao: array[TJoyFuncBotao] of Integer;    // JOY_BOTAO_NENHUM ou 1..16
  end;

  TJoyEixosBrutos = array[0..JOY_EIXOS - 1] of Integer;

  { Resultado da aplicação do mapa a uma leitura do dispositivo. }
  TJoyComando = record
    Rolagem, Arfagem, Guinada, Acelerador: Byte;
    TemEixo: array[TJoyFuncEixo] of Boolean;
    Botao: array[TJoyFuncBotao] of Boolean;
  end;

function NomeFuncEixo(F: TJoyFuncEixo): string;
{ Sentido positivo da função, para orientar a captura e o usuário. }
function SentidoFuncEixo(F: TJoyFuncEixo): string;
function NomeFuncBotao(F: TJoyFuncBotao): string;
function NomePerfil(P: TJoyPerfil): string;
function NomeEixo(AIndice: Integer): string;
function NomeBotao(ANumero: Integer): string;

function MapaPerfil(P: TJoyPerfil): TJoyMapa;
{ Mapa equivalente ao comportamento anterior (eixos X/Y/Z, botões 1..6). }
function MapaPadrao: TJoyMapa;
function MapasIguais(const A, B: TJoyMapa): Boolean;
{ Perfil igual ao mapa, ou False se o mapa for personalizado. }
function PerfilDoMapa(const M: TJoyMapa; out P: TJoyPerfil): Boolean;

{ False se o mapa não puder ser usado (mesmo eixo ou botão em duas
  funções, índices fora da faixa). AErros lista os problemas; AAvisos traz
  observações que não impedem o uso (ex.: acelerador sem eixo). }
function ValidaMapa(const M: TJoyMapa; out AErros, AAvisos: string): Boolean;

{ Eixo bruto (0..65535) para byte (0..255), com inversão opcional. }
function EixoParaByte(ABruto: Integer; AInverte: Boolean): Byte;
{ Botão (1..16) apertado na máscara (bit 0 = botão 1). }
function BotaoApertado(AMascara: Cardinal; ANumero: Integer): Boolean;
{ Aplica o mapa. Funções sem eixo ficam no centro (acelerador em 0). }
function AplicaMapa(const M: TJoyMapa; const AEixos: TJoyEixosBrutos;
  ABotoes: Cardinal): TJoyComando;

{ Captura por movimento. ABase é a leitura com o comando solto; AAtual, com
  o comando levado ao sentido positivo da função (SentidoFuncEixo). Devolve
  o eixo que mais se moveu e se ele precisa ser invertido; False se nenhum
  eixo passou de JOY_CAPTURA_MINIMO do curso. }
function DetectaEixo(F: TJoyFuncEixo; const ABase, AAtual: TJoyEixosBrutos;
  out AEixo: Integer; out AInverte: Boolean): Boolean;
{ Primeiro botão apertado agora e solto na leitura anterior (0 = nenhum). }
function DetectaBotao(AAntes, AAgora: Cardinal): Integer;

procedure LeMapa(AIni: TCustomIniFile; const ASecao: string; var M: TJoyMapa);
procedure GravaMapa(AIni: TCustomIniFile; const ASecao: string; const M: TJoyMapa);

implementation

const
  CHAVE_EIXO: array[TJoyFuncEixo] of string =
    ('EIXO_ROLAGEM', 'EIXO_ARFAGEM', 'EIXO_GUINADA', 'EIXO_ACELERADOR');
  CHAVE_INVERTE: array[TJoyFuncEixo] of string =
    ('INVERTE_ROLAGEM', 'INVERTE_ARFAGEM', 'INVERTE_GUINADA', 'INVERTE_ACELERADOR');
  CHAVE_BOTAO: array[TJoyFuncBotao] of string =
    ('BOTAO_GIRA_ESQUERDA', 'BOTAO_GIRA_DIREITA', 'BOTAO_DECOLAR', 'BOTAO_POUSAR',
     'BOTAO_PAIRAR', 'BOTAO_MANOBRA', 'BOTAO_CORTE');

function NomeFuncEixo(F: TJoyFuncEixo): string;
begin
  case F of
    jeRolagem: Result := 'Rolagem (esquerda/direita)';
    jeArfagem: Result := 'Arfagem (frente/trás)';
    jeGuinada: Result := 'Guinada (girar)';
    jeAcelerador: Result := 'Acelerador / subida';
  end;
end;

function SentidoFuncEixo(F: TJoyFuncEixo): string;
begin
  case F of
    jeRolagem: Result := 'para a DIREITA';
    jeArfagem: Result := 'para a FRENTE';
    jeGuinada: Result := 'girando para a DIREITA';
    jeAcelerador: Result := 'para o MÁXIMO (subir)';
  end;
end;

function NomeFuncBotao(F: TJoyFuncBotao): string;
begin
  case F of
    jbGiraEsquerda: Result := 'Girar à esquerda';
    jbGiraDireita: Result := 'Girar à direita';
    jbDecolar: Result := 'Decolar / armar';
    jbPousar: Result := 'Pousar / desarmar';
    jbPairar: Result := 'Pairar / centralizar';
    jbManobra: Result := 'Manobra especial / flip';
    jbCorte: Result := 'PÂNICO: corte dos motores';
  end;
end;

function NomePerfil(P: TJoyPerfil): string;
begin
  case P of
    jpManche: Result := 'Manche simples (X/Y, acelerador Z, giro por botões)';
    jpMancheTorcao: Result := 'Manche com torção ou pedal (giro no eixo R)';
    jpGamepadModo2: Result := 'Controle de videogame - Modo 2 (acelerador à esquerda)';
    jpGamepadModo1: Result := 'Controle de videogame - Modo 1 (acelerador à direita)';
  end;
end;

function NomeEixo(AIndice: Integer): string;
begin
  if (AIndice >= 0) and (AIndice < JOY_EIXOS) then
    Result := Format('Eixo %d (%s)', [AIndice + 1, NOMES_EIXO[AIndice]])
  else
    Result := 'Nenhum';
end;

function NomeBotao(ANumero: Integer): string;
begin
  if (ANumero >= 1) and (ANumero <= JOY_BOTOES) then
    Result := 'Botão ' + IntToStr(ANumero)
  else
    Result := 'Nenhum';
end;

function MapaVazio: TJoyMapa;
var
  E: TJoyFuncEixo;
  B: TJoyFuncBotao;
begin
  for E := Low(E) to High(E) do
  begin
    Result.Eixo[E] := JOY_EIXO_NENHUM;
    Result.Inverte[E] := False;
  end;
  for B := Low(B) to High(B) do
    Result.Botao[B] := JOY_BOTAO_NENHUM;
end;

function MapaPerfil(P: TJoyPerfil): TJoyMapa;
begin
  Result := MapaVazio;
  case P of
    jpManche:
      begin
        // Comportamento anterior do cockpit, sem nenhuma mudança.
        Result.Eixo[jeRolagem] := 0;
        Result.Eixo[jeArfagem] := 1;
        Result.Eixo[jeAcelerador] := 2;
        Result.Botao[jbGiraEsquerda] := 1;
        Result.Botao[jbGiraDireita] := 2;
        Result.Botao[jbDecolar] := 3;
        Result.Botao[jbPousar] := 4;
        Result.Botao[jbPairar] := 5;
        Result.Botao[jbManobra] := 6;
      end;
    jpMancheTorcao:
      begin
        // Manche de voo com acelerador de alavanca (empurrar = mais, que no
        // winmm é o valor mínimo) e giro na torção do manche ou nos pedais.
        Result.Eixo[jeRolagem] := 0;
        Result.Eixo[jeArfagem] := 1;
        Result.Eixo[jeAcelerador] := 2;
        Result.Inverte[jeAcelerador] := True;
        Result.Eixo[jeGuinada] := 3;
        Result.Botao[jbCorte] := 2;      // botão do polegar
        Result.Botao[jbDecolar] := 3;
        Result.Botao[jbPousar] := 4;
        Result.Botao[jbPairar] := 5;
        Result.Botao[jbManobra] := 6;
      end;
    jpGamepadModo2, jpGamepadModo1:
      begin
        // Controle de videogame no winmm: X/Y = analógico esquerdo,
        // Z = gatilhos, R = vertical direito, U = horizontal direito.
        // Botões: 1 A, 2 B, 3 X, 4 Y, 5 LB, 6 RB, 7 Back, 8 Start.
        Result.Eixo[jeGuinada] := 0;
        Result.Eixo[jeRolagem] := 4;
        if P = jpGamepadModo2 then
        begin
          Result.Eixo[jeAcelerador] := 1;  // vertical esquerdo
          Result.Eixo[jeArfagem] := 3;     // vertical direito
        end
        else
        begin
          Result.Eixo[jeArfagem] := 1;
          Result.Eixo[jeAcelerador] := 3;
        end;
        // Para cima = valor mínimo; no acelerador cima tem de ser "mais".
        Result.Inverte[jeAcelerador] := True;
        Result.Botao[jbDecolar] := 1;
        Result.Botao[jbPousar] := 2;
        Result.Botao[jbPairar] := 3;
        Result.Botao[jbManobra] := 4;
        Result.Botao[jbGiraEsquerda] := 5;
        Result.Botao[jbGiraDireita] := 6;
        Result.Botao[jbCorte] := 7;
      end;
  end;
end;

function MapaPadrao: TJoyMapa;
begin
  Result := MapaPerfil(jpManche);
end;

function MapasIguais(const A, B: TJoyMapa): Boolean;
var
  E: TJoyFuncEixo;
  F: TJoyFuncBotao;
begin
  Result := False;
  for E := Low(E) to High(E) do
  begin
    if A.Eixo[E] <> B.Eixo[E] then Exit;
    // Inverter só conta quando há eixo.
    if (A.Eixo[E] <> JOY_EIXO_NENHUM) and (A.Inverte[E] <> B.Inverte[E]) then Exit;
  end;
  for F := Low(F) to High(F) do
    if A.Botao[F] <> B.Botao[F] then Exit;
  Result := True;
end;

function PerfilDoMapa(const M: TJoyMapa; out P: TJoyPerfil): Boolean;
var
  Q: TJoyPerfil;
begin
  P := jpManche;
  for Q := Low(Q) to High(Q) do
    if MapasIguais(M, MapaPerfil(Q)) then
    begin
      P := Q;
      Exit(True);
    end;
  Result := False;
end;

function ValidaMapa(const M: TJoyMapa; out AErros, AAvisos: string): Boolean;

  procedure Junta(var S: string; const T: string);
  begin
    if S <> '' then
      S := S + LineEnding;
    S := S + T;
  end;

var
  E, E2: TJoyFuncEixo;
  B, B2: TJoyFuncBotao;
begin
  AErros := '';
  AAvisos := '';
  for E := Low(E) to High(E) do
  begin
    if (M.Eixo[E] <> JOY_EIXO_NENHUM) and
       ((M.Eixo[E] < 0) or (M.Eixo[E] >= JOY_EIXOS)) then
      Junta(AErros, Format('%s: eixo inválido (%d).', [NomeFuncEixo(E), M.Eixo[E]]));
    if M.Eixo[E] = JOY_EIXO_NENHUM then
      Continue;
    for E2 := Succ(E) to High(E) do
      if M.Eixo[E2] = M.Eixo[E] then
        Junta(AErros, Format('%s e %s usam o mesmo %s.',
          [NomeFuncEixo(E), NomeFuncEixo(E2), NomeEixo(M.Eixo[E])]));
  end;
  for B := Low(B) to High(B) do
  begin
    if (M.Botao[B] <> JOY_BOTAO_NENHUM) and
       ((M.Botao[B] < 1) or (M.Botao[B] > JOY_BOTOES)) then
      Junta(AErros, Format('%s: botão inválido (%d).', [NomeFuncBotao(B), M.Botao[B]]));
    if M.Botao[B] = JOY_BOTAO_NENHUM then
      Continue;
    for B2 := Succ(B) to High(B) do
      if M.Botao[B2] = M.Botao[B] then
        Junta(AErros, Format('%s e %s usam o mesmo %s.',
          [NomeFuncBotao(B), NomeFuncBotao(B2), NomeBotao(M.Botao[B])]));
  end;

  if M.Eixo[jeAcelerador] = JOY_EIXO_NENHUM then
    Junta(AAvisos, 'Acelerador sem eixo: só o teclado (E/Q) controla a subida.');
  if (M.Eixo[jeGuinada] = JOY_EIXO_NENHUM) and
     (M.Botao[jbGiraEsquerda] = JOY_BOTAO_NENHUM) and
     (M.Botao[jbGiraDireita] = JOY_BOTAO_NENHUM) then
    Junta(AAvisos, 'Sem giro no joystick: só o teclado (1/2) gira o drone.');
  if M.Botao[jbCorte] = JOY_BOTAO_NENHUM then
    Junta(AAvisos, 'Sem botão de PÂNICO no joystick: o corte fica só na barra de espaço.');
  Result := AErros = '';
end;

function EixoParaByte(ABruto: Integer; AInverte: Boolean): Byte;
begin
  Result := Byte(EnsureRange(Round(EnsureRange(ABruto, 0, JOY_BRUTO_MAX) * 255 /
    JOY_BRUTO_MAX), 0, 255));
  if AInverte then
    Result := 255 - Result;
end;

function BotaoApertado(AMascara: Cardinal; ANumero: Integer): Boolean;
begin
  Result := (ANumero >= 1) and (ANumero <= JOY_BOTOES) and
    ((AMascara and (Cardinal(1) shl (ANumero - 1))) <> 0);
end;

function AplicaMapa(const M: TJoyMapa; const AEixos: TJoyEixosBrutos;
  ABotoes: Cardinal): TJoyComando;

  function Valor(E: TJoyFuncEixo; APadrao: Byte; out ATem: Boolean): Byte;
  var
    I: Integer;
  begin
    I := M.Eixo[E];
    ATem := (I >= 0) and (I < JOY_EIXOS);
    if ATem then
      Result := EixoParaByte(AEixos[I], M.Inverte[E])
    else
      Result := APadrao;
  end;

var
  B: TJoyFuncBotao;
begin
  Result := Default(TJoyComando);
  Result.Rolagem := Valor(jeRolagem, JOY_CENTRO, Result.TemEixo[jeRolagem]);
  Result.Arfagem := Valor(jeArfagem, JOY_CENTRO, Result.TemEixo[jeArfagem]);
  Result.Guinada := Valor(jeGuinada, JOY_CENTRO, Result.TemEixo[jeGuinada]);
  Result.Acelerador := Valor(jeAcelerador, 0, Result.TemEixo[jeAcelerador]);
  for B := Low(B) to High(B) do
    Result.Botao[B] := BotaoApertado(ABotoes, M.Botao[B]);
end;

function DetectaEixo(F: TJoyFuncEixo; const ABase, AAtual: TJoyEixosBrutos;
  out AEixo: Integer; out AInverte: Boolean): Boolean;
var
  I, Delta, Maior: Integer;
  SubiuValor: Boolean;
begin
  AEixo := JOY_EIXO_NENHUM;
  AInverte := False;
  Maior := 0;
  SubiuValor := False;
  for I := 0 to JOY_EIXOS - 1 do
  begin
    Delta := AAtual[I] - ABase[I];
    if Abs(Delta) > Maior then
    begin
      Maior := Abs(Delta);
      AEixo := I;
      SubiuValor := Delta > 0;
    end;
  end;
  Result := (AEixo <> JOY_EIXO_NENHUM) and (Maior >= JOY_CAPTURA_MINIMO * JOY_BRUTO_MAX / 2);
  if not Result then
  begin
    AEixo := JOY_EIXO_NENHUM;
    Exit;
  end;
  // Sentido positivo esperado no valor (convenção do cabeçalho):
  // rolagem, guinada e acelerador sobem; arfagem para a frente desce.
  if F = jeArfagem then
    AInverte := SubiuValor
  else
    AInverte := not SubiuValor;
end;

function DetectaBotao(AAntes, AAgora: Cardinal): Integer;
var
  N: Integer;
begin
  for N := 1 to JOY_BOTOES do
    if BotaoApertado(AAgora, N) and not BotaoApertado(AAntes, N) then
      Exit(N);
  Result := JOY_BOTAO_NENHUM;
end;

procedure LeMapa(AIni: TCustomIniFile; const ASecao: string; var M: TJoyMapa);
var
  E: TJoyFuncEixo;
  B: TJoyFuncBotao;
  Lido: TJoyMapa;
  Erros, Avisos: string;
begin
  // Sem a seção, mantém M (o padrão = comportamento anterior).
  if not AIni.SectionExists(ASecao) then
    Exit;
  Lido := M;
  for E := Low(E) to High(E) do
  begin
    Lido.Eixo[E] := AIni.ReadInteger(ASecao, CHAVE_EIXO[E], M.Eixo[E]);
    Lido.Inverte[E] := AIni.ReadBool(ASecao, CHAVE_INVERTE[E], M.Inverte[E]);
  end;
  for B := Low(B) to High(B) do
    Lido.Botao[B] := AIni.ReadInteger(ASecao, CHAVE_BOTAO[B], M.Botao[B]);
  // Arquivo editado à mão com erro: fica o mapa anterior.
  if ValidaMapa(Lido, Erros, Avisos) then
    M := Lido;
end;

procedure GravaMapa(AIni: TCustomIniFile; const ASecao: string; const M: TJoyMapa);
var
  E: TJoyFuncEixo;
  B: TJoyFuncBotao;
begin
  for E := Low(E) to High(E) do
  begin
    AIni.WriteInteger(ASecao, CHAVE_EIXO[E], M.Eixo[E]);
    AIni.WriteBool(ASecao, CHAVE_INVERTE[E], M.Inverte[E]);
  end;
  for B := Low(B) to High(B) do
    AIni.WriteInteger(ASecao, CHAVE_BOTAO[B], M.Botao[B]);
end;

end.
