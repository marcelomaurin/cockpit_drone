unit Camera;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, BCGameGrid, LCLType;

type

  { TfrmCam }

  TfrmCam = class(TForm)
    gridCam: TBCGameGrid;
    Image1: TImage;
    Label1: TLabel;
    Label8: TLabel;
    tmAtualizaImagem: TTimer;

    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Image1DblClick(Sender: TObject);
    procedure tmAtualizaImagemStartTimer(Sender: TObject);
    procedure tmAtualizaImagemStopTimer(Sender: TObject);
    procedure tmAtualizaImagemTimer(Sender: TObject);

  private
    FCameraAtiva: Boolean;
    FGridAtiva: Boolean;

    procedure AjustaLayout;
    procedure AtualizaVisualEstado;
    procedure AtualizaDaConexao;

  public
    procedure AtivaCamera;
    procedure DesativaCamera;
    procedure AlternaCamera;
    procedure MostrarGrid;
    procedure OcultarGrid;
    procedure AlternaGrid;
    procedure DefineStatus(const ATexto: string);
    procedure LimpaImagem;

    property CameraAtiva: Boolean read FCameraAtiva;
    property GridAtiva: Boolean read FGridAtiva;
  end;

var
  frmCam: TfrmCam;

implementation

{$R *.lfm}

uses
  main, ConectionCX10W;

{ TfrmCam }

procedure TfrmCam.FormCreate(Sender: TObject);
begin
  KeyPreview := True;

  FCameraAtiva := False;
  FGridAtiva := True;

  Caption := 'Câmera';
  Label1.Caption := 'Visualização da Câmera';
  Label8.Caption := 'OFFLINE';

  if Assigned(Image1) then
  begin
    Image1.Align := alClient;
    Image1.Center := True;
    Image1.Stretch := True;
    Image1.Proportional := True;
  end;

  if Assigned(gridCam) then
  begin
    gridCam.Align := alClient;
    gridCam.Visible := True;
    gridCam.BringToFront;
  end;

  if Assigned(tmAtualizaImagem) then
  begin
    tmAtualizaImagem.Enabled := False;
    tmAtualizaImagem.Interval := 200;
  end;

  AtualizaVisualEstado;
  AjustaLayout;
end;

procedure TfrmCam.FormResize(Sender: TObject);
begin
  AjustaLayout;
end;

procedure TfrmCam.FormShow(Sender: TObject);
begin
  if FCameraAtiva then
    tmAtualizaImagem.Enabled := True;

  AtualizaVisualEstado;
  AjustaLayout;
  AtualizaDaConexao;
end;

procedure TfrmCam.FormHide(Sender: TObject);
begin
  if Assigned(tmAtualizaImagem) then
    tmAtualizaImagem.Enabled := False;

  Label8.Caption := 'OCULTA';
end;

procedure TfrmCam.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_ESCAPE:
      Hide;

    VK_F2:
      AlternaGrid;

    VK_F5:
      AlternaCamera;
  end;
end;

procedure TfrmCam.Image1DblClick(Sender: TObject);
begin
  AlternaGrid;
end;

procedure TfrmCam.tmAtualizaImagemStartTimer(Sender: TObject);
begin

end;

procedure TfrmCam.tmAtualizaImagemStopTimer(Sender: TObject);
begin

end;

procedure TfrmCam.tmAtualizaImagemTimer(Sender: TObject);
begin
  AtualizaDaConexao;
end;

procedure TfrmCam.AjustaLayout;
begin
  if Assigned(Image1) then
    Image1.SendToBack;

  if Assigned(gridCam) and FGridAtiva then
    gridCam.BringToFront;
end;

procedure TfrmCam.AtualizaVisualEstado;
begin
  if FCameraAtiva then
  begin
    if Showing then
      Label8.Caption := 'ONLINE'
    else
      Label8.Caption := 'ATIVA';
  end
  else
  begin
    Label8.Caption := 'OFFLINE';
  end;

  if Assigned(gridCam) then
    gridCam.Visible := FGridAtiva;
end;

procedure TfrmCam.AtualizaDaConexao;
var
  Conn: TfrmConectionCX10W;
begin
  if not FCameraAtiva then
  begin
    DefineStatus('OFFLINE');
    Exit;
  end;

  if not Assigned(frmMain) then
  begin
    DefineStatus('MAIN INDISPONÍVEL');
    Exit;
  end;

  if not Assigned(frmMain.frmConnection) then
  begin
    DefineStatus('SEM CONEXÃO');
    Exit;
  end;

  if not (frmMain.frmConnection is TfrmConectionCX10W) then
  begin
    DefineStatus('CONEXÃO INVÁLIDA');
    Exit;
  end;

  Conn := TfrmConectionCX10W(frmMain.frmConnection);

  if Assigned(Conn.Bitmap) and (Conn.Bitmap.Width > 0) and (Conn.Bitmap.Height > 0) then
  begin
    Image1.Picture.Bitmap.Assign(Conn.Bitmap);

    if Conn.UltimaImagemDataHora > 0 then
      DefineStatus(
        'ONLINE  IMG: ' +
        FormatDateTime('hh:nn:ss', Conn.UltimaImagemDataHora) +
        '  TCP:' + IntToStr(Conn.TotalPacotesTCP) +
        '  UDP:' + IntToStr(Conn.TotalPacotesUDP)
      )
    else
      DefineStatus(
        'ONLINE  TCP:' + IntToStr(Conn.TotalPacotesTCP) +
        '  UDP:' + IntToStr(Conn.TotalPacotesUDP)
      );
  end
  else
  begin
    DefineStatus(
      'SEM IMAGEM  TCP:' + IntToStr(Conn.TotalPacotesTCP) +
      '  UDP:' + IntToStr(Conn.TotalPacotesUDP)
    );
  end;
end;

procedure TfrmCam.AtivaCamera;
begin
  FCameraAtiva := True;

  if Assigned(tmAtualizaImagem) then
    tmAtualizaImagem.Enabled := True;

  AtualizaVisualEstado;
  AtualizaDaConexao;
end;

procedure TfrmCam.DesativaCamera;
begin
  FCameraAtiva := False;

  if Assigned(tmAtualizaImagem) then
    tmAtualizaImagem.Enabled := False;

  AtualizaVisualEstado;
end;

procedure TfrmCam.AlternaCamera;
begin
  if FCameraAtiva then
    DesativaCamera
  else
    AtivaCamera;
end;

procedure TfrmCam.MostrarGrid;
begin
  FGridAtiva := True;
  AtualizaVisualEstado;
  AjustaLayout;
end;

procedure TfrmCam.OcultarGrid;
begin
  FGridAtiva := False;
  AtualizaVisualEstado;
end;

procedure TfrmCam.AlternaGrid;
begin
  FGridAtiva := not FGridAtiva;
  AtualizaVisualEstado;
  AjustaLayout;
end;

procedure TfrmCam.DefineStatus(const ATexto: string);
begin
  Label8.Caption := Trim(ATexto);
end;

procedure TfrmCam.LimpaImagem;
begin
  if Assigned(Image1) and Assigned(Image1.Picture) then
    Image1.Picture.Clear;
end;

end.
