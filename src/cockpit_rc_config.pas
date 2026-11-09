unit cockpit_rc_config;
{$mode objfpc}{$H+}
interface
uses Classes,SysUtils,Forms,Controls,StdCtrls,Spin,rc_wire_protocol,vehicle_rc_profile;
type
 TRCConfigPanel=class(TScrollBox)
 private
  FProtocol:TRCWireProtocol;FVehicle:TVehicleClass;FLoading:Boolean;
  FClass:TComboBox;FDevice,FBaud,FRate,FAddress,FVideoURL:TEdit;FArm:TSpinEdit;
  FAxes:array[0..3]of TSpinEdit;FInvert:array[0..3]of TCheckBox;
  FEnable:TCheckBox;FInfo,FError:TLabel;
  procedure ClassChanged(Sender:TObject);
  procedure SaveClick(Sender:TObject);
 public
  OnVehicleChanged:TNotifyEvent;
  constructor Create(AOwner:TComponent);override;
  procedure SelectProtocol(P:TRCWireProtocol);
  procedure LoadSettings;
  function SaveSettings:Boolean;
 end;
implementation
uses setmain;
constructor TRCConfigPanel.Create(AOwner:TComponent);
var I:Integer;L:TLabel;Button:TButton;
 function Edit(const ACaption:string;Y:Integer):TEdit;
 var LabelText:TLabel;
 begin LabelText:=TLabel.Create(Self);LabelText.Parent:=Self;LabelText.SetBounds(12,Y+3,220,20);LabelText.Caption:=ACaption;
 Result:=TEdit.Create(Self);Result.Parent:=Self;Result.SetBounds(245,Y,200,24);end;
begin
 inherited Create(AOwner);Align:=alClient;BorderStyle:=bsNone;FProtocol:=rcMSP1;FVehicle:=vcDrone;
 L:=TLabel.Create(Self);L.Parent:=Self;L.SetBounds(12,12,440,20);L.Caption:='Categoria do veiculo / controladora:';
 FClass:=TComboBox.Create(Self);FClass.Parent:=Self;FClass.SetBounds(12,40,433,26);FClass.Name:='rcVehicleClass';FClass.Style:=csDropDownList;
 FClass.Items.CommaText:='Drone,Helicoptero,Aviao,Carro,Barco,Submarino';FClass.ItemIndex:=0;FClass.OnChange:=@ClassChanged;
 FDevice:=Edit('Porta serial (ex.: COM3):',80);FBaud:=Edit('Velocidade serial (baud):',110);
 FRate:=Edit('Frequencia dos quadros (Hz):',140);FAddress:=Edit('Endereco CRSF (decimal):',170);
 for I:=0 to 3 do begin
  L:=TLabel.Create(Self);L.Parent:=Self;L.SetBounds(12,215+I*32,225,20);
  case I of 0:L.Caption:='Canal rolagem / lateral / direcao';1:L.Caption:='Canal arfagem / avanco';2:L.Caption:='Canal guinada';3:L.Caption:='Canal acelerador / vertical';end;
  FAxes[I]:=TSpinEdit.Create(Self);FAxes[I].Parent:=Self;FAxes[I].SetBounds(245,210+I*32,70,26);FAxes[I].MinValue:=1;FAxes[I].MaxValue:=16;
  FInvert[I]:=TCheckBox.Create(Self);FInvert[I].Parent:=Self;FInvert[I].SetBounds(330,210+I*32,115,26);FInvert[I].Caption:='Inverter';
 end;
 L:=TLabel.Create(Self);L.Parent:=Self;L.SetBounds(12,345,225,20);L.Caption:='Canal de armamento (A/B):';
 FArm:=TSpinEdit.Create(Self);FArm.Parent:=Self;FArm.SetBounds(245,340,70,26);FArm.MinValue:=1;FArm.MaxValue:=16;
 FVideoURL:=Edit('URL de video FPV (opcional):',375);
 FEnable:=TCheckBox.Create(Self);FEnable.Parent:=Self;FEnable.SetBounds(12,415,433,26);FEnable.Caption:='Permitir saida serial real neste perfil';
 FInfo:=TLabel.Create(Self);FInfo.Parent:=Self;FInfo.SetBounds(12,455,433,85);FInfo.AutoSize:=False;FInfo.WordWrap:=True;
 FError:=TLabel.Create(Self);FError.Parent:=Self;FError.SetBounds(12,545,433,60);FError.AutoSize:=False;FError.WordWrap:=True;
 Button:=TButton.Create(Self);Button.Parent:=Self;Button.SetBounds(12,610,160,30);Button.Caption:='Salvar perfil RC';Button.OnClick:=@SaveClick;
 LoadSettings;
end;
procedure TRCConfigPanel.SelectProtocol(P:TRCWireProtocol);
begin if P=FProtocol then begin if FVehicle<>FSetMain.RCSelected[P] then LoadSettings;Exit;end;SaveSettings;FProtocol:=P;FVehicle:=FSetMain.RCSelected[P];LoadSettings;end;
procedure TRCConfigPanel.LoadSettings;
var S:TRCSettings;I:Integer;
begin
 if not Assigned(FSetMain) then Exit;
 FLoading:=True;try FVehicle:=FSetMain.RCSelected[FProtocol];FClass.ItemIndex:=Ord(FVehicle);S:=FSetMain.RCSettings[FProtocol,FVehicle];
 FVideoURL.Text:=S.VideoURL;FDevice.Text:=S.Device;FBaud.Text:=IntToStr(S.Baud);FRate.Text:=IntToStr(S.RateHz);FAddress.Text:=IntToStr(S.Address);
 FArm.Value:=S.ArmChannel;FEnable.Checked:=S.RealEnabled;
 for I:=0 to 3 do begin FAxes[I].Value:=S.Axis[I];FInvert[I].Checked:=S.Invert[I];FAxes[I].MaxValue:=RCChannelCount(FProtocol);end;
 FArm.MaxValue:=RCChannelCount(FProtocol);
 FInfo.Caption:='A arma; B desarma; Espaco corta. Modo simulador usa os mesmos quadros em UDP local. No equipamento real, configure a controladora/receptor para receber '+RCKeys[FProtocol]+'.';
 if FProtocol=rcSBUS then FInfo.Caption:=FInfo.Caption+' SBUS requer UART 100000 8E2 e inversao eletrica apropriada.';
 finally FLoading:=False;end;
end;
function TRCConfigPanel.SaveSettings:Boolean;
var S:TRCSettings;I,A:Integer;E:string;
begin
 Result:=False;if FLoading or not Assigned(FSetMain) then Exit;
 S:=DefaultRCSettings(FProtocol,FVehicle);S.VideoURL:=Trim(FVideoURL.Text);S.Device:=Trim(FDevice.Text);S.Baud:=StrToIntDef(FBaud.Text,0);
 S.RateHz:=StrToIntDef(FRate.Text,0);S.ArmChannel:=FArm.Value;S.RealEnabled:=FEnable.Checked;
 A:=StrToIntDef(FAddress.Text,-1);if (A<0) or (A>255) then begin FError.Caption:='Endereco CRSF precisa estar entre 0 e 255';Exit;end;S.Address:=A;
 for I:=0 to 3 do begin S.Axis[I]:=FAxes[I].Value;S.Invert[I]:=FInvert[I].Checked;end;
 Result:=ValidateRCSettings(FProtocol,S,E);FError.Caption:=E;
 if Result then begin FSetMain.RCSettings[FProtocol,FVehicle]:=S;FSetMain.RCSelected[FProtocol]:=FVehicle;end;
end;
procedure TRCConfigPanel.ClassChanged(Sender:TObject);
var NewClass:TVehicleClass;
begin if FLoading or (FClass.ItemIndex<0) then Exit;NewClass:=TVehicleClass(FClass.ItemIndex);
 if not SaveSettings then begin FLoading:=True;FClass.ItemIndex:=Ord(FVehicle);FLoading:=False;Exit;end;
 FVehicle:=NewClass;FSetMain.RCSelected[FProtocol]:=FVehicle;LoadSettings;
 if Assigned(OnVehicleChanged) then OnVehicleChanged(Self);end;
procedure TRCConfigPanel.SaveClick(Sender:TObject);
begin if SaveSettings then begin FSetMain.SalvaContexto;FError.Caption:='Perfil salvo para '+VehicleKeys[FVehicle];end;end;
end.
