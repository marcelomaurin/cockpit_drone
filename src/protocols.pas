unit protocols;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics;

const
  { Índices de Configuração > Protocolo (cbProtocol). }
  PROTOCOLO_CX10W = 0;
  PROTOCOLO_MAVLINK = 1;
  PROTOCOLO_TELLO = 2;
  PROTOCOLO_OPENDRONE = 3;
  PROTOCOLO_FQ777 = 4;
  PROTOCOLO_ARDRONE = 5;
  PROTOCOLO_ESP32DRONE = 6;

{ Nome do drone/protocolo para mensagens. }
function NomeProtocolo(AIndice: Integer): string;
{ True só para drones com GPS e navegação autônoma por pontos (rota de voo).
  Hoje: MAVLink (ArduPilot/PX4). Os demais não têm GPS; o AR.Drone 2.0 só tem
  com o acessório Flight Recorder, cujo protocolo de rota não é público. }
function ProtocoloTemGPS(AIndice: Integer): Boolean;

type
  TVideoFrameEvent = procedure(Sender: TObject; ABitmap: TBitmap) of object;
  TErrorEvent = procedure(Sender: TObject; const AMsg: string) of object;
  TStatusEvent = procedure(Sender: TObject; const AStatus: string) of object;

  { TBaseProtocol }

  TBaseProtocol = class
  protected
    FHost: string;
    FTcpPort: Integer;
    FUdpPort: Integer;
    FActive: Boolean;
    FBitmap: TBitmap;
    FOnVideoFrame: TVideoFrameEvent;
    FOnError: TErrorEvent;
    FOnStatus: TStatusEvent;

    procedure DoVideoFrame(ABitmap: TBitmap);
    procedure DoError(const AMsg: string);
    procedure DoStatus(const AStatus: string);
  public
    constructor Create; virtual;
    destructor Destroy; override;

    procedure Connect(const AHost: string; ATcpPort, AUdpPort: Integer) virtual; abstract;
    procedure Disconnect virtual; abstract;
    procedure SendCommand(AX, AY, AZ, AB1, AB2, AB3, AB4, AB5, AB6: Byte) virtual; abstract;

    property Host: string read FHost;
    property TcpPort: Integer read FTcpPort;
    property UdpPort: Integer read FUdpPort;
    property Active: Boolean read FActive;
    property Bitmap: TBitmap read FBitmap;

    property OnVideoFrame: TVideoFrameEvent read FOnVideoFrame write FOnVideoFrame;
    property OnError: TErrorEvent read FOnError write FOnError;
    property OnStatus: TStatusEvent read FOnStatus write FOnStatus;
  end;

implementation

function NomeProtocolo(AIndice: Integer): string;
begin
  case AIndice of
    PROTOCOLO_CX10W: Result := 'Cheerson CX-10W';
    PROTOCOLO_MAVLINK: Result := 'MAVLink (ArduPilot/PX4)';
    PROTOCOLO_TELLO: Result := 'DJI Tello';
    PROTOCOLO_OPENDRONE: Result := 'OpenDrone ESP32';
    PROTOCOLO_FQ777: Result := 'FQ777-954';
    PROTOCOLO_ARDRONE: Result := 'Parrot AR.Drone 2.0';
    PROTOCOLO_ESP32DRONE: Result := 'Drone ESP32 (firmware Cockpit)';
  else
    Result := 'protocolo ' + IntToStr(AIndice);
  end;
end;

function ProtocoloTemGPS(AIndice: Integer): Boolean;
begin
  Result := AIndice = PROTOCOLO_MAVLINK;
end;

{ TBaseProtocol }

constructor TBaseProtocol.Create;
begin
  inherited Create;
  FActive := False;
  FBitmap := TBitmap.Create;
end;

destructor TBaseProtocol.Destroy;
begin
  FBitmap.Free;
  inherited Destroy;
end;

procedure TBaseProtocol.DoVideoFrame(ABitmap: TBitmap);
begin
  if Assigned(FOnVideoFrame) then
    FOnVideoFrame(Self, ABitmap);
end;

procedure TBaseProtocol.DoError(const AMsg: string);
begin
  if Assigned(FOnError) then
    FOnError(Self, AMsg);
end;

procedure TBaseProtocol.DoStatus(const AStatus: string);
begin
  if Assigned(FOnStatus) then
    FOnStatus(Self, AStatus);
end;

end.
