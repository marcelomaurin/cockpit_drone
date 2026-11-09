unit simprincipal;

{ Janela principal do simulador (montada em código, sem .lfm).

  Lado esquerdo: equipamento, mapa, mundo compartilhado, falhas e controles.
  Lado direito: a vista escolhida (câmera, terceira pessoa ou mapa), o mapa
  pequeno no canto e o registro de mensagens embaixo.

  Preferências em simulador.ini, na pasta de configuração do usuário
  (nunca no repositório): chave do Google, fonte do mapa, servidor do mundo,
  apelido, último ponto de partida e último modelo. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls, ComCtrls,
  Spin, IniFiles, LCLType, LCLIntf, Dialogs,
  simtipos, simgeo, simsimulacao, simemulador, simmavlink, simmapa, simmundo, simvisao, simedificios_cache,simedificios,simrastercache,simquintais;

type

  { TFrmPrincipal }

  TFrmPrincipal = class(TForm)
  private
    FSim: TSimulacao;
    FModelos: TListaModelos;
    FGer: TGerenciadorBlocos;
    FVisao, FVisaoMini, FVisaoCockpit: TVisao;
    FUltimoQuadroCockpit:QWord;
    FEdificios:TGerenciadorEdificios;
    FRaster:TGerenciadorRaster;
    FEdServidorEdificios:TEdit;FArquivoEdificios:string;
    FCkEdificios,FCkTerrenos,FCkCriadouros:TCheckBox;
    FUltimoResumoLotes:string;
    FLbEdificios:TLabel;
    FMundo: TClienteMundo;
    FIni: TIniFile;
    FOrigem: TPontoGeo;
    FUltimaManutencao: QWord;

    // Equipamento
    FCbModelo: TComboBox;
    FEdLat, FEdLon: TEdit;
    FBtLigar: TButton;
    FLbPortas: TLabel;
    FEdMavIP: TEdit;
    FSpMavPortaCockpit, FSpMavPortaLocal: TSpinEdit;
    // Mapa
    FCbFonte: TComboBox;
    FEdChave: TEdit;
    FEdOSM: TEdit;
    FLbFonte: TLabel;
    // Mundo
    FEdUrl, FEdApelido, FEdMsg: TEdit;
    FBtMundo: TButton;
    FLbMundo: TLabel;
    // Falhas
    FCkSinal, FCkGPS, FCkSinalInfinito, FCkCameraInspecao: TCheckBox;
    FTbVento: TTrackBar;
    FSpVentoRumo: TSpinEdit;
    FLbVento: TLabel;
    FCbAtraso: TComboBox;
    // Simulação
    FBtPausar: TButton;
    // Vistas
    FCbVista: TComboBox;
    FTbZoom: TTrackBar;
    FPbVista: TPaintBox;
    FPbMini: TPaintBox;
    FPainelVista: TPanel;
    FMemo: TMemo;
    FLbPainel: TLabel;
    FTimer: TTimer;

    procedure MontaTela;
    procedure CarregaPreferencias;
    procedure SalvaPreferencias;
    procedure CriaGerenciador;
    function DadosVista: TDadosVista;
    procedure Log(const ATexto: string);
    function LeNumero(const ATexto: string; APadrao: Double): Double;
    procedure AtualizaFalhas(Sender: TObject);
    procedure PosicionaMini(Sender: TObject);
    procedure LeOrigem;

    procedure BtLigarClick(Sender: TObject);
    procedure BtAplicarMapaClick(Sender: TObject);
    procedure BtImportarEdificios(Sender:TObject);
    procedure BtGabaritoClick(Sender:TObject);
    function CenaAtiva:TCenaEdificios;
    procedure BtInternetEdificios(Sender:TObject);
    procedure BtMundoClick(Sender: TObject);
    procedure BtEnviarClick(Sender: TObject);
    procedure BtSinalClick(Sender: TObject);
    procedure BtMarcarClick(Sender: TObject);
    procedure BtBateriaClick(Sender: TObject);
    procedure BtPausarClick(Sender: TObject);
    procedure BtReiniciarClick(Sender: TObject);
    procedure CbModeloChange(Sender: TObject);
    procedure PbVistaPaint(Sender: TObject);
    procedure PbMiniPaint(Sender: TObject);
    procedure PbVistaMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure Tick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  FrmPrincipal: TFrmPrincipal;

implementation

const
  VERSAO_SIMULADOR = '0.46';
  NOME_PASTA_CONFIG = 'CockpitDroneSimulador';

function NomeAplicacao: string;
begin
  Result := NOME_PASTA_CONFIG;
end;

{ Pasta de preferências e do cache de mapas, por usuário:
  Windows: %LOCALAPPDATA%\CockpitDroneSimulador\  Linux: ~/.config/CockpitDroneSimulador/ }
function PastaConfig: string;
begin
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False));
end;

function NumeroTexto(AValor: Double): string;
var
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Result := FormatFloat('0.000000', AValor, FS);
end;

{ TFrmPrincipal }

constructor TFrmPrincipal.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner, 0);
  Caption := 'Simulador Cockpit Drone ' + VERSAO_SIMULADOR;
  Width := 1200;
  Height := 760;
  Position := poScreenCenter;
  KeyPreview := True;
  OnClose := @FormClose;
  OnGetApplicationName := @NomeAplicacao;
  ForceDirectories(PastaConfig);
  FIni := TIniFile.Create(PastaConfig + 'simulador.ini');
  FModelos := CarregaModelos(ExtractFilePath(ParamStr(0)) + 'config' + PathDelim + 'equipamentos.json');
  if Length(FModelos) = 0 then
    FModelos := ModelosPadrao;
  FSim := TSimulacao.Create;
  MontaTela;
  CarregaPreferencias;
  LeOrigem;
  CriaGerenciador;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 40; // 25 quadros por segundo
  FTimer.OnTimer := @Tick;
  FTimer.Enabled := True;
  Log('Simulador pronto. Escolha o modelo e o ponto de partida (clique no mapa) e ligue o equipamento.');
  Log('No cockpit, aponte o IP do drone para o IP desta máquina (127.0.0.1 na mesma máquina) ' +
    'e desligue a conexão automática de Wi-Fi do FQ777-954.');
end;

destructor TFrmPrincipal.Destroy;
begin
  FTimer.Enabled := False;
  FreeAndNil(FMundo);
  FreeAndNil(FSim);
  FreeAndNil(FVisao);
  FreeAndNil(FVisaoMini);
  FreeAndNil(FVisaoCockpit);
  FreeAndNil(FRaster);
  FreeAndNil(FEdificios);
  FreeAndNil(FGer);
  FIni.Free;
  inherited Destroy;
end;

procedure TFrmPrincipal.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  SalvaPreferencias;
  FTimer.Enabled := False;
  FreeAndNil(FMundo);
  FSim.Desliga;
end;

procedure TFrmPrincipal.MontaTela;
var
  Esq: TScrollBox;
  Topo: TPanel;
  Gb: TGroupBox;
  Y: Integer;
  Bt: TButton;
  I: Integer;
  Spl: TSplitter;
  ProxTopo: Integer;

  function NovoGrupo(const ATitulo: string; AAltura: Integer): TGroupBox;
  begin
    Result := TGroupBox.Create(Self);
    Result.Parent := Esq;
    Result.Caption := ATitulo;
    Result.Align := alTop;
    Result.Height := AAltura;
    Result.BorderSpacing.Around := 4;
    // alTop ordena pelo Top: valores crescentes mantêm a ordem de criação.
    Result.Top := ProxTopo;
    Inc(ProxTopo, AAltura + 10);
    Y := 4;
  end;

  function Rotulo(AParent: TWinControl; const ATexto: string): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := AParent;
    Result.Left := 8;
    Result.Top := Y + 3;
    Result.Caption := ATexto;
  end;

  function Edita(AParent: TWinControl; ALeft, AWidth: Integer; const ATexto: string): TEdit;
  begin
    Result := TEdit.Create(Self);
    Result.Parent := AParent;
    Result.Left := ALeft;
    Result.Top := Y;
    Result.Width := AWidth;
    Result.Text := ATexto;
  end;

  function Botao(AParent: TWinControl; ALeft, AWidth: Integer; const ATexto: string;
    AEvento: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := AParent;
    Result.Left := ALeft;
    Result.Top := Y;
    Result.Width := AWidth;
    Result.Height := 26;
    Result.Caption := ATexto;
    Result.OnClick := AEvento;
  end;

  function Spin(AParent: TWinControl; ALeft, AMin, AMax, AValor: Integer): TSpinEdit;
  begin
    Result := TSpinEdit.Create(Self);
    Result.Parent := AParent;
    Result.Left := ALeft;
    Result.Top := Y;
    Result.Width := 80;
    Result.MinValue := AMin;
    Result.MaxValue := AMax;
    Result.Value := AValor;
  end;

begin
  // ---------- Lado esquerdo ----------
  Esq := TScrollBox.Create(Self);
  Esq.Parent := Self;
  Esq.Align := alLeft;
  Esq.Width := 330;
  Esq.HorzScrollBar.Visible := False;
  ProxTopo := 0;

  Gb := NovoGrupo('Equipamento', 250);
  Rotulo(Gb, 'Modelo:');
  FCbModelo := TComboBox.Create(Self);
  FCbModelo.Parent := Gb;
  FCbModelo.Left := 80;
  FCbModelo.Top := Y;
  FCbModelo.Width := 225;
  FCbModelo.Style := csDropDownList;
  for I := 0 to High(FModelos) do
    FCbModelo.Items.Add(FModelos[I].Nome);
  FCbModelo.ItemIndex := 0;
  FCbModelo.OnChange := @CbModeloChange;
  Inc(Y, 30);
  Rotulo(Gb, 'Latitude:');
  FEdLat := Edita(Gb, 80, 120, '-21.176700');
  Inc(Y, 28);
  Rotulo(Gb, 'Longitude:');
  FEdLon := Edita(Gb, 80, 120, '-47.820800');
  Inc(Y, 28);
  Rotulo(Gb, 'MAVLink:');
  FEdMavIP := Edita(Gb, 80, 110, '127.0.0.1');
  FEdMavIP.Hint := 'IP do cockpit (para onde o simulador envia o MAVLink)';
  FEdMavIP.ShowHint := True;
  FSpMavPortaCockpit := Spin(Gb, 195, 1, 65535, MAV_PORTA_COCKPIT);
  FSpMavPortaCockpit.Width := 70;
  FSpMavPortaCockpit.Hint := 'Porta do cockpit (padrão 14550)';
  FSpMavPortaCockpit.ShowHint := True;
  Inc(Y, 28);
  Rotulo(Gb, 'Porta local:');
  FSpMavPortaLocal := Spin(Gb, 80, 1, 65535, MAV_PORTA_LOCAL);
  Inc(Y, 32);
  FBtLigar := Botao(Gb, 8, 297, 'Ligar equipamento', @BtLigarClick);
  FBtLigar.Font.Style := [fsBold];
  Inc(Y, 32);
  FLbPortas := Rotulo(Gb, 'Desligado.');
  FLbPortas.WordWrap := True;
  FLbPortas.AutoSize := False;
  FLbPortas.Width := 297;
  FLbPortas.Height := 40;

  Gb := NovoGrupo('Mapa', 470);
  Rotulo(Gb, 'Fonte:');
  FCbFonte := TComboBox.Create(Self);
  FCbFonte.Parent := Gb;
  FCbFonte.Left := 80;
  FCbFonte.Top := Y;
  FCbFonte.Width := 225;
  FCbFonte.Style := csDropDownList;
  FCbFonte.Items.Add('Automático (Google, senão OpenStreetMap)');
  FCbFonte.Items.Add('Google (satélite)');
  FCbFonte.Items.Add('OpenStreetMap (ruas)');
  FCbFonte.ItemIndex := 0;
  Inc(Y, 30);
  Rotulo(Gb, 'Chave Google:');
  FEdChave := Edita(Gb, 100, 205, '');
  FEdChave.PasswordChar := '*';
  Inc(Y, 28);
  Rotulo(Gb, 'Blocos OSM:');
  FEdOSM := Edita(Gb, 100, 205, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
  Inc(Y, 30);
  Botao(Gb, 8, 120, 'Aplicar mapa', @BtAplicarMapaClick);
  Y:=155;Rotulo(Gb,'Servidor de construcoes (HTTPS):');
  Inc(Y,22);FEdServidorEdificios:=Edita(Gb,8,297,SERVIDOR_EDIFICIOS_PADRAO);
  Y:=209;Botao(Gb,8,145,'Arquivo OSM...',@BtImportarEdificios);
  Botao(Gb,160,145,'Usar internet',@BtInternetEdificios);
  FCkEdificios:=TCheckBox.Create(Self);FCkEdificios.Parent:=Gb;
  FCkEdificios.SetBounds(8,245,300,24);FCkEdificios.Checked:=True;
  FCkEdificios.Caption:='Construcoes 3D no OpenStreetMap';
  FCkTerrenos:=TCheckBox.Create(Self);FCkTerrenos.Parent:=Gb;
  FCkTerrenos.SetBounds(8,273,300,24);FCkTerrenos.Checked:=True;
  FCkTerrenos.Caption:='Simular casas nos terrenos';
  FCkTerrenos.Hint:='Completa areas residenciais respeitando vias. Use Aplicar mapa.';FCkTerrenos.ShowHint:=True;
  FCkCriadouros:=TCheckBox.Create(Self);FCkCriadouros.Parent:=Gb;
  FCkCriadouros.SetBounds(8,301,300,24);FCkCriadouros.Checked:=True;
  FCkCriadouros.Caption:='Quintais com criadouros (Aedes)';
  FCkCriadouros.Hint:='Casas simuladas ganham lote com muro e quintal; parte deles tem vasos com prato, piscina verde, '+
    'caixa d''agua destampada, pneus, tanque de peixes abandonado ou baldes com agua. Use Aplicar mapa.';
  FCkCriadouros.ShowHint:=True;
  FLbEdificios:=TLabel.Create(Self);FLbEdificios.Parent:=Gb;
  FLbEdificios.AutoSize:=False;FLbEdificios.WordWrap:=True;FLbEdificios.SetBounds(8,329,300,64);
  Y:=397;Botao(Gb,8,200,'Salvar gabarito dos quintais...',@BtGabaritoClick);
  FLbFonte := TLabel.Create(Self);
  FLbFonte.Parent := Gb;
  FLbFonte.Left := 135;
  FLbFonte.Top := 105;FLbFonte.Width:=165;FLbFonte.AutoSize:=False;FLbFonte.WordWrap:=True;FLbFonte.Height:=42;
  FLbFonte.Caption := '-';

  Gb := NovoGrupo('Mundo compartilhado', 190);
  Rotulo(Gb, 'Servidor:');
  FEdUrl := Edita(Gb, 80, 225, 'https://maurinsoft.com.br/cockpit/api.php');
  Inc(Y, 28);
  Rotulo(Gb, 'Apelido:');
  FEdApelido := Edita(Gb, 80, 120, 'piloto');
  FBtMundo := Botao(Gb, 205, 100, 'Entrar', @BtMundoClick);
  Inc(Y, 30);
  FLbMundo := Rotulo(Gb, 'fora do mundo');
  Inc(Y, 22);
  FEdMsg := Edita(Gb, 8, 220, '');
  FEdMsg.TextHint := 'mensagem para quem está a até 2 km';
  Botao(Gb, 233, 72, 'Enviar', @BtEnviarClick);
  Inc(Y, 30);
  Botao(Gb, 8, 145, 'Piscar luzes', @BtSinalClick);
  Botao(Gb, 160, 145, 'Marcar este ponto', @BtMarcarClick);

  Gb := NovoGrupo('Falhas', 200);
  FCkSinal := TCheckBox.Create(Self);
  FCkSinal.Parent := Gb;
  FCkSinal.Left := 8;
  FCkSinal.Top := Y;
  FCkSinal.Caption := 'Perda de sinal';
  FCkSinal.OnChange := @AtualizaFalhas;
  FCkGPS := TCheckBox.Create(Self);
  FCkGPS.Parent := Gb;
  FCkGPS.Left := 160;
  FCkGPS.Top := Y;
  FCkGPS.Caption := 'Perda de GPS';
  FCkGPS.OnChange := @AtualizaFalhas;
  Inc(Y, 26);
  Botao(Gb, 8, 145, 'Bateria fraca', @BtBateriaClick);
  Inc(Y, 32);
  FLbVento := Rotulo(Gb, 'Vento: 0 m/s');
  Inc(Y, 18);
  FTbVento := TTrackBar.Create(Self);
  FTbVento.Parent := Gb;
  FTbVento.Left := 8;
  FTbVento.Top := Y;
  FTbVento.Width := 200;
  FTbVento.Min := 0;
  FTbVento.Max := 15;
  FTbVento.OnChange := @AtualizaFalhas;
  FSpVentoRumo := Spin(Gb, 215, 0, 359, 90);
  FSpVentoRumo.Hint := 'De onde o vento vem (graus)';
  FSpVentoRumo.ShowHint := True;
  FSpVentoRumo.OnChange := @AtualizaFalhas;
  Inc(Y, 40);
  Rotulo(Gb, 'Atraso de rede:');
  FCbAtraso := TComboBox.Create(Self);
  FCbAtraso.Parent := Gb;
  FCbAtraso.Left := 110;
  FCbAtraso.Top := Y;
  FCbAtraso.Width := 100;
  FCbAtraso.Style := csDropDownList;
  FCbAtraso.Items.CommaText := '"sem atraso","100 ms","250 ms","500 ms","1000 ms"';
  FCbAtraso.ItemIndex := 0;
  FCbAtraso.OnChange := @AtualizaFalhas;

  Gb := NovoGrupo('Simulação', 133);
  FCkSinalInfinito := TCheckBox.Create(Self);
  FCkSinalInfinito.Parent := Gb;
  FCkSinalInfinito.SetBounds(8, Y, 297, 24);
  FCkSinalInfinito.Caption := 'Sinal infinito (treinamento)';
  FCkSinalInfinito.Hint := 'Mantem o sinal simulado em qualquer distancia e altura.';
  FCkSinalInfinito.ShowHint := True;
  FCkSinalInfinito.OnChange := @AtualizaFalhas;
  Inc(Y, 28);
  FCkCameraInspecao := TCheckBox.Create(Self);
  FCkCameraInspecao.Parent := Gb;
  FCkCameraInspecao.SetBounds(8, Y, 297, 24);
  FCkCameraInspecao.Caption := 'Camera de inspecao (60 graus para baixo)';
  FCkCameraInspecao.Hint := 'Inclina a camera do drone para olhar quintais e telhados, como na inspecao de criadouros. '+
    'Vale para a imagem enviada ao cockpit.';
  FCkCameraInspecao.ShowHint := True;
  FCkCameraInspecao.OnChange := @AtualizaFalhas;
  Inc(Y, 28);
  FBtPausar := Botao(Gb, 8, 145, 'Pausar', @BtPausarClick);
  Botao(Gb, 160, 145, 'Reiniciar na partida', @BtReiniciarClick);

  // ---------- Lado direito ----------
  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := alBottom;
  FMemo.Height := 120;
  FMemo.ReadOnly := True;
  FMemo.ScrollBars := ssAutoVertical;
  Spl := TSplitter.Create(Self);
  Spl.Parent := Self;
  Spl.Align := alBottom;

  Topo := TPanel.Create(Self);
  Topo.Parent := Self;
  Topo.Align := alTop;
  Topo.Height := 36;
  Topo.BevelOuter := bvNone;
  with TLabel.Create(Self) do
  begin
    Parent := Topo;
    Left := 8;
    Top := 10;
    Caption := 'Vista:';
  end;
  FCbVista := TComboBox.Create(Self);
  FCbVista.Parent := Topo;
  FCbVista.Left := 50;
  FCbVista.Top := 6;
  FCbVista.Width := 170;
  FCbVista.Style := csDropDownList;
  FCbVista.Items.Add('Câmera do drone');
  FCbVista.Items.Add('Terceira pessoa');
  FCbVista.Items.Add('Mapa de cima');
  FCbVista.ItemIndex := 2;
  with TLabel.Create(Self) do
  begin
    Parent := Topo;
    Left := 235;
    Top := 10;
    Caption := 'Zoom do mapa:';
  end;
  FTbZoom := TTrackBar.Create(Self);
  FTbZoom.Parent := Topo;
  FTbZoom.Left := 330;
  FTbZoom.Top := 4;
  FTbZoom.Width := 160;
  FTbZoom.Min := 13;
  FTbZoom.Max := 19;
  FTbZoom.Position := 17;
  FLbPainel := TLabel.Create(Self);
  FLbPainel.Parent := Topo;
  FLbPainel.Left := 505;
  FLbPainel.Top := 10;
  FLbPainel.Caption := '';

  FPainelVista := TPanel.Create(Self);
  FPainelVista.Parent := Self;
  FPainelVista.Align := alClient;
  FPainelVista.BevelOuter := bvNone;
  FPainelVista.Color := clBlack;
  FPainelVista.OnResize := @PosicionaMini;
  FPbVista := TPaintBox.Create(Self);
  FPbVista.Parent := FPainelVista;
  FPbVista.Align := alClient;
  FPbVista.OnPaint := @PbVistaPaint;
  FPbVista.OnMouseDown := @PbVistaMouseDown;
  FPbMini := TPaintBox.Create(Self);
  FPbMini.Parent := FPainelVista;
  FPbMini.Width := 260;
  FPbMini.Height := 180;
  FPbMini.OnPaint := @PbMiniPaint;
  FPbMini.BringToFront;
end;

procedure TFrmPrincipal.PosicionaMini(Sender: TObject);
begin
  FPbMini.Left := FPainelVista.ClientWidth - FPbMini.Width - 10;
  FPbMini.Top := FPainelVista.ClientHeight - FPbMini.Height - 30;
end;

procedure TFrmPrincipal.CarregaPreferencias;
var
  I: Integer;Erro:string;
begin
  FEdChave.Text := FIni.ReadString('mapa', 'chave_google', '');
  case ModoFonteDeTexto(FIni.ReadString('mapa', 'fonte_mapa', 'auto')) of
    mfGoogle: FCbFonte.ItemIndex := 1;
    mfOSM: FCbFonte.ItemIndex := 2;
  else
    FCbFonte.ItemIndex := 0;
  end;
  FCkEdificios.Checked:=FIni.ReadBool('mapa','edificios_3d',True);
  FCkTerrenos.Checked:=FIni.ReadBool('mapa','simular_terrenos',True);
  FCkCriadouros.Checked:=FIni.ReadBool('treinamento','criadouros_aedes',True);
  FEdServidorEdificios.Text:=FIni.ReadString('mapa','servidor_edificios',SERVIDOR_EDIFICIOS_PADRAO);
  FArquivoEdificios:=FIni.ReadString('mapa','arquivo_edificios','');
  if (FArquivoEdificios<>'') and not ValidaArquivoOSM(FArquivoEdificios,Erro) then begin
    Log('Arquivo de construcoes ignorado: '+Erro+' Usando os mapas carregados.');FArquivoEdificios:='';end;
  FEdOSM.Text := FIni.ReadString('mapa', 'servidor_osm', FEdOSM.Text);
  FEdUrl.Text := FIni.ReadString('mundo', 'url', FEdUrl.Text);
  if (Trim(FEdUrl.Text) = 'https://maurinsoft.com.br/cockpit/') or (Trim(FEdUrl.Text) = 'https://maurinsoft.com.br/cockpit') then
    FEdUrl.Text := 'https://maurinsoft.com.br/cockpit/api.php';
  FEdApelido.Text := FIni.ReadString('mundo', 'apelido', FEdApelido.Text);
  FEdLat.Text := FIni.ReadString('voo', 'lat', FEdLat.Text);
  FEdLon.Text := FIni.ReadString('voo', 'lon', FEdLon.Text);
  I := IndiceModelo(FModelos, FIni.ReadString('voo', 'modelo', 'tello'));
  if I >= 0 then
    FCbModelo.ItemIndex := I;
  FEdMavIP.Text := FIni.ReadString('mavlink', 'ip_cockpit', FEdMavIP.Text);
  FSpMavPortaCockpit.Value := FIni.ReadInteger('mavlink', 'porta_cockpit', MAV_PORTA_COCKPIT);
  FSpMavPortaLocal.Value := FIni.ReadInteger('mavlink', 'porta_local', MAV_PORTA_LOCAL);
  CbModeloChange(nil);
  FCkSinalInfinito.Checked := FIni.ReadBool('treinamento', 'sinal_infinito', False);
  FCkCameraInspecao.Checked := FIni.ReadBool('treinamento', 'camera_inspecao', False);
  AtualizaFalhas(nil);
end;

procedure TFrmPrincipal.SalvaPreferencias;
const
  FONTES: array[0..2] of string = ('auto', 'google', 'osm');
begin
  try
    FIni.WriteBool('treinamento', 'sinal_infinito', FCkSinalInfinito.Checked);
    FIni.WriteBool('treinamento', 'camera_inspecao', FCkCameraInspecao.Checked);
    FIni.WriteString('mapa', 'chave_google', Trim(FEdChave.Text));
    FIni.WriteString('mapa', 'fonte_mapa', FONTES[EnsureRange(FCbFonte.ItemIndex, 0, 2)]);
    FIni.WriteString('mapa', 'servidor_osm', Trim(FEdOSM.Text));
    FIni.WriteBool('mapa','edificios_3d',FCkEdificios.Checked);
    FIni.WriteBool('mapa','simular_terrenos',FCkTerrenos.Checked);
    FIni.WriteBool('treinamento','criadouros_aedes',FCkCriadouros.Checked);
    FIni.WriteString('mapa','servidor_edificios',Trim(FEdServidorEdificios.Text));
    FIni.WriteString('mapa','arquivo_edificios',FArquivoEdificios);
    FIni.WriteString('mundo', 'url', Trim(FEdUrl.Text));
    FIni.WriteString('mundo', 'apelido', Trim(FEdApelido.Text));
    FIni.WriteString('voo', 'lat', Trim(FEdLat.Text));
    FIni.WriteString('voo', 'lon', Trim(FEdLon.Text));
    if FCbModelo.ItemIndex >= 0 then
      FIni.WriteString('voo', 'modelo', FModelos[FCbModelo.ItemIndex].Chave);
    FIni.WriteString('mavlink', 'ip_cockpit', Trim(FEdMavIP.Text));
    FIni.WriteInteger('mavlink', 'porta_cockpit', FSpMavPortaCockpit.Value);
    FIni.WriteInteger('mavlink', 'porta_local', FSpMavPortaLocal.Value);
    FIni.UpdateFile;
  except
    on E: Exception do
      Log('Não foi possível salvar as preferências: ' + E.Message);
  end;
end;

procedure TFrmPrincipal.BtImportarEdificios(Sender:TObject);
var D:TOpenDialog;Erro:string;
begin
  D:=TOpenDialog.Create(Self);
  try D.Title:='Contornos de edificios: exportacao JSON do Overpass';D.Filter:='OSM Overpass JSON|*.json';
    if D.Execute then begin
      if not ValidaArquivoOSM(D.FileName,Erro) then begin MessageDlg('Arquivo de construcoes invalido',Erro,mtError,[mbOK],0);Exit;end;
      FArquivoEdificios:=D.FileName;BtAplicarMapaClick(nil);end;
  finally D.Free;end;
end;
function TFrmPrincipal.CenaAtiva:TCenaEdificios;
begin
  Result:=Default(TCenaEdificios);
  if Assigned(FEdificios) then Result:=FEdificios.Cena;
  if (Length(Result.Itens)=0) and Assigned(FRaster) then Result:=FRaster.Cena;
end;
procedure TFrmPrincipal.BtGabaritoClick(Sender:TObject);
var D:TSaveDialog;Cena:TCenaEdificios;NLotes,NRisco,NItens:Integer;
begin
  Cena:=CenaAtiva;ContaLotes(Cena,NLotes,NRisco,NItens);
  if NLotes=0 then begin
    MessageDlg('Ainda nao ha quintais simulados nesta regiao. Marque "Simular casas nos terrenos" e '+
      '"Quintais com criadouros", clique Aplicar mapa e aguarde o carregamento.',mtInformation,[mbOK],0);Exit;end;
  D:=TSaveDialog.Create(Self);
  try
    D.Title:='Gabarito dos quintais (uso do instrutor)';D.FileName:='gabarito_criadouros.csv';
    D.Filter:='Planilha CSV (*.csv)|*.csv';D.DefaultExt:='csv';D.Options:=D.Options+[ofOverwritePrompt];
    if not D.Execute then Exit;
    SalvaGabarito(Cena,D.FileName);
    Log(Format('Gabarito salvo: %s (%d quintais, %d com criadouro).',[D.FileName,NLotes,NRisco]));
  finally D.Free;end;
end;
procedure TFrmPrincipal.BtInternetEdificios(Sender:TObject);
begin FArquivoEdificios:='';BtAplicarMapaClick(nil);end;

procedure TFrmPrincipal.CriaGerenciador;
var
  Modo: TModoFonte;
begin
  FreeAndNil(FVisao);
  FreeAndNil(FVisaoMini);
  FreeAndNil(FVisaoCockpit);
  FreeAndNil(FRaster);
  FreeAndNil(FEdificios);
  FreeAndNil(FGer);
  case FCbFonte.ItemIndex of
    1: Modo := mfGoogle;
    2: Modo := mfOSM;
  else
    Modo := mfAuto;
  end;
  Screen.Cursor := crHourGlass;
  try
    FGer := TGerenciadorBlocos.Create(
      PastaConfig + 'cache_mapas',
      Trim(FEdChave.Text), Trim(FEdOSM.Text), Modo);
  finally
    Screen.Cursor := crDefault;
  end;
  GerarCriadouros:=FCkCriadouros.Checked;
  FEdificios:=TGerenciadorEdificios.Create(PastaConfig+'cache_edificios',Trim(FEdServidorEdificios.Text),FArquivoEdificios,FCkTerrenos.Checked);
  FRaster:=TGerenciadorRaster.Create(FGer,FCkTerrenos.Checked);
  FVisao := TVisao.Create(FGer,1,FEdificios,FRaster);
  FVisaoMini := TVisao.Create(FGer,0,FEdificios,FRaster);
  FVisaoCockpit := TVisao.Create(FGer,1,FEdificios,FRaster);
end;

procedure TFrmPrincipal.Log(const ATexto: string);
begin
  FMemo.Lines.Add(ATexto);
  while FMemo.Lines.Count > 500 do
    FMemo.Lines.Delete(0);
  FMemo.SelStart := Length(FMemo.Text);
end;

function TFrmPrincipal.LeNumero(const ATexto: string; APadrao: Double): Double;
var
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Result := StrToFloatDef(StringReplace(Trim(ATexto), ',', '.', [rfReplaceAll]), APadrao, FS);
end;

procedure TFrmPrincipal.LeOrigem;
begin
  FOrigem.Lat := EnsureRange(LeNumero(FEdLat.Text, -21.1767), -85, 85);
  FOrigem.Lon := EnsureRange(LeNumero(FEdLon.Text, -47.8208), -180, 180);
  if Assigned(FSim) then
    FSim.DefineOrigemParada(FOrigem);
end;

procedure TFrmPrincipal.CbModeloChange(Sender: TObject);
var
  Mav: Boolean;
begin
  Mav := (FCbModelo.ItemIndex >= 0) and SameText(FModelos[FCbModelo.ItemIndex].Protocolo, 'mavlink');
  FEdMavIP.Enabled := Mav;
  FSpMavPortaCockpit.Enabled := Mav;
  FSpMavPortaLocal.Enabled := Mav;
end;

procedure TFrmPrincipal.AtualizaFalhas(Sender: TObject);
const
  ATRASOS: array[0..4] of Integer = (0, 100, 250, 500, 1000);
var
  F: TFalhas;
begin
  F.SinalInfinito := FCkSinalInfinito.Checked;
  if Assigned(FCkCameraInspecao) and FCkCameraInspecao.Checked then InclinacaoInspecaoGraus := 60
  else InclinacaoInspecaoGraus := -1;
  FCkSinal.Enabled := not F.SinalInfinito;
  F.PerdaSinal := FCkSinal.Checked and not F.SinalInfinito;
  F.PerdaGPS := FCkGPS.Checked;
  F.VentoMS := FTbVento.Position;
  F.VentoRumoGraus := FSpVentoRumo.Value;
  F.AtrasoMs := ATRASOS[EnsureRange(FCbAtraso.ItemIndex, 0, 4)];
  FLbVento.Caption := Format('Vento: %d m/s vindo de %d°', [FTbVento.Position, FSpVentoRumo.Value]);
  FSim.DefineFalhas(F);
  // Persist just this option here; the other preferences have their own save flow.
  if Sender = FCkSinalInfinito then
    try
      FIni.WriteBool('treinamento', 'sinal_infinito', F.SinalInfinito);
      FIni.UpdateFile;
    except
      on E: Exception do Log('Nao foi possivel salvar sinal infinito: ' + E.Message);
    end;
end;

procedure TFrmPrincipal.BtLigarClick(Sender: TObject);
var
  Erro: string;
  M: TOpcoesMavlink;
begin
  if FSim.Ligado then
  begin
    FSim.Desliga;
    FBtLigar.Caption := 'Ligar equipamento';
    FLbPortas.Caption := 'Desligado.';
    FCbModelo.Enabled := True;
    Log('Equipamento desligado.');
    Exit;
  end;
  LeOrigem;
  M.IPCockpit := Trim(FEdMavIP.Text);
  M.PortaCockpit := FSpMavPortaCockpit.Value;
  M.PortaLocal := FSpMavPortaLocal.Value;
  AtualizaFalhas(nil);
  if not FSim.Liga(FModelos[FCbModelo.ItemIndex], FOrigem, M, Erro) then
  begin
    Log('Não foi possível ligar: ' + Erro + '. Feche outro programa que use a mesma porta.');
    Exit;
  end;
  FBtLigar.Caption := 'Desligar equipamento';
  FBtPausar.Caption:='Pausar';
  FLbPortas.Caption := FSim.Emulador.Descricao;
  FCbModelo.Enabled := False;
  if FCbVista.ItemIndex = 2 then
    FCbVista.ItemIndex := 0;
  SalvaPreferencias;
end;

procedure TFrmPrincipal.BtAplicarMapaClick(Sender: TObject);
begin
  CriaGerenciador;
  SalvaPreferencias;
end;

procedure TFrmPrincipal.BtMundoClick(Sender: TObject);
var
  Modelo: string;
begin
  if Assigned(FMundo) then
  begin
    FreeAndNil(FMundo);
    FBtMundo.Caption := 'Entrar';
    FLbMundo.Caption := 'fora do mundo';
    Exit;
  end;
  if Trim(FEdApelido.Text) = '' then
  begin
    Log('Informe um apelido para entrar no mundo.');
    Exit;
  end;
  if FCbModelo.ItemIndex >= 0 then
    Modelo := FModelos[FCbModelo.ItemIndex].Chave
  else
    Modelo := 'desconhecido';
  FMundo := TClienteMundo.Create(FEdUrl.Text, FEdApelido.Text, Modelo, @FSim.LeEstado);
  FBtMundo.Caption := 'Sair';
  SalvaPreferencias;
end;

procedure TFrmPrincipal.BtEnviarClick(Sender: TObject);
begin
  if Assigned(FMundo) then
  begin
    FMundo.EnviaMensagem(FEdMsg.Text);
    FEdMsg.Text := '';
  end
  else
    Log('Entre no mundo compartilhado para enviar mensagens.');
end;

procedure TFrmPrincipal.BtSinalClick(Sender: TObject);
begin
  if Assigned(FMundo) then
    FMundo.EnviaSinal;
end;

procedure TFrmPrincipal.BtMarcarClick(Sender: TObject);
var
  E: TEstadoVoo;
begin
  if not Assigned(FMundo) then
    Exit;
  E := FSim.LeEstado;
  FMundo.EnviaMarcador(E.Lat, E.Lon, FEdApelido.Text);
end;

procedure TFrmPrincipal.BtBateriaClick(Sender: TObject);
begin
  FSim.BateriaFraca;
  Log('Falha: bateria fraca (12%).');
end;

procedure TFrmPrincipal.BtPausarClick(Sender: TObject);
begin
  FSim.Pausado := not FSim.Pausado;
  if FSim.Pausado then
    FBtPausar.Caption := 'Continuar'
  else
    FBtPausar.Caption := 'Pausar';
end;

procedure TFrmPrincipal.BtReiniciarClick(Sender: TObject);
begin
  if not FSim.Ligado then
    Exit;
  FSim.Reinicia;
  FBtPausar.Caption:='Pausar';
  Log('Reinicio solicitado no ponto de partida; baixe a aceleracao e repita o armamento/decolagem.');
end;

function TFrmPrincipal.DadosVista: TDadosVista;
var
  I: Integer;
begin
  Result:=Default(TDadosVista);
  if FSim.Ligado then
  begin
    Result.Estado := FSim.LeEstado;
    Result.Param := FSim.Param;
    Result.Origem := FSim.Origem;
    Result.Rastro := FSim.Rastro;
    Result.Fase := FSim.Emulador.FaseTexto;
  end
  else
  begin
    Result.Origem := FOrigem;
    Result.Estado.NoChao := True;
    Result.Estado.Bateria := 100;
    Result.Estado.Z := 1.5;
    I := Max(0, FCbModelo.ItemIndex);
    Result.Param := FModelos[I];
    Result.Fase := 'desligado (clique no mapa para escolher a partida)';
  end;
  Result.ZoomMapa := FTbZoom.Position;
  if Assigned(FMundo) then
  begin
    Result.Vizinhos := FMundo.Vizinhos;
    Result.Marcadores := FMundo.Marcadores;
    Result.NoMundo := True;
    Result.RaioMundoM := FMundo.Raio;
  end;
end;

procedure TFrmPrincipal.PbVistaPaint(Sender: TObject);
var
  T: TTipoVista;
begin
  if not Assigned(FVisao) then
    Exit;
  T := TTipoVista(EnsureRange(FCbVista.ItemIndex, 0, 2));
  FVisao.Desenha(FPbVista.Canvas, FPbVista.ClientRect, T, DadosVista, 0.5);

end;

procedure TFrmPrincipal.PbMiniPaint(Sender: TObject);
var
  T: TTipoVista;
  D: TDadosVista;
begin
  if not Assigned(FVisaoMini) then
    Exit;
  // O quadro pequeno mostra o mapa; se a vista principal é o mapa, a câmera.
  if FCbVista.ItemIndex = 2 then
    T := tvCamera
  else
    T := tvMapa;
  D := DadosVista;
  D.ZoomMapa := Min(19, FTbZoom.Position);
  FVisaoMini.Desenha(FPbMini.Canvas, FPbMini.ClientRect, T, D, 0.6);
  FPbMini.Canvas.Pen.Color := clWhite;
  FPbMini.Canvas.Brush.Style := bsClear;
  FPbMini.Canvas.Rectangle(FPbMini.ClientRect);

end;

procedure TFrmPrincipal.PbVistaMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Z: Integer;
  Cx, Cy, Lat, Lon: Double;
begin
  // Com o equipamento desligado, um clique no mapa escolhe o ponto de partida.
  if FSim.Ligado or (FCbVista.ItemIndex <> 2) then
    Exit;
  Z := FTbZoom.Position;
  GeoParaPixel(FOrigem.Lat, FOrigem.Lon, Z, Cx, Cy);
  PixelParaGeo(Cx + (X - FPbVista.Width / 2), Cy + (Y - FPbVista.Height / 2), Z, Lat, Lon);
  FEdLat.Text := NumeroTexto(Lat);
  FEdLon.Text := NumeroTexto(Lon);
  LeOrigem;
  Log(Format('Ponto de partida: %s, %s', [FEdLat.Text, FEdLon.Text]));
end;

procedure TFrmPrincipal.Tick(Sender: TObject);
var
  S: string;
  E: TEstadoVoo;
  Cena: TCenaEdificios;
  NLotes, NRisco, NItens: Integer;
begin
  if Assigned(FSim.Emulador) then
    while FSim.Emulador.ProximaMensagem(S) do
      Log(S);
  if Assigned(FGer) then
  begin
    while FGer.ProximaMensagem(S) do
      Log('Mapa: ' + S);
    if GetTickCount64 - FUltimaManutencao > 1000 then
    begin
      FUltimaManutencao := GetTickCount64;
      FGer.Manutencao;
      FLbFonte.Caption := Format('%s  (%d baixados, %d do cache)',
        [FGer.NomeFonte, FGer.Baixados, FGer.DoCache]);
    end;
  end;
  if Assigned(FEdificios) then begin
    E:=DadosVista.Estado;
    if not FSim.Ligado then begin E.Lat:=FOrigem.Lat;E.Lon:=FOrigem.Lon;end;
    FEdificios.Atualiza(E.Lat,E.Lon,FCkEdificios.Checked and not FGer.EhSatelite);
    FRaster.Atualiza(E.Lat,E.Lon,FCkEdificios.Checked and not FGer.EhSatelite);
    if Length(FEdificios.Cena.Itens)>0 then S:=FEdificios.Status else S:=FRaster.Status;
    Cena:=CenaAtiva;ContaLotes(Cena,NLotes,NRisco,NItens);
    if NLotes>0 then begin
      S:=S+LineEnding+Format('Quintais: %d; com criadouro: %d (%d itens com agua parada)',[NLotes,NRisco,NItens]);
      if S<>FUltimoResumoLotes then begin
        Log(Format('Treinamento Aedes: %d quintais, %d com criadouro. O gabarito fica em Mapa > Salvar gabarito.',[NLotes,NRisco]));
        FUltimoResumoLotes:=S;
      end;
    end;
    FLbEdificios.Caption:=S;
  end;
  if Assigned(FMundo) then
  begin
    while FMundo.ProximaMensagem(S) do
      Log('Mundo: ' + S);
    FLbMundo.Caption := FMundo.EstadoTexto;
  end;
  if FSim.Ligado then
  begin
    E := FSim.LeEstado;
    FLbPainel.Caption := Format('%s | %s | cockpit: %d pacotes recebidos, %d enviados',
      [FSim.Param.Nome, FSim.Emulador.FaseTexto, FSim.Emulador.PacotesRx, FSim.Emulador.PacotesTx]);
    if FSim.LeFalhas.SinalInfinito then
      FLbPainel.Caption := FLbPainel.Caption + ' | SINAL INFINITO';
    if E.SinalPerdido then
      FLbPainel.Caption := FLbPainel.Caption + ' | SEM SINAL';
  end
  else
    FLbPainel.Caption := 'Equipamento desligado';
  if Assigned(FVisaoCockpit) and (GetTickCount64-FUltimoQuadroCockpit>=100) then begin
    FUltimoQuadroCockpit:=GetTickCount64;
    FVisaoCockpit.GeraQuadroCamera(DadosVista,640,360,
      IncludeTrailingPathDelimiter(GetTempDir)+'cockpit_sim_camera.bmp');
  end;
  PosicionaMini(nil);
  FPbVista.Invalidate;
  FPbMini.Invalidate;
end;

end.
