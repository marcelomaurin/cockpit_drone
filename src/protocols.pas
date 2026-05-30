unit protocols;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics;

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
