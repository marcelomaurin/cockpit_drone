unit Camera;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, BCGameGrid;

type

  { TfrmCam }

  TfrmCam = class(TForm)
    gridCam: TBCGameGrid;
    Image1: TImage;
    Label1: TLabel;
    Label8: TLabel;
  private

  public

  end;

var
  frmCam: TfrmCam;

implementation

{$R *.lfm}

end.

