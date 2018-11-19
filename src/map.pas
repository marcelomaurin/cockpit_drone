unit map;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, BCGameGrid;

type

  { TfrmMap }

  TfrmMap = class(TForm)
    gridMAP: TBCGameGrid;
    Image2: TImage;
    Label9: TLabel;
  private

  public

  end;

var
  frmMap: TfrmMap;

implementation

{$R *.lfm}

end.

