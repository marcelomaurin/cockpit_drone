unit About;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls;

type

  { TfrmAbout }

  TfrmAbout = class(TForm)
    Image1: TImage;
    Label1: TLabel;
    Label2: TLabel;
    lbversao: TLabel;
    procedure FormShow(Sender: TObject);
  private

  public

  end;

var
  frmAbout: TfrmAbout;

implementation

{$R *.lfm}

{ TfrmAbout }

uses main;

procedure TfrmAbout.FormShow(Sender: TObject);
begin
  lbversao.Caption := 'Versão ' + FloatToStr(versao);
end;



end.
