unit GPS;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  gpstarget, gpsskyplot, gpssignalplot, gpsportconnected, nmeadecode, LazSerial,
  SdpoSerial;

type

  { TfrmGPS }

  TfrmGPS = class(TForm)
    GPSPortConnected1: TGPSPortConnected;
    GPSSignalPlot1: TGPSSignalPlot;
    GPSSkyPlot1: TGPSSkyPlot;
    GPSTarget1: TGPSTarget;
    NMEADecode1: TNMEADecode;
    pnGPS: TPanel;
    SdpoSerial1: TSdpoSerial;
  private

  public

  end;

var
  frmGPS: TfrmGPS;

implementation

{$R *.lfm}

end.

