unit GPS;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  gpstarget, gpsskyplot, gpssignalplot;

type

  { TfrmGPS }

  TfrmGPS = class(TForm)
    GPSSignalPlot1: TGPSSignalPlot;
    GPSSkyPlot1: TGPSSkyPlot;
    GPSTarget1: TGPSTarget;
    pnGPS: TPanel;
  private

  public

  end;

var
  frmGPS: TfrmGPS;

implementation

{$R *.lfm}

end.

