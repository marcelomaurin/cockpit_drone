unit rotavoo;

{ Planejamento de rota de voo — somente para drones com GPS.

  Disponível quando o protocolo selecionado tem GPS (ProtocoloTemGPS em
  protocols.pas; hoje o MAVLink: ArduPilot ou PX4). Com outro drone a janela
  não abre e explica o motivo.

  Fluxo:
    1. Pontos: clique no mapa (botão "Adicionar pelo mapa" ou Ctrl+clique),
       posição atual do drone, ou arquivo do Mission Planner/QGroundControl
       (.waypoints). Latitude, longitude, altitude e velocidade são editáveis
       na tabela.
    2. Opções: altitude de decolagem, velocidade padrão, o que fazer ao
       terminar e distância máxima do ponto de partida.
    3. "Enviar ao drone": valida e envia a missão; o drone confirma.
    4. "Iniciar rota": confirma com o piloto, arma, decola e percorre a rota.
       Pausar, Continuar, Voltar ao ponto de partida e Pousar a qualquer momento.

  Segurança: a rota só é enviada com GPS 3D (6+ satélites), posição e ponto de
  partida conhecidos, bateria >= 30% (quando informada), drone desarmado e
  todos os pontos válidos (altitude, velocidade, geocerca, distância máxima).
  Alterada depois de enviada, a rota precisa ser enviada de novo. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Grids,
  Dialogs, flightplan, aidronemavlink, rotamavlink, protocols;

const
  ROTA_SATELITES_MIN = 6;
  ROTA_BATERIA_MIN = 30;

type

  { TfrmRotaVoo }

  TfrmRotaVoo = class(TForm)
  private
    FGrade: TStringGrid;
    FBtMapa: TButton;
    FBtsEdicao: array of TButton;
    FModoAdicionar: Boolean;

    FEdDecolagem: TEdit;
    FEdVelocidade: TEdit;
    FEdDistMax: TEdit;
    FCbAcao: TComboBox;
    FLbResumo: TLabel;

    FLbConexao: TLabel;
    FLbGps: TLabel;
    FLbPosicao: TLabel;
    FLbBateria: TLabel;
    FLbModo: TLabel;
    FLbRota: TLabel;

    FBtEnviar: TButton;
    FBtIniciar: TButton;
    FBtPausar: TButton;
    FBtContinuar: TButton;
    FBtVoltar: TButton;
    FBtPousar: TButton;

    FMemo: TMemo;
    FTimer: TTimer;
    FAbrir: TOpenDialog;
    FSalvar: TSaveDialog;

    FAssinaturaEnviada: string;
    FPrecisaAtualizar: Boolean;
    FUltimoItem: Integer;
    FSemGpsAvisado: Boolean;

    procedure MontaTela;
    procedure Log(const ATexto: string);
    procedure AtualizaGrade;
    procedure AtualizaResumo;
    procedure AtualizaPainel;
    procedure RedesenhaMapa;
    procedure CarregaOpcoes;
    procedure LeOpcoes;
    procedure EscreveOpcoes;
    function Protocolo: TAIDroneMavlink;
    function EmVoo: Boolean;
    function RotaEnviadaAtual: Boolean;
    function ValidaComMensagem: Boolean;
    function DroneProntoParaRota(AParaEnvio: Boolean; out AMotivo: string): Boolean;
    function LinhaSelecionada: Integer;
    procedure SelecionaPonto(AIndice: Integer);
    procedure DefineModoAdicionar(AValor: Boolean);

    procedure GradeEditor(Sender: TObject; aCol, aRow: Integer; var Editor: TWinControl);
    procedure GradeValida(Sender: TObject; aCol, aRow: Integer;
      const OldValue: string; var NewValue: string);
    procedure OpcaoAlterada(Sender: TObject);

    procedure BtMapaClick(Sender: TObject);
    procedure BtPosicaoDroneClick(Sender: TObject);
    procedure BtSubirClick(Sender: TObject);
    procedure BtDescerClick(Sender: TObject);
    procedure BtRemoverClick(Sender: TObject);
    procedure BtLimparClick(Sender: TObject);
    procedure BtAbrirClick(Sender: TObject);
    procedure BtSalvarClick(Sender: TObject);
    procedure BtValidarClick(Sender: TObject);
    procedure BtEnviarClick(Sender: TObject);
    procedure BtIniciarClick(Sender: TObject);
    procedure BtPausarClick(Sender: TObject);
    procedure BtContinuarClick(Sender: TObject);
    procedure BtVoltarClick(Sender: TObject);
    procedure BtPousarClick(Sender: TObject);
    procedure TimerTick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
  public
    constructor Create(AOwner: TComponent); override;
    { Adiciona um ponto ao fim da rota (clique no mapa). }
    procedure AdicionaPonto(ALat, ALon: Double);
    property ModoAdicionar: Boolean read FModoAdicionar;
  end;

var
  frmRotaVoo: TfrmRotaVoo = nil;

{ True se o drone selecionado tem GPS; senão AMotivo explica por quê. }
function RotaDisponivel(out AMotivo: string): Boolean;
{ Abre a janela de rota (ou explica por que não está disponível). }
procedure AbreRotaVoo;

implementation

uses
  setmain, main, map, conectionmavlink;

const
  COL_LAT = 1;
  COL_LON = 2;
  COL_ALT = 3;
  COL_VEL = 4;
  COL_TRECHO = 5;
  COL_ESTADO = 6;

function ProtocoloSelecionado: Integer;
begin
  if Assigned(FSetMain) then
    Result := FSetMain.DroneProtocolo
  else
    Result := -1;
end;

function RotaDisponivel(out AMotivo: string): Boolean;
var
  Idx: Integer;
begin
  AMotivo := '';
  Idx := ProtocoloSelecionado;
  Result := ProtocoloTemGPS(Idx);
  if not Result then
    AMotivo := Format(
      'O planejamento de rota de voo está disponível apenas para drones com GPS.' + LineEnding +
      LineEnding +
      'O drone selecionado (%s) não tem GPS.' + LineEnding + LineEnding +
      'Drones com GPS suportados: MAVLink (ArduPilot ou PX4).' + LineEnding +
      'Selecione-o em Configuração > Protocolo.', [NomeProtocolo(Idx)]);
end;

procedure AbreRotaVoo;
var
  Motivo: string;
begin
  if not RotaDisponivel(Motivo) then
  begin
    MessageDlg('Rota de voo', Motivo, mtInformation, [mbOK], 0);
    Exit;
  end;
  if not Assigned(frmRotaVoo) then
    frmRotaVoo := TfrmRotaVoo.Create(Application);
  frmRotaVoo.Show;
  frmRotaVoo.BringToFront;
  if Assigned(frmMain) then
    frmMain.MostraMapa;
end;

{ TfrmRotaVoo }

constructor TfrmRotaVoo.Create(AOwner: TComponent);
begin
  // Formulário montado em código: não há .lfm para carregar.
  inherited CreateNew(AOwner, 0);
  Caption := 'Rota de voo (drones com GPS)';
  Width := 960;
  Height := 600;
  Position := poDesigned;
  Left := 20;
  Top := 60;
  OnClose := @FormClose;
  FUltimoItem := -99;

  FAbrir := TOpenDialog.Create(Self);
  FAbrir.Title := 'Abrir rota';
  FAbrir.Filter := 'Rota (Mission Planner / QGroundControl)|*.waypoints;*.txt|Todos os arquivos|*.*';
  FSalvar := TSaveDialog.Create(Self);
  FSalvar.Title := 'Salvar rota';
  FSalvar.Filter := 'Rota (Mission Planner / QGroundControl)|*.waypoints|Todos os arquivos|*.*';
  FSalvar.DefaultExt := 'waypoints';
  FSalvar.Options := FSalvar.Options + [ofOverwritePrompt];

  MontaTela;
  CarregaOpcoes;
  AtualizaGrade;
  AtualizaResumo;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 250;
  FTimer.OnTimer := @TimerTick;
  FTimer.Enabled := True;

  Log('Pontos: "Adicionar pelo mapa" e clique no mapa (ou Ctrl+clique). ' +
    'Arraste o mapa para navegar e use a roda do mouse para o zoom.');
end;

procedure TfrmRotaVoo.MontaTela;
var
  Topo, Direita, Opcoes: TPanel;
  GbDrone, GbComandos: TGroupBox;
  X: Integer;

  function Botao(AParent: TWinControl; ALeft, ATop, AWidth: Integer;
    const ATexto: string; AEvento: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := AParent;
    Result.SetBounds(ALeft, ATop, AWidth, 28);
    Result.Caption := ATexto;
    Result.OnClick := AEvento;
  end;

  function BotaoEdicao(const ATexto: string; AWidth: Integer; AEvento: TNotifyEvent): TButton;
  begin
    Result := Botao(Topo, X, 6, AWidth, ATexto, AEvento);
    Inc(X, AWidth + 4);
    SetLength(FBtsEdicao, Length(FBtsEdicao) + 1);
    FBtsEdicao[High(FBtsEdicao)] := Result;
  end;

  function Rotulo(AParent: TWinControl; ALeft, ATop: Integer; const ATexto: string;
    ANegrito: Boolean = False): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := AParent;
    Result.Left := ALeft;
    Result.Top := ATop;
    Result.Caption := ATexto;
    if ANegrito then
      Result.Font.Style := [fsBold];
  end;

  function Valor(ATop: Integer; const ATitulo: string): TLabel;
  begin
    Rotulo(GbDrone, 8, ATop, ATitulo, True);
    Result := Rotulo(GbDrone, 78, ATop, '-');
  end;

  function Campo(ALeft, AWidth: Integer; const ATitulo: string): TEdit;
  begin
    Rotulo(Opcoes, ALeft, 8, ATitulo);
    Result := TEdit.Create(Self);
    Result.Parent := Opcoes;
    Result.SetBounds(ALeft, 26, AWidth, 24);
    Result.OnEditingDone := @OpcaoAlterada;
  end;

begin
  // Barra de edição da rota
  Topo := TPanel.Create(Self);
  Topo.Parent := Self;
  Topo.Align := alTop;
  Topo.Height := 40;
  Topo.BevelOuter := bvNone;
  X := 8;
  FBtMapa := BotaoEdicao('Adicionar pelo mapa', 150, @BtMapaClick);
  BotaoEdicao('Posição do drone', 120, @BtPosicaoDroneClick);
  BotaoEdicao('Subir', 60, @BtSubirClick);
  BotaoEdicao('Descer', 60, @BtDescerClick);
  BotaoEdicao('Remover', 70, @BtRemoverClick);
  BotaoEdicao('Limpar', 64, @BtLimparClick);
  BotaoEdicao('Abrir...', 70, @BtAbrirClick);
  Botao(Topo, X, 6, 70, 'Salvar...', @BtSalvarClick);

  // Painel do drone e comandos
  Direita := TPanel.Create(Self);
  Direita.Parent := Self;
  Direita.Align := alRight;
  Direita.Width := 320;
  Direita.BevelOuter := bvNone;

  GbDrone := TGroupBox.Create(Self);
  GbDrone.Parent := Direita;
  GbDrone.Align := alTop;
  GbDrone.Height := 150;
  GbDrone.Caption := ' Drone ';
  FLbConexao := Valor(4, 'Conexão:');
  FLbGps := Valor(24, 'GPS:');
  FLbPosicao := Valor(44, 'Posição:');
  FLbBateria := Valor(64, 'Bateria:');
  FLbModo := Valor(84, 'Modo:');
  FLbRota := Valor(104, 'Rota:');

  GbComandos := TGroupBox.Create(Self);
  GbComandos.Parent := Direita;
  GbComandos.Align := alTop;
  GbComandos.Top := 200;
  GbComandos.Height := 168;
  GbComandos.Caption := ' Comandos ';
  FBtEnviar := Botao(GbComandos, 8, 4, 145, 'Enviar ao drone', @BtEnviarClick);
  FBtIniciar := Botao(GbComandos, 160, 4, 145, 'Iniciar rota', @BtIniciarClick);
  FBtIniciar.Font.Style := [fsBold];
  FBtPausar := Botao(GbComandos, 8, 40, 145, 'Pausar (pairar)', @BtPausarClick);
  FBtContinuar := Botao(GbComandos, 160, 40, 145, 'Continuar rota', @BtContinuarClick);
  FBtVoltar := Botao(GbComandos, 8, 76, 297, 'Voltar ao ponto de partida (RTL)', @BtVoltarClick);
  FBtPousar := Botao(GbComandos, 8, 112, 297, 'POUSAR AGORA', @BtPousarClick);
  FBtPousar.Font.Style := [fsBold];
  FBtPousar.Font.Color := clRed;

  FMemo := TMemo.Create(Self);
  FMemo.Parent := Direita;
  FMemo.Align := alClient;
  FMemo.ReadOnly := True;
  FMemo.ScrollBars := ssAutoVertical;

  // Opções da rota
  Opcoes := TPanel.Create(Self);
  Opcoes.Parent := Self;
  Opcoes.Align := alBottom;
  Opcoes.Height := 84;
  Opcoes.BevelOuter := bvNone;
  FEdDecolagem := Campo(8, 70, 'Decolagem (m):');
  FEdVelocidade := Campo(118, 70, 'Velocidade (m/s):');
  FEdDistMax := Campo(238, 80, 'Distância máx. (m):');
  Rotulo(Opcoes, 358, 8, 'Ao terminar:');
  FCbAcao := TComboBox.Create(Self);
  FCbAcao.Parent := Opcoes;
  FCbAcao.SetBounds(358, 26, 200, 24);
  FCbAcao.Style := csDropDownList;
  FCbAcao.Items.Add('Voltar ao ponto de partida');
  FCbAcao.Items.Add('Pousar no último ponto');
  FCbAcao.Items.Add('Pairar no último ponto');
  FCbAcao.OnChange := @OpcaoAlterada;
  Botao(Opcoes, 570, 24, 64, 'Validar', @BtValidarClick);
  FLbResumo := Rotulo(Opcoes, 8, 58, '', True);

  // Tabela de pontos
  FGrade := TStringGrid.Create(Self);
  FGrade.Parent := Self;
  FGrade.Align := alClient;
  FGrade.ColCount := 7;
  FGrade.RowCount := 1;
  FGrade.FixedCols := 1;
  FGrade.FixedRows := 1;
  FGrade.Options := [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine,
    goEditing, goColSizing, goTabs, goThumbTracking];
  FGrade.Cells[0, 0] := 'Nº';
  FGrade.Cells[COL_LAT, 0] := 'Latitude';
  FGrade.Cells[COL_LON, 0] := 'Longitude';
  FGrade.Cells[COL_ALT, 0] := 'Altitude (m)';
  FGrade.Cells[COL_VEL, 0] := 'Velocidade (m/s)';
  FGrade.Cells[COL_TRECHO, 0] := 'Trecho (m)';
  FGrade.Cells[COL_ESTADO, 0] := 'Situação';
  FGrade.ColWidths[0] := 36;
  FGrade.ColWidths[COL_LAT] := 100;
  FGrade.ColWidths[COL_LON] := 100;
  FGrade.ColWidths[COL_ALT] := 82;
  FGrade.ColWidths[COL_VEL] := 105;
  FGrade.ColWidths[COL_TRECHO] := 76;
  FGrade.ColWidths[COL_ESTADO] := 80;
  FGrade.OnSelectEditor := @GradeEditor;
  FGrade.OnValidateEntry := @GradeValida;
end;

procedure TfrmRotaVoo.Log(const ATexto: string);
begin
  if not Assigned(FMemo) then
    Exit;
  if FMemo.Lines.Count > 400 then
    FMemo.Lines.Delete(0);
  if (Length(ATexto) > 9) and (ATexto[3] = ':') and (ATexto[6] = ':') then
    FMemo.Lines.Add(ATexto)   // já vem com hora (avisos do protocolo)
  else
    FMemo.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + ATexto);
end;

{ Opções }

procedure TfrmRotaVoo.CarregaOpcoes;
begin
  if Assigned(FSetMain) then
  begin
    GlobalFlightPlan.AltitudeDecolagem := FSetMain.Rota.AltDecolagem;
    GlobalFlightPlan.VelocidadePadrao := FSetMain.Rota.Velocidade;
    GlobalFlightPlan.AcaoFinal := TAcaoFinal(EnsureRange(FSetMain.Rota.AcaoFinal, 0, 2));
    GlobalFlightPlan.DistanciaMaxima := FSetMain.Rota.DistMaxima;
  end;
  EscreveOpcoes;
end;

procedure TfrmRotaVoo.EscreveOpcoes;
begin
  FEdDecolagem.Text := FormataNumero(GlobalFlightPlan.AltitudeDecolagem, 1);
  FEdVelocidade.Text := FormataNumero(GlobalFlightPlan.VelocidadePadrao, 1);
  FEdDistMax.Text := FormataNumero(GlobalFlightPlan.DistanciaMaxima, 0);
  FCbAcao.ItemIndex := Ord(GlobalFlightPlan.AcaoFinal);
end;

procedure TfrmRotaVoo.LeOpcoes;
var
  V: Double;
begin
  if LeNumero(FEdDecolagem.Text, V) and (V >= ROTA_ALT_MIN_ABSOLUTA) and (V <= ROTA_ALT_MAX_ABSOLUTA) then
    GlobalFlightPlan.AltitudeDecolagem := V
  else
    Log(Format('Decolagem: use de %s a %s m.', [FormataNumero(ROTA_ALT_MIN_ABSOLUTA, 0),
      FormataNumero(ROTA_ALT_MAX_ABSOLUTA, 0)]));
  if LeNumero(FEdVelocidade.Text, V) and (V >= ROTA_VEL_MIN) and (V <= ROTA_VEL_MAX) then
    GlobalFlightPlan.VelocidadePadrao := V
  else
    Log(Format('Velocidade: use de %s a %s m/s.', [FormataNumero(ROTA_VEL_MIN, 1),
      FormataNumero(ROTA_VEL_MAX, 0)]));
  if LeNumero(FEdDistMax.Text, V) and (V >= 10) and (V <= 5000) then
    GlobalFlightPlan.DistanciaMaxima := V
  else
    Log('Distância máxima: use de 10 a 5000 m.');
  if FCbAcao.ItemIndex >= 0 then
    GlobalFlightPlan.AcaoFinal := TAcaoFinal(FCbAcao.ItemIndex);
  EscreveOpcoes;

  if Assigned(FSetMain) then
  begin
    FSetMain.Rota.AltDecolagem := GlobalFlightPlan.AltitudeDecolagem;
    FSetMain.Rota.Velocidade := GlobalFlightPlan.VelocidadePadrao;
    FSetMain.Rota.AcaoFinal := Ord(GlobalFlightPlan.AcaoFinal);
    FSetMain.Rota.DistMaxima := GlobalFlightPlan.DistanciaMaxima;
    FSetMain.SalvaContexto;
  end;
end;

procedure TfrmRotaVoo.OpcaoAlterada(Sender: TObject);
begin
  LeOpcoes;
  FPrecisaAtualizar := True;
end;

{ Tabela }

function TfrmRotaVoo.LinhaSelecionada: Integer;
begin
  Result := FGrade.Row - 1;
  if (Result < 0) or (Result >= GlobalFlightPlan.WaypointCount) then
    Result := -1;
end;

procedure TfrmRotaVoo.SelecionaPonto(AIndice: Integer);
begin
  if (AIndice >= 0) and (AIndice + 1 < FGrade.RowCount) then
    FGrade.Row := AIndice + 1;
end;

procedure TfrmRotaVoo.AtualizaGrade;
var
  I, Linha: Integer;
  W: TWaypoint;
  S: string;
begin
  Linha := FGrade.Row;
  FGrade.BeginUpdate;
  try
    FGrade.RowCount := GlobalFlightPlan.WaypointCount + 1;
    for I := 0 to GlobalFlightPlan.WaypointCount - 1 do
    begin
      W := GlobalFlightPlan[I];
      FGrade.Cells[0, I + 1] := IntToStr(I + 1);
      FGrade.Cells[COL_LAT, I + 1] := FormataNumero(W.Latitude, 7);
      FGrade.Cells[COL_LON, I + 1] := FormataNumero(W.Longitude, 7);
      FGrade.Cells[COL_ALT, I + 1] := FormataNumero(W.Altitude, 1);
      FGrade.Cells[COL_VEL, I + 1] := FormataNumero(W.Speed, 1);
      if (I = 0) and not GlobalFlightPlan.HomeValido then
        FGrade.Cells[COL_TRECHO, I + 1] := '-'
      else
        FGrade.Cells[COL_TRECHO, I + 1] := FormataNumero(GlobalFlightPlan.DistanciaTrecho(I), 0);
      if W.Status = 'ACTIVE' then
        S := 'EM CURSO'
      else if W.Status = 'COMPLETED' then
        S := 'concluído'
      else
        S := 'pendente';
      FGrade.Cells[COL_ESTADO, I + 1] := S;
    end;
  finally
    FGrade.EndUpdate;
  end;
  if (Linha > 0) and (Linha < FGrade.RowCount) then
    FGrade.Row := Linha;
end;

procedure TfrmRotaVoo.AtualizaResumo;
const
  ACOES: array[TAcaoFinal] of string = ('voltar ao ponto de partida',
    'pousar no último ponto', 'pairar no último ponto');
var
  S: string;
begin
  if GlobalFlightPlan.WaypointCount = 0 then
  begin
    FLbResumo.Caption := 'Rota vazia.';
    Exit;
  end;
  S := Format('%d pontos  |  %s m  |  cerca de %s  |  ao terminar: %s',
    [GlobalFlightPlan.WaypointCount, FormataNumero(GlobalFlightPlan.DistanciaTotal, 0),
     TextoTempo(GlobalFlightPlan.TempoEstimado), ACOES[GlobalFlightPlan.AcaoFinal]]);
  if not GlobalFlightPlan.HomeValido then
    S := S + '  (sem ponto de partida: distância parcial)';
  FLbResumo.Caption := S;
end;

procedure TfrmRotaVoo.RedesenhaMapa;
begin
  if Assigned(frmMap) and frmMap.Visible then
    frmMap.gridMAP.RenderAndDrawControl;
end;

procedure TfrmRotaVoo.GradeEditor(Sender: TObject; aCol, aRow: Integer;
  var Editor: TWinControl);
begin
  // Só latitude, longitude, altitude e velocidade; nunca em voo.
  if (aCol < COL_LAT) or (aCol > COL_VEL) or (aRow < 1) or EmVoo then
    Editor := nil;
end;

procedure TfrmRotaVoo.GradeValida(Sender: TObject; aCol, aRow: Integer;
  const OldValue: string; var NewValue: string);
var
  W: TWaypoint;
  V: Double;
  Ok: Boolean;
begin
  W := GlobalFlightPlan[aRow - 1];
  if not Assigned(W) then
    Exit;
  Ok := LeNumero(NewValue, V);
  case aCol of
    COL_LAT: Ok := Ok and (Abs(V) <= 90) and (V <> 0);
    COL_LON: Ok := Ok and (Abs(V) <= 180) and (V <> 0);
    COL_ALT: Ok := Ok and (V >= ROTA_ALT_MIN_ABSOLUTA) and (V <= ROTA_ALT_MAX_ABSOLUTA);
    COL_VEL: Ok := Ok and (V >= ROTA_VEL_MIN) and (V <= ROTA_VEL_MAX);
  end;
  if not Ok then
  begin
    Log(Format('Valor inválido "%s" no ponto %d.', [NewValue, aRow]));
    NewValue := OldValue;
    Exit;
  end;
  case aCol of
    COL_LAT: W.Latitude := V;
    COL_LON: W.Longitude := V;
    COL_ALT: W.Altitude := V;
    COL_VEL: W.Speed := V;
  end;
  FPrecisaAtualizar := True;
end;

{ Pontos }

procedure TfrmRotaVoo.AdicionaPonto(ALat, ALon: Double);
var
  Alt: Double;
  N: Integer;
begin
  if EmVoo then
  begin
    Log('Não é possível alterar a rota com o drone armado.');
    Exit;
  end;
  N := GlobalFlightPlan.WaypointCount;
  if N >= ROTA_MAX_PONTOS then
  begin
    Log(Format('Limite de %d pontos atingido.', [ROTA_MAX_PONTOS]));
    Exit;
  end;
  if N > 0 then
    Alt := GlobalFlightPlan[N - 1].Altitude
  else
    Alt := GlobalFlightPlan.AltitudeDecolagem;
  GlobalFlightPlan.AddWaypoint(ALat, ALon, Alt, GlobalFlightPlan.VelocidadePadrao);
  Log(Format('Ponto %d: %s, %s a %s m.', [N + 1, FormataNumero(ALat, 6),
    FormataNumero(ALon, 6), FormataNumero(Alt, 1)]));
  if not GlobalFlightPlan.IsWithinGeofence(ALat, ALon) then
    Log(Format('Atenção: o ponto %d está fora da geocerca.', [N + 1]));
  if GlobalFlightPlan.HomeValido and (DistanciaMetros(GlobalFlightPlan.HomeLat,
    GlobalFlightPlan.HomeLon, ALat, ALon) > GlobalFlightPlan.DistanciaMaxima) then
    Log(Format('Atenção: o ponto %d passa da distância máxima do ponto de partida.', [N + 1]));
  AtualizaGrade;
  SelecionaPonto(N);
  AtualizaResumo;
  RedesenhaMapa;
end;

procedure TfrmRotaVoo.DefineModoAdicionar(AValor: Boolean);
begin
  FModoAdicionar := AValor;
  if FModoAdicionar then
  begin
    FBtMapa.Caption := 'Parar de adicionar';
    FBtMapa.Font.Style := [fsBold];
    if Assigned(frmMain) then
      frmMain.MostraMapa;
  end
  else
  begin
    FBtMapa.Caption := 'Adicionar pelo mapa';
    FBtMapa.Font.Style := [];
  end;
end;

procedure TfrmRotaVoo.BtMapaClick(Sender: TObject);
begin
  DefineModoAdicionar(not FModoAdicionar);
end;

procedure TfrmRotaVoo.BtPosicaoDroneClick(Sender: TObject);
var
  P: TAIDroneMavlink;
begin
  P := Protocolo;
  if (P = nil) or (not P.Telemetry.Connected) or (not P.Telemetry.PositionValid) then
  begin
    Log('Posição do drone indisponível (sem conexão ou sem GPS).');
    Exit;
  end;
  AdicionaPonto(P.Telemetry.Lat, P.Telemetry.Lon);
end;

procedure TfrmRotaVoo.BtSubirClick(Sender: TObject);
var
  I: Integer;
begin
  I := LinhaSelecionada;
  if (I > 0) and not EmVoo then
  begin
    GlobalFlightPlan.MoveWaypoint(I, I - 1);
    AtualizaGrade;
    SelecionaPonto(I - 1);
    FPrecisaAtualizar := True;
  end;
end;

procedure TfrmRotaVoo.BtDescerClick(Sender: TObject);
var
  I: Integer;
begin
  I := LinhaSelecionada;
  if (I >= 0) and (I < GlobalFlightPlan.WaypointCount - 1) and not EmVoo then
  begin
    GlobalFlightPlan.MoveWaypoint(I, I + 1);
    AtualizaGrade;
    SelecionaPonto(I + 1);
    FPrecisaAtualizar := True;
  end;
end;

procedure TfrmRotaVoo.BtRemoverClick(Sender: TObject);
var
  I: Integer;
begin
  I := LinhaSelecionada;
  if (I >= 0) and not EmVoo then
  begin
    GlobalFlightPlan.DeleteWaypoint(I);
    Log(Format('Ponto %d removido.', [I + 1]));
    FPrecisaAtualizar := True;
  end;
end;

procedure TfrmRotaVoo.BtLimparClick(Sender: TObject);
begin
  if EmVoo or (GlobalFlightPlan.WaypointCount = 0) then
    Exit;
  if MessageDlg('Rota de voo', 'Apagar todos os pontos da rota?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    GlobalFlightPlan.ClearWaypoints;
    Log('Rota apagada.');
    FPrecisaAtualizar := True;
  end;
end;

procedure TfrmRotaVoo.BtAbrirClick(Sender: TObject);
var
  Erro: string;
begin
  if EmVoo or not FAbrir.Execute then
    Exit;
  if GlobalFlightPlan.CarregaArquivo(FAbrir.FileName, Erro) then
  begin
    EscreveOpcoes;
    LeOpcoes;
    Log(Format('Rota carregada: %d pontos (%s).', [GlobalFlightPlan.WaypointCount,
      ExtractFileName(FAbrir.FileName)]));
    FPrecisaAtualizar := True;
  end
  else
    MessageDlg('Abrir rota', Erro, mtError, [mbOK], 0);
end;

procedure TfrmRotaVoo.BtSalvarClick(Sender: TObject);
begin
  if GlobalFlightPlan.WaypointCount = 0 then
  begin
    Log('A rota está vazia.');
    Exit;
  end;
  if not FSalvar.Execute then
    Exit;
  try
    GlobalFlightPlan.SalvaArquivo(FSalvar.FileName);
    Log('Rota salva em ' + FSalvar.FileName);
  except
    on E: Exception do
      MessageDlg('Salvar rota', E.Message, mtError, [mbOK], 0);
  end;
end;

{ Validação }

function TfrmRotaVoo.ValidaComMensagem: Boolean;
var
  Erros, Avisos: TStringList;
  I: Integer;
begin
  Erros := TStringList.Create;
  Avisos := TStringList.Create;
  try
    Result := GlobalFlightPlan.Valida(Erros, Avisos);
    for I := 0 to Avisos.Count - 1 do
      Log('Aviso: ' + Avisos[I]);
    if not Result then
    begin
      for I := 0 to Erros.Count - 1 do
        Log('Erro: ' + Erros[I]);
      MessageDlg('Rota de voo', 'A rota tem problemas:' + LineEnding + LineEnding +
        Trim(Erros.Text), mtError, [mbOK], 0);
    end;
  finally
    Avisos.Free;
    Erros.Free;
  end;
end;

procedure TfrmRotaVoo.BtValidarClick(Sender: TObject);
begin
  LeOpcoes;
  if ValidaComMensagem then
  begin
    Log('Rota válida.');
    MessageDlg('Rota de voo', 'Rota válida.' + LineEnding + FLbResumo.Caption,
      mtInformation, [mbOK], 0);
  end;
end;

{ Drone }

function TfrmRotaVoo.Protocolo: TAIDroneMavlink;
begin
  Result := nil;
  if Assigned(frmMain) and (frmMain.frmConnection is TfrmConectionMavlink) then
    Result := TfrmConectionMavlink(frmMain.frmConnection).Mavlink;
end;

function TfrmRotaVoo.EmVoo: Boolean;
var
  P: TAIDroneMavlink;
begin
  P := Protocolo;
  Result := (P <> nil) and P.Active and (P.Telemetry.Armed or P.RouteActive);
end;

function TfrmRotaVoo.RotaEnviadaAtual: Boolean;
var
  P: TAIDroneMavlink;
begin
  P := Protocolo;
  Result := (P <> nil) and (P.MissionState = msAccepted) and
    (FAssinaturaEnviada = GlobalFlightPlan.Assinatura);
end;

function TfrmRotaVoo.DroneProntoParaRota(AParaEnvio: Boolean; out AMotivo: string): Boolean;
var
  P: TAIDroneMavlink;
  T: TAIMavTelemetry;
begin
  Result := False;
  P := Protocolo;
  if (P = nil) or not P.Active then
  begin
    AMotivo := 'Ligue o cockpit (Start) com o protocolo MAVLink para falar com o drone.';
    Exit;
  end;
  T := P.Telemetry;
  if not T.Connected then
    AMotivo := 'O drone não está respondendo (sem sinal MAVLink).'
  else if (T.Autopilot <> MAV_AUTOPILOT_ARDUPILOT) and (T.Autopilot <> MAV_AUTOPILOT_PX4) then
    AMotivo := 'Piloto automático não suportado: a rota funciona com ArduPilot ou PX4.'
  else if not P.IsMultirotor then
    AMotivo := 'A rota é feita para multirrotores; este veículo é de outro tipo.'
  else if T.GpsFix < 3 then
    AMotivo := 'O GPS do drone ainda não tem fix 3D (' + P.GpsText + '). Aguarde.'
  else if T.Satellites < ROTA_SATELITES_MIN then
    AMotivo := Format('Poucos satélites (%d; mínimo %d). Aguarde.', [T.Satellites, ROTA_SATELITES_MIN])
  else if not T.PositionValid then
    AMotivo := 'A posição do drone ainda é desconhecida.'
  else if not GlobalFlightPlan.HomeValido then
    AMotivo := 'O ponto de partida do drone ainda é desconhecido.'
  else if (T.BatteryPct >= 0) and (T.BatteryPct < ROTA_BATERIA_MIN) then
    AMotivo := Format('Bateria em %d%% (mínimo %d%% para iniciar uma rota).',
      [T.BatteryPct, ROTA_BATERIA_MIN])
  else if AParaEnvio and T.Armed then
    AMotivo := 'O drone está armado: pouse e desarme antes de trocar a rota.'
  else
    Result := True;
end;

procedure TfrmRotaVoo.BtEnviarClick(Sender: TObject);
var
  P: TAIDroneMavlink;
  Motivo: string;
  M: TAIMavMission;
  I: Integer;
begin
  LeOpcoes;
  if not DroneProntoParaRota(True, Motivo) then
  begin
    MessageDlg('Enviar rota', Motivo, mtWarning, [mbOK], 0);
    Exit;
  end;
  if not ValidaComMensagem then
    Exit;
  P := Protocolo;
  M := MontaMissao(GlobalFlightPlan, P.Telemetry.Autopilot = MAV_AUTOPILOT_ARDUPILOT);
  if Length(M) = 0 then
  begin
    MessageDlg('Enviar rota', 'Não foi possível montar a missão.', mtError, [mbOK], 0);
    Exit;
  end;
  Log('Missão:');
  for I := 0 to High(M) do
    Log(Format('  %d. %s', [I, TAIDroneMavlink.DescribeItem(M[I])]));
  GlobalFlightPlan.ResetStatus;
  FAssinaturaEnviada := GlobalFlightPlan.Assinatura;
  FUltimoItem := -99;
  P.UploadMission(M);
  FPrecisaAtualizar := True;
end;

procedure TfrmRotaVoo.BtIniciarClick(Sender: TObject);
const
  ACOES: array[TAcaoFinal] of string = ('voltar ao ponto de partida e pousar',
    'pousar no último ponto', 'pairar no último ponto');
var
  P: TAIDroneMavlink;
  Motivo, Texto: string;
begin
  P := Protocolo;
  if not RotaEnviadaAtual then
  begin
    MessageDlg('Iniciar rota', 'A rota ainda não foi enviada ou mudou depois do envio.' +
      LineEnding + 'Clique em "Enviar ao drone" antes de iniciar.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if not DroneProntoParaRota(False, Motivo) then
  begin
    MessageDlg('Iniciar rota', Motivo, mtWarning, [mbOK], 0);
    Exit;
  end;
  if not ValidaComMensagem then
    Exit;

  if P.Telemetry.Armed then
    Texto := 'O drone (já armado) vai seguir a rota desde o início:'
  else
    Texto := Format('O drone vai ARMAR e DECOLAR até %s m. Depois:',
      [FormataNumero(GlobalFlightPlan.AltitudeDecolagem, 1)]);
  Texto := Texto + LineEnding + Format('  %d pontos, %s m, cerca de %s;',
    [GlobalFlightPlan.WaypointCount, FormataNumero(GlobalFlightPlan.DistanciaTotal, 0),
     TextoTempo(GlobalFlightPlan.TempoEstimado)]) + LineEnding +
    '  ao terminar: ' + ACOES[GlobalFlightPlan.AcaoFinal] + '.' + LineEnding + LineEnding +
    'Confira se a área está livre de pessoas e obstáculos e se você pode ' +
    'retomar o controle (Pausar, Voltar ao ponto de partida, Pousar).' + LineEnding +
    LineEnding + 'Iniciar a rota agora?';
  if MessageDlg('Iniciar rota', Texto, mtWarning, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  DefineModoAdicionar(False);
  GlobalFlightPlan.ResetStatus;
  FUltimoItem := -99;
  P.StartMission;
  FPrecisaAtualizar := True;
end;

procedure TfrmRotaVoo.BtPausarClick(Sender: TObject);
begin
  if Protocolo <> nil then
    Protocolo.PauseMission;
end;

procedure TfrmRotaVoo.BtContinuarClick(Sender: TObject);
begin
  if Protocolo <> nil then
    Protocolo.ResumeMission;
end;

procedure TfrmRotaVoo.BtVoltarClick(Sender: TObject);
begin
  if Protocolo <> nil then
    Protocolo.ReturnToLaunch;
end;

procedure TfrmRotaVoo.BtPousarClick(Sender: TObject);
begin
  if Protocolo <> nil then
    Protocolo.Land;
end;

{ Atualização periódica }

procedure TfrmRotaVoo.AtualizaPainel;
var
  P: TAIDroneMavlink;
  T: TAIMavTelemetry;
  Conectado, Atual, Voando: Boolean;
  I, Ativo: Integer;
begin
  P := Protocolo;
  Conectado := (P <> nil) and P.Active and P.Telemetry.Connected;
  if Conectado then
    T := P.Telemetry
  else
    FillChar(T, SizeOf(T), 0);
  Atual := RotaEnviadaAtual;
  Voando := EmVoo;

  if not ProtocoloTemGPS(ProtocoloSelecionado) then
    FLbConexao.Caption := 'drone selecionado sem GPS'
  else if P = nil then
    FLbConexao.Caption := 'desligado (clique em Start no cockpit)'
  else if not P.Active then
    FLbConexao.Caption := 'falha ao abrir a porta UDP'
  else if not Conectado then
    FLbConexao.Caption := 'aguardando o drone...'
  else if T.Autopilot = MAV_AUTOPILOT_PX4 then
    FLbConexao.Caption := Format('PX4, sistema %d', [T.SysId])
  else
    FLbConexao.Caption := Format('ArduPilot, sistema %d', [T.SysId]);

  if Conectado then
  begin
    FLbGps.Caption := P.GpsText;
    if (T.GpsFix >= 3) and (T.Satellites >= ROTA_SATELITES_MIN) then
      FLbGps.Font.Color := clGreen
    else
      FLbGps.Font.Color := clRed;
    if T.PositionValid then
      FLbPosicao.Caption := Format('%s, %s  alt %s m  %s m/s',
        [FormataNumero(T.Lat, 6), FormataNumero(T.Lon, 6),
         FormataNumero(T.RelativeAlt, 1), FormataNumero(T.GroundSpeed, 1)])
    else
      FLbPosicao.Caption := 'desconhecida';
    if T.BatteryPct >= 0 then
      FLbBateria.Caption := Format('%d%%  (%s V)', [T.BatteryPct, FormataNumero(T.BatteryVoltage, 2)])
    else if T.BatteryVoltage > 0 then
      FLbBateria.Caption := FormataNumero(T.BatteryVoltage, 2) + ' V'
    else
      FLbBateria.Caption := '-';
    FLbModo.Caption := P.ModeText;
    if T.Armed then
      FLbModo.Font.Color := clRed
    else
      FLbModo.Font.Color := clDefault;
  end
  else
  begin
    FLbGps.Caption := '-';
    FLbGps.Font.Color := clDefault;
    FLbPosicao.Caption := '-';
    FLbBateria.Caption := '-';
    FLbModo.Caption := '-';
    FLbModo.Font.Color := clDefault;
  end;

  // Situação da rota
  if P = nil then
    FLbRota.Caption := 'não enviada'
  else
    case P.MissionState of
      msNone: FLbRota.Caption := 'não enviada';
      msUploading: FLbRota.Caption := 'enviando ao drone...';
      msFailed: FLbRota.Caption := 'envio falhou (veja abaixo)';
      msAccepted:
        if not Atual then
          FLbRota.Caption := 'ALTERADA depois do envio: envie de novo'
        else if P.RouteActive or P.IsMissionMode then
        begin
          Ativo := -1;
          for I := 0 to GlobalFlightPlan.WaypointCount - 1 do
            if GlobalFlightPlan[I].Status = 'ACTIVE' then
              Ativo := I;
          if Ativo >= 0 then
            FLbRota.Caption := Format('em execução: ponto %d de %d',
              [Ativo + 1, GlobalFlightPlan.WaypointCount])
          else if (GlobalFlightPlan.WaypointCount > 0) and
            (GlobalFlightPlan[GlobalFlightPlan.WaypointCount - 1].Status = 'COMPLETED') then
            FLbRota.Caption := 'pontos concluídos: finalizando'
          else
            FLbRota.Caption := 'em execução: decolando';
        end
        else
          FLbRota.Caption := 'enviada e confirmada pelo drone';
    end;

  // Botões
  FBtEnviar.Enabled := Conectado and (not T.Armed) and (P.MissionState <> msUploading) and
    (GlobalFlightPlan.WaypointCount > 0);
  FBtIniciar.Enabled := Conectado and Atual and (not P.RouteActive) and (P.StartState = ssNone);
  FBtPausar.Enabled := Conectado and T.Armed;
  FBtContinuar.Enabled := Conectado and T.Armed and Atual and (not P.IsMissionMode);
  FBtVoltar.Enabled := Conectado and T.Armed;
  FBtPousar.Enabled := Conectado and T.Armed;
  for I := 0 to High(FBtsEdicao) do
    FBtsEdicao[I].Enabled := not Voando;
  FEdDecolagem.Enabled := not Voando;
  FEdVelocidade.Enabled := not Voando;
  FEdDistMax.Enabled := not Voando;
  FCbAcao.Enabled := not Voando;
  if Voando and FModoAdicionar then
    DefineModoAdicionar(False);
end;

procedure TfrmRotaVoo.TimerTick(Sender: TObject);
var
  P: TAIDroneMavlink;
  T: TAIMavTelemetry;
  Msg: string;
  HLat, HLon: Double;
  TemHome: Boolean;
begin
  if not Visible then
    Exit;

  // O drone selecionado deixou de ter GPS (troca de protocolo).
  if not ProtocoloTemGPS(ProtocoloSelecionado) then
  begin
    if not FSemGpsAvisado then
    begin
      FSemGpsAvisado := True;
      DefineModoAdicionar(False);
      Log('O drone selecionado não tem GPS: rota indisponível. Selecione o MAVLink.');
    end;
  end
  else
    FSemGpsAvisado := False;

  P := Protocolo;
  if P <> nil then
  begin
    while TfrmConectionMavlink(frmMain.frmConnection).ProximoAviso(Msg) do
      Log(Msg);
    T := P.Telemetry;

    // Ponto de partida: o do drone; antes dele, a posição atual (no chão).
    TemHome := False;
    if T.Connected and T.HomeValid then
    begin
      HLat := T.HomeLat;
      HLon := T.HomeLon;
      TemHome := True;
    end
    else if T.Connected and T.PositionValid and not T.Armed then
    begin
      HLat := T.Lat;
      HLon := T.Lon;
      TemHome := True;
    end;
    if TemHome and ((not GlobalFlightPlan.HomeValido) or
      (DistanciaMetros(HLat, HLon, GlobalFlightPlan.HomeLat, GlobalFlightPlan.HomeLon) > 2)) then
    begin
      GlobalFlightPlan.DefineHome(HLat, HLon);
      FPrecisaAtualizar := True;
    end;

    // Andamento da rota no drone
    if RotaEnviadaAtual and (P.RouteActive or P.IsMissionMode or T.Armed) and
      (T.CurrentItem <> FUltimoItem) then
    begin
      FUltimoItem := T.CurrentItem;
      AtualizaEstadoPontos(GlobalFlightPlan, P.Mission, T.CurrentItem);
      FPrecisaAtualizar := True;
    end;
  end;

  if FPrecisaAtualizar and not FGrade.EditorMode then
  begin
    FPrecisaAtualizar := False;
    AtualizaGrade;
    AtualizaResumo;
    RedesenhaMapa;
  end;
  AtualizaPainel;
end;

procedure TfrmRotaVoo.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  DefineModoAdicionar(False);
  CloseAction := caHide;
end;

end.
