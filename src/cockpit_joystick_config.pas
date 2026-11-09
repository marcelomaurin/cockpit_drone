unit cockpit_joystick_config;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Spin, IniFiles,
  cockpit_joystick_mapping;
type
  TFlightJoystickPanel=class(TScrollBox)
  private
    FPreset:TComboBox;
    FAxes:array[0..3] of TComboBox;
    FInvert:array[0..3] of TCheckBox;
    FButtons:array[1..6] of TSpinEdit;
    FTrigger:TCheckBox;
    FZone:TSpinEdit;
    FTitle,FGuide,FReadings:TLabel;
    FLoading:Boolean;
    FFile,FSection:string;
    FApply:TButton;
    procedure PresetChanged(Sender:TObject);
    procedure PutSettings(const S:TFlightJoystickSettings);
    function GetSettings:TFlightJoystickSettings;
  public
    constructor Create(AOwner:TComponent); override;
    procedure LoadModel(const FileName,Brand,ModelName:string; ProtocolIndex:Integer);
    procedure SaveProfile;
    procedure ShowReadings(X,Y,Z:Byte; Yaw:Double; Available:Boolean);
    property Settings:TFlightJoystickSettings read GetSettings;
    property ApplyButton:TButton read FApply;
  end;
implementation
uses Math;
constructor TFlightJoystickPanel.Create(AOwner:TComponent);
const Names:array[0..3] of string=('Rolagem (direita/esquerda)','Arfagem (frente/tras)',
  'Guinada (giro)','Aceleracao / subir-descer');
  ButtonNames:array[1..6] of string=('Giro esquerdo (alternativo)','Giro direito (alternativo)',
  'Decolar / armar','Pousar / desarmar','Centralizar (legado)','Auxiliar 6');
var I,J:Integer; L:TLabel;
  procedure LabelAt(const Txt:string; X,Y,W,H:Integer);
  var T:TLabel;
  begin T:=TLabel.Create(Self); T.Parent:=Self; T.AutoSize:=False;
    T.WordWrap:=True; T.Caption:=Txt; T.SetBounds(X,Y,W,H); end;
begin
  inherited Create(AOwner); BorderStyle:=bsNone; HorzScrollBar.Visible:=False;
  FTitle:=TLabel.Create(Self); FTitle.Parent:=Self;
  FTitle.AutoSize:=False; FTitle.WordWrap:=True; FTitle.SetBounds(12,8,420,40);
  LabelAt('Perfil dos manches:',12,52,180,20);
  FPreset:=TComboBox.Create(Self); FPreset.Parent:=Self; FPreset.Name:='cbPerfilVoo';
  FPreset.Style:=csDropDownList; FPreset.SetBounds(180,48,250,26);
  FPreset.Items.Add('Automatico (Xbox Modo 2 / generico legado)');
  FPreset.Items.Add('Modo 2 - padrao de radiocontrole');
  FPreset.Items.Add('Xbox - acelerador no RT');
  FPreset.Items.Add('Personalizado'); FPreset.Items.Add('Legado - eixos X/Y/Z e botoes');
  FPreset.OnChange:=@PresetChanged;
  for I:=0 to 3 do begin
    LabelAt(Names[I],12,85+I*34,180,25);
    FAxes[I]:=TComboBox.Create(Self); FAxes[I].Parent:=Self;
    FAxes[I].Name:='cbEixoVoo'+IntToStr(I); FAxes[I].Style:=csDropDownList;
    FAxes[I].SetBounds(190,81+I*34,155,26);
    FAxes[I].Items.Add('Sem eixo (botoes)');
    for J:=0 to 5 do FAxes[I].Items.Add('Eixo '+IntToStr(J));
    FInvert[I]:=TCheckBox.Create(Self); FInvert[I].Parent:=Self;
    FInvert[I].Name:='ckInverterVoo'+IntToStr(I); FInvert[I].Caption:='Inverter'; FInvert[I].SetBounds(355,84+I*34,80,24);
  end;
  FTrigger:=TCheckBox.Create(Self); FTrigger.Parent:=Self;
  FTrigger.Caption:='Acelerador em gatilho (0..1, em vez de manche -1..1)';
  FTrigger.SetBounds(12,222,420,24);
  LabelAt('Zona morta dos comandos (%):',12,255,270,22);
  FZone:=TSpinEdit.Create(Self); FZone.Parent:=Self; FZone.MinValue:=0;
  FZone.MaxValue:=40; FZone.SetBounds(325,251,90,26);
  LabelAt('Xbox: 0=LX, 1=LY, 2=RX, 3=RY, 4=LT, 5=RT. Genericos usam os eixos do driver; inverta conforme o teste.',12,286,415,42);
  LabelAt('Botoes: 0 desativa. Xbox: A=1, B=2, X=3, Y=4, LB=5, RB=6.',12,335,420,36);
  for I:=1 to 6 do begin
    LabelAt(ButtonNames[I],12,379+(I-1)*30,290,24);
    FButtons[I]:=TSpinEdit.Create(Self); FButtons[I].Parent:=Self;
    FButtons[I].Name:='edBotaoVoo'+IntToStr(I); FButtons[I].MinValue:=0;
    FButtons[I].MaxValue:=34; FButtons[I].SetBounds(325,375+(I-1)*30,90,25);
  end;
  FApply:=TButton.Create(Self); FApply.Parent:=Self; FApply.Name:='btAplicarPerfilVoo';
  FApply.Caption:='Salvar e testar perfil'; FApply.SetBounds(12,570,200,32);
  LabelAt('Aplique com Start desligado. Configuracao salva por marca/modelo. O teste usa o mesmo caminho do voo.',12,611,420,36);
  FReadings:=TLabel.Create(Self); FReadings.Parent:=Self; FReadings.AutoSize:=False;
  FReadings.WordWrap:=True; FReadings.SetBounds(12,656,420,40);
  FReadings.Caption:='Ative o teste para ver os comandos de voo.';
  FGuide:=TLabel.Create(Self); FGuide.Parent:=Self; FGuide.AutoSize:=False;
  FGuide.WordWrap:=True; FGuide.SetBounds(12,707,420,100);
  PutSettings(DefaultFlightJoystickSettings);
end;
procedure TFlightJoystickPanel.PutSettings(const S:TFlightJoystickSettings);
var I:Integer;
begin
  FLoading:=True;
  try FPreset.ItemIndex:=EnsureRange(S.Profile,0,4);
    for I:=0 to 3 do begin
      FAxes[I].ItemIndex:=EnsureRange(S.Axis[I],-1,5)+1;
      FInvert[I].Checked:=S.Invert[I];
      FAxes[I].Enabled:=S.Profile=jpCustom; FInvert[I].Enabled:=S.Profile=jpCustom;
    end;
    FTrigger.Checked:=S.TriggerThrottle; FTrigger.Enabled:=S.Profile=jpCustom;
    FZone.Value:=EnsureRange(S.DeadZone,0,40);
    for I:=1 to 6 do begin FButtons[I].Value:=EnsureRange(S.Button[I],0,34);
      FButtons[I].Enabled:=S.Profile=jpCustom; end;
  finally FLoading:=False; end;
end;
function TFlightJoystickPanel.GetSettings:TFlightJoystickSettings;
var I:Integer;
begin
  Result:=DefaultFlightJoystickSettings; Result.Profile:=FPreset.ItemIndex;
  for I:=0 to 3 do begin Result.Axis[I]:=FAxes[I].ItemIndex-1;
    Result.Invert[I]:=FInvert[I].Checked; end;
  Result.TriggerThrottle:=FTrigger.Checked; Result.DeadZone:=FZone.Value;
  for I:=1 to 6 do Result.Button[I]:=FButtons[I].Value;
end;
procedure TFlightJoystickPanel.PresetChanged(Sender:TObject);
var S:TFlightJoystickSettings; P:Integer;
begin
  if FLoading then Exit;
  P:=FPreset.ItemIndex; S:=GetSettings;
  if P<>jpCustom then begin S:=EffectiveFlightJoystickSettings(S,True); S.Profile:=P; end;
  PutSettings(S);
end;
procedure TFlightJoystickPanel.LoadModel(const FileName,Brand,ModelName:string; ProtocolIndex:Integer);
var Ini:TIniFile; S:TFlightJoystickSettings; I:Integer; Key,SectionName:string;
begin
  Key:=Brand+'/'+ModelName; SectionName:='JOYSTICK_';
  for I:=1 to Length(Key) do SectionName:=SectionName+IntToHex(Ord(Key[I]),2);
  if (FSection=SectionName) and (FFile=FileName) then Exit;
  FSection:=SectionName; FFile:=FileName;
  S:=DefaultFlightJoystickSettings;
  Ini:=TIniFile.Create(FFile);
  try
    S.Profile:=EnsureRange(Ini.ReadInteger(FSection,'PERFIL',S.Profile),0,4);
    S.DeadZone:=EnsureRange(Ini.ReadInteger(FSection,'ZONA_MORTA',8),0,40);
    for I:=0 to 3 do begin
      S.Axis[I]:=EnsureRange(Ini.ReadInteger(FSection,'EIXO_'+IntToStr(I),S.Axis[I]),-1,5);
      S.Invert[I]:=Ini.ReadBool(FSection,'INVERTER_'+IntToStr(I),False);
    end;
    S.TriggerThrottle:=Ini.ReadBool(FSection,'GATILHO',False);
    for I:=1 to 6 do S.Button[I]:=EnsureRange(Ini.ReadInteger(FSection,'BOTAO_'+IntToStr(I),S.Button[I]),0,34);
  finally Ini.Free; end;
  PutSettings(S); if S.Profile<>jpCustom then PresetChanged(nil);
  FTitle.Caption:=Brand+' '+ModelName+' - perfil proprio de pilotagem';
  case ProtocolIndex of
    0,4: FGuide.Caption:='Cheerson/FQ777: aceleracao direta. Modo 2: esquerdo embaixo = motores parados; centro ~50%; acima do centro = subir. Primeiro leve ao minimo para liberar. A/B nao decolam nem pousam automaticamente.';
    2,5: FGuide.Caption:='Tello/AR.Drone: Modo 2, esquerdo para cima/baixo = velocidade vertical; centro = pairar. A decola, B pousa. Aguarde a decolagem antes de comandar os manches.';
    6: FGuide.Caption:='ESP32 CDP: esquerdo = aceleracao e giro; direito = direcao. Primeiro baixe o acelerador, A arma e B desarma. O firmware valida os comandos.';
  else FGuide.Caption:='Modo 2: esquerdo = aceleracao e giro; direito = frente/tras e esquerda/direita. MAVLink/ESP-Drone seguem os modos e procedimentos de armamento do adaptador e do autopiloto.'; end;
end;
procedure TFlightJoystickPanel.SaveProfile;
var Ini:TIniFile; S:TFlightJoystickSettings; I:Integer;
begin
  if FSection='' then Exit;
  S:=GetSettings; Ini:=TIniFile.Create(FFile);
  try Ini.WriteInteger(FSection,'PERFIL',S.Profile);
    Ini.WriteInteger(FSection,'ZONA_MORTA',S.DeadZone);
    for I:=0 to 3 do begin Ini.WriteInteger(FSection,'EIXO_'+IntToStr(I),S.Axis[I]);
      Ini.WriteBool(FSection,'INVERTER_'+IntToStr(I),S.Invert[I]); end;
    Ini.WriteBool(FSection,'GATILHO',S.TriggerThrottle);
    for I:=1 to 6 do Ini.WriteInteger(FSection,'BOTAO_'+IntToStr(I),S.Button[I]);
    Ini.UpdateFile;
  finally Ini.Free; end;
end;
procedure TFlightJoystickPanel.ShowReadings(X,Y,Z:Byte; Yaw:Double; Available:Boolean);
begin
  if not Available then FReadings.Caption:='Sem leitura do joystick. Comandos zerados.'
  else FReadings.Caption:=Format('Voo: rolagem %d | arfagem %d | aceleracao %.0f%% | giro %.2f',[X,Y,100*Z/255,Yaw]);
end;
end.
