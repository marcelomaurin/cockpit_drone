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
    procedure GPSPortConnected1Show(Sender: TObject);
    procedure GPSSignalPlot1Click(Sender: TObject);
    procedure NMEADecode1NMEA(Sender: TObject; NMEA: TNMEADecode);
    procedure SdpoSerial1RxData(Sender: TObject);
  private
    buffer : string;
  public

  end;

var
  frmGPS: TfrmGPS;

implementation

{$R *.lfm}

{ TfrmGPS }

uses main;

procedure TfrmGPS.FormShow(Sender: TObject);
begin
  try
   SdpoSerial1.Close;
   SdpoSerial1.Device :=  frmconfig.edSerialPort.Text;
   SdpoSerial1.BaudRate:= TBaudRate(frmconfig.cbBaudrate.ItemIndex);
   SdpoSerial1.DataBits:= TDataBits(frmconfig.cbDatabits.ItemIndex);
   SdpoSerial1.FlowControl:= TFlowControl(frmconfig.rgFlowControl.ItemIndex);
   SdpoSerial1.StopBits:= TStopBits(frmConfig.rgStopbit.ItemIndex);
   if frmconfig.ckbGPS.Checked then
   begin
        //SdpoSerial1.Open;
        //GPSPortConnected1.SetupPort;
        GPSPortConnected1.OpenPort;
        //GPSPortConnected1.Active:= true;
        //GPSPortConnected1.Position;
        GPSPortConnected1.DoShow;
        //GPSPortConnected1.Execute := true;

        frmmain.AtivaGPS();
   end;

  except
        frmmain.DesativaGPS();
  end;
end;

procedure TfrmGPS.FormCreate(Sender: TObject);
begin
  GPSSignalPlot1.NMEADecode := NMEADecode1;
  GPSSkyPlot1.NMEADecode := nmeadecode1;
  GPSTarget1.NMEADecode := nmeadecode1;
  buffer := '';
end;

procedure TfrmGPS.GPSPortConnected1Show(Sender: TObject);
begin
  memo1.Lines.Append(datetimetostr(now)+':GPS PORT:Connected ');

end;

procedure TfrmGPS.GPSSignalPlot1Click(Sender: TObject);
begin

end;

procedure TfrmGPS.NMEADecode1NMEA(Sender: TObject; NMEA: TNMEADecode);
var
  dLat, dLong, dSpeed : double;
  fvalid : boolean;
begin
  case NMEA.MessageType of
    GGAMsg :
      begin
        with NMEA.GGA do
        begin
          //lblGGAGeoidal.Caption := Separation + ' ' + SeparationUnits;
          //lblGGAAltitude.Caption := Altitude + ' ' + AltitudeUnits;
          //lblGGASatCount.Caption := SatsInUse;
          if (trystrtofloat(LatitudeDegree, dLat)) then
          begin
            //lblGGALat.Caption := format('%9.6f', [abs(dLat)]) + ' (' + LatHemis + ')';
          end;
          if (trystrtofloat(LongitudeDegree, dLong)) then
          begin
            //lblGGALong.Caption := format('%9.6f', [abs(dLong)]) + ' (' + LongHemis + ')';
          end;
          //lblGGAHDOP.Caption := HDOP;
          //lblGGAUTCTime.Caption := UTC;
          if (FixQuality = '0') then
            //lblGGAQuality.Caption := 'Invalid'
          else if (FixQuality = '1') then
            //lblGGAQuality.Caption := 'GPS Fix'
          else if (FixQuality = '2') then
            //lblGGAQuality.Caption := 'DGPS Fix';
        end;
      end;
    GSAMsg :
      begin
        with NMEA.GSA do
        begin
          if (FixStatus = '1') then
            //lblGSAFix.Caption := 'Fix not available'
          else if (FixStatus = '2') then
            //lblGSAFix.Caption := FixStatus + 'D'
          else if (FixStatus = '3') then
            //lblGSAFix.Caption := FixStatus + 'D';
          if (Mode = 'A') then
            //lblGSAMode.Caption := 'Automatic 2D/3D'
          else if (Mode = 'M') then
            //lblGSAMode.Caption := 'Manual';
          //lblGSAHDOP.Caption := HDOP;
          //lblGSAVDOP.Caption := VDOP;
          //lblGSAPDOP.Caption := PDOP;
        end;
      end;
    RMCMsg :
      begin
        with NMEA.RMC do
        begin
          if (Status = 'A') then
            //lblRMCValidity.Caption := 'Active'
          else if (Status = 'V') then
            //lblRMCValidity.Caption := 'Invalid';
          if trystrtofloat(LatitudeDegree, dLat) then
            //lblRMCLat.Caption := format('%9.6f', [abs(dLat)]) + ' (' + LatHemis + ')';
          if trystrtofloat(LongitudeDegree, dLong) then
            //lblRMCLong.Caption := format('%9.6f', [abs(dLong)]) + ' (' + LongHemis + ')';
          if (trystrtofloat(Speed, dSpeed)) then
            //lblRMCSpeed.Caption := format('%5.1f', [dSpeed * 1.852]) + ' Km/h';
          //lblRMCDate.Caption := UTCDate;
          //lblRMCTime.Caption := UTCTime;
          //lblRMCTrue.Caption := TrueCourse;
          if (MagneticVariation = '-9999') then
            //lblRMCMagVar.Caption := ''
          else
            //lblRMCMagVar.Caption := MagneticVariation + ' ' + MagDeviation;
        end
      end;
    WPLMsg :
      begin
        with NMEA.WPL do
        begin
          //lblWPName.Caption := WayPointName;
          //lblWPLatitude.Caption := Latitude;
          //lblWPLongitude.Caption := Longitude;
        end;
      end;
    GLLMsg :
      begin
        with NMEA.GLL do
        begin
          dLat := abs(strtofloat(LatitudeDegree));
          dLong := abs(strtofloat(LongitudeDegree));
          lblGLLLat.Caption := format('%9.6f', [dLat]) + ' (' + LatHemis + ')';
          lblGLLLong.Caption := format('%9.6f', [dLong]) + ' (' + LongHemis + ')';
          lblGLLTime.Caption := UTCTime;
          if (Status = 'A') then
            //lblGLLStatus.Caption := 'Valid'
          else if (Status = 'V') then
            //lblGLLStatus.Caption := 'Invalid';
        end;
      end;
    PGRMMsg:
      begin
        with NMEA.PGRMM do
          //lblGarminMapDatum.Caption := MapDatum;
      end;
    PGRMZMsg:
      begin
        with NMEA.PGRMZ do
        begin
          if (UnitAltitude = 'f') then
            //lblGarminAltitude.Caption := Altitude + ' ' + 'Feet'
          else
            begin
            //lblGarminAltitude.Caption := Altitude + ' ' + UnitAltitude;
            end;
          //lblGarminPosFix.Caption := PositionFix;

        end;
      end;
    PGRMEMsg:
      begin
        with NMEA.PGRME do
        begin
          //lblGarminHPE.Caption := HPE + ' ' + UnitHPE;
          //lblGarminVPE.Caption := VPE + ' ' + UnitVPE;
          //lblGarminSEPE.Caption := SEPE + ' ' + UnitSEPE;
        end;
      end;
  end;
end;

procedure TfrmGPS.SdpoSerial1RxData(Sender: TObject);
var
  Instring: string;
  posicao: integer;
  cmd : string;
begin

       InString := SdpoSerial1.ReadData;

       if InString = '' then
       begin
         exit;
       end;


       buffer := buffer +  Instring;
       NMEADecode1.Sentence := Instring;
       posicao := pos(#13,buffer);
       if (posicao > 0) then
       begin
            cmd :=copy(buffer,1,posicao);
            if (cmd <>'') then
            begin
              memo1.Lines.Append(datetimetostr(now)+':Buffer:'+cmd);
              buffer := copy(buffer,posicao+1,length(buffer));
            end;
       end;
       Application.ProcessMessages;
end;

end.

