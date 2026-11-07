unit joystick;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SdpoJoystick, joymapa;

const
  JOY_REF        = 127;
  JOY_OUT_MIN    = 0;
  JOY_OUT_MAX    = 255;
  JOY_IN_MIN     = 0;
  JOY_IN_MAX     = 65535;
  JOY_DEAD_LOW   = 120;
  JOY_DEAD_HIGH  = 140;

type
  TJoystickButtons = record
    B1: Byte;
    B2: Byte;
    B3: Byte;
    B4: Byte;
    B5: Byte;
    B6: Byte;
  end;

  { Estado já convertido pelo mapa (joymapa.pas). X/Y/Z/G seguem a convenção
    da leitura bruta do frmMain: X 0 = esquerda, Y 0 = frente, Z 0 = mínimo,
    G 0 = gira à esquerda. B1..B6 são as funções dos botões 1..6 do cockpit
    (girar esq./dir., decolar, pousar, pairar, manobra), não os botões
    físicos. }
  TJoystickState = record
    X: Byte;
    Y: Byte;
    Z: Byte;
    G: Byte;                 // guinada pelo eixo (se TemGuinada)
    TemGuinada: Boolean;
    TemAcelerador: Boolean;
    Corte: Boolean;          // botão de PÂNICO apertado
    Buttons: TJoystickButtons;
    { Leitura do dispositivo antes do mapa (para Configurações). }
    Brutos: TJoyEixosBrutos;
    BotoesBrutos: Cardinal;  // bit 0 = botão 1
  end;

  { TJoystickController }

  TJoystickController = class
  private
    FJoystick: TSdpoJoystick;
    FState: TJoystickState;
    FActive: Boolean;
    FMapa: TJoyMapa;

    procedure SetActive(const AValue: Boolean);
    function GetButtonValue(const AIndex: Integer): Byte;

  public
    constructor Create(AJoystick: TSdpoJoystick);
    procedure ResetState;
    function ConfigureDevice(const ADeviceIndex: Integer): Boolean;
    function Activate: Boolean;
    procedure Deactivate;
    function UpdateState: Boolean; // True = leitura bem-sucedida, mesmo sem mudancas

    property Active: Boolean read FActive write SetActive;
    property State: TJoystickState read FState;
    { Função de cada eixo e botão; o padrão repete o comportamento anterior. }
    property Mapa: TJoyMapa read FMapa write FMapa;
  end;

implementation

{ TJoystickController }

constructor TJoystickController.Create(AJoystick: TSdpoJoystick);
begin
  inherited Create;
  FJoystick := AJoystick;
  FActive := False;
  FMapa := MapaPadrao;
  ResetState;
end;

procedure TJoystickController.SetActive(const AValue: Boolean);
begin
  if AValue then
    Activate
  else
    Deactivate;
end;

procedure TJoystickController.ResetState;
var
  I: Integer;
begin
  FState.X := JOY_REF;
  FState.Y := JOY_REF;
  FState.Z := JOY_REF;
  FState.G := JOY_REF;
  FState.TemGuinada := False;
  FState.TemAcelerador := False;
  FState.Corte := False;
  for I := 0 to JOY_EIXOS - 1 do
    FState.Brutos[I] := JOY_BRUTO_MAX div 2;
  FState.BotoesBrutos := 0;

  FState.Buttons.B1 := 0;
  FState.Buttons.B2 := 0;
  FState.Buttons.B3 := 0;
  FState.Buttons.B4 := 0;
  FState.Buttons.B5 := 0;
  FState.Buttons.B6 := 0;
end;

function TJoystickController.ConfigureDevice(const ADeviceIndex: Integer): Boolean;
begin
  Result := False;

  if not Assigned(FJoystick) then
    Exit;

  try
    FJoystick.Active := False;

    if ADeviceIndex = 0 then
      FJoystick.DeviceWin := dwJoystickID1
    else
      FJoystick.DeviceWin := dwJoystickID2;

    Result := True;
  except
    Result := False;
  end;
end;

function TJoystickController.Activate: Boolean;
begin
  Result := False;

  if not Assigned(FJoystick) then
    Exit;

  try
    FJoystick.Active := True;
    FActive := True;
    ResetState;
    Result := True;
  except
    FActive := False;
    Result := False;
  end;
end;

procedure TJoystickController.Deactivate;
begin
  if not Assigned(FJoystick) then
    Exit;

  try
    FJoystick.Active := False;
  except
  end;

  FActive := False;
  ResetState;
end;

function TJoystickController.GetButtonValue(const AIndex: Integer): Byte;
begin
  Result := 0;

  if not Assigned(FJoystick) then
    Exit;

  try
    if FJoystick.Buttons[AIndex].ToBoolean then
      Result := 255
    else
      Result := 0;
  except
    Result := 0;
  end;
end;

function TJoystickController.UpdateState: Boolean;
var
  NewState: TJoystickState;
  Cmd: TJoyComando;
  I: Integer;

  function Botao(F: TJoyFuncBotao): Byte;
  begin
    if Cmd.Botao[F] then
      Result := 255
    else
      Result := 0;
  end;

begin
  Result := False;

  if (not Assigned(FJoystick)) or (not FActive) then
    Exit;

  try
    NewState := Default(TJoystickState);
    // Todos os eixos (X, Y, Z, R, U, V) e botões; o mapa escolhe quais usar.
    for I := 0 to JOY_EIXOS - 1 do
      NewState.Brutos[I] := FJoystick.Axis[I];
    for I := 0 to JOY_BOTOES - 1 do
      if GetButtonValue(I) = 255 then
        NewState.BotoesBrutos := NewState.BotoesBrutos or (Cardinal(1) shl I);

    Cmd := AplicaMapa(FMapa, NewState.Brutos, NewState.BotoesBrutos);
    NewState.X := Cmd.Rolagem;
    NewState.Y := Cmd.Arfagem;
    NewState.Z := Cmd.Acelerador;
    NewState.G := Cmd.Guinada;
    NewState.TemGuinada := Cmd.TemEixo[jeGuinada];
    NewState.TemAcelerador := Cmd.TemEixo[jeAcelerador];
    NewState.Corte := Cmd.Botao[jbCorte];

    NewState.Buttons.B1 := Botao(jbGiraEsquerda);
    NewState.Buttons.B2 := Botao(jbGiraDireita);
    NewState.Buttons.B3 := Botao(jbDecolar);
    NewState.Buttons.B4 := Botao(jbPousar);
    NewState.Buttons.B5 := Botao(jbPairar);
    NewState.Buttons.B6 := Botao(jbManobra);

    FState := NewState;
    Result := True;
  except
    ResetState;
    Result := False;
  end;
end;

end.
