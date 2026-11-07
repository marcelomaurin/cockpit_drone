unit config;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ComCtrls, ExtCtrls, Arrow, AdvLed, Types, SdpoJoystick, funcs, SdpoSerial,
  fpjson, jsonparser, IniFiles, cockpit_i18n
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

type

  { Tfrmconfig }

  Tfrmconfig = class(TForm)
    advButton0: TAdvLed;
    advButton1: TAdvLed;
    advButton2: TAdvLed;
    advButton3: TAdvLed;
    advButton4: TAdvLed;
    advButton5: TAdvLed;
    Arrow1: TArrow;
    Arrow2: TArrow;
    Arrow3: TArrow;
    Arrow4: TArrow;
    cbDevice: TComboBox;
    ckbGPS: TCheckBox;
    ckTest: TCheckBox;
    ckJoyActive: TCheckBox;
    cbBaudrate: TComboBox;
    cbSerialPort: TComboBox;
    edIP: TEdit;
    edTCPPORT: TEdit;
    edUDPPORT: TEdit;
    Label1: TLabel;
    Label10: TLabel;
    Label11: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    label1b1: TLabel;
    label1b2: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    lbX: TLabel;
    label1b: TLabel;
    lbY: TLabel;
    lbZ: TLabel;
    pcDrones: TPageControl;
    pnNAV: TPanel;
    cbDatabits: TRadioGroup;
    rgFlowControl: TRadioGroup;
    rgParity: TRadioGroup;
    rgStopbit: TRadioGroup;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    tsEquipamento: TTabSheet;
    timerJoystick: TTimer;

    procedure btCalibrationClick(Sender: TObject);
    procedure cbDeviceChange(Sender: TObject);
    procedure cbDroneClick(Sender: TObject);
    procedure cbSerialPortChange(Sender: TObject);
    procedure ckJoyActiveChange(Sender: TObject);
    procedure ckTestChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Label4Click(Sender: TObject);
    procedure TabSheet1ContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure timerJoystickTimer(Sender: TObject);
    procedure cbProtocolChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormShow(Sender: TObject);

  private
    procedure AtualizaLedsBotoes;
    procedure LimpaLeitura;
    function MainDisponivel: Boolean;
    function PortaSerialExiste(const APorta: string): Boolean;
    procedure CarregaPortasSeriais;
    procedure AdicionaPortaSeExistir(const APorta: string);
    function CriaCampo(AParent: TWinControl; ALeft, ATop, AWidth: Integer;
      const ARotulo, ANome: string): TEdit;
    function CriaOpcao(AParent: TWinControl; ALeft, ATop: Integer;
      const ARotulo, ANome: string): TCheckBox;
    procedure CriaAbaFQ777;
    procedure CriaAbaTello;
    procedure CriaAbaOpendrone;
    procedure CriaAbaARDrone;
    procedure CriaAbaESP32Drone;
    function GetModelConfigPath: string;
    procedure SelecionaModeloPorProtocolo(AProtoIdx: Integer);
    procedure CarregaCatalogo;
    procedure MarcaAlterada(Sender: TObject);
    procedure ModeloAlterado(Sender: TObject);
    procedure SelecionaModeloSalvo;
    procedure IdiomaAlterado(Sender: TObject);
    procedure CarregaIdioma;
    procedure CX10WSimuladoClick(Sender: TObject);

  public
    TipoAtivo: Integer;
    lblProtocol: TLabel;
    lblMarca: TLabel;
    lblModelo: TLabel;
    cbProtocol: TComboBox;
    cbMarca: TComboBox;
    cbModelo: TComboBox;
    cbIdioma: TComboBox;
    lblIdioma: TLabel;
    lblModeloStatus: TLabel;
    FCatalogo: TJSONArray;
    FCarregandoModelo: Boolean;

    // Dynamic tabs and edits
    ckCX10WSimulado: TCheckBox;
    tsMavlink: TTabSheet;
    edMavIP: TEdit;
    edMavPort: TEdit;
    edMavSysId: TEdit;

    tsTello: TTabSheet;
    edTelloIP: TEdit;
    ckTelloVideo: TCheckBox;
    edTelloFFmpeg: TEdit;

    tsOpendrone: TTabSheet;
    edOpendroneIP: TEdit;
    edOpendronePort: TEdit;
    edOpendroneAngulo: TEdit;

    tsFQ777: TTabSheet;
    edFQ777IP: TEdit;
    edFQ777TCP: TEdit;
    edFQ777UDP: TEdit;
    ckFQ777WifiAuto: TCheckBox;
    edFQ777SSID: TEdit;
    edFQ777Senha: TEdit;
    ckFQ777Video: TCheckBox;
    ckFQ777Gravar: TCheckBox;
    edFQ777FFmpeg: TEdit;
    edFQ777ZonaMorta: TEdit;
    edFQ777EixoRolagem: TEdit;
    edFQ777EixoArfagem: TEdit;
    edFQ777EixoGuinada: TEdit;
    edFQ777EixoAcelerador: TEdit;
    cbFQ777Acelerador: TComboBox;

    tsARDrone: TTabSheet;
    edARDroneIP: TEdit;
    ckARDroneVideo: TCheckBox;
    edARDroneFFmpeg: TEdit;
    edARDroneAltura: TEdit;
    ckARDroneExterno: TCheckBox;
    edARDroneSensibilidade: TEdit;

    tsESP32Drone: TTabSheet;
    edESP32IP: TEdit;
    edESP32Porta: TEdit;

    procedure AtualizaAbasProtocolo;
    procedure CarregarValoresTela;
    procedure SalvarConfiguracoes;
  end;

var
  frmconfig: Tfrmconfig;

implementation

{$R *.lfm}

uses
  main, setmain, Math;

{ Tfrmconfig }

function Tfrmconfig.MainDisponivel: Boolean;
begin
  Result := Assigned(frmMain) and Assigned(frmMain.SdpoJoystick1);
end;

procedure Tfrmconfig.LimpaLeitura;
begin
  lbX.Caption := '0';
  lbY.Caption := '0';
  lbZ.Caption := '0';

  advButton0.State := lsOff;
  advButton1.State := lsOff;
  advButton2.State := lsOff;
  advButton3.State := lsOff;
  advButton4.State := lsOff;
  advButton5.State := lsOff;
end;

procedure Tfrmconfig.AtualizaLedsBotoes;
begin
  if not MainDisponivel then
  begin
    LimpaLeitura;
    Exit;
  end;

  if frmMain.SdpoJoystick1.Buttons[0].ToBoolean then advButton0.State := lsOn else advButton0.State := lsOff;
  if frmMain.SdpoJoystick1.Buttons[1].ToBoolean then advButton1.State := lsOn else advButton1.State := lsOff;
  if frmMain.SdpoJoystick1.Buttons[2].ToBoolean then advButton2.State := lsOn else advButton2.State := lsOff;
  if frmMain.SdpoJoystick1.Buttons[3].ToBoolean then advButton3.State := lsOn else advButton3.State := lsOff;
  if frmMain.SdpoJoystick1.Buttons[4].ToBoolean then advButton4.State := lsOn else advButton4.State := lsOff;
  if frmMain.SdpoJoystick1.Buttons[5].ToBoolean then advButton5.State := lsOn else advButton5.State := lsOff;
end;

function Tfrmconfig.PortaSerialExiste(const APorta: string): Boolean;
{$IFDEF MSWINDOWS}
var
  Buffer: array[0..1023] of Char;
  NomeInterno: string;
begin
  FillChar(Buffer, SizeOf(Buffer), 0);

  NomeInterno := APorta;
  Result := QueryDosDevice(PChar(NomeInterno), Buffer, SizeOf(Buffer) div SizeOf(Char)) <> 0;
end;
{$ELSE}
begin
  Result := FileExists(APorta);
end;
{$ENDIF}

procedure Tfrmconfig.AdicionaPortaSeExistir(const APorta: string);
begin
  if (Trim(APorta) <> '') and PortaSerialExiste(APorta) then
  begin
    if cbSerialPort.Items.IndexOf(APorta) < 0 then
      cbSerialPort.Items.Add(APorta);
  end;
end;

procedure Tfrmconfig.CarregaPortasSeriais;
var
  I: Integer;
  Porta: string;
  PortaAnterior: string;
  SR: TSearchRec;
begin
  PortaAnterior := Trim(cbSerialPort.Text);

  cbSerialPort.Items.BeginUpdate;
  try
    cbSerialPort.Items.Clear;

    {$IFDEF MSWINDOWS}
    for I := 1 to 256 do
    begin
      Porta := 'COM' + IntToStr(I);
      AdicionaPortaSeExistir(Porta);
    end;
    {$ELSE}

    if FindFirst('/dev/ttyUSB*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') then
          AdicionaPortaSeExistir('/dev/' + SR.Name);
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;

    if FindFirst('/dev/ttyACM*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') then
          AdicionaPortaSeExistir('/dev/' + SR.Name);
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;

    if FindFirst('/dev/ttyS*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') then
          AdicionaPortaSeExistir('/dev/' + SR.Name);
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;

    if DirectoryExists('/dev/serial/by-id') then
    begin
      if FindFirst('/dev/serial/by-id/*', faAnyFile, SR) = 0 then
      begin
        repeat
          if (SR.Name <> '.') and (SR.Name <> '..') then
            AdicionaPortaSeExistir('/dev/serial/by-id/' + SR.Name);
        until FindNext(SR) <> 0;
        FindClose(SR);
      end;
    end;
    {$ENDIF}

    if PortaAnterior <> '' then
      cbSerialPort.ItemIndex := cbSerialPort.Items.IndexOf(PortaAnterior);

    if (cbSerialPort.ItemIndex < 0) and (cbSerialPort.Items.Count > 0) then
      cbSerialPort.ItemIndex := 0;
  finally
    cbSerialPort.Items.EndUpdate;
  end;
end;

procedure Tfrmconfig.FormCreate(Sender: TObject);
begin
  TipoAtivo := 0;
  LimpaLeitura;
  CarregaPortasSeriais;

  lblIdioma := TLabel.Create(Self);
  lblIdioma.Parent := pnNAV;
  lblIdioma.Caption := 'Idioma / Language';
  lblIdioma.Align := alTop;
  cbIdioma := TComboBox.Create(Self);
  cbIdioma.Parent := pnNAV;
  cbIdioma.Align := alTop;
  cbIdioma.Style := csDropDownList;
  cbIdioma.Items.Add('Português (Brasil)');
  cbIdioma.Items.Add('English');
  cbIdioma.Items.Add('Español');
  cbIdioma.Items.Add('中文 (简体)');
  cbIdioma.Items.Add('العربية');
  cbIdioma.Items.Add('Deutsch');
  cbIdioma.Items.Add('Русский');
  cbIdioma.Items.Add('हिन्दी');
  CarregaIdioma;
  cbIdioma.OnChange := @IdiomaAlterado;

  OnShow := @FormShow;
  OnClose := @FormClose;

  lblProtocol := TLabel.Create(Self);
  lblProtocol.Parent := tsEquipamento;
  lblProtocol.Caption := 'Protocolo de Comunicação:';
  lblProtocol.Font.Style := [fsBold];
  lblProtocol.SetBounds(16, 12, 320, 16);

  cbProtocol := TComboBox.Create(Self);
  cbProtocol.Parent := tsEquipamento;
  cbProtocol.SetBounds(16, 30, 320, 24);
  cbProtocol.Style := csDropDownList;
  cbProtocol.Items.Add('Cheerson CX-10W');
  cbProtocol.Items.Add('MAVLink (ArduPilot/PX4)');
  cbProtocol.Items.Add('DJI Tello (UDP)');
  cbProtocol.Items.Add('ESP-Drone / OpenDrone (CRTP)');
  cbProtocol.Items.Add('FQ777-954 (Wi-Fi)');
  cbProtocol.Items.Add('Parrot AR.Drone 2.0');
  cbProtocol.Items.Add('Drone ESP32 (firmware Cockpit)');

  if Assigned(FSetMain) then
  begin
    cbProtocol.ItemIndex := FSetMain.DroneProtocolo;
    TipoAtivo := FSetMain.DroneProtocolo;
  end
  else
    cbProtocol.ItemIndex := 0;

  cbProtocol.OnChange := @cbProtocolChange;

  lblMarca := TLabel.Create(Self);
  lblMarca.Parent := tsEquipamento;
  lblMarca.Caption := 'Fabricante / Marca:';
  lblMarca.Font.Style := [fsBold];
  lblMarca.SetBounds(16, 64, 320, 16);

  cbMarca := TComboBox.Create(Self);
  cbMarca.Parent := tsEquipamento;
  cbMarca.SetBounds(16, 82, 320, 24);
  cbMarca.Style := csDropDownList;
  cbMarca.OnChange := @MarcaAlterada;

  lblModelo := TLabel.Create(Self);
  lblModelo.Parent := tsEquipamento;
  lblModelo.Caption := 'Modelo do Drone:';
  lblModelo.Font.Style := [fsBold];
  lblModelo.SetBounds(16, 116, 320, 16);

  cbModelo := TComboBox.Create(Self);
  cbModelo.Parent := tsEquipamento;
  cbModelo.SetBounds(16, 134, 320, 24);
  cbModelo.Style := csDropDownList;
  cbModelo.OnChange := @ModeloAlterado;

  lblModeloStatus := TLabel.Create(Self);
  lblModeloStatus.Parent := tsEquipamento;
  lblModeloStatus.SetBounds(16, 170, 420, 60);
  lblModeloStatus.AutoSize := False;
  lblModeloStatus.WordWrap := True;

  CarregaCatalogo;
  SelecionaModeloSalvo;

  // Create tsMavlink
  tsMavlink := TTabSheet.Create(Self);
  tsMavlink.Name := 'tsMavlink';
  tsMavlink.PageControl := pcDrones;
  tsMavlink.Caption := 'MAVLink';

  with TLabel.Create(Self) do
  begin
    Parent := tsMavlink;
    Left := 15; Top := 15;
    Caption := 'IP do drone ou da ponte Wi-Fi:';
  end;
  edMavIP := TEdit.Create(Self);
  edMavIP.Name := 'edMavIP';
  edMavIP.Parent := tsMavlink;
  edMavIP.Left := 15; edMavIP.Top := 32; edMavIP.Width := 150;
  edMavIP.Text := '192.168.4.1';

  with TLabel.Create(Self) do
  begin
    Parent := tsMavlink;
    Left := 15; Top := 65;
    Caption := 'Porta UDP em que o cockpit escuta:';
  end;
  edMavPort := TEdit.Create(Self);
  edMavPort.Name := 'edMavPort';
  edMavPort.Parent := tsMavlink;
  edMavPort.Left := 15; edMavPort.Top := 82; edMavPort.Width := 100;
  edMavPort.Text := '14550';

  with TLabel.Create(Self) do
  begin
    Parent := tsMavlink;
    Left := 15; Top := 120;
    Caption := 'ArduPilot ou PX4 (multirrotor com GPS). O drone (SITL, ponte' + LineEnding +
      'Wi-Fi ou rádio) envia para esta porta; o cockpit responde a ele.' + LineEnding +
      'Planejamento de rota: botão "Rota de voo" no cockpit.';
  end;
  // Mantido por compatibilidade; o cockpit usa sempre o sistema 255.
  edMavSysId := TEdit.Create(Self);
  edMavSysId.Name := 'edMavSysId';
  edMavSysId.Parent := tsMavlink;
  edMavSysId.Visible := False;
  edMavSysId.Text := '255';

  CriaAbaTello;
  CriaAbaOpendrone;
  CriaAbaFQ777;
  CriaAbaARDrone;
  CriaAbaESP32Drone;

  TabSheet1.Caption := 'Cheerson CX-10W';
  ckCX10WSimulado := CriaOpcao(TabSheet1, 8, 175, 'Simulado (conecta no simulador local 127.0.0.1)', 'ckCX10WSimulado');
  ckCX10WSimulado.OnClick := @CX10WSimuladoClick;

  CarregarValoresTela;
end;

procedure Tfrmconfig.CX10WSimuladoClick(Sender: TObject);
begin
  MarcaAlterada(Sender);
  if Assigned(ckCX10WSimulado) and ckCX10WSimulado.Checked then
  begin
    if (Trim(edIP.Text) = '') or (Trim(edIP.Text) = '172.16.10.1') then
      edIP.Text := '127.0.0.1';
  end
  else
  begin
    if Trim(edIP.Text) = '127.0.0.1' then
      edIP.Text := '172.16.10.1';
  end;
end;

function Tfrmconfig.CriaCampo(AParent: TWinControl; ALeft, ATop, AWidth: Integer;
  const ARotulo, ANome: string): TEdit;
begin
  with TLabel.Create(Self) do
  begin
    Parent := AParent;
    Left := ALeft; Top := ATop;
    Caption := ARotulo;
  end;
  Result := TEdit.Create(Self);
  Result.Name := ANome;
  Result.Parent := AParent;
  Result.Left := ALeft; Result.Top := ATop + 17; Result.Width := AWidth;
  Result.Text := '';
end;

function Tfrmconfig.CriaOpcao(AParent: TWinControl; ALeft, ATop: Integer;
  const ARotulo, ANome: string): TCheckBox;
begin
  Result := TCheckBox.Create(Self);
  Result.Name := ANome;
  Result.Parent := AParent;
  Result.Left := ALeft; Result.Top := ATop;
  Result.Caption := ARotulo;
end;

procedure Tfrmconfig.CriaAbaTello;
var
  Box: TScrollBox;
begin
  tsTello := TTabSheet.Create(Self);
  tsTello.Name := 'tsTello';
  tsTello.PageControl := pcDrones;
  tsTello.Caption := 'DJI Tello';

  Box := TScrollBox.Create(Self);
  Box.Parent := tsTello;
  Box.Align := alClient;
  Box.BorderStyle := bsNone;

  edTelloIP := CriaCampo(Box, 15, 10, 130, 'IP do drone:', 'edTelloIP');
  with TLabel.Create(Self) do
  begin
    Parent := Box;
    Left := 155; Top := 30;
    Caption := 'Portas fixas: comandos 8889, telemetria 8890, vídeo 11111';
  end;
  ckTelloVideo := CriaOpcao(Box, 15, 60, 'Receber vídeo da câmera', 'ckTelloVideo');
  edTelloFFmpeg := CriaCampo(Box, 15, 82, 270,
    'ffmpeg (vazio = ao lado do programa ou no PATH):', 'edTelloFFmpeg');
  with TLabel.Create(Self) do
  begin
    Parent := Box;
    Left := 15; Top := 132;
    Caption := 'Botão 3 decola, botão 4 pousa; Q/E sobe e desce. Emergência na janela do drone.';
  end;
end;

procedure Tfrmconfig.CriaAbaOpendrone;
var
  Box: TScrollBox;
begin
  tsOpendrone := TTabSheet.Create(Self);
  tsOpendrone.Name := 'tsOpendrone';
  tsOpendrone.PageControl := pcDrones;
  tsOpendrone.Caption := 'ESP-Drone / OpenDrone';

  Box := TScrollBox.Create(Self);
  Box.Parent := tsOpendrone;
  Box.Align := alClient;
  Box.BorderStyle := bsNone;

  edOpendroneIP := CriaCampo(Box, 15, 10, 130, 'IP do drone:', 'edOpendroneIP');
  edOpendronePort := CriaCampo(Box, 155, 10, 60, 'UDP:', 'edOpendronePort');
  edOpendroneAngulo := CriaCampo(Box, 15, 60, 60, 'Ângulo máx. (graus):', 'edOpendroneAngulo');
  with TLabel.Create(Self) do
  begin
    Parent := Box;
    Left := 15; Top := 112;
    Caption := 'ESP-Drone da Espressif (CRTP). O cockpit escuta na porta 2399.' + LineEnding +
      'A aceleração só é liberada depois que o manche desce ao mínimo.';
  end;
end;

procedure Tfrmconfig.CriaAbaFQ777;
var
  Box: TScrollBox;
begin
  tsFQ777 := TTabSheet.Create(Self);
  tsFQ777.Name := 'tsFQ777';
  tsFQ777.PageControl := pcDrones;
  tsFQ777.Caption := 'FQ777-954';

  Box := TScrollBox.Create(Self);
  Box.Parent := tsFQ777;
  Box.Align := alClient;
  Box.BorderStyle := bsNone;

  // Rede do drone
  edFQ777IP := CriaCampo(Box, 15, 10, 130, 'IP do drone:', 'edFQ777IP');
  edFQ777TCP := CriaCampo(Box, 155, 10, 60, 'TCP:', 'edFQ777TCP');
  edFQ777UDP := CriaCampo(Box, 225, 10, 60, 'UDP:', 'edFQ777UDP');

  // Wi-Fi
  ckFQ777WifiAuto := CriaOpcao(Box, 15, 60,
    'Procurar e conectar no Wi-Fi do drone ao ligar', 'ckFQ777WifiAuto');
  edFQ777SSID := CriaCampo(Box, 15, 82, 130, 'Nome da rede (padrões ;):', 'edFQ777SSID');
  edFQ777Senha := CriaCampo(Box, 155, 82, 130, 'Senha (vazio = aberta):', 'edFQ777Senha');
  edFQ777Senha.PasswordChar := '*';

  // Vídeo
  ckFQ777Video := CriaOpcao(Box, 15, 132, 'Receber vídeo da câmera', 'ckFQ777Video');
  ckFQ777Gravar := CriaOpcao(Box, 15, 152, 'Gravar vídeo (.h264 na pasta videos)', 'ckFQ777Gravar');
  edFQ777FFmpeg := CriaCampo(Box, 15, 174, 270,
    'ffmpeg (vazio = ao lado do programa ou no PATH):', 'edFQ777FFmpeg');

  // Controle
  edFQ777ZonaMorta := CriaCampo(Box, 15, 224, 50, 'Zona morta %:', 'edFQ777ZonaMorta');
  with TLabel.Create(Self) do
  begin
    Parent := Box;
    Left := 85; Top := 224;
    Caption := 'Acelerador:';
  end;
  cbFQ777Acelerador := TComboBox.Create(Self);
  cbFQ777Acelerador.Name := 'cbFQ777Acelerador';
  cbFQ777Acelerador.Parent := Box;
  cbFQ777Acelerador.Left := 85; cbFQ777Acelerador.Top := 241; cbFQ777Acelerador.Width := 200;
  cbFQ777Acelerador.Style := csDropDownList;
  cbFQ777Acelerador.Items.Add('Gatilho (solto = parado)');
  cbFQ777Acelerador.Items.Add('Manche (embaixo = parado)');

  with TLabel.Create(Self) do
  begin
    Parent := Box;
    Left := 15; Top := 276;
    Caption := 'Eixo do joystick (0..5) para cada comando:';
  end;
  edFQ777EixoRolagem := CriaCampo(Box, 15, 296, 40, 'Rolagem', 'edFQ777EixoRolagem');
  edFQ777EixoArfagem := CriaCampo(Box, 80, 296, 40, 'Arfagem', 'edFQ777EixoArfagem');
  edFQ777EixoGuinada := CriaCampo(Box, 145, 296, 40, 'Guinada', 'edFQ777EixoGuinada');
  edFQ777EixoAcelerador := CriaCampo(Box, 210, 296, 40, 'Acelerador', 'edFQ777EixoAcelerador');
end;

procedure Tfrmconfig.CriaAbaARDrone;
var
  Box: TScrollBox;
begin
  tsARDrone := TTabSheet.Create(Self);
  tsARDrone.Name := 'tsARDrone';
  tsARDrone.PageControl := pcDrones;
  tsARDrone.Caption := 'AR.Drone 2.0';

  Box := TScrollBox.Create(Self);
  Box.Parent := tsARDrone;
  Box.Align := alClient;
  Box.BorderStyle := bsNone;

  edARDroneIP := CriaCampo(Box, 15, 10, 130, 'IP do drone:', 'edARDroneIP');
  with TLabel.Create(Self) do
  begin
    Parent := Box;
    Left := 155; Top := 30;
    Caption := 'Portas fixas: AT 5556, telemetria 5554, vídeo 5555';
  end;

  ckARDroneVideo := CriaOpcao(Box, 15, 60, 'Receber vídeo da câmera frontal', 'ckARDroneVideo');
  edARDroneFFmpeg := CriaCampo(Box, 15, 82, 270,
    'ffmpeg (vazio = ao lado do programa ou no PATH):', 'edARDroneFFmpeg');

  edARDroneAltura := CriaCampo(Box, 15, 132, 60, 'Altura máx. (m):', 'edARDroneAltura');
  edARDroneSensibilidade := CriaCampo(Box, 145, 132, 60, 'Sensibilidade %:', 'edARDroneSensibilidade');
  ckARDroneExterno := CriaOpcao(Box, 15, 182,
    'Voo ao ar livre (sem protetor de hélices)', 'ckARDroneExterno');

  with TLabel.Create(Self) do
  begin
    Parent := Box;
    Left := 15; Top := 212;
    Caption := 'Botão 3 decola, botão 4 pousa. Emergência e calibração na janela do drone.';
  end;
end;

procedure Tfrmconfig.CriaAbaESP32Drone;
var
  Box: TScrollBox;
begin
  tsESP32Drone := TTabSheet.Create(Self);
  tsESP32Drone.Name := 'tsESP32Drone';
  tsESP32Drone.PageControl := pcDrones;
  tsESP32Drone.Caption := 'Drone ESP32';

  Box := TScrollBox.Create(Self);
  Box.Parent := tsESP32Drone;
  Box.Align := alClient;
  Box.BorderStyle := bsNone;

  edESP32IP := CriaCampo(Box, 15, 10, 130, 'IP do drone:', 'edESP32IP');
  edESP32Porta := CriaCampo(Box, 155, 10, 60, 'UDP:', 'edESP32Porta');

  with TLabel.Create(Self) do
  begin
    Parent := Box;
    Left := 15; Top := 62;
    Caption := 'Firmware: pasta firmware/esp32_drone (rede CockpitDrone-XXXX).';
  end;
  with TLabel.Create(Self) do
  begin
    Parent := Box;
    Left := 15; Top := 82;
    Caption := 'Botão 3 arma (aceleração no mínimo), botão 4 desarma.';
  end;
end;

function Tfrmconfig.GetModelConfigPath: string;
var
  Dir: string;
begin
  Dir := IncludeTrailingPathDelimiter(GetAppConfigDir(False));
  if not DirectoryExists(Dir) then
    ForceDirectories(Dir);
  Result := Dir + 'drone_model.ini';
  if not FileExists(Result) and FileExists(ExtractFilePath(Application.ExeName) + 'drone_model.ini') then
    Result := ExtractFilePath(Application.ExeName) + 'drone_model.ini';
end;

procedure Tfrmconfig.SelecionaModeloPorProtocolo(AProtoIdx: Integer);
var
  I, Idx: Integer;
  O: TJSONObject;
  Marca, Modelo: string;
begin
  if not Assigned(FCatalogo) or (AProtoIdx < 0) then Exit;
  Marca := '';
  Modelo := '';
  for I := 0 to FCatalogo.Count - 1 do
  begin
    O := FCatalogo.Objects[I];
    Idx := O.Get('cockpit_protocol_index', -1);
    if Idx = AProtoIdx then
    begin
      Marca := O.Get('brand', '');
      Modelo := O.Get('model', '');
      Break;
    end;
  end;
  if Marca <> '' then
  begin
    FCarregandoModelo := True;
    try
      cbMarca.ItemIndex := cbMarca.Items.IndexOf(Marca);
      cbModelo.Items.Clear;
      for I := 0 to FCatalogo.Count - 1 do
        if FCatalogo.Objects[I].Get('brand', '') = Marca then
          cbModelo.Items.Add(FCatalogo.Objects[I].Get('model', ''));
      cbModelo.ItemIndex := cbModelo.Items.IndexOf(Modelo);
      if (cbModelo.ItemIndex < 0) and (cbModelo.Items.Count > 0) then
        cbModelo.ItemIndex := 0;
    finally
      FCarregandoModelo := False;
    end;
    if cbModelo.ItemIndex >= 0 then
      lblModeloStatus.Caption := 'Modelo selecionado: ' + cbMarca.Text + ' ' + cbModelo.Text;
  end
  else if (cbMarca.ItemIndex < 0) and (cbMarca.Items.Count > 0) then
  begin
    cbMarca.ItemIndex := 0;
    MarcaAlterada(nil);
  end;
end;

procedure Tfrmconfig.CarregaCatalogo;
const
  JSON_CATALOGO_FALLBACK =
    '{"models":[' +
    '{"brand":"Cheerson","model":"CX-10W","cockpit_protocol_index":0},' +
    '{"brand":"Ryze","model":"Tello","cockpit_protocol_index":2},' +
    '{"brand":"Parrot","model":"AR.Drone 2.0","cockpit_protocol_index":5},' +
    '{"brand":"FQ777","model":"954","cockpit_protocol_index":4},' +
    '{"brand":"Maurinsoft","model":"Drone ESP32 (CDP)","cockpit_protocol_index":6},' +
    '{"brand":"Espressif","model":"ESP-Drone / OpenDrone","cockpit_protocol_index":3},' +
    '{"brand":"ArduPilot / PX4","model":"MAVLink Genérico","cockpit_protocol_index":1}' +
    ']}';
var
  P, BaseDir, JsonTexto: string;
  J, Models: TJSONData;
  I: Integer;
  Marca: string;
begin
  FCatalogo := nil;
  BaseDir := ExtractFilePath(Application.ExeName);
  P := BaseDir + 'data' + PathDelim + 'drone_models.json';
  if not FileExists(P) then
    P := BaseDir + 'drone_models.json';
  if not FileExists(P) then
    P := ExpandFileName(BaseDir + '..' + PathDelim + 'data' + PathDelim + 'drone_models.json');
  if not FileExists(P) then
    P := ExpandFileName(BaseDir + '..' + PathDelim + 'drone_models.json');
  if not FileExists(P) then
    P := ExpandFileName(BaseDir + '..' + PathDelim + '..' + PathDelim + 'data' + PathDelim + 'drone_models.json');
  if not FileExists(P) then
    P := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'drone_models.json';
  if not FileExists(P) then
    P := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'data' + PathDelim + 'drone_models.json';

  JsonTexto := '';
  if FileExists(P) then
  begin
    with TStringList.Create do
    try
      LoadFromFile(P);
      JsonTexto := Text;
    finally
      Free;
    end;
  end
  else
    JsonTexto := JSON_CATALOGO_FALLBACK;

  try
    J := GetJSON(JsonTexto);
    try
      if J.JSONType = jtObject then
      begin
        Models := J.FindPath('models');
        if (Models <> nil) and (Models.JSONType = jtArray) then
          FCatalogo := TJSONArray(Models.Clone);
      end;
    finally
      J.Free;
    end;

    cbMarca.Items.Clear;
    if Assigned(FCatalogo) then
    begin
      for I := 0 to FCatalogo.Count - 1 do
      begin
        Marca := FCatalogo.Objects[I].Get('brand', '');
        if (Marca <> '') and (cbMarca.Items.IndexOf(Marca) < 0) then
          cbMarca.Items.Add(Marca);
      end;
    end;
  except
    on E: Exception do
    begin
      FreeAndNil(FCatalogo);
      lblModeloStatus.Caption := 'Erro no catalogo: ' + E.Message;
    end;
  end;
end;

procedure Tfrmconfig.MarcaAlterada(Sender: TObject);
var
  I: Integer;
begin
  cbModelo.Items.Clear;
  if not Assigned(FCatalogo) or (cbMarca.ItemIndex < 0) then Exit;
  for I := 0 to FCatalogo.Count - 1 do
    if FCatalogo.Objects[I].Get('brand', '') = cbMarca.Text then
      cbModelo.Items.Add(FCatalogo.Objects[I].Get('model', ''));
  if (cbModelo.Items.Count > 0) and (cbModelo.ItemIndex < 0) then
    cbModelo.ItemIndex := 0;
  if not FCarregandoModelo and (cbModelo.ItemIndex >= 0) then
    ModeloAlterado(nil)
  else
    lblModeloStatus.Caption := 'Selecione o modelo.';
end;

procedure Tfrmconfig.ModeloAlterado(Sender: TObject);
var
  I, Idx: Integer;
  O: TJSONObject;
  Ini: TIniFile;
  P: string;
begin
  if FCarregandoModelo or not Assigned(FCatalogo) or
     (cbMarca.ItemIndex < 0) or (cbModelo.ItemIndex < 0) then Exit;
  for I := 0 to FCatalogo.Count - 1 do
  begin
    O := FCatalogo.Objects[I];
    if (O.Get('brand', '') <> cbMarca.Text) or
       (O.Get('model', '') <> cbModelo.Text) then Continue;
    Idx := O.Get('cockpit_protocol_index', -1);
    if (Idx < 0) or (Idx >= cbProtocol.Items.Count) then
    begin
      cbProtocol.ItemIndex := -1;
      TipoAtivo := -1;
      if Assigned(FSetMain) then
      begin
        FSetMain.DroneProtocolo := -1;
        FSetMain.SalvaContexto;
      end;
      AtualizaAbasProtocolo;
      lblModeloStatus.Caption := 'SEM SUPORTE: adaptador indisponivel. Nao conectar.';
    end
    else
    begin
      cbProtocol.ItemIndex := Idx;
      if Assigned(FSetMain) then
      begin
        FSetMain.DroneProtocolo := Idx;
        TipoAtivo := Idx;
        AtualizaAbasProtocolo;
        SalvarConfiguracoes;
      end;
      lblModeloStatus.Caption := 'Protocolo selecionado: ' + cbProtocol.Text +
        '. Verifique compatibilidade do equipamento antes de conectar.';
    end;
    P := GetModelConfigPath;
    Ini := TIniFile.Create(P);
    try
      Ini.WriteString('MODEL', 'BRAND', cbMarca.Text);
      Ini.WriteString('MODEL', 'NAME', cbModelo.Text);
    finally
      Ini.Free;
    end;
    Break;
  end;
end;

procedure Tfrmconfig.SelecionaModeloSalvo;
var
  Ini: TIniFile;
  Marca, Modelo: string;
begin
  Marca := '';
  Modelo := '';
  if FileExists(GetModelConfigPath) then
  begin
    Ini := TIniFile.Create(GetModelConfigPath);
    try
      Marca := Ini.ReadString('MODEL', 'BRAND', '');
      Modelo := Ini.ReadString('MODEL', 'NAME', '');
    finally
      Ini.Free;
    end;
  end;

  if (Marca <> '') and (cbMarca.Items.IndexOf(Marca) >= 0) then
  begin
    FCarregandoModelo := True;
    try
      cbMarca.ItemIndex := cbMarca.Items.IndexOf(Marca);
      MarcaAlterada(nil);
      cbModelo.ItemIndex := cbModelo.Items.IndexOf(Modelo);
      if (cbModelo.ItemIndex < 0) and (cbModelo.Items.Count > 0) then
        cbModelo.ItemIndex := 0;
    finally
      FCarregandoModelo := False;
    end;
    if cbModelo.ItemIndex >= 0 then
      ModeloAlterado(nil);
  end
  else
  begin
    if Assigned(cbProtocol) and (cbProtocol.ItemIndex >= 0) then
      SelecionaModeloPorProtocolo(cbProtocol.ItemIndex)
    else if cbMarca.Items.Count > 0 then
    begin
      cbMarca.ItemIndex := 0;
      MarcaAlterada(nil);
      if cbModelo.Items.Count > 0 then
      begin
        cbModelo.ItemIndex := 0;
        ModeloAlterado(nil);
      end;
    end;
  end;
end;

procedure Tfrmconfig.cbProtocolChange(Sender: TObject);
begin
  if Assigned(FSetMain) and Assigned(cbProtocol) then
  begin
    FSetMain.DroneProtocolo := cbProtocol.ItemIndex;
    TipoAtivo := cbProtocol.ItemIndex;
    AtualizaAbasProtocolo;
    SalvarConfiguracoes;
  end;
  if not FCarregandoModelo and Assigned(cbProtocol) then
    SelecionaModeloPorProtocolo(cbProtocol.ItemIndex);
end;

procedure Tfrmconfig.Label4Click(Sender: TObject);
begin
end;

procedure Tfrmconfig.cbDroneClick(Sender: TObject);
begin
end;

procedure Tfrmconfig.cbSerialPortChange(Sender: TObject);
begin
end;

procedure Tfrmconfig.ckJoyActiveChange(Sender: TObject);
begin
  if not MainDisponivel then
    Exit;

  try
    frmMain.SdpoJoystick1.Active := False;

    if cbDevice.ItemIndex = 0 then
      frmMain.SdpoJoystick1.DeviceWin := dwJoystickID1
    else
      frmMain.SdpoJoystick1.DeviceWin := dwJoystickID2;

    if ckJoyActive.Checked then
      frmMain.SdpoJoystick1.Active := True;

  except
    on E: Exception do
    begin
      ckJoyActive.Checked := False;
      timerJoystick.Enabled := False;
      LimpaLeitura;
    end;
  end;
end;

procedure Tfrmconfig.ckTestChange(Sender: TObject);
begin
  if ckTest.Checked then
  begin
    ckJoyActive.Checked := True;
    ckJoyActiveChange(ckJoyActive);
    timerJoystick.Enabled := True;
  end
  else
  begin
    timerJoystick.Enabled := False;
    LimpaLeitura;
  end;
end;

procedure Tfrmconfig.btCalibrationClick(Sender: TObject);
begin
end;

procedure Tfrmconfig.cbDeviceChange(Sender: TObject);
begin
  if ckJoyActive.Checked then
    ckJoyActiveChange(ckJoyActive);
end;

procedure Tfrmconfig.TabSheet1ContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
begin
end;

procedure Tfrmconfig.timerJoystickTimer(Sender: TObject);
var
  X, Y, Z: Integer;
begin
  if not MainDisponivel then
  begin
    LimpaLeitura;
    Exit;
  end;

  if not frmMain.SdpoJoystick1.Active then
  begin
    LimpaLeitura;
    Exit;
  end;

  try
    X := MAPA(0, 65535, 0, 255, frmMain.SdpoJoystick1.Axis[0].ToDouble);
    Y := MAPA(0, 65535, 0, 255, frmMain.SdpoJoystick1.Axis[1].ToDouble);
    Z := MAPA(0, 65535, 0, 255, frmMain.SdpoJoystick1.Axis[2].ToDouble);

    lbX.Caption := IntToStr(X);
    lbY.Caption := IntToStr(Y);
    lbZ.Caption := IntToStr(Z);

    AtualizaLedsBotoes;
  except
    on E: Exception do
      LimpaLeitura;
  end;
end;

procedure Tfrmconfig.FormShow(Sender: TObject);
begin
  CarregarValoresTela;
  AplicarIdioma(Self);
end;

procedure Tfrmconfig.CarregaIdioma;
var
  Ini: TIniFile;
  Codigo: string;
  I: Integer;
const
  Codigos: array[0..7] of string = ('pt-BR', 'en', 'es', 'zh-CN', 'ar', 'de', 'ru', 'hi');
begin
  Ini := TIniFile.Create(GetAppConfigDir(False) + 'cockpit_ui.ini');
  try
    Codigo := Ini.ReadString('interface', 'language', 'pt-BR');
  finally
    Ini.Free;
  end;
  cbIdioma.ItemIndex := 0;
  for I := 0 to High(Codigos) do
    if SameText(Codigo, Codigos[I]) then cbIdioma.ItemIndex := I;
end;

procedure Tfrmconfig.IdiomaAlterado(Sender: TObject);
var
  Ini: TIniFile;
const
  Codigos: array[0..7] of string = ('pt-BR', 'en', 'es', 'zh-CN', 'ar', 'de', 'ru', 'hi');
begin
  if cbIdioma.ItemIndex < 0 then Exit;
  ForceDirectories(GetAppConfigDir(False));
  Ini := TIniFile.Create(GetAppConfigDir(False) + 'cockpit_ui.ini');
  try
    Ini.WriteString('interface', 'language', Codigos[cbIdioma.ItemIndex]);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
  AplicarIdioma(Self);

end;

procedure Tfrmconfig.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  SalvarConfiguracoes;
  CloseAction := caHide;
end;

procedure Tfrmconfig.AtualizaAbasProtocolo;
begin
  if Assigned(TabSheet1) then
    TabSheet1.TabVisible := (TipoAtivo = 0);
  if Assigned(tsMavlink) then
    tsMavlink.TabVisible := (TipoAtivo = 1);
  if Assigned(tsTello) then
    tsTello.TabVisible := (TipoAtivo = 2);
  if Assigned(tsOpendrone) then
    tsOpendrone.TabVisible := (TipoAtivo = 3);
  if Assigned(tsFQ777) then
    tsFQ777.TabVisible := (TipoAtivo = 4);
  if Assigned(tsARDrone) then
    tsARDrone.TabVisible := (TipoAtivo = 5);
  if Assigned(tsESP32Drone) then
    tsESP32Drone.TabVisible := (TipoAtivo = 6);
end;

procedure Tfrmconfig.CarregarValoresTela;
begin
  if not Assigned(FSetMain) then
    Exit;

  ckJoyActive.Checked := FSetMain.JoystickAtivo;
  cbDevice.ItemIndex := FSetMain.JoystickDeviceIndex;

  cbSerialPort.Text := FSetMain.SerialPort;
  cbBaudrate.ItemIndex := FSetMain.BaudRate;
  ckbGPS.Checked := FSetMain.UsaSerial;

  if Assigned(cbProtocol) then
  begin
    cbProtocol.ItemIndex := FSetMain.DroneProtocolo;
    TipoAtivo := FSetMain.DroneProtocolo;
  end;
  if (cbMarca.ItemIndex < 0) or (cbModelo.ItemIndex < 0) then
    SelecionaModeloSalvo;

  // Aba do Cheerson CX-10W: seção própria [CX10W].
  if Assigned(ckCX10WSimulado) then
    ckCX10WSimulado.Checked := FSetMain.CX10W.Simulado;
  edIP.Text := FSetMain.CX10W.IP;
  edTCPPORT.Text := IntToStr(FSetMain.CX10W.PortaTCP);
  edUDPPORT.Text := IntToStr(FSetMain.CX10W.PortaUDP);

  // MAVLink: seção própria [MAVLINK].
  if Assigned(edMavIP) then
    edMavIP.Text := FSetMain.Mavlink.IP;
  if Assigned(edMavPort) then
    edMavPort.Text := IntToStr(FSetMain.Mavlink.Porta);

  if Assigned(tsTello) then
  begin
    edTelloIP.Text := FSetMain.Tello.IP;
    ckTelloVideo.Checked := FSetMain.Tello.Video;
    edTelloFFmpeg.Text := FSetMain.Tello.FFmpeg;
  end;

  if Assigned(tsOpendrone) then
  begin
    edOpendroneIP.Text := FSetMain.ESPDrone.IP;
    edOpendronePort.Text := IntToStr(FSetMain.ESPDrone.Porta);
    edOpendroneAngulo.Text := IntToStr(FSetMain.ESPDrone.AnguloMaximo);
  end;

  if Assigned(tsFQ777) then
    with FSetMain.FQ777 do
    begin
      edFQ777IP.Text := IP;
      edFQ777TCP.Text := IntToStr(PortaTCP);
      edFQ777UDP.Text := IntToStr(PortaUDP);
      ckFQ777WifiAuto.Checked := WifiAuto;
      edFQ777SSID.Text := WifiSSID;
      edFQ777Senha.Text := WifiSenha;
      ckFQ777Video.Checked := Video;
      ckFQ777Gravar.Checked := GravarVideo;
      edFQ777FFmpeg.Text := FFmpeg;
      edFQ777ZonaMorta.Text := IntToStr(ZonaMorta);
      edFQ777EixoRolagem.Text := IntToStr(EixoRolagem);
      edFQ777EixoArfagem.Text := IntToStr(EixoArfagem);
      edFQ777EixoGuinada.Text := IntToStr(EixoGuinada);
      edFQ777EixoAcelerador.Text := IntToStr(EixoAcelerador);
      if AceleradorCentrado then
        cbFQ777Acelerador.ItemIndex := 1
      else
        cbFQ777Acelerador.ItemIndex := 0;
    end;

  if Assigned(tsARDrone) then
    with FSetMain.ARDrone do
    begin
      edARDroneIP.Text := IP;
      ckARDroneVideo.Checked := Video;
      edARDroneFFmpeg.Text := FFmpeg;
      edARDroneAltura.Text := IntToStr(AlturaMaxima);
      ckARDroneExterno.Checked := Externo;
      edARDroneSensibilidade.Text := IntToStr(Sensibilidade);
    end;

  if Assigned(tsESP32Drone) then
    with FSetMain.ESP32Drone do
    begin
      edESP32IP.Text := IP;
      edESP32Porta.Text := IntToStr(Porta);
    end;

  AtualizaAbasProtocolo;
end;

procedure Tfrmconfig.SalvarConfiguracoes;
var
  Val: Integer;
begin
  if not Assigned(FSetMain) then
    Exit;

  FSetMain.JoystickAtivo := ckJoyActive.Checked;
  FSetMain.JoystickDeviceIndex := cbDevice.ItemIndex;

  FSetMain.SerialPort := cbSerialPort.Text;
  FSetMain.BaudRate := cbBaudrate.ItemIndex;
  FSetMain.UsaSerial := ckbGPS.Checked;

  case TipoAtivo of
    0:
      begin
        // Cheerson CX-10W: não altera a seção [DRONE] dos outros protocolos.
        if Assigned(ckCX10WSimulado) then
          FSetMain.CX10W.Simulado := ckCX10WSimulado.Checked;
        if FSetMain.CX10W.Simulado and ((Trim(edIP.Text) = '') or (Trim(edIP.Text) = '172.16.10.1')) then
          FSetMain.CX10W.IP := '127.0.0.1'
        else if Trim(edIP.Text) <> '' then
          FSetMain.CX10W.IP := Trim(edIP.Text);
        if TryStrToInt(Trim(edTCPPORT.Text), Val) and (Val > 0) then
          FSetMain.CX10W.PortaTCP := Val;
        if TryStrToInt(Trim(edUDPPORT.Text), Val) and (Val > 0) then
          FSetMain.CX10W.PortaUDP := Val;
      end;
    1:
      begin
        // Seção própria [MAVLINK]: não altera a [DRONE] dos outros protocolos.
        if Assigned(edMavIP) and (Trim(edMavIP.Text) <> '') then
          FSetMain.Mavlink.IP := Trim(edMavIP.Text);
        if Assigned(edMavPort) and TryStrToInt(Trim(edMavPort.Text), Val) and
          (Val > 0) and (Val < 65536) then
          FSetMain.Mavlink.Porta := Val;
      end;
    2:
      // Seção própria [TELLO].
      if Assigned(tsTello) then
        with FSetMain.Tello do
        begin
          if Trim(edTelloIP.Text) <> '' then
            IP := Trim(edTelloIP.Text);
          Video := ckTelloVideo.Checked;
          FFmpeg := Trim(edTelloFFmpeg.Text);
        end;
    3:
      // Seção própria [ESPDRONE].
      if Assigned(tsOpendrone) then
        with FSetMain.ESPDrone do
        begin
          if Trim(edOpendroneIP.Text) <> '' then
            IP := Trim(edOpendroneIP.Text);
          Porta := EnsureRange(StrToIntDef(Trim(edOpendronePort.Text), Porta), 1, 65535);
          AnguloMaximo := EnsureRange(StrToIntDef(Trim(edOpendroneAngulo.Text), AnguloMaximo), 5, 45);
        end;
    4:
      // Seção própria [FQ777]: não altera a configuração dos outros drones.
      if Assigned(tsFQ777) then
        with FSetMain.FQ777 do
        begin
          if Trim(edFQ777IP.Text) <> '' then
            IP := Trim(edFQ777IP.Text);
          PortaTCP := StrToIntDef(Trim(edFQ777TCP.Text), PortaTCP);
          PortaUDP := StrToIntDef(Trim(edFQ777UDP.Text), PortaUDP);
          WifiAuto := ckFQ777WifiAuto.Checked;
          WifiSSID := Trim(edFQ777SSID.Text);
          WifiSenha := edFQ777Senha.Text;
          Video := ckFQ777Video.Checked;
          GravarVideo := ckFQ777Gravar.Checked;
          FFmpeg := Trim(edFQ777FFmpeg.Text);
          ZonaMorta := StrToIntDef(Trim(edFQ777ZonaMorta.Text), ZonaMorta);
          EixoRolagem := StrToIntDef(Trim(edFQ777EixoRolagem.Text), EixoRolagem);
          EixoArfagem := StrToIntDef(Trim(edFQ777EixoArfagem.Text), EixoArfagem);
          EixoGuinada := StrToIntDef(Trim(edFQ777EixoGuinada.Text), EixoGuinada);
          EixoAcelerador := StrToIntDef(Trim(edFQ777EixoAcelerador.Text), EixoAcelerador);
          AceleradorCentrado := cbFQ777Acelerador.ItemIndex = 1;
        end;
    5:
      // Seção própria [ARDRONE].
      if Assigned(tsARDrone) then
        with FSetMain.ARDrone do
        begin
          if Trim(edARDroneIP.Text) <> '' then
            IP := Trim(edARDroneIP.Text);
          Video := ckARDroneVideo.Checked;
          FFmpeg := Trim(edARDroneFFmpeg.Text);
          AlturaMaxima := EnsureRange(StrToIntDef(Trim(edARDroneAltura.Text), AlturaMaxima), 1, 100);
          Externo := ckARDroneExterno.Checked;
          Sensibilidade := EnsureRange(StrToIntDef(Trim(edARDroneSensibilidade.Text), Sensibilidade), 10, 100);
        end;
    6:
      // Seção própria [ESP32DRONE].
      if Assigned(tsESP32Drone) then
        with FSetMain.ESP32Drone do
        begin
          if Trim(edESP32IP.Text) <> '' then
            IP := Trim(edESP32IP.Text);
          Porta := StrToIntDef(Trim(edESP32Porta.Text), Porta);
        end;
  end;

  FSetMain.DroneProtocolo := TipoAtivo;
  FSetMain.SalvaContexto;
end;

end.
