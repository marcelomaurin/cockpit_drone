unit setmain;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, IniFiles;

const
  CONFIG_FILE = 'drone.cfg';

type

  { TSetMain }

  TSetMain = class(TObject)
  private
    FPathConfig: string;

    // Janela principal
    FPosX: Integer;
    FPosY: Integer;
    FWidth: Integer;
    FHeight: Integer;
    FMaximizado: Boolean;

    // Drone / rede
    FDroneIP: string;
    FDronePortaComando: Integer;
    FDronePortaVideo: Integer;
    FDronePortaStatus: Integer;
    FAutoConectar: Boolean;

    // Serial
    FSerialPort: string;
    FBaudRate: Integer;
    FUsaSerial: Boolean;

    // Joystick
    FJoystickAtivo: Boolean;
    FJoystickDeviceIndex: Integer;
    FJoystickNome: string;

    // Controle
    FTimerInterval: Integer;
    FThrottleMin: Integer;
    FThrottleMax: Integer;
    FCentroJoy: Integer;
    FZonaMorta: Integer;
    FEscalaComando: Integer;

    // Câmera
    FCameraAtiva: Boolean;
    FSalvarFrames: Boolean;
    FPastaFrames: string;

    // GPS / mapa
    FMapaZoom: Integer;
    FLatReferencia: Double;
    FLonReferencia: Double;
    FLatHome: Double;
    FLonHome: Double;
    FMostrarGrid: Boolean;
    FMostrarObjetos: Boolean;

    // Gerais
    FUltimoProjeto: string;
    FLogAtivo: Boolean;
    FAutoStart: Boolean;

    procedure SetPosX(const AValue: Integer);
    procedure SetPosY(const AValue: Integer);
    procedure SetWidth(const AValue: Integer);
    procedure SetHeight(const AValue: Integer);

    procedure Default;
    function GetConfigFileName: string;

  public
    constructor Create;
    destructor Destroy; override;

    procedure IdentificaArquivo;
    procedure CarregaContexto;
    procedure SalvaContexto;

    property PosX: Integer read FPosX write SetPosX;
    property PosY: Integer read FPosY write SetPosY;
    property Width: Integer read FWidth write SetWidth;
    property Height: Integer read FHeight write SetHeight;
    property Maximizado: Boolean read FMaximizado write FMaximizado;

    property DroneIP: string read FDroneIP write FDroneIP;
    property DronePortaComando: Integer read FDronePortaComando write FDronePortaComando;
    property DronePortaVideo: Integer read FDronePortaVideo write FDronePortaVideo;
    property DronePortaStatus: Integer read FDronePortaStatus write FDronePortaStatus;
    property AutoConectar: Boolean read FAutoConectar write FAutoConectar;

    property SerialPort: string read FSerialPort write FSerialPort;
    property BaudRate: Integer read FBaudRate write FBaudRate;
    property UsaSerial: Boolean read FUsaSerial write FUsaSerial;

    property JoystickAtivo: Boolean read FJoystickAtivo write FJoystickAtivo;
    property JoystickDeviceIndex: Integer read FJoystickDeviceIndex write FJoystickDeviceIndex;
    property JoystickNome: string read FJoystickNome write FJoystickNome;

    property TimerInterval: Integer read FTimerInterval write FTimerInterval;
    property ThrottleMin: Integer read FThrottleMin write FThrottleMin;
    property ThrottleMax: Integer read FThrottleMax write FThrottleMax;
    property CentroJoy: Integer read FCentroJoy write FCentroJoy;
    property ZonaMorta: Integer read FZonaMorta write FZonaMorta;
    property EscalaComando: Integer read FEscalaComando write FEscalaComando;

    property CameraAtiva: Boolean read FCameraAtiva write FCameraAtiva;
    property SalvarFrames: Boolean read FSalvarFrames write FSalvarFrames;
    property PastaFrames: string read FPastaFrames write FPastaFrames;

    property MapaZoom: Integer read FMapaZoom write FMapaZoom;
    property LatReferencia: Double read FLatReferencia write FLatReferencia;
    property LonReferencia: Double read FLonReferencia write FLonReferencia;
    property LatHome: Double read FLatHome write FLatHome;
    property LonHome: Double read FLonHome write FLonHome;
    property MostrarGrid: Boolean read FMostrarGrid write FMostrarGrid;
    property MostrarObjetos: Boolean read FMostrarObjetos write FMostrarObjetos;

    property UltimoProjeto: string read FUltimoProjeto write FUltimoProjeto;
    property LogAtivo: Boolean read FLogAtivo write FLogAtivo;
    property AutoStart: Boolean read FAutoStart write FAutoStart;
  end;

var
  FSetMain: TSetMain;

implementation

{ TSetMain }

constructor TSetMain.Create;
begin
  inherited Create;
  IdentificaArquivo;
  Default;
  CarregaContexto;
end;

destructor TSetMain.Destroy;
begin
  inherited Destroy;
end;

procedure TSetMain.SetPosX(const AValue: Integer);
begin
  FPosX := AValue;
end;

procedure TSetMain.SetPosY(const AValue: Integer);
begin
  FPosY := AValue;
end;

procedure TSetMain.SetWidth(const AValue: Integer);
begin
  if AValue > 200 then
    FWidth := AValue;
end;

procedure TSetMain.SetHeight(const AValue: Integer);
begin
  if AValue > 200 then
    FHeight := AValue;
end;

procedure TSetMain.Default;
begin
  // Janela
  FPosX := 100;
  FPosY := 100;
  FWidth := 1200;
  FHeight := 800;
  FMaximizado := False;

  // Drone / rede
  FDroneIP := '192.168.10.1';
  FDronePortaComando := 8080;
  FDronePortaVideo := 7060;
  FDronePortaStatus := 8081;
  FAutoConectar := False;

  // Serial
  FSerialPort := 'COM1';
  FBaudRate := 115200;
  FUsaSerial := False;

  // Joystick
  FJoystickAtivo := False;
  FJoystickDeviceIndex := 0;
  FJoystickNome := '';

  // Controle
  FTimerInterval := 100;
  FThrottleMin := 0;
  FThrottleMax := 255;
  FCentroJoy := 127;
  FZonaMorta := 8;
  FEscalaComando := 80;

  // Câmera
  FCameraAtiva := False;
  FSalvarFrames := False;
  FPastaFrames := ExtractFilePath(ParamStr(0)) + 'frames';

  // GPS / mapa
  FMapaZoom := 18;
  FLatReferencia := 0;
  FLonReferencia := 0;
  FLatHome := 0;
  FLonHome := 0;
  FMostrarGrid := True;
  FMostrarObjetos := True;

  // Gerais
  FUltimoProjeto := '';
  FLogAtivo := True;
  FAutoStart := False;
end;

procedure TSetMain.IdentificaArquivo;
begin
  FPathConfig := IncludeTrailingPathDelimiter(GetAppConfigDir(False));
  if not DirectoryExists(FPathConfig) then
    ForceDirectories(FPathConfig);
end;

function TSetMain.GetConfigFileName: string;
begin
  Result := FPathConfig + CONFIG_FILE;
end;

procedure TSetMain.CarregaContexto;
var
  Ini: TIniFile;
begin
  if not FileExists(GetConfigFileName) then
    Exit;

  Ini := TIniFile.Create(GetConfigFileName);
  try
    // Janela
    FPosX := Ini.ReadInteger('JANELA', 'POSX', FPosX);
    FPosY := Ini.ReadInteger('JANELA', 'POSY', FPosY);
    FWidth := Ini.ReadInteger('JANELA', 'WIDTH', FWidth);
    FHeight := Ini.ReadInteger('JANELA', 'HEIGHT', FHeight);
    FMaximizado := Ini.ReadBool('JANELA', 'MAXIMIZADO', FMaximizado);

    // Drone / rede
    FDroneIP := Ini.ReadString('DRONE', 'IP', FDroneIP);
    FDronePortaComando := Ini.ReadInteger('DRONE', 'PORTA_COMANDO', FDronePortaComando);
    FDronePortaVideo := Ini.ReadInteger('DRONE', 'PORTA_VIDEO', FDronePortaVideo);
    FDronePortaStatus := Ini.ReadInteger('DRONE', 'PORTA_STATUS', FDronePortaStatus);
    FAutoConectar := Ini.ReadBool('DRONE', 'AUTO_CONECTAR', FAutoConectar);

    // Serial
    FSerialPort := Ini.ReadString('SERIAL', 'PORTA', FSerialPort);
    FBaudRate := Ini.ReadInteger('SERIAL', 'BAUDRATE', FBaudRate);
    FUsaSerial := Ini.ReadBool('SERIAL', 'USA_SERIAL', FUsaSerial);

    // Joystick
    FJoystickAtivo := Ini.ReadBool('JOYSTICK', 'ATIVO', FJoystickAtivo);
    FJoystickDeviceIndex := Ini.ReadInteger('JOYSTICK', 'DEVICE_INDEX', FJoystickDeviceIndex);
    FJoystickNome := Ini.ReadString('JOYSTICK', 'NOME', FJoystickNome);

    // Controle
    FTimerInterval := Ini.ReadInteger('CONTROLE', 'TIMER_INTERVAL', FTimerInterval);
    FThrottleMin := Ini.ReadInteger('CONTROLE', 'THROTTLE_MIN', FThrottleMin);
    FThrottleMax := Ini.ReadInteger('CONTROLE', 'THROTTLE_MAX', FThrottleMax);
    FCentroJoy := Ini.ReadInteger('CONTROLE', 'CENTRO_JOY', FCentroJoy);
    FZonaMorta := Ini.ReadInteger('CONTROLE', 'ZONA_MORTA', FZonaMorta);
    FEscalaComando := Ini.ReadInteger('CONTROLE', 'ESCALA_COMANDO', FEscalaComando);

    // Câmera
    FCameraAtiva := Ini.ReadBool('CAMERA', 'ATIVA', FCameraAtiva);
    FSalvarFrames := Ini.ReadBool('CAMERA', 'SALVAR_FRAMES', FSalvarFrames);
    FPastaFrames := Ini.ReadString('CAMERA', 'PASTA_FRAMES', FPastaFrames);

    // GPS / mapa
    FMapaZoom := Ini.ReadInteger('MAPA', 'ZOOM', FMapaZoom);
    FLatReferencia := Ini.ReadFloat('MAPA', 'LAT_REFERENCIA', FLatReferencia);
    FLonReferencia := Ini.ReadFloat('MAPA', 'LON_REFERENCIA', FLonReferencia);
    FLatHome := Ini.ReadFloat('MAPA', 'LAT_HOME', FLatHome);
    FLonHome := Ini.ReadFloat('MAPA', 'LON_HOME', FLonHome);
    FMostrarGrid := Ini.ReadBool('MAPA', 'MOSTRAR_GRID', FMostrarGrid);
    FMostrarObjetos := Ini.ReadBool('MAPA', 'MOSTRAR_OBJETOS', FMostrarObjetos);

    // Gerais
    FUltimoProjeto := Ini.ReadString('GERAL', 'ULTIMO_PROJETO', FUltimoProjeto);
    FLogAtivo := Ini.ReadBool('GERAL', 'LOG_ATIVO', FLogAtivo);
    FAutoStart := Ini.ReadBool('GERAL', 'AUTO_START', FAutoStart);
  finally
    Ini.Free;
  end;
end;

procedure TSetMain.SalvaContexto;
var
  Ini: TIniFile;
begin
  if not DirectoryExists(FPathConfig) then
    ForceDirectories(FPathConfig);

  Ini := TIniFile.Create(GetConfigFileName);
  try
    // Janela
    Ini.WriteInteger('JANELA', 'POSX', FPosX);
    Ini.WriteInteger('JANELA', 'POSY', FPosY);
    Ini.WriteInteger('JANELA', 'WIDTH', FWidth);
    Ini.WriteInteger('JANELA', 'HEIGHT', FHeight);
    Ini.WriteBool('JANELA', 'MAXIMIZADO', FMaximizado);

    // Drone / rede
    Ini.WriteString('DRONE', 'IP', FDroneIP);
    Ini.WriteInteger('DRONE', 'PORTA_COMANDO', FDronePortaComando);
    Ini.WriteInteger('DRONE', 'PORTA_VIDEO', FDronePortaVideo);
    Ini.WriteInteger('DRONE', 'PORTA_STATUS', FDronePortaStatus);
    Ini.WriteBool('DRONE', 'AUTO_CONECTAR', FAutoConectar);

    // Serial
    Ini.WriteString('SERIAL', 'PORTA', FSerialPort);
    Ini.WriteInteger('SERIAL', 'BAUDRATE', FBaudRate);
    Ini.WriteBool('SERIAL', 'USA_SERIAL', FUsaSerial);

    // Joystick
    Ini.WriteBool('JOYSTICK', 'ATIVO', FJoystickAtivo);
    Ini.WriteInteger('JOYSTICK', 'DEVICE_INDEX', FJoystickDeviceIndex);
    Ini.WriteString('JOYSTICK', 'NOME', FJoystickNome);

    // Controle
    Ini.WriteInteger('CONTROLE', 'TIMER_INTERVAL', FTimerInterval);
    Ini.WriteInteger('CONTROLE', 'THROTTLE_MIN', FThrottleMin);
    Ini.WriteInteger('CONTROLE', 'THROTTLE_MAX', FThrottleMax);
    Ini.WriteInteger('CONTROLE', 'CENTRO_JOY', FCentroJoy);
    Ini.WriteInteger('CONTROLE', 'ZONA_MORTA', FZonaMorta);
    Ini.WriteInteger('CONTROLE', 'ESCALA_COMANDO', FEscalaComando);

    // Câmera
    Ini.WriteBool('CAMERA', 'ATIVA', FCameraAtiva);
    Ini.WriteBool('CAMERA', 'SALVAR_FRAMES', FSalvarFrames);
    Ini.WriteString('CAMERA', 'PASTA_FRAMES', FPastaFrames);

    // GPS / mapa
    Ini.WriteInteger('MAPA', 'ZOOM', FMapaZoom);
    Ini.WriteFloat('MAPA', 'LAT_REFERENCIA', FLatReferencia);
    Ini.WriteFloat('MAPA', 'LON_REFERENCIA', FLonReferencia);
    Ini.WriteFloat('MAPA', 'LAT_HOME', FLatHome);
    Ini.WriteFloat('MAPA', 'LON_HOME', FLonHome);
    Ini.WriteBool('MAPA', 'MOSTRAR_GRID', FMostrarGrid);
    Ini.WriteBool('MAPA', 'MOSTRAR_OBJETOS', FMostrarObjetos);

    // Gerais
    Ini.WriteString('GERAL', 'ULTIMO_PROJETO', FUltimoProjeto);
    Ini.WriteBool('GERAL', 'LOG_ATIVO', FLogAtivo);
    Ini.WriteBool('GERAL', 'AUTO_START', FAutoStart);

    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

initialization
  FSetMain := TSetMain.Create;

finalization
  FreeAndNil(FSetMain);

end.
