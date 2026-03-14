unit GPS;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, ComCtrls, gpstarget, gpsskyplot, gpssignalplot, gpsportconnected,
  nmeadecode, LazSerial, AdvLed, SdpoSerial, config;

type

  { TfrmGPS }

  TfrmGPS = class(TForm)
    GPSPortConnected1: TGPSPortConnected;
    GPSSignalPlot1: TGPSSignalPlot;
    GPSSkyPlot1: TGPSSkyPlot;
    GPSTarget1: TGPSTarget;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    lblGLLTime: TLabel;
    lblGLLLong: TLabel;
    lblGLLLat: TLabel;
    Memo1: TMemo;
    NMEADecode1: TNMEADecode;
    PageControl1: TPageControl;
    pnGPS: TPanel;
    SdpoSerial1: TSdpoSerial;
    tslog: TTabSheet;
    tbSAT: TTabSheet;
    tsSignal: TTabSheet;
    tslocation: TTabSheet;

    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure GPSPortConnected1Show(Sender: TObject);
    procedure GPSSignalPlot1Click(Sender: TObject);
    procedure NMEADecode1NMEA(Sender: TObject; NMEA: TNMEADecode);
    procedure SdpoSerial1RxData(Sender: TObject);

  private
    FBuffer: string;

    FLatitude: Double;
    FLongitude: Double;
    FAltitude: Double;
    FVelocidade: Double;
    FCurso: Double;
    FHDOP: Double;
    FVDOP: Double;
    FPDOP: Double;

    FSatelites: Integer;
    FFixQuality: Integer;
    FFixStatus: Integer;
    FModoFix: string;

    FDataUTC: string;
    FHoraUTC: string;

    FTemPosicao: Boolean;
    FTemAltitude: Boolean;

    procedure Log(const AMsg: string);
    procedure EnsureConfig;
    procedure ConfiguraSerial;
    procedure AbrirGPS;
    procedure FecharGPS;
    procedure ProcessaBufferNMEA;
    function SafeStrToFloat(const S: string; out V: Double): Boolean;
    function SafeStrToInt(const S: string; out V: Integer): Boolean;

  public
    procedure Atualiza;

    property Latitude: Double read FLatitude;
    property Longitude: Double read FLongitude;
    property Altitude: Double read FAltitude;
    property Velocidade: Double read FVelocidade;
    property Curso: Double read FCurso;
    property Satelites: Integer read FSatelites;
    property HDOP: Double read FHDOP;
    property VDOP: Double read FVDOP;
    property PDOP: Double read FPDOP;
    property FixQuality: Integer read FFixQuality;
    property FixStatus: Integer read FFixStatus;
    property ModoFix: string read FModoFix;
    property DataUTC: string read FDataUTC;
    property HoraUTC: string read FHoraUTC;
    property TemPosicao: Boolean read FTemPosicao;
    property TemAltitude: Boolean read FTemAltitude;
  end;

var
  frmGPS: TfrmGPS;

implementation

{$R *.lfm}

uses
  main;

{ TfrmGPS }

procedure TfrmGPS.Log(const AMsg: string);
begin
  if Assigned(Memo1) then
    Memo1.Lines.Append(FormatDateTime('dd/mm/yyyy hh:nn:ss', Now) + ': ' + AMsg);
end;

procedure TfrmGPS.EnsureConfig;
begin
  if not Assigned(frmconfig) then
    frmconfig := Tfrmconfig.Create(Self);
end;

function TfrmGPS.SafeStrToFloat(const S: string; out V: Double): Boolean;
var
  T: string;
begin
  T := Trim(S);
  T := StringReplace(T, ',', FormatSettings.DecimalSeparator, [rfReplaceAll]);
  T := StringReplace(T, '.', FormatSettings.DecimalSeparator, [rfReplaceAll]);
  Result := TryStrToFloat(T, V);
end;

function TfrmGPS.SafeStrToInt(const S: string; out V: Integer): Boolean;
begin
  Result := TryStrToInt(Trim(S), V);
end;

procedure TfrmGPS.ConfiguraSerial;
begin
  EnsureConfig;

  if SdpoSerial1.Active then
    SdpoSerial1.Close;

  SdpoSerial1.Device := Trim(frmconfig.edSerialPort.Text);
  SdpoSerial1.BaudRate := TBaudRate(frmconfig.cbBaudrate.ItemIndex);
  SdpoSerial1.DataBits := TDataBits(frmconfig.cbDatabits.ItemIndex);
  SdpoSerial1.FlowControl := TFlowControl(frmconfig.rgFlowControl.ItemIndex);
  SdpoSerial1.StopBits := TStopBits(frmconfig.rgStopbit.ItemIndex);
end;

procedure TfrmGPS.AbrirGPS;
begin
  EnsureConfig;

  if not frmconfig.ckbGPS.Checked then
  begin
    Log('GPS desabilitado na configuração');
    if Assigned(frmMain) then
      frmMain.DesativaGPS;
    Exit;
  end;

  ConfiguraSerial;

  try
    if not SdpoSerial1.Active then
      SdpoSerial1.Open;

    if Assigned(GPSPortConnected1) then
    begin
      try
        GPSPortConnected1.OpenPort;
      except
      end;

      try
        GPSPortConnected1.DoShow;
      except
      end;
    end;

    Log('GPS ativo na porta ' + SdpoSerial1.Device);

    if Assigned(frmMain) then
      frmMain.AtivaGPS;

  except
    on E: Exception do
    begin
      Log('Erro ao abrir GPS: ' + E.Message);
      if Assigned(frmMain) then
        frmMain.DesativaGPS;
      FecharGPS;
    end;
  end;
end;

procedure TfrmGPS.FecharGPS;
begin
  try
    if Assigned(GPSPortConnected1) then
    begin
      try
        GPSPortConnected1.ClosePort;
      except
      end;
    end;
  except
  end;

  try
    if SdpoSerial1.Active then
      SdpoSerial1.Close;
  except
  end;

  if Assigned(frmMain) then
    frmMain.DesativaGPS;
end;

procedure TfrmGPS.ProcessaBufferNMEA;
var
  P: Integer;
  Linha: string;
begin
  repeat
    P := Pos(#13, FBuffer);
    if P = 0 then
      P := Pos(#10, FBuffer);

    if P > 0 then
    begin
      Linha := Trim(Copy(FBuffer, 1, P - 1));
      Delete(FBuffer, 1, P);

      while (Length(FBuffer) > 0) and ((FBuffer[1] = #10) or (FBuffer[1] = #13)) do
        Delete(FBuffer, 1, 1);

      if Linha <> '' then
      begin
        Log('NMEA: ' + Linha);
        try
          NMEADecode1.Sentence := Linha;
        except
          on E: Exception do
            Log('Erro ao interpretar NMEA: ' + E.Message);
        end;
      end;
    end;
  until P = 0;
end;

procedure TfrmGPS.Atualiza;
var
  dLat, dLong, dAlt, dVel, dCurso, dHDOP, dVDOP, dPDOP: Double;
  iSat, iFixQuality, iFixStatus: Integer;
begin
  FTemPosicao := False;
  FTemAltitude := False;

  { posição e hora - GLL }
  if SafeStrToFloat(NMEADecode1.GLL.LatitudeDegree, dLat) and
     SafeStrToFloat(NMEADecode1.GLL.LongitudeDegree, dLong) then
  begin
    if SameText(NMEADecode1.GLL.LatHemis, 'S') then
      dLat := -Abs(dLat)
    else
      dLat := Abs(dLat);

    if SameText(NMEADecode1.GLL.LongHemis, 'W') then
      dLong := -Abs(dLong)
    else
      dLong := Abs(dLong);

    FLatitude := dLat;
    FLongitude := dLong;
    FTemPosicao := True;
    FHoraUTC := NMEADecode1.GLL.UTCTime;
  end;

  { fallback posição / altitude / satélites / hdop / qualidade - GGA }
  if SafeStrToFloat(NMEADecode1.GGA.LatitudeDegree, dLat) and
     SafeStrToFloat(NMEADecode1.GGA.LongitudeDegree, dLong) then
  begin
    if SameText(NMEADecode1.GGA.LatHemis, 'S') then
      dLat := -Abs(dLat)
    else
      dLat := Abs(dLat);

    if SameText(NMEADecode1.GGA.LongHemis, 'W') then
      dLong := -Abs(dLong)
    else
      dLong := Abs(dLong);

    if not FTemPosicao then
    begin
      FLatitude := dLat;
      FLongitude := dLong;
      FTemPosicao := True;
    end;
  end;

  if SafeStrToFloat(NMEADecode1.GGA.Altitude, dAlt) then
  begin
    FAltitude := dAlt;
    FTemAltitude := True;
  end;

  if SafeStrToInt(NMEADecode1.GGA.SatsInUse, iSat) then
    FSatelites := iSat;

  if SafeStrToFloat(NMEADecode1.GGA.HDOP, dHDOP) then
    FHDOP := dHDOP;

  if SafeStrToInt(NMEADecode1.GGA.FixQuality, iFixQuality) then
    FFixQuality := iFixQuality;

  if NMEADecode1.GGA.UTC <> '' then
    FHoraUTC := NMEADecode1.GGA.UTC;

  { fallback posição / velocidade / curso / data / hora - RMC }
  if SafeStrToFloat(NMEADecode1.RMC.LatitudeDegree, dLat) and
     SafeStrToFloat(NMEADecode1.RMC.LongitudeDegree, dLong) then
  begin
    if SameText(NMEADecode1.RMC.LatHemis, 'S') then
      dLat := -Abs(dLat)
    else
      dLat := Abs(dLat);

    if SameText(NMEADecode1.RMC.LongHemis, 'W') then
      dLong := -Abs(dLong)
    else
      dLong := Abs(dLong);

    if not FTemPosicao then
    begin
      FLatitude := dLat;
      FLongitude := dLong;
      FTemPosicao := True;
    end;
  end;

  if SafeStrToFloat(NMEADecode1.RMC.Speed, dVel) then
    FVelocidade := dVel;

  if SafeStrToFloat(NMEADecode1.RMC.TrueCourse, dCurso) then
    FCurso := dCurso;

  if NMEADecode1.RMC.UTCDate <> '' then
    FDataUTC := NMEADecode1.RMC.UTCDate;

  if NMEADecode1.RMC.UTCTime <> '' then
    FHoraUTC := NMEADecode1.RMC.UTCTime;

  { GSA - fix e dop }
  if SafeStrToInt(NMEADecode1.GSA.FixStatus, iFixStatus) then
    FFixStatus := iFixStatus;

  FModoFix := NMEADecode1.GSA.Mode;

  if SafeStrToFloat(NMEADecode1.GSA.PDOP, dPDOP) then
    FPDOP := dPDOP;

  if SafeStrToFloat(NMEADecode1.GSA.HDOP, dHDOP) then
    FHDOP := dHDOP;

  if SafeStrToFloat(NMEADecode1.GSA.VDOP, dVDOP) then
    FVDOP := dVDOP;

  { fallback altitude - PGRMZ }
  if (not FTemAltitude) and SafeStrToFloat(NMEADecode1.PGRMZ.Altitude, dAlt) then
  begin
    FAltitude := dAlt;
    FTemAltitude := True;
  end;
end;

procedure TfrmGPS.FormCreate(Sender: TObject);
begin
  GPSSignalPlot1.NMEADecode := NMEADecode1;
  GPSSkyPlot1.NMEADecode := NMEADecode1;
  GPSTarget1.NMEADecode := NMEADecode1;

  FBuffer := '';
  FLatitude := 0;
  FLongitude := 0;
  FAltitude := 0;
  FVelocidade := 0;
  FCurso := 0;
  FHDOP := 0;
  FVDOP := 0;
  FPDOP := 0;
  FSatelites := 0;
  FFixQuality := 0;
  FFixStatus := 0;
  FModoFix := '';
  FDataUTC := '';
  FHoraUTC := '';
  FTemPosicao := False;
  FTemAltitude := False;

  lblGLLLat.Caption := '';
  lblGLLLong.Caption := '';
  lblGLLTime.Caption := '';
end;

procedure TfrmGPS.FormShow(Sender: TObject);
begin
  AbrirGPS;
end;

procedure TfrmGPS.FormHide(Sender: TObject);
begin
  FecharGPS;
end;

procedure TfrmGPS.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  FecharGPS;
  CloseAction := caHide;
end;

procedure TfrmGPS.GPSPortConnected1Show(Sender: TObject);
begin
  Log('GPS PORT: Connected');
end;

procedure TfrmGPS.GPSSignalPlot1Click(Sender: TObject);
begin
end;

procedure TfrmGPS.NMEADecode1NMEA(Sender: TObject; NMEA: TNMEADecode);
var
  dLat, dLong, dSpeed: Double;
begin
  case NMEA.MessageType of
    GGAMsg:
      begin
        with NMEA.GGA do
        begin
          if SafeStrToFloat(LatitudeDegree, dLat) then
          begin
          end;

          if SafeStrToFloat(LongitudeDegree, dLong) then
          begin
          end;
        end;
      end;

    GSAMsg:
      begin
      end;

    RMCMsg:
      begin
        with NMEA.RMC do
        begin
          if SafeStrToFloat(LatitudeDegree, dLat) then
          begin
          end;

          if SafeStrToFloat(LongitudeDegree, dLong) then
          begin
          end;

          if SafeStrToFloat(Speed, dSpeed) then
          begin
          end;
        end;
      end;

    WPLMsg:
      begin
      end;

    GLLMsg:
      begin
        with NMEA.GLL do
        begin
          if SafeStrToFloat(LatitudeDegree, dLat) then
            lblGLLLat.Caption := Format('%9.6f', [Abs(dLat)]) + ' (' + LatHemis + ')'
          else
            lblGLLLat.Caption := '';

          if SafeStrToFloat(LongitudeDegree, dLong) then
            lblGLLLong.Caption := Format('%9.6f', [Abs(dLong)]) + ' (' + LongHemis + ')'
          else
            lblGLLLong.Caption := '';

          lblGLLTime.Caption := UTCTime;
        end;
      end;

    PGRMMsg:
      begin
      end;

    PGRMZMsg:
      begin
      end;

    PGRMEMsg:
      begin
      end;
  end;

  Atualiza;
end;

procedure TfrmGPS.SdpoSerial1RxData(Sender: TObject);
var
  InString: string;
begin
  try
    InString := SdpoSerial1.ReadData;

    if InString = '' then
      Exit;

    FBuffer := FBuffer + InString;
    ProcessaBufferNMEA;

  except
    on E: Exception do
      Log('Erro RxData: ' + E.Message);
  end;
end;

end.
