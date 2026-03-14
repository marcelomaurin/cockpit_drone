unit ConectionCX10W;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Menus, lNetComponents, BCRadialProgressBar, BGRASpriteAnimation,
  MPlayerCtrl, config, lNet, AdvLed, hexlib, FPImage, FPReadJPEG, IntfGraphics;

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
    $CC, $7F, $7F, $00, $7F, $00, $7F, $33
  );

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
    procedure UpdateMainOfflineState;
    procedure DisconnectSockets;
    function TcpReady: Boolean;
    function UdpReady: Boolean;

    procedure AtualizaTelemetria(const AData: TBytes; AOrigem: TTelemetriaOrigem);
    function BytesToHex(const AData: TBytes): string;
    procedure ProcessaBytesTCP(const AData: TBytes);
    function ExtraiJPEGDoBuffer: Boolean;
    procedure CarregaJpegNoBitmap(const AJpegData: TBytes; ADestino: TBitmap);

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
  Result := Assigned(LTCPComponent1) and LTCPComponent1.Active and (not FError);
end;

function TfrmConectionCX10W.UdpReady: Boolean;
begin
  Result := Assigned(LUDPComponent1) and LUDPComponent1.Active and (not FError);
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
    if Assigned(LTCPComponent1) and LTCPComponent1.Active then
      LTCPComponent1.Disconnect(True);
  except
  end;

  try
    if Assigned(LUDPComponent1) and LUDPComponent1.Active then
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
  V: Byte;
begin
  V := 0;

  if High(AData) >= 5 then
  begin
    V := AData[1];
    for I := 2 to 5 do
      V := V xor AData[I];
  end;

  Result := V and $FF;
end;

function TfrmConectionCX10W.BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + IntToHex(AData[I], 2);
end;

procedure TfrmConectionCX10W.AtualizaTelemetria(const AData: TBytes; AOrigem: TTelemetriaOrigem);
begin
  FUltimaTelemetriaHex := BytesToHex(AData);
  FUltimaTelemetriaOrigem := AOrigem;
  FUltimaTelemetriaDataHora := Now;
  FUltimaTelemetriaTamanho := Length(AData);

  case AOrigem of
    toTCP:
      begin
        FUltimoPacoteTCPHex := FUltimaTelemetriaHex;
        Inc(FTotalPacotesTCP);
      end;
    toUDP:
      begin
        FUltimoPacoteUDPHex := FUltimaTelemetriaHex;
        Inc(FTotalPacotesUDP);
      end;
  end;
end;

procedure TfrmConectionCX10W.CarregaJpegNoBitmap(const AJpegData: TBytes; ADestino: TBitmap);
var
  MS: TMemoryStream;
  Reader: TFPReaderJPEG;
  IntfImg: TLazIntfImage;
begin
  if not Assigned(ADestino) then
    Exit;

  if Length(AJpegData) = 0 then
    Exit;

  MS := TMemoryStream.Create;
  Reader := TFPReaderJPEG.Create;
  IntfImg := TLazIntfImage.Create(0, 0);
  try
    MS.WriteBuffer(AJpegData[0], Length(AJpegData));
    MS.Position := 0;

    IntfImg.LoadFromStream(MS, Reader);
    ADestino.LoadFromIntfImage(IntfImg);
  finally
    IntfImg.Free;
    Reader.Free;
    MS.Free;
  end;
end;

function TfrmConectionCX10W.ExtraiJPEGDoBuffer: Boolean;
var
  P: PByte;
  I, InicioJPEG, FimJPEG: Integer;
  Temp: TMemoryStream;
  BufferBytes: PByte;
  Tamanho: Integer;
begin
  Result := False;

  if not Assigned(FVideoBuffer) then
    Exit;

  if FVideoBuffer.Size < 4 then
    Exit;

  InicioJPEG := -1;
  FimJPEG := -1;

  Tamanho := FVideoBuffer.Size;
  BufferBytes := FVideoBuffer.Memory;

  for I := 0 to Tamanho - 2 do
  begin
    P := BufferBytes + I;
    if (P^ = $FF) and ((P + 1)^ = $D8) then
    begin
      InicioJPEG := I;
      Break;
    end;
  end;

  if InicioJPEG < 0 then
    Exit;

  for I := InicioJPEG + 2 to Tamanho - 2 do
  begin
    P := BufferBytes + I;
    if (P^ = $FF) and ((P + 1)^ = $D9) then
    begin
      FimJPEG := I + 1;
      Break;
    end;
  end;

  if (FimJPEG <= InicioJPEG) then
    Exit;

  Temp := TMemoryStream.Create;
  try
    Temp.WriteBuffer((BufferBytes + InicioJPEG)^, FimJPEG - InicioJPEG + 1);
    if CarregaJPEGNoBitmap(Temp) then
      Result := True;
  finally
    Temp.Free;
  end;

  Temp := TMemoryStream.Create;
  try
    if FimJPEG + 1 < Tamanho then
      Temp.WriteBuffer((BufferBytes + FimJPEG + 1)^, Tamanho - (FimJPEG + 1));
    FVideoBuffer.Clear;
    if Temp.Size > 0 then
    begin
      Temp.Position := 0;
      FVideoBuffer.CopyFrom(Temp, Temp.Size);
    end;
  finally
    Temp.Free;
  end;
end;

procedure TfrmConectionCX10W.ProcessaBytesTCP(const AData: TBytes);
begin
  if Length(AData) = 0 then
    Exit;

  FVideoBuffer.Position := FVideoBuffer.Size;
  FVideoBuffer.WriteBuffer(AData[0], Length(AData));

  while ExtraiJPEGDoBuffer do
  begin
    { continua enquanto houver mais de um frame no buffer }
  end;
end;

procedure TfrmConectionCX10W.FormCreate(Sender: TObject);
begin
  FError := False;
  FX := $7F;
  FY := $7F;
  FZ := $7F;
  FB1 := 0;
  FB2 := 0;
  FB3 := 0;
  FB4 := 0;
  FB5 := 0;
  FB6 := 0;
  timerJoystick.Enabled := False;

  FBitmap := TBitmap.Create;
  FVideoBuffer := TMemoryStream.Create;
  FUltimaImagemDataHora := 0;

  FUltimaTelemetriaHex := '';
  FUltimaTelemetriaOrigem := toNenhuma;
  FUltimaTelemetriaDataHora := 0;
  FUltimaTelemetriaTamanho := 0;
  FUltimoPacoteTCPHex := '';
  FUltimoPacoteUDPHex := '';
  FTotalPacotesTCP := 0;
  FTotalPacotesUDP := 0;
end;

procedure TfrmConectionCX10W.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FBitmap);
  FreeAndNil(FVideoBuffer);
end;

procedure TfrmConectionCX10W.Label5Click(Sender: TObject);
begin
end;

procedure TfrmConectionCX10W.lbStateConectionChangeBounds(Sender: TObject);
begin
  Log(lbStateConection.Caption);
end;

procedure TfrmConectionCX10W.LTCPComponent1Accept(aSocket: TLSocket);
begin
  SetStatus('Accept connection');
end;

procedure TfrmConectionCX10W.LTCPComponent1Connect(aSocket: TLSocket);
begin
  SetStatus('Connection open');

  sendMagicPackets;
  Sleep(1000);
  Application.ProcessMessages;

  { habilitação de vídeo }
  sendMagicPacketsVideo1;
  Sleep(500);
  Application.ProcessMessages;

  sendMagicPacketsVideo2;
  Sleep(500);
  Application.ProcessMessages;

  AtivaJoystick;

  if Assigned(frmMain) then
    frmMain.AtivouDrone;

  Application.ProcessMessages;
end;

procedure TfrmConectionCX10W.AtivaJoystick;
begin
  timerJoystick.Enabled := True;
end;

procedure TfrmConectionCX10W.DesativaJoystick;
begin
  timerJoystick.Enabled := False;
  if Assigned(frmMain) then
    frmMain.DesativaJoystick;
end;

procedure TfrmConectionCX10W.LTCPComponent1Disconnect(aSocket: TLSocket);
begin
  SetStatus('Connection close');
  DesativaJoystick;
end;

procedure TfrmConectionCX10W.DesativaConnection;
begin
  FError := True;
  DesativaJoystick;
  DisconnectSockets;
  UpdateMainOfflineState;
  Hide;
end;

procedure TfrmConectionCX10W.LTCPComponent1Error(const msg: string; aSocket: TLSocket);
begin
  SetStatus('Erro connection: ' + msg);
  FError := True;
  DesativaConnection;
end;

procedure TfrmConectionCX10W.LTCPComponent1Receive(aSocket: TLSocket);
var
  Buffer: array[0..8191] of Byte;
  Lidos: Integer;
  Dados: TBytes;
begin
  Lidos := aSocket.Get(Buffer[0], SizeOf(Buffer));

  if Lidos <= 0 then
    Exit;

  SetLength(Dados, Lidos);
  Move(Buffer[0], Dados[0], Lidos);

  AtualizaTelemetria(Dados, toTCP);
  ProcessaBytesTCP(Dados);

  Log('RECEIVE_TCP: ' + FUltimoPacoteTCPHex);
end;

procedure TfrmConectionCX10W.LUDPComponent1Error(const msg: string; aSocket: TLSocket);
begin
  Log('UDP_Erro: ' + msg);
  FError := True;
end;

procedure TfrmConectionCX10W.LUDPComponent1Receive(aSocket: TLSocket);
var
  Buffer: array[0..2047] of Byte;
  Lidos: Integer;
  Dados: TBytes;
begin
  Lidos := aSocket.Get(Buffer[0], SizeOf(Buffer));

  if Lidos <= 0 then
    Exit;

  SetLength(Dados, Lidos);
  Move(Buffer[0], Dados[0], Lidos);

  AtualizaTelemetria(Dados, toUDP);

  Log('RECEIVE_UDP: ' + FUltimoPacoteUDPHex);
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

  if Mudou then
    sendGamepadData;
end;

procedure TfrmConectionCX10W.sendMagicPackets;
begin
  if not TcpReady then
    Exit;

  try
    LTCPComponent1.Send(MAGIC_BYTES_CTRL, Length(MAGIC_BYTES_CTRL));
    Log('SEND_TCP CTRL: ' + IntToStr(Length(MAGIC_BYTES_CTRL)) + ' bytes');
  except
    on E: Exception do
    begin
      FError := True;
      Log('Erro ao enviar pacote CTRL: ' + E.Message);
    end;
  end;
end;

procedure TfrmConectionCX10W.sendMagicPacketsVideo1;
begin
  if not TcpReady then
    Exit;

  try
    LTCPComponent1.Send(MAGIC_BYTES_VIDEO_1A, Length(MAGIC_BYTES_VIDEO_1A));
    LTCPComponent1.Send(MAGIC_BYTES_VIDEO_1B, Length(MAGIC_BYTES_VIDEO_1B));
    Log('SEND_TCP VIDEO1');
  except
    on E: Exception do
    begin
      FError := True;
      Log('Erro ao enviar pacote VIDEO1: ' + E.Message);
    end;
  end;
end;

procedure TfrmConectionCX10W.sendMagicPacketsVideo2;
begin
  if not TcpReady then
    Exit;

  try
    LTCPComponent1.Send(MAGIC_BYTES_VIDEO_2, Length(MAGIC_BYTES_VIDEO_2));
    Log('SEND_TCP VIDEO2');
  except
    on E: Exception do
    begin
      FError := True;
      Log('Erro ao enviar pacote VIDEO2: ' + E.Message);
    end;
  end;
end;

procedure TfrmConectionCX10W.sendGamepadData;
var
  DataArray: array[0..7] of Byte;
  I: Integer;
  Info: string;
begin
  if not UdpReady then
  begin
    Log('UDP Erro: componente inativo');
    FError := True;
    Exit;
  end;

  for I := 0 to 7 do
    DataArray[I] := DEFAULT_PACKET[I];

  DataArray[1] := FZ;
  DataArray[2] := FX;
  DataArray[3] := FY;
  DataArray[4] := FB1;
  DataArray[5] := FB2;
  DataArray[6] := BuildChecksum(DataArray);

  Info := '';
  for I := 0 to High(DataArray) do
    Info := Info + IntToHex(DataArray[I], 2);

  try
    LUDPComponent1.Send(DataArray, Length(DataArray));
    Log('SEND_UDP: ' + Info);
  except
    on E: Exception do
    begin
      FError := True;
      Log('Erro ao enviar UDP: ' + E.Message);
    end;
  end;
end;

procedure TfrmConectionCX10W.PegaConfiguracao;
var
  VTcpPort, VUdpPort: Integer;
begin
  Log('Configuration Begin');

  if not Assigned(frmconfig) then
  begin
    FError := True;
    SetStatus('Configuração indisponível');
    Exit;
  end;

  lbIP.Caption := Trim(frmconfig.edIP.Text);
  lbTCP.Caption := Trim(frmconfig.edTCPPORT.Text);
  lbUDP.Caption := Trim(frmconfig.edUDPPORT.Text);
  lbStateConection.Caption := 'Offline';

  VTcpPort := SafeStrToInt(lbTCP.Caption, 0);
  VUdpPort := SafeStrToInt(lbUDP.Caption, 0);

  if lbIP.Caption = '' then
  begin
    FError := True;
    SetStatus('IP inválido');
    Exit;
  end;

  if (VTcpPort <= 0) or (VTcpPort > 65535) then
  begin
    FError := True;
    SetStatus('Porta TCP inválida');
    Exit;
  end;

  if (VUdpPort <= 0) or (VUdpPort > 65535) then
  begin
    FError := True;
    SetStatus('Porta UDP inválida');
    Exit;
  end;

  DisconnectSockets;

  LTCPComponent1.Host := lbIP.Caption;
  LUDPComponent1.Host := lbIP.Caption;
  LTCPComponent1.Port := VTcpPort;
  LUDPComponent1.Port := VUdpPort;

  FError := False;
end;

procedure TfrmConectionCX10W.InicioHandShake;
var
  VTcpPort, VUdpPort: Integer;
begin
  FError := False;
  Log('Hand Shake');
  SetStatus('Connecting...');

  VTcpPort := SafeStrToInt(lbTCP.Caption, 0);
  VUdpPort := SafeStrToInt(lbUDP.Caption, 0);

  if (lbIP.Caption = '') or (VTcpPort <= 0) or (VUdpPort <= 0) then
  begin
    FError := True;
    SetStatus('Fail: configuração inválida');
    Exit;
  end;

  try
    LTCPComponent1.Connect(lbIP.Caption, VTcpPort);
    LUDPComponent1.Connect(lbIP.Caption, VUdpPort);
  except
    on E: Exception do
    begin
      Log('Hand Shake fail: ' + E.Message);
      SetStatus('Fail...');
      FError := True;
    end;
  end;
end;

end.
