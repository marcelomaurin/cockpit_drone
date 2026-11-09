unit Camera;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, BCGameGrid, LCLType, cockpit_i18n, multiplayer_state;

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
    FParticipants: TLabel;
    FCameraAtiva: Boolean;
    FGridAtiva: Boolean;
    FVisaoAtiva: Boolean;
    FUltimoQuadroVisao: QWord;
    FBotaoVisao: TButton;
    FResultadoVisao: TLabel;
    procedure AlternaVisao(Sender: TObject);
    procedure AtualizaResultadoVisao;

    procedure AjustaLayout;
    procedure AtualizaVisualEstado;
    procedure AtualizaDaConexao;

  public
    procedure SetParticipants(const Items: TParticipants);
    procedure AtivaCamera;
    procedure DesativaCamera;
    procedure AlternaCamera;
    procedure MostrarGrid;
    procedure OcultarGrid;
    procedure AlternaGrid;
    procedure DefineStatus(const ATexto: string);
    procedure LimpaImagem;
    { Exibe um quadro entregue pela conexão (usado pelo FQ777-954). }
    procedure MostraQuadro(ABitmap: TBitmap);

    property CameraAtiva: Boolean read FCameraAtiva;
    property GridAtiva: Boolean read FGridAtiva;
  end;

var
  frmCam: TfrmCam;

implementation

{$R *.lfm}

uses
  setmain, main, conexaodrone, conectionmavlink, conectionopendrone,
  conectionesp32drone;

{ TfrmCam }

procedure TfrmCam.FormCreate(Sender: TObject);
begin
  KeyPreview := True;
  FParticipants := TLabel.Create(Self);
  FParticipants.Parent := Self;
  FParticipants.Align := alBottom;
  FParticipants.Font.Color := clNavy;
  FParticipants.WordWrap := True;


  FCameraAtiva := False;
  FGridAtiva := True;
  FVisaoAtiva := False;
  FUltimoQuadroVisao := 0;
  FBotaoVisao := TButton.Create(Self);
  FBotaoVisao.Parent := Self;
  FBotaoVisao.Align := alBottom;
  FBotaoVisao.Caption := 'Iniciar reconhecimento (pessoas/poses)';
  FBotaoVisao.OnClick := @AlternaVisao;
  FResultadoVisao := TLabel.Create(Self);
  FResultadoVisao.Parent := Self;
  FResultadoVisao.Align := alBottom;
  FResultadoVisao.AutoSize := False;
  FResultadoVisao.Height := 34;
  FResultadoVisao.Caption := 'Visao IA: desativada';

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
    tmAtualizaImagem.Interval := 50;
  end;

  AtualizaVisualEstado;
  AjustaLayout;
end;

procedure TfrmCam.SetParticipants(const Items: TParticipants);
var I: Integer; S: string;
begin
  S := '';
  for I := 0 to High(Items) do
  begin
    if I >= 8 then begin S := S + ' ...'; Break end;
    S := S + Format('%s (%.0f m; alt %.0f m)  ',
      [Items[I].Name, Items[I].Distance, Items[I].Altitude]);
  end;
  FParticipants.Caption := 'Participantes proximos: ' + S;
  FParticipants.Visible := Length(Items) > 0;
end;

procedure TfrmCam.FormResize(Sender: TObject);
begin
  AjustaLayout;
end;

procedure TfrmCam.FormShow(Sender: TObject);
begin
  AplicarIdioma(Self);
  AtivaCamera;
  AtualizaVisualEstado;
  AjustaLayout;
  AtualizaDaConexao;
end;

procedure TfrmCam.FormHide(Sender: TObject);
begin
  DesativaCamera;
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
  AtualizaResultadoVisao;
end;

procedure TfrmCam.AlternaVisao(Sender: TObject);
begin
  FVisaoAtiva := not FVisaoAtiva;
  if FVisaoAtiva then
    FBotaoVisao.Caption := 'Parar reconhecimento'
  else
    FBotaoVisao.Caption := 'Iniciar reconhecimento (pessoas/poses)';
  if not FVisaoAtiva then FResultadoVisao.Caption := 'Visao IA: desativada';
end;

procedure TfrmCam.AtualizaResultadoVisao;
var
  L: TStringList;
  P: string;
begin
  if not FVisaoAtiva then Exit;
  P := GetAppConfigDir(False) + 'vision_result.txt';
  if not FileExists(P) then
  begin
    FResultadoVisao.Caption := 'Visao IA: aguardando analisador Python';
    Exit;
  end;
  L := TStringList.Create;
  try
    L.LoadFromFile(P);
    if L.Count > 0 then FResultadoVisao.Caption := Copy(L[0], 1, 150);
  finally
    L.Free;
  end;
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

procedure TfrmCam.MostraQuadro(ABitmap: TBitmap);
begin
  if FCameraAtiva and Assigned(ABitmap) and (ABitmap.Width > 0) then
  begin
    Image1.Picture.Bitmap.Assign(ABitmap);
    if FVisaoAtiva and (GetTickCount64 - FUltimoQuadroVisao >= 1000) then
    begin
      FUltimoQuadroVisao := GetTickCount64;
      ForceDirectories(GetAppConfigDir(False));
      try
        Image1.Picture.Bitmap.SaveToFile(GetAppConfigDir(False) + 'vision_frame.bmp');
      except
        on E: Exception do FResultadoVisao.Caption := 'Erro ao salvar quadro: ' + E.Message;
      end;
    end;
  end;
end;

procedure TfrmCam.AtualizaDaConexao;
var
  Conn: TfrmConexaoDrone;
  SimCamFile: string;
  SimDt: TDateTime;
  SimFS: TFileStream;
  BmpSim: TBitmap;
  SimCarregado: Boolean;
begin
  if not FCameraAtiva then
  begin
    DefineStatus('OFFLINE');
    Exit;
  end;

  // Verifica se ha fluxo recente de imagem gerado pelo simulador local
  SimCamFile := IncludeTrailingPathDelimiter(GetTempDir) + 'cockpit_sim_camera.bmp';
  if Assigned(FSetMain) and FSetMain.SimulationMode and
    FileExists(SimCamFile) and FileAge(SimCamFile, SimDt) then
  begin
    // Se o arquivo foi atualizado nos ultimos 4 segundos
    if (Now - SimDt) < (4.0 / 86400.0) then
    begin
      SimCarregado := False;
      BmpSim := TBitmap.Create;
      try
        try
          SimFS := TFileStream.Create(SimCamFile, fmOpenRead or fmShareDenyNone);
          try
            BmpSim.LoadFromStream(SimFS);
            SimCarregado := True;
          finally
            SimFS.Free;
          end;
        except
          // Se o simulador estiver gravando naquele instante, ignora e tenta no proximo tick
        end;

        if SimCarregado and (BmpSim.Width > 0) then
        begin
          MostraQuadro(BmpSim);
          DefineStatus('SIMULADOR ONLINE (127.0.0.1)');
          Exit;
        end;
      finally
        BmpSim.Free;
      end;
    end;
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

  if not (frmMain.frmConnection is TfrmConexaoDrone) then
  begin
    DefineStatus('CONEXÃO INVÁLIDA');
    Exit;
  end;

  // A imagem chega por MostraQuadro; aqui só o estado.
  Conn := TfrmConexaoDrone(frmMain.frmConnection);
  if Conn.VideoExternoConfigurado then begin
    BmpSim:=TBitmap.Create;
    try
      if Conn.CarregaQuadroExterno(BmpSim) then begin MostraQuadro(BmpSim);DefineStatus('ONLINE - FPV pela URL configurada');end
      else DefineStatus('FPV: aguardando fluxo/decodificacao da URL configurada');
    finally BmpSim.Free;end;
    Exit;
  end;
  if (Conn is TfrmConectionMavlink) or (Conn is TfrmConectionOpendrone) or
     (Conn is TfrmConectionESP32Drone) then
    DefineStatus('ESTE DRONE NÃO ENVIA VÍDEO PARA O COCKPIT')
  else if not Conn.VideoLigado then
    DefineStatus('VÍDEO DESLIGADO NA CONFIGURAÇÃO')
  else if Conn.VideoChegando and (Conn.UltimaImagemDataHora > 0) then
    DefineStatus('ONLINE  IMG: ' + FormatDateTime('hh:nn:ss', Conn.UltimaImagemDataHora) +
      '  QUADROS: ' + IntToStr(Conn.Decoder.FramesDecoded))
  else if Conn.VideoChegando then
    DefineStatus('RECEBENDO VÍDEO, AGUARDANDO DECODIFICADOR (ffmpeg)')
  else
    DefineStatus('AGUARDANDO VÍDEO DO DRONE');
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
