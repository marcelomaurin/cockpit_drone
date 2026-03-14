unit controler;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Math;

type
  TMotorArray = array[1..4] of Byte;

  { TDroneControler }

  TDroneControler = class
  private
    FMotor: TMotorArray;

    FThrottle: Integer;
    FRoll: Integer;
    FPitch: Integer;
    FYaw: Integer;

    FMinMotor: Integer;
    FMaxMotor: Integer;
    FCentroJoy: Integer;
    FZonaMorta: Integer;
    FEscalaComando: Integer;
    FAtivo: Boolean;

    function ClampMotor(const AValue: Integer): Byte;
    function NormalizaEixo(const AValor: Byte): Integer;
    function AplicaZonaMorta(const AValor: Integer): Integer;
    procedure CalculaMotores;
  public
    constructor Create;

    procedure Reset;
    procedure Atualiza(const AX, AY, AZ: Byte;
      const AB1, AB2, AB3, AB4, AB5, AB6: Byte);

    property Ativo: Boolean read FAtivo write FAtivo;

    property Motor1: Byte read FMotor[1];
    property Motor2: Byte read FMotor[2];
    property Motor3: Byte read FMotor[3];
    property Motor4: Byte read FMotor[4];
    property Motores: TMotorArray read FMotor;

    property Throttle: Integer read FThrottle;
    property Roll: Integer read FRoll;
    property Pitch: Integer read FPitch;
    property Yaw: Integer read FYaw;

    property MinMotor: Integer read FMinMotor write FMinMotor;
    property MaxMotor: Integer read FMaxMotor write FMaxMotor;
    property CentroJoy: Integer read FCentroJoy write FCentroJoy;
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
  FThrottle := 0;
  FRoll := 0;
  FPitch := 0;
  FYaw := 0;

  FMotor[1] := 0;
  FMotor[2] := 0;
  FMotor[3] := 0;
  FMotor[4] := 0;
end;

function TDroneControler.ClampMotor(const AValue: Integer): Byte;
begin
  Result := Byte(EnsureRange(AValue, FMinMotor, FMaxMotor));
end;

function TDroneControler.AplicaZonaMorta(const AValor: Integer): Integer;
begin
  if Abs(AValor) <= FZonaMorta then
    Result := 0
  else
    Result := AValor;
end;

function TDroneControler.NormalizaEixo(const AValor: Byte): Integer;
begin
  Result := Round(((Integer(AValor) - FCentroJoy) / 128) * FEscalaComando);
  Result := AplicaZonaMorta(Result);
end;

procedure TDroneControler.CalculaMotores;
var
  M1, M2, M3, M4: Integer;
begin
  if not FAtivo then
  begin
    Reset;
    Exit;
  end;

  {
    Mixagem padrão Quad X

    Convenção usada:
    Motor1 = Frente Esquerda
    Motor2 = Frente Direita
    Motor3 = Traseira Direita
    Motor4 = Traseira Esquerda

    Pitch +  => anda para frente
    Roll  +  => inclina para direita
    Yaw   +  => gira
  }

  M1 := FThrottle + FPitch - FRoll + FYaw;
  M2 := FThrottle + FPitch + FRoll - FYaw;
  M3 := FThrottle - FPitch + FRoll + FYaw;
  M4 := FThrottle - FPitch - FRoll - FYaw;

  FMotor[1] := ClampMotor(M1);
  FMotor[2] := ClampMotor(M2);
  FMotor[3] := ClampMotor(M3);
  FMotor[4] := ClampMotor(M4);
end;

procedure TDroneControler.Atualiza(const AX, AY, AZ: Byte;
  const AB1, AB2, AB3, AB4, AB5, AB6: Byte);
var
  VRoll, VPitch, VYaw: Integer;
begin
  if not FAtivo then
  begin
    Reset;
    Exit;
  end;

  {
    Z = throttle base
    X = roll
    Y = pitch

    Você pode inverter sinais depois se o drone reagir ao contrário.
  }

  FThrottle := EnsureRange(AZ, FMinMotor, FMaxMotor);

  VRoll := NormalizaEixo(AX);
  VPitch := NormalizaEixo(AY);

  { yaw via botões:
    B1 gira para um lado
    B2 gira para o outro
  }
  VYaw := 0;
  if AB1 = 255 then
    VYaw := -FEscalaComando div 2
  else
  if AB2 = 255 then
    VYaw := FEscalaComando div 2;

  {
    Inverte pitch para ficar mais natural:
    joystick para cima = frente
  }
  FRoll := VRoll;
  FPitch := -VPitch;
  FYaw := VYaw;

  CalculaMotores;
end;

end.
