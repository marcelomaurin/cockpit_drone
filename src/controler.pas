unit controler;

{ Conversão única dos comandos do cockpit.

  O frmMain guarda o manche em bytes (X, Y, Z e botões B1..B6). Este
  controlador é o único lugar que transforma esses bytes em comandos de voo:
    - Rolagem/Arfagem -1..1 (+ = direita/frente), com centro (CentroJoy) e
      zona morta (ZonaMorta, % do curso) da configuração;
    - Guinada pelos botões 1/2;
    - Acelerador 0..1 (Z inteiro) e Subida -1..1 (Z em relação ao centro).
  As janelas de conexão (conexaodrone.pas) enviam estes valores ao drone, e a
  mistura Quad X calculada a partir deles aparece nos mostradores Engine
  01..04: é a estimativa do que cada motor recebe com o comando atual
  (EscalaComando = % do curso dos motores usado por rolagem/arfagem/guinada). }

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Math;

const
  GUINADA_BOTAO = 0.6;  // fração da guinada máxima com os botões 1/2

type
  TMotorArray = array[1..4] of Byte;

  { TDroneControler }

  TDroneControler = class
  private
    FMotor: TMotorArray;
    FRolagem, FArfagem, FGuinada: Double;
    FAcelerador, FSubida: Double;
    FMinMotor: Integer;
    FMaxMotor: Integer;
    FCentroJoy: Integer;
    FZonaMorta: Integer;
    FEscalaComando: Integer;
    FAtivo: Boolean;
    function ClampMotor(const AValue: Integer): Byte;
    function Eixo(const AValor: Byte): Double;
    procedure CalculaMotores;
  public
    constructor Create;

    procedure Reset;
    procedure Atualiza(const AX, AY, AZ: Byte;
      const AB1, AB2, AB3, AB4, AB5, AB6: Byte);

    property Ativo: Boolean read FAtivo write FAtivo;

    { Comando de voo atual (zero com o controlador desligado). }
    property Rolagem: Double read FRolagem;
    property Arfagem: Double read FArfagem;
    property Guinada: Double read FGuinada;
    property Acelerador: Double read FAcelerador;
    property Subida: Double read FSubida;

    { Mistura Quad X estimada. }
    property Motor1: Byte read FMotor[1];
    property Motor2: Byte read FMotor[2];
    property Motor3: Byte read FMotor[3];
    property Motor4: Byte read FMotor[4];
    property Motores: TMotorArray read FMotor;

    property MinMotor: Integer read FMinMotor write FMinMotor;
    property MaxMotor: Integer read FMaxMotor write FMaxMotor;
    property CentroJoy: Integer read FCentroJoy write FCentroJoy;
    { Zona morta em % do curso do manche (0..50). }
    property ZonaMorta: Integer read FZonaMorta write FZonaMorta;
    property EscalaComando: Integer read FEscalaComando write FEscalaComando;
  end;

implementation

{ TDroneControler }

constructor TDroneControler.Create;
begin
  inherited Create;
  FMinMotor := 0;
  FMaxMotor := 255;
  FCentroJoy := 127;
  FZonaMorta := 8;
  FEscalaComando := 80;
  FAtivo := False;
  Reset;
end;

procedure TDroneControler.Reset;
begin
  FRolagem := 0;
  FArfagem := 0;
  FGuinada := 0;
  FAcelerador := 0;
  FSubida := 0;
  FillChar(FMotor, SizeOf(FMotor), 0);
end;

function TDroneControler.ClampMotor(const AValue: Integer): Byte;
begin
  Result := Byte(EnsureRange(AValue, Max(0, FMinMotor), Min(255, FMaxMotor)));
end;

function TDroneControler.Eixo(const AValor: Byte): Double;
var
  Centro: Integer;
  Zona: Double;
begin
  // Byte -> -1..1 em relação ao centro configurado, cada lado com o seu curso.
  Centro := EnsureRange(FCentroJoy, 1, 254);
  if AValor >= Centro then
    Result := (AValor - Centro) / (255 - Centro)
  else
    Result := (AValor - Centro) / Centro;
  // Zona morta proporcional: |v| <= zona vira 0 e o restante vai até 1.
  Zona := EnsureRange(FZonaMorta, 0, 50) / 100;
  if Abs(Result) <= Zona then
    Result := 0
  else
    Result := Sign(Result) * Min(1.0, (Abs(Result) - Zona) / (1 - Zona));
end;

procedure TDroneControler.CalculaMotores;
var
  T, R, P, Y, Escala: Double;
begin
  {
    Mixagem Quad X (estimativa para os mostradores)
    Motor1 = Frente Esquerda    Motor2 = Frente Direita
    Motor3 = Traseira Direita   Motor4 = Traseira Esquerda
    Arfagem + = frente: os motores de trás aceleram.
    Rolagem + = direita: os motores da esquerda aceleram.
    Guinada + = horário: os motores que giram no sentido anti-horário
    (frente esquerda e traseira direita) aceleram.
  }
  T := FMinMotor + FAcelerador * (FMaxMotor - FMinMotor);
  Escala := EnsureRange(FEscalaComando, 0, 100) / 100 * 127;
  R := FRolagem * Escala;
  P := FArfagem * Escala;
  Y := FGuinada * Escala;
  FMotor[1] := ClampMotor(Round(T - P + R + Y));
  FMotor[2] := ClampMotor(Round(T - P - R - Y));
  FMotor[3] := ClampMotor(Round(T + P - R + Y));
  FMotor[4] := ClampMotor(Round(T + P + R - Y));
end;

procedure TDroneControler.Atualiza(const AX, AY, AZ: Byte;
  const AB1, AB2, AB3, AB4, AB5, AB6: Byte);
begin
  if not FAtivo then
  begin
    Reset;
    Exit;
  end;
  // No frmMain X cresce para a ESQUERDA e Y para a FRENTE.
  FRolagem := -Eixo(AX);
  FArfagem := Eixo(AY);
  FAcelerador := AZ / 255;
  FSubida := Eixo(AZ);
  FGuinada := 0;
  if (AB1 = 255) and (AB2 <> 255) then
    FGuinada := -GUINADA_BOTAO
  else if (AB2 = 255) and (AB1 <> 255) then
    FGuinada := GUINADA_BOTAO;
  CalculaMotores;
end;

end.
