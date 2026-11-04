unit setmain;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, IniFiles;

const
  CONFIG_FILE = 'drone.cfg';

type

  { Configuração exclusiva do Cheerson CX-10W (seção [CX10W] do drone.cfg),
    separada da seção [DRONE] usada pelos demais protocolos. }
  TCX10WSettings = record
    IP: string;
    PortaTCP: Integer;           // inicialização e vídeo
    PortaUDP: Integer;           // comando
    Video: Boolean;
    FFmpeg: string;              // '' = procura ao lado do programa e no PATH
  end;

  { Parrot AR.Drone 2.0 (seção [ARDRONE] do drone.cfg). }
  TARDroneSettings = record
    IP: string;
    Video: Boolean;
    FFmpeg: string;              // '' = procura ao lado do programa e no PATH
    AlturaMaxima: Integer;       // metros
    Externo: Boolean;            // voo ao ar livre (sem protetor de hélices)
    Sensibilidade: Integer;      // % do comando máximo usado pelo manche
  end;

  { Drone ESP32 com o firmware Cockpit (seção [ESP32DRONE] do drone.cfg). }
  TESP32DroneSettings = record
    IP: string;
    Porta: Integer;              // UDP
  end;

  { Configuração exclusiva do FQ777-954 (seção [FQ777] do drone.cfg). }
  TFQ777Settings = record
    IP: string;
    PortaTCP: Integer;
    PortaUDP: Integer;
    Video: Boolean;
    GravarVideo: Boolean;
    FFmpeg: string;              // '' = procura ao lado do programa e no PATH
    WifiAuto: Boolean;           // procura e conecta na rede do drone
    WifiSSID: string;            // padrões separados por ';' (curingas * ?)
    WifiSenha: string;           // '' = rede aberta
    ZonaMorta: Integer;          // % do curso do manche
    EixoRolagem: Integer;        // índices de eixo do TAIJoystick (0..5)
    EixoArfagem: Integer;
    EixoGuinada: Integer;
    EixoAcelerador: Integer;
    AceleradorCentrado: Boolean; // False = gatilho 0..1; True = manche -1..1
  end;

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
    FDroneProtocolo: Integer;

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

  public
    CX10W: TCX10WSettings;
    ARDrone: TARDroneSettings;
    ESP32Drone: TESP32DroneSettings;
    FQ777: TFQ777Settings;

    function GetConfigFileName: string;
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
    property DroneProtocolo: Integer read FDroneProtocolo write FDroneProtocolo;

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
  FDroneProtocolo := 0;

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

  // Cheerson CX-10W
  CX10W.IP := '172.16.10.1';
  CX10W.PortaTCP := 8888;
  CX10W.PortaUDP := 8895;
  CX10W.Video := True;
  CX10W.FFmpeg := '';

  // Parrot AR.Drone 2.0
  ARDrone.IP := '192.168.1.1';
  ARDrone.Video := True;
  ARDrone.FFmpeg := '';
  ARDrone.AlturaMaxima := 3;
  ARDrone.Externo := False;
  ARDrone.Sensibilidade := 50;

  // Drone ESP32 (firmware Cockpit)
  ESP32Drone.IP := '192.168.4.1';
  ESP32Drone.Porta := 4210;

  // FQ777-954
  FQ777.IP := '172.16.10.1';
  FQ777.PortaTCP := 8888;
  FQ777.PortaUDP := 8895;
  FQ777.Video := True;
  FQ777.GravarVideo := False;
  FQ777.FFmpeg := '';
  FQ777.WifiAuto := True;
  FQ777.WifiSSID := 'FQ777';
  FQ777.WifiSenha := '';
  FQ777.ZonaMorta := 8;
  FQ777.EixoRolagem := 0;     // manche esquerdo X
  FQ777.EixoArfagem := 1;     // manche esquerdo Y
  FQ777.EixoGuinada := 2;     // manche direito X
  FQ777.EixoAcelerador := 5;  // gatilho direito (R2/RT), como no app original
  FQ777.AceleradorCentrado := False;
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
    FDroneProtocolo := Ini.ReadInteger('DRONE', 'PROTOCOLO', FDroneProtocolo);

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

    // Cheerson CX-10W
    CX10W.IP := Ini.ReadString('CX10W', 'IP', CX10W.IP);
    CX10W.PortaTCP := Ini.ReadInteger('CX10W', 'PORTA_TCP', CX10W.PortaTCP);
    CX10W.PortaUDP := Ini.ReadInteger('CX10W', 'PORTA_UDP', CX10W.PortaUDP);
    CX10W.Video := Ini.ReadBool('CX10W', 'VIDEO', CX10W.Video);
    CX10W.FFmpeg := Ini.ReadString('CX10W', 'FFMPEG', CX10W.FFmpeg);

    // Parrot AR.Drone 2.0
    ARDrone.IP := Ini.ReadString('ARDRONE', 'IP', ARDrone.IP);
    ARDrone.Video := Ini.ReadBool('ARDRONE', 'VIDEO', ARDrone.Video);
    ARDrone.FFmpeg := Ini.ReadString('ARDRONE', 'FFMPEG', ARDrone.FFmpeg);
    ARDrone.AlturaMaxima := Ini.ReadInteger('ARDRONE', 'ALTURA_MAXIMA', ARDrone.AlturaMaxima);
    ARDrone.Externo := Ini.ReadBool('ARDRONE', 'EXTERNO', ARDrone.Externo);
    ARDrone.Sensibilidade := Ini.ReadInteger('ARDRONE', 'SENSIBILIDADE', ARDrone.Sensibilidade);

    // Drone ESP32 (firmware Cockpit)
    ESP32Drone.IP := Ini.ReadString('ESP32DRONE', 'IP', ESP32Drone.IP);
    ESP32Drone.Porta := Ini.ReadInteger('ESP32DRONE', 'PORTA', ESP32Drone.Porta);

    // FQ777-954
    FQ777.IP := Ini.ReadString('FQ777', 'IP', FQ777.IP);
    FQ777.PortaTCP := Ini.ReadInteger('FQ777', 'PORTA_TCP', FQ777.PortaTCP);
    FQ777.PortaUDP := Ini.ReadInteger('FQ777', 'PORTA_UDP', FQ777.PortaUDP);
    FQ777.Video := Ini.ReadBool('FQ777', 'VIDEO', FQ777.Video);
    FQ777.GravarVideo := Ini.ReadBool('FQ777', 'GRAVAR_VIDEO', FQ777.GravarVideo);
    FQ777.FFmpeg := Ini.ReadString('FQ777', 'FFMPEG', FQ777.FFmpeg);
    FQ777.WifiAuto := Ini.ReadBool('FQ777', 'WIFI_AUTO', FQ777.WifiAuto);
    FQ777.WifiSSID := Ini.ReadString('FQ777', 'WIFI_SSID', FQ777.WifiSSID);
    FQ777.WifiSenha := Ini.ReadString('FQ777', 'WIFI_SENHA', FQ777.WifiSenha);
    FQ777.ZonaMorta := Ini.ReadInteger('FQ777', 'ZONA_MORTA', FQ777.ZonaMorta);
    FQ777.EixoRolagem := Ini.ReadInteger('FQ777', 'EIXO_ROLAGEM', FQ777.EixoRolagem);
    FQ777.EixoArfagem := Ini.ReadInteger('FQ777', 'EIXO_ARFAGEM', FQ777.EixoArfagem);
    FQ777.EixoGuinada := Ini.ReadInteger('FQ777', 'EIXO_GUINADA', FQ777.EixoGuinada);
    FQ777.EixoAcelerador := Ini.ReadInteger('FQ777', 'EIXO_ACELERADOR', FQ777.EixoAcelerador);
    FQ777.AceleradorCentrado := Ini.ReadBool('FQ777', 'ACELERADOR_CENTRADO', FQ777.AceleradorCentrado);
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
    Ini.WriteInteger('DRONE', 'PROTOCOLO', FDroneProtocolo);

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

    // Cheerson CX-10W
    Ini.WriteString('CX10W', 'IP', CX10W.IP);
    Ini.WriteInteger('CX10W', 'PORTA_TCP', CX10W.PortaTCP);
    Ini.WriteInteger('CX10W', 'PORTA_UDP', CX10W.PortaUDP);
    Ini.WriteBool('CX10W', 'VIDEO', CX10W.Video);
    Ini.WriteString('CX10W', 'FFMPEG', CX10W.FFmpeg);

    // Parrot AR.Drone 2.0
    Ini.WriteString('ARDRONE', 'IP', ARDrone.IP);
    Ini.WriteBool('ARDRONE', 'VIDEO', ARDrone.Video);
    Ini.WriteString('ARDRONE', 'FFMPEG', ARDrone.FFmpeg);
    Ini.WriteInteger('ARDRONE', 'ALTURA_MAXIMA', ARDrone.AlturaMaxima);
    Ini.WriteBool('ARDRONE', 'EXTERNO', ARDrone.Externo);
    Ini.WriteInteger('ARDRONE', 'SENSIBILIDADE', ARDrone.Sensibilidade);

    // Drone ESP32 (firmware Cockpit)
    Ini.WriteString('ESP32DRONE', 'IP', ESP32Drone.IP);
    Ini.WriteInteger('ESP32DRONE', 'PORTA', ESP32Drone.Porta);

    // FQ777-954
    Ini.WriteString('FQ777', 'IP', FQ777.IP);
    Ini.WriteInteger('FQ777', 'PORTA_TCP', FQ777.PortaTCP);
    Ini.WriteInteger('FQ777', 'PORTA_UDP', FQ777.PortaUDP);
    Ini.WriteBool('FQ777', 'VIDEO', FQ777.Video);
    Ini.WriteBool('FQ777', 'GRAVAR_VIDEO', FQ777.GravarVideo);
    Ini.WriteString('FQ777', 'FFMPEG', FQ777.FFmpeg);
    Ini.WriteBool('FQ777', 'WIFI_AUTO', FQ777.WifiAuto);
    Ini.WriteString('FQ777', 'WIFI_SSID', FQ777.WifiSSID);
    Ini.WriteString('FQ777', 'WIFI_SENHA', FQ777.WifiSenha);
    Ini.WriteInteger('FQ777', 'ZONA_MORTA', FQ777.ZonaMorta);
    Ini.WriteInteger('FQ777', 'EIXO_ROLAGEM', FQ777.EixoRolagem);
    Ini.WriteInteger('FQ777', 'EIXO_ARFAGEM', FQ777.EixoArfagem);
    Ini.WriteInteger('FQ777', 'EIXO_GUINADA', FQ777.EixoGuinada);
    Ini.WriteInteger('FQ777', 'EIXO_ACELERADOR', FQ777.EixoAcelerador);
    Ini.WriteBool('FQ777', 'ACELERADOR_CENTRADO', FQ777.AceleradorCentrado);

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
