unit ConectionCX10W;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Menus, lNetComponents, BCRadialProgressBar, BGRASpriteAnimation,
  MPlayerCtrl, config, lNet, AdvLed, hexlib, FPImage, FPReadJPEG, IntfGraphics,
  setmain;

const
  MAGIC_BYTES_CTRL: array[0..105] of Byte = (
    $49, $54, $64, $00, $00, $00, $5D, $00, $00, $00, $81, $85, $FF, $BD, $2A, $29, $5C, $AD, $67, $82, $5C, $57, $BE, $41, $03, $F8, $CA, $E2, $64, $30, $A3, $C1,
    $5E, $40, $DE, $30, $F6, $D6, $95, $E0, $30, $B7, $C2, $E5, $B7, $D6, $5D, $A8, $65, $9E, $B2, $E2, $D5, $E0, $C2, $CB, $6C, $59, $CD, $CB, $66, $1E, $7E, $1E,
    $B0, $CE, $8E, $E8, $DF, $32, $45, $6F, $A8, $42, $EE, $2E, $09, $A3, $9B, $DD, $05, $C8, $30, $A2, $81, $C8, $2A, $9E, $DA, $7F, $D5, $86, $0E, $AF, $AB, $FE,
    $FA, $3C, $7E, $54, $4F, $F2, $8A, $D2, $93, $CD
  );

  MAGIC_BYTES_VIDEO_1A: array[0..105] of Byte = (
    $49, $54, $64, $00, $00, $00, $52, $00, $00, $00, $0F, $32, $81, $95, $45, $2E, $F5, $E1, $A9, $28, $10, $86, $63, $17, $36, $C3, $CA, $E2, $64, $30, $A3, $C1,
    $5E, $40, $DE, $30, $F6, $D6, $95, $E0, $30, $B7, $C2, $E5, $B7, $D6, $5D, $A8, $65, $9E, $B2, $E2, $D5, $E0, $C2, $CB, $6C, $59, $CD, $CB, $66, $1E, $7E, $1E,
    $B0, $CE, $8E, $E8, $DF, $32, $45, $6F, $A8, $42, $B7, $33, $0F, $B7, $C9, $57, $82, $FC, $3D, $67, $E7, $C3, $A6, $67, $28, $DA, $D8, $B5, $98, $48, $C7, $67,
    $0C, $94, $B2, $9B, $54, $D2, $37, $9E, $2E, $7A
  );

  MAGIC_BYTES_VIDEO_1B: array[0..105] of Byte = (
    $49, $54, $64, $00, $00, $00, $52, $00, $00, $00, $54, $B2, $D1, $F6, $63, $48, $C7, $CD, $B6, $E0, $5B, $0D, $1D, $BC, $A8, $1B, $CA, $E2, $64, $30, $A3, $C1,
    $5E, $40, $DE, $30, $F6, $D6, $95, $E0, $30, $B7, $C2, $E5, $B7, $D6, $5D, $A8, $65, $9E, $B2, $E2, $D5, $E0, $C2, $CB, $6C, $59, $CD, $CB, $66, $1E, $7E, $1E,
    $B0, $CE, $8E, $E8, $DF, $32, $45, $6F, $A8, $42, $B7, $33, $0F, $B7, $C9, $57, $82, $FC, $3D, $67, $E7, $C3, $A6, $67, $28, $DA, $D8, $B5, $98, $48, $C7, $67,
    $0C, $94, $B2, $9B, $54, $D2, $37, $9E, $2E, $7A
  );

  MAGIC_BYTES_VIDEO_2: array[0..105] of Byte = (
    $49, $54, $64, $00, $00, $00, $58, $00, $00, $00, $80, $86, $38, $C3, $8D, $13, $50, $FD, $67, $41, $C2, $EE, $36, $89, $A0, $54, $CA, $E2, $64, $30, $A3, $C1,
    $5E, $40, $DE, $30, $F6, $D6, $95, $E0, $30, $B7, $C2, $E5, $B7, $D6, $5D, $A8, $65, $9E, $B2, $E2, $D5, $E0, $C2, $CB, $6C, $59, $CD, $CB, $66, $1E, $7E, $1E,
    $B0, $CE, $8E, $E8, $DF, $32, $45, $6F, $A8, $42, $EB, $20, $BE, $38, $3A, $AB, $05, $A8, $C2, $A7, $1F, $2C, $90, $6D, $93, $F7, $2A, $85, $E7, $35, $6E, $FF,
    $E1, $B8, $F5, $AF, $09, $7F, $91, $47, $F8, $7E
  );

  DEFAULT_PACKET: array[0..7] of Byte = (
    $CC, $7F, $7F, $7F, $7F, $00, $7F, $33
  );

  AXIS_CENTER = $7F;

type
  TTelemetriaOrigem = (toNenhuma, toTCP, toUDP);

  { TfrmConectionCX10W }

  TfrmConectionCX10W = class(TForm)
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    lbStateConection: TLabel;
    lbTCP: TLabel;
    lbIP: TLabel;
    lbdevicename: TLabel;
    lbUDP: TLabel;
    LTCPComponent1: TLTCPComponent;
    LUDPComponent1: TLUDPComponent;
    meLog: TMemo;
    MenuItem1: TMenuItem;
    pnTop: TPanel;
    pnBotton: TPanel;
    popLog: TPopupMenu;
    timerJoystick: TTimer;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Label5Click(Sender: TObject);
    procedure lbStateConectionChangeBounds(Sender: TObject);
    procedure LTCPComponent1Accept(aSocket: TLSocket);
    procedure LTCPComponent1Connect(aSocket: TLSocket);
    procedure LTCPComponent1Disconnect(aSocket: TLSocket);
    procedure LTCPComponent1Error(const msg: string; aSocket: TLSocket);
    procedure LTCPComponent1Receive(aSocket: TLSocket);
    procedure LUDPComponent1Error(const msg: string; aSocket: TLSocket);
    procedure LUDPComponent1Receive(aSocket: TLSocket);
    procedure pnBottonClick(Sender: TObject);
    procedure timerJoystickTimer(Sender: TObject);

  private
    FX, FY, FZ: Byte;
    FB1, FB2, FB3, FB4, FB5, FB6: Byte;
    FError: Boolean;

    FHost: string;
    FTcpPort: Integer;
    FUdpPort: Integer;

    FBitmap: TBitmap;
    FVideoBuffer: TMemoryStream;
    FUltimaImagemDataHora: TDateTime;

    FUltimaTelemetriaHex: string;
    FUltimaTelemetriaOrigem: TTelemetriaOrigem;
    FUltimaTelemetriaDataHora: TDateTime;
    FUltimaTelemetriaTamanho: Integer;
    FUltimoPacoteTCPHex: string;
    FUltimoPacoteUDPHex: string;
    FTotalPacotesTCP: Int64;
    FTotalPacotesUDP: Int64;

    procedure Log(const ATexto: string);
    procedure SetStatus(const ATexto: string);
    procedure SyncFromMain(var AMudou: Boolean);
    function SafeStrToInt(const S: string; const ADefault: Integer): Integer;
    function BuildChecksum(const AData: array of Byte): Byte;
    function BuildFlags: Byte;
    function BuildYaw: Byte;
    procedure UpdateMainOfflineState;
    procedure DisconnectSockets;
    function TcpReady: Boolean;
    function UdpReady: Boolean;

    procedure AtualizaTelemetria(const AData: TBytes; AOrigem: TTelemetriaOrigem);
    function BytesToHex(const AData: TBytes): string;
    procedure ProcessaBytesTCP(const AData: TBytes);
    function ExtraiJPEGDoBuffer: Boolean;
    procedure CarregaJpegNoBitmap(const AJpegData: TBytes; ADestino: TBitmap);

    function LerTextoConfig(const ANome: array of string; const ADefault: string): string;
    function LerInteiroConfig(const ANome: array of string; const ADefault: Integer): Integer;
    function LerBooleanoConfig(const ANome: array of string; const ADefault: Boolean): Boolean;
    procedure EnviaTCP(const ABytes: array of Byte; const ADescricao: string);
    procedure EnviaUDP(const ABytes: array of Byte; const ADescricao: string);

  public
    procedure PegaConfiguracao;
    procedure InicioHandShake;
    procedure sendMagicPackets;
    procedure sendMagicPacketsVideo1;
    procedure sendMagicPacketsVideo2;
    procedure sendGamepadData;
    procedure DesativaJoystick;
    procedure AtivaJoystick;
    procedure DesativaConnection;

    property Bitmap: TBitmap read FBitmap;
    property UltimaImagemDataHora: TDateTime read FUltimaImagemDataHora;

    property UltimaTelemetriaHex: string read FUltimaTelemetriaHex;
    property UltimaTelemetriaOrigem: TTelemetriaOrigem read FUltimaTelemetriaOrigem;
    property UltimaTelemetriaDataHora: TDateTime read FUltimaTelemetriaDataHora;
    property UltimaTelemetriaTamanho: Integer read FUltimaTelemetriaTamanho;

    property UltimoPacoteTCPHex: string read FUltimoPacoteTCPHex;
    property UltimoPacoteUDPHex: string read FUltimoPacoteUDPHex;
    property TotalPacotesTCP: Int64 read FTotalPacotesTCP;
    property TotalPacotesUDP: Int64 read FTotalPacotesUDP;
  end;

var
  frmConectionCX10W: TfrmConectionCX10W;

implementation

{$R *.lfm}

uses
  main;

{ TfrmConectionCX10W }

procedure TfrmConectionCX10W.Log(const ATexto: string);
begin
  if Assigned(meLog) then
    meLog.Append(FormatDateTime('dd/mm/yyyy hh:nn:ss', Now) + ': ' + ATexto);
end;

procedure TfrmConectionCX10W.SetStatus(const ATexto: string);
begin
  if Assigned(lbStateConection) then
    lbStateConection.Caption := ATexto;
  Log(ATexto);
end;

function TfrmConectionCX10W.SafeStrToInt(const S: string; const ADefault: Integer): Integer;
begin
  if not TryStrToInt(Trim(S), Result) then
    Result := ADefault;
end;

function TfrmConectionCX10W.TcpReady: Boolean;
begin
  Result := Assigned(LTCPComponent1) and LTCPComponent1.Connected and (not FError);
end;

function TfrmConectionCX10W.UdpReady: Boolean;
begin
  Result := Assigned(LUDPComponent1) and LUDPComponent1.Connected and (not FError);
end;

procedure TfrmConectionCX10W.UpdateMainOfflineState;
begin
  if Assigned(frmMain) then
  begin
    frmMain.AdvStart.State := lsOff;
    frmMain.AdvStart.Blink := False;
    frmMain.DesativaJoystick;
  end;
end;

procedure TfrmConectionCX10W.DisconnectSockets;
begin
  try
    if Assigned(LTCPComponent1) and LTCPComponent1.Connected then
      LTCPComponent1.Disconnect(True);
  except
  end;

  try
    if Assigned(LUDPComponent1) and LUDPComponent1.Connected then
      LUDPComponent1.Disconnect(True);
  except
  end;
end;

procedure TfrmConectionCX10W.SyncFromMain(var AMudou: Boolean);
begin
  if not Assigned(frmMain) then
    Exit;

  if FX <> frmMain.X then
  begin
    FX := frmMain.X;
    AMudou := True;
  end;

  if FY <> frmMain.Y then
  begin
    FY := frmMain.Y;
    AMudou := True;
  end;

  if FZ <> frmMain.Z then
  begin
    FZ := frmMain.Z;
    AMudou := True;
  end;

  if FB1 <> frmMain.B1 then
  begin
    FB1 := frmMain.B1;
    AMudou := True;
  end;

  if FB2 <> frmMain.B2 then
  begin
    FB2 := frmMain.B2;
    AMudou := True;
  end;

  if FB3 <> frmMain.B3 then
  begin
    FB3 := frmMain.B3;
    AMudou := True;
  end;

  if FB4 <> frmMain.B4 then
  begin
    FB4 := frmMain.B4;
    AMudou := True;
  end;

  if FB5 <> frmMain.B5 then
  begin
    FB5 := frmMain.B5;
    AMudou := True;
  end;

  if FB6 <> frmMain.B6 then
  begin
    FB6 := frmMain.B6;
    AMudou := True;
  end;
end;

function TfrmConectionCX10W.BuildChecksum(const AData: array of Byte): Byte;
var
  I: Integer;
begin
  Result := 0;
  if High(AData) < 5 then
    Exit;

  for I := 1 to 5 do
    Result := Result xor AData[I];
end;

function TfrmConectionCX10W.BuildFlags: Byte;
begin
  Result := 0;

  if FB3 = 255 then Result := Result or $01;
  if FB4 = 255 then Result := Result or $02;
  if FB5 = 255 then Result := Result or $04;
  if FB6 = 255 then Result := Result or $08;
end;

function TfrmConectionCX10W.BuildYaw: Byte;
begin
  Result := AXIS_CENTER;

  if (FB1 = 255) and (FB2 = 0) then
    Result := 0
  else
  if (FB2 = 255) and (FB1 = 0) then
    Result := 255;
end;

function TfrmConectionCX10W.BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
  begin
    if Result <> '' then
      Result := Result + ' ';
    Result := Result + IntToHex(AData[I], 2);
  end;
end;

procedure TfrmConectionCX10W.AtualizaTelemetria(const AData: TBytes; AOrigem: TTelemetriaOrigem);
begin
  FUltimaTelemetriaHex := BytesToHex(AData);
  FUltimaTelemetriaOrigem := AOrigem;
  FUltimaTelemetriaDataHora := Now;
  FUltimaTelemetriaTamanho := Length(AData);

  case AOrigem of
    toTCP: Inc(FTotalPacotesTCP);
    toUDP: Inc(FTotalPacotesUDP);
  end;
end;

procedure TfrmConectionCX10W.CarregaJpegNoBitmap(const AJpegData: TBytes; ADestino: TBitmap);
var
  MS: TMemoryStream;
  Img: TFPMemoryImage;
  Reader: TFPReaderJPEG;
  IntfImg: TLazIntfImage;
begin
  if (Length(AJpegData) = 0) or (not Assigned(ADestino)) then
    Exit;

  MS := TMemoryStream.Create;
  Img := TFPMemoryImage.Create(0, 0);
  Reader := TFPReaderJPEG.Create;
  IntfImg := TLazIntfImage.Create(0, 0);
  try
    MS.WriteBuffer(AJpegData[0], Length(AJpegData));
    MS.Position := 0;

    Img.LoadFromStream(MS, Reader);

    IntfImg.SetSize(Img.Width, Img.Height);
    IntfImg.LoadFromBitmap(ADestino.Handle, ADestino.MaskHandle);
    IntfImg.Assign(Img);

    ADestino.LoadFromIntfImage(IntfImg);
    FUltimaImagemDataHora := Now;
  finally
    IntfImg.Free;
    Reader.Free;
    Img.Free;
    MS.Free;
  end;
end;

function TfrmConectionCX10W.ExtraiJPEGDoBuffer: Boolean;
var
  PData: PByte;
  Buf: TBytes;
  I, J, Tamanho: Integer;
  InicioJpeg, FimJpeg: Integer;
  Img: TBytes;
  Restante: TBytes;
begin
  Result := False;

  if (not Assigned(FVideoBuffer)) or (FVideoBuffer.Size < 4) then
    Exit;

  SetLength(Buf, FVideoBuffer.Size);
  FVideoBuffer.Position := 0;
  if Length(Buf) > 0 then
    FVideoBuffer.ReadBuffer(Buf[0], Length(Buf));

  InicioJpeg := -1;
  FimJpeg := -1;

  for I := 0 to High(Buf) - 1 do
  begin
    if (Buf[I] = $FF) and (Buf[I + 1] = $D8) then
    begin
      InicioJpeg := I;
      Break;
    end;
  end;

  if InicioJpeg < 0 then
  begin
    FVideoBuffer.Clear;
    Exit;
  end;

  for J := InicioJpeg + 2 to High(Buf) - 1 do
  begin
    if (Buf[J] = $FF) and (Buf[J + 1] = $D9) then
    begin
      FimJpeg := J + 1;
      Break;
    end;
  end;

  if FimJpeg < 0 then
  begin
    FVideoBuffer.Clear;
    FVideoBuffer.WriteBuffer(Buf[InicioJpeg], Length(Buf) - InicioJpeg);
    Exit;
  end;

  Tamanho := FimJpeg - InicioJpeg + 1;
  SetLength(Img, Tamanho);
  Move(Buf[InicioJpeg], Img[0], Tamanho);

  CarregaJpegNoBitmap(Img, FBitmap);

  if FimJpeg < High(Buf) then
  begin
    SetLength(Restante, High(Buf) - FimJpeg);
    Move(Buf[FimJpeg + 1], Restante[0], Length(Restante));
    FVideoBuffer.Clear;
    if Length(Restante) > 0 then
      FVideoBuffer.WriteBuffer(Restante[0], Length(Restante));
  end
  else
    FVideoBuffer.Clear;

  Result := True;
end;

procedure TfrmConectionCX10W.ProcessaBytesTCP(const AData: TBytes);
begin
  if (Length(AData) = 0) or (not Assigned(FVideoBuffer)) then
    Exit;

  FVideoBuffer.Position := FVideoBuffer.Size;
  FVideoBuffer.WriteBuffer(AData[0], Length(AData));
  ExtraiJPEGDoBuffer;
end;

function TfrmConectionCX10W.LerTextoConfig(const ANome: array of string; const ADefault: string): string;
var
  I: Integer;
  C: TComponent;
begin
  Result := ADefault;

  if Assigned(FSetMain) and (ADefault = '192.168.10.1') and (Trim(FSetMain.DroneIP) <> '') then
    Result := FSetMain.DroneIP;

  if not Assigned(frmConfig) then
    Exit;

  for I := Low(ANome) to High(ANome) do
  begin
    C := frmConfig.FindComponent(ANome[I]);
    if Assigned(C) then
    begin
      if C is TEdit then
        Exit(TEdit(C).Text);
      if C is TLabel then
        Exit(TLabel(C).Caption);
      if C is TComboBox then
        Exit(TComboBox(C).Text);
    end;
  end;
end;

function TfrmConectionCX10W.LerInteiroConfig(const ANome: array of string; const ADefault: Integer): Integer;
begin
  Result := SafeStrToInt(LerTextoConfig(ANome, IntToStr(ADefault)), ADefault);
end;

function TfrmConectionCX10W.LerBooleanoConfig(const ANome: array of string; const ADefault: Boolean): Boolean;
var
  I: Integer;
  C: TComponent;
  S: string;
begin
  Result := ADefault;

  if not Assigned(frmConfig) then
    Exit;

  for I := Low(ANome) to High(ANome) do
  begin
    C := frmConfig.FindComponent(ANome[I]);
    if Assigned(C) then
    begin
      if C is TCheckBox then
        Exit(TCheckBox(C).Checked);

      if C is TComboBox then
      begin
        S := Trim(LowerCase(TComboBox(C).Text));
        Exit((S = '1') or (S = 'true') or (S = 'sim') or (S = 'yes'));
      end;
    end;
  end;
end;

procedure TfrmConectionCX10W.EnviaTCP(const ABytes: array of Byte; const ADescricao: string);
var
  N: Integer;
  Tmp: TBytes;
begin
  if not TcpReady then
    Exit;

  if Length(ABytes) = 0 then
    Exit;

  N := LTCPComponent1.Send(ABytes[0], Length(ABytes));
  if N > 0 then
  begin
    SetLength(Tmp, Length(ABytes));
    Move(ABytes[0], Tmp[0], Length(ABytes));
    FUltimoPacoteTCPHex := BytesToHex(Tmp);
    Log(ADescricao + ' enviado via TCP: ' + FUltimoPacoteTCPHex);
  end
  else
    Log('Falha ao enviar ' + ADescricao + ' via TCP');
end;

procedure TfrmConectionCX10W.EnviaUDP(const ABytes: array of Byte; const ADescricao: string);
var
  N: Integer;
  Tmp: TBytes;
begin
  if not UdpReady then
    Exit;

  if Length(ABytes) = 0 then
    Exit;

  N := LUDPComponent1.Send(ABytes[0], Length(ABytes));
  if N > 0 then
  begin
    SetLength(Tmp, Length(ABytes));
    Move(ABytes[0], Tmp[0], Length(ABytes));
    FUltimoPacoteUDPHex := BytesToHex(Tmp);
  end
  else
    Log('Falha ao enviar ' + ADescricao + ' via UDP');
end;

procedure TfrmConectionCX10W.PegaConfiguracao;
begin
  if Assigned(FSetMain) then
  begin
    FHost := FSetMain.DroneIP;
    FTcpPort := FSetMain.DronePortaComando;
    FUdpPort := FSetMain.DronePortaVideo;
  end;

  if Trim(FHost) = '' then
    FHost := '192.168.10.1';

  if FTcpPort <= 0 then
    FTcpPort := 8888;

  if FUdpPort <= 0 then
    FUdpPort := 8895;

  FHost := LerTextoConfig(['edIP', 'edtIP', 'txtIP', 'lbIP'], FHost);
  FTcpPort := LerInteiroConfig(['edTCP', 'edtTCP', 'edPortTCP', 'edtPortTCP'], FTcpPort);
  FUdpPort := LerInteiroConfig(['edUDP', 'edtUDP', 'edPortUDP', 'edtPortUDP'], FUdpPort);

  if Assigned(lbIP) then
    lbIP.Caption := FHost;
  if Assigned(lbTCP) then
    lbTCP.Caption := IntToStr(FTcpPort);
  if Assigned(lbUDP) then
    lbUDP.Caption := IntToStr(FUdpPort);

  Log('Configuração carregada: IP=' + FHost + ' TCP=' + IntToStr(FTcpPort) +
    ' UDP=' + IntToStr(FUdpPort));
end;

procedure TfrmConectionCX10W.InicioHandShake;
begin
  FError := False;
  PegaConfiguracao;

  SetStatus('Iniciando conexão com o drone...');

  try
    if Assigned(LTCPComponent1) then
    begin
      if LTCPComponent1.Connected then
        LTCPComponent1.Disconnect(True);
      LTCPComponent1.Connect(FHost, FTcpPort);
    end;
  except
    on E: Exception do
    begin
      FError := True;
      SetStatus('Erro ao iniciar TCP: ' + E.Message);
      UpdateMainOfflineState;
    end;
  end;

  try
    if Assigned(LUDPComponent1) then
    begin
      if LUDPComponent1.Connected then
        LUDPComponent1.Disconnect(True);
      LUDPComponent1.Connect(FHost, FUdpPort);
    end;
  except
    on E: Exception do
    begin
      FError := True;
      SetStatus('Erro ao iniciar UDP: ' + E.Message);
      UpdateMainOfflineState;
    end;
  end;
end;

procedure TfrmConectionCX10W.sendMagicPackets;
begin
  EnviaTCP(MAGIC_BYTES_CTRL, 'Handshake CTRL');
end;

procedure TfrmConectionCX10W.sendMagicPacketsVideo1;
begin
  EnviaTCP(MAGIC_BYTES_VIDEO_1A, 'Handshake VIDEO 1A');
  Sleep(40);
  EnviaTCP(MAGIC_BYTES_VIDEO_1B, 'Handshake VIDEO 1B');
end;

procedure TfrmConectionCX10W.sendMagicPacketsVideo2;
begin
  EnviaTCP(MAGIC_BYTES_VIDEO_2, 'Handshake VIDEO 2');
end;

procedure TfrmConectionCX10W.sendGamepadData;
var
  Packet: array[0..7] of Byte;
  Flags: Byte;
  Yaw: Byte;
begin
  Packet := DEFAULT_PACKET;

  Flags := BuildFlags;
  Yaw := BuildYaw;

  Packet[1] := FZ;     // throttle
  Packet[2] := Yaw;    // yaw
  Packet[3] := FY;     // pitch
  Packet[4] := FX;     // roll
  Packet[5] := Flags;  // flags / comandos
  Packet[6] := BuildChecksum(Packet);
  Packet[7] := $33;

  EnviaUDP(Packet, 'Controle');
end;

procedure TfrmConectionCX10W.DesativaJoystick;
begin
  if Assigned(timerJoystick) then
    timerJoystick.Enabled := False;
end;

procedure TfrmConectionCX10W.AtivaJoystick;
begin
  if Assigned(timerJoystick) then
    timerJoystick.Enabled := True;
end;

procedure TfrmConectionCX10W.DesativaConnection;
begin
  DesativaJoystick;
  DisconnectSockets;
  SetStatus('Conexão encerrada.');
end;

procedure TfrmConectionCX10W.FormCreate(Sender: TObject);
begin
  FX := AXIS_CENTER;
  FY := AXIS_CENTER;
  FZ := AXIS_CENTER;

  FB1 := 0;
  FB2 := 0;
  FB3 := 0;
  FB4 := 0;
  FB5 := 0;
  FB6 := 0;

  FError := False;
  FHost := '192.168.10.1';
  FTcpPort := 8888;
  FUdpPort := 8895;

  FBitmap := TBitmap.Create;
  FVideoBuffer := TMemoryStream.Create;

  FUltimaTelemetriaHex := '';
  FUltimaTelemetriaOrigem := toNenhuma;
  FUltimaTelemetriaDataHora := 0;
  FUltimaTelemetriaTamanho := 0;
  FUltimoPacoteTCPHex := '';
  FUltimoPacoteUDPHex := '';
  FTotalPacotesTCP := 0;
  FTotalPacotesUDP := 0;

  if Assigned(timerJoystick) then
  begin
    timerJoystick.Interval := 50;
    timerJoystick.Enabled := False;
  end;

  SetStatus('Aguardando início...');
end;

procedure TfrmConectionCX10W.FormDestroy(Sender: TObject);
begin
  DesativaConnection;
  FreeAndNil(FVideoBuffer);
  FreeAndNil(FBitmap);
end;

procedure TfrmConectionCX10W.Label5Click(Sender: TObject);
begin
end;

procedure TfrmConectionCX10W.lbStateConectionChangeBounds(Sender: TObject);
begin
end;

procedure TfrmConectionCX10W.LTCPComponent1Accept(aSocket: TLSocket);
begin
  Log('TCP accept.');
end;

procedure TfrmConectionCX10W.LTCPComponent1Connect(aSocket: TLSocket);
begin
  FError := False;
  SetStatus('TCP conectado ao drone.');

  sendMagicPackets;
  Sleep(50);
  sendMagicPacketsVideo1;
  Sleep(50);
  sendMagicPacketsVideo2;
  Sleep(50);

  AtivaJoystick;

  if Assigned(frmMain) then
    frmMain.AtivouDrone;

  SetStatus('Handshake concluído.');
end;

procedure TfrmConectionCX10W.LTCPComponent1Disconnect(aSocket: TLSocket);
begin
  SetStatus('TCP desconectado.');
  UpdateMainOfflineState;
end;

procedure TfrmConectionCX10W.LTCPComponent1Error(const msg: string; aSocket: TLSocket);
begin
  FError := True;
  SetStatus('Erro TCP: ' + msg);
  UpdateMainOfflineState;
end;

procedure TfrmConectionCX10W.LTCPComponent1Receive(aSocket: TLSocket);
var
  Buf: array[0..8191] of Byte;
  L: Integer;
  Data: TBytes;
begin
  repeat
    L := aSocket.Get(Buf[0], SizeOf(Buf));
    if L > 0 then
    begin
      SetLength(Data, L);
      Move(Buf[0], Data[0], L);
      AtualizaTelemetria(Data, toTCP);
      ProcessaBytesTCP(Data);
    end;
  until L <= 0;
end;

procedure TfrmConectionCX10W.LUDPComponent1Error(const msg: string; aSocket: TLSocket);
begin
  FError := True;
  SetStatus('Erro UDP: ' + msg);
end;

procedure TfrmConectionCX10W.LUDPComponent1Receive(aSocket: TLSocket);
var
  Buf: array[0..2047] of Byte;
  L: Integer;
  Data: TBytes;
begin
  repeat
    L := aSocket.Get(Buf[0], SizeOf(Buf));
    if L > 0 then
    begin
      SetLength(Data, L);
      Move(Buf[0], Data[0], L);
      AtualizaTelemetria(Data, toUDP);
    end;
  until L <= 0;
end;

procedure TfrmConectionCX10W.pnBottonClick(Sender: TObject);
begin
end;

procedure TfrmConectionCX10W.timerJoystickTimer(Sender: TObject);
var
  Mudou: Boolean;
begin
  Mudou := False;
  SyncFromMain(Mudou);

  if Mudou or (Now - FUltimaTelemetriaDataHora > EncodeTime(0, 0, 0, 150)) then
    sendGamepadData;
end;

end.
