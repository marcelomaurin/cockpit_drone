unit ConectionCX10W;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Menus, lNetComponents, BCRadialProgressBar, BGRASpriteAnimation,
  MPlayerCtrl, config, lNet, advled, hexlib;

const
     magicBytesCtrl : array[0..105] of byte = (
              $49, $54, $64, $00, $00, $00, $5D, $00, $00, $00, $81, $85, $FF, $BD, $2A, $29, $5C, $AD, $67, $82, $5C, $57, $BE, $41, $03, $F8, $CA, $E2, $64, $30, $A3, $C1,
	      $5E, $40, $DE, $30, $F6, $D6, $95, $E0, $30, $B7, $C2, $E5, $B7, $D6, $5D, $A8, $65, $9E, $B2, $E2, $D5, $E0, $C2, $CB, $6C, $59, $CD, $CB, $66, $1E, $7E, $1E,
	      $B0, $CE, $8E, $E8, $DF, $32, $45, $6F, $A8, $42, $EE, $2E, $09, $A3, $9B, $DD, $05, $C8, $30, $A2, $81, $C8, $2A, $9E, $DA, $7F, $D5, $86, $0E, $AF, $AB, $FE,
	      $FA, $3C, $7E, $54, $4F, $F2, $8A, $D2, $93, $CD
               );

     magicBytesVideo1A  : array[0..105] of byte = (
       	      $49, $54, $64, $00, $00, $00, $52, $00, $00, $00, $0F, $32, $81, $95, $45, $2E, $F5, $E1, $A9, $28, $10, $86, $63, $17, $36, $C3, $CA, $E2, $64, $30, $A3, $C1,
              $5E, $40, $DE, $30, $F6, $D6, $95, $E0, $30, $B7, $C2, $E5, $B7, $D6, $5D, $A8, $65, $9E, $B2, $E2, $D5, $E0, $C2, $CB, $6C, $59, $CD, $CB, $66, $1E, $7E, $1E,
              $B0, $CE, $8E, $E8, $DF, $32, $45, $6F, $A8, $42, $B7, $33, $0F, $B7, $C9, $57, $82, $FC, $3D, $67, $E7, $C3, $A6, $67, $28, $DA, $D8, $B5, $98, $48, $C7, $67,
              $0C, $94, $B2, $9B, $54, $D2, $37, $9E, $2E, $7A
              );

     magicBytesVideo1B  : array[0..105] of byte = (
                   $49, $54, $64, $00, $00, $00, $52, $00, $00, $00, $54, $B2, $D1, $F6, $63, $48, $C7, $CD, $B6, $E0, $5B, $0D, $1D, $BC, $A8, $1B, $CA, $E2, $64, $30, $A3, $C1,
                   $5E, $40, $DE, $30, $F6, $D6, $95, $E0, $30, $B7, $C2, $E5, $B7, $D6, $5D, $A8, $65, $9E, $B2, $E2, $D5, $E0, $C2, $CB, $6C, $59, $CD, $CB, $66, $1E, $7E, $1E,
                   $B0, $CE, $8E, $E8, $DF, $32, $45, $6F, $A8, $42, $B7, $33, $0F, $B7, $C9, $57, $82, $FC, $3D, $67, $E7, $C3, $A6, $67, $28, $DA, $D8, $B5, $98, $48, $C7, $67,
                   $0C, $94, $B2, $9B, $54, $D2, $37, $9E, $2E, $7A
                   );

     magicVideoIdx : integer =  0;

     magicBytesVideo2 : array[0..105] of byte = (
      	      $49, $54, $64, $00, $00, $00, $58, $00, $00, $00, $80, $86, $38, $C3, $8D, $13, $50, $FD, $67, $41, $C2, $EE, $36, $89, $A0, $54, $CA, $E2, $64, $30, $A3, $C1,
                   $5E, $40, $DE, $30, $F6, $D6, $95, $E0, $30, $B7, $C2, $E5, $B7, $D6, $5D, $A8, $65, $9E, $B2, $E2, $D5, $E0, $C2, $CB, $6C, $59, $CD, $CB, $66, $1E, $7E, $1E,
                   $B0, $CE, $8E, $E8, $DF, $32, $45, $6F, $A8, $42, $EB, $20, $BE, $38, $3A, $AB, $05, $A8, $C2, $A7, $1F, $2C, $90, $6D, $93, $F7, $2A, $85, $E7, $35, $6E, $FF,
                   $E1, $B8, $F5, $AF, $09, $7F, $91, $47, $F8, $7E
                   );

     data  : array[0..7] of byte = (
                   $CC, $7F, $7F, $0, $7F, $0, $7F, $33
                   );

type

  { TfrmConectionCX10W }

  TfrmConectionCX10W = class(TForm)
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    lbStateConection: TLabel;
    lbTCP: TLabel;
    lbIP: TLabel;
    lbdevicename: TLabel;
    lbUDP: TLabel;
    LTCPComponent1: TLTCPComponent;
    LUDPComponent1: TLUDPComponent;
    meLog: TMemo;
    MenuItem1: TMenuItem;
    pnTop: TPanel;
    pnBotton: TPanel;
    popLog: TPopupMenu;
    timerJoystick: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure Label5Click(Sender: TObject);
    procedure lbStateConectionChangeBounds(Sender: TObject);
    procedure LTCPComponent1Accept(aSocket: TLSocket);
    procedure LTCPComponent1Connect(aSocket: TLSocket);
    procedure LTCPComponent1Disconnect(aSocket: TLSocket);
    procedure LTCPComponent1Error(const msg: string; aSocket: TLSocket);
    procedure LTCPComponent1Receive(aSocket: TLSocket);
    procedure LUDPComponent1Error(const msg: string; aSocket: TLSocket);
    procedure LUDPComponent1Receive(aSocket: TLSocket);
    procedure pnBottonClick(Sender: TObject);
    procedure timerJoystickTimer(Sender: TObject);
  private
      X,Y,Z : byte;
      B1,B2,B3, B4,B5,B6 : byte;

  public

          magicBytesVideo1A : string;
          magicBytesVideo1B : string;
          magicVideoIdx: integer;
          magicBytesVideo2 : string;

          procedure PegaConfiguracao();
          procedure InicioHandShake();
          procedure sendMagicPackets();
          procedure sendMagicPacketsVideo1();
          procedure sendMagicPacketsVideo2();
          function checksum(): byte;
          procedure sendGamepadData();
          procedure DesativaJoystick();
          procedure AtivaJoystick();
          procedure DesativaConnection();
  end;





var
  frmConectionCX10W: TfrmConectionCX10W;

implementation

{$R *.lfm}
uses main;

procedure TfrmConectionCX10W.Label5Click(Sender: TObject);
begin

end;

procedure TfrmConectionCX10W.lbStateConectionChangeBounds(Sender: TObject);
begin
  meLog.Append(datetimetostr(now)+':'+lbStateConection.caption);
end;

procedure TfrmConectionCX10W.FormCreate(Sender: TObject);
begin


end;

procedure TfrmConectionCX10W.LTCPComponent1Accept(aSocket: TLSocket);
begin
    lbStateConection.Caption:= 'Accept connection';
end;

procedure TfrmConectionCX10W.LTCPComponent1Connect(aSocket: TLSocket);
begin
  lbStateConection.Caption:= 'Connection open';

  //Inicia
  sendMagicPackets();
  sendMagicPacketsVideo1();
  //sendMagicPacketsVideo2();


  AtivaJoystick();
  FrmMain.AtivouDrone();


end;


procedure TfrmConectionCX10W.AtivaJoystick();
begin
     timerJoystick.Enabled:= true;
end;

procedure TfrmConectionCX10W.DesativaJoystick();
begin
  timerJoystick.Enabled:= false;
  frmMain.DesativaJoystick();
end;

procedure TfrmConectionCX10W.LTCPComponent1Disconnect(aSocket: TLSocket);
begin
    lbStateConection.Caption:= 'Connection close';
    DesativaJoystick();
end;


procedure TfrmConectionCX10W.DesativaConnection();
begin
   frmMain.AdvStartClick(self);
end;

procedure TfrmConectionCX10W.LTCPComponent1Error(const msg: string;
  aSocket: TLSocket);
begin
    lbStateConection.Caption:= 'Erro connection';
    DesativaJoystick();
    DesativaConnection();
end;

procedure TfrmConectionCX10W.LTCPComponent1Receive(aSocket: TLSocket);
var
  info : string;
begin
  aSocket.GetMessage(info);
  meLog.Append(datetimetostr(now)+'RECEIVE_TCP:'+StringToHex(info));
end;

procedure TfrmConectionCX10W.LUDPComponent1Error(const msg: string;
  aSocket: TLSocket);
begin
  meLog.Append(datetimetostr(now)+'UDP_Erro:');
end;

procedure TfrmConectionCX10W.LUDPComponent1Receive(aSocket: TLSocket);
var
  info: string;
begin
  aSocket.GetMessage(info);
  meLog.Append(datetimetostr(now)+'RECEIVE_UDP:'+StringToHex(info));
end;

procedure TfrmConectionCX10W.pnBottonClick(Sender: TObject);
begin

end;

procedure TfrmConectionCX10W.timerJoystickTimer(Sender: TObject);
var

  a : integer;
  mudou : boolean;
begin
  mudou := false;
  //Captura a posicao do comando e envia se for diferente
  if X <> frmMain.X then
  begin
       X :=frmMain.X;
       mudou := true;
  end;
  if Y <> frmMain.Y then
  begin
       Y :=frmMain.Y;
       mudou := true;
  end;

  if Z <> frmMain.Z then
  begin
       Z :=frmMain.Z;
       mudou := true;
  end;


  if B1 <> frmMain.B1 then
  begin
       B1 :=frmMain.B1;
       mudou := true;
  end;
  if B2 <> frmMain.B2 then
  begin
       B2 :=frmMain.B2;
       mudou := true;
  end;
  if B3 <> frmMain.B3 then
  begin
       B1 :=frmMain.B1;
       mudou := true;
  end;
  if B4 <> frmMain.B4 then
  begin
       B4 :=frmMain.B4;
       mudou := true;
  end;
  if B5 <> frmMain.B5 then
  begin
       B5 :=frmMain.B5;
       mudou := true;
  end;
  if B6 <> frmMain.B6 then
  begin
       B6 :=frmMain.B6;
       mudou := true;
  end;








 if (mudou ) then
 begin
      sendGamepadData();
 end;

end;

procedure TfrmConectionCX10W.sendMagicPackets();
begin
         LTCPComponent1.Send(magicBytesCtrl, Length(magicBytesCtrl));
end;

procedure TfrmConectionCX10W.sendMagicPacketsVideo1();
begin

    LTCPComponent1.Send(magicBytesVideo1A,Length(magicBytesVideo1A));
    LTCPComponent1.Send(magicBytesVideo1B,Length(magicBytesVideo1B));

end;

procedure TfrmConectionCX10W.sendMagicPacketsVideo2();
begin
     LTCPComponent1.Send(magicBytesVideo2,Length(magicBytesVideo2));
end;

function TfrmConectionCX10W.checksum(): byte;
var
  acum : byte;
  info : byte;
  a : integer;
begin
  acum := ord(data[1]);
  for a := 2 to 5 do
  begin
     info := ord(data[a]);
     acum := acum xor info;
  end;
  result := acum and $FF;
    //result := (((((data[1] xor data[2]) xor data[3]) xor data[4]) xor data[5]) and $FF);
end;

procedure TfrmConectionCX10W.sendGamepadData();
var
  DataArray : array[0..7] of byte;
  a : integer;
  info : string;
begin
    for a:= 1 to 6 do
        DataArray[a] := data[a];

    DataArray[1] := ord(frmMain.X and 255);
    DataArray[2] := ord(2- (frmMain.Y and 255));
    DataArray[3] := ord(frmMain.B1 and 255);
    DataArray[4] := ord(frmMain.B2 and 255);
    DataArray[6] := ord(checksum());
    info := '';
    for a:= 1 to 6 do
       info := info + StringToHex(chr(DataArray[a]));


    if LUDPComponent1.Active then
    begin
      LUDPComponent1.Send(DataArray,length(DataArray));
      meLog.Append(datetimetostr(now)+':'+info);

    end
    else
    begin
      meLog.Append(datetimetostr(now)+': UDP Erro');
    end;

end;

//Da inicio ao processo de comunicacao
procedure TfrmConectionCX10W.PegaConfiguracao();
begin
     meLog.Append(datetimetostr(now)+': Configuration Begin');
     lbip.Caption := frmconfig.edIP.text;
     lbTCP.Caption := frmconfig.edTCPPORT.text;
     lbUDP.Caption:= frmconfig.edUDPPORT.Text;
     lbStateConection.caption := 'Offline';
     if LTCPComponent1.Active =true then
     begin
          LTCPComponent1.Disconnect(true);
     end;
     if LUDPComponent1.Active=true then
     begin
          LUDPComponent1.Disconnect(true);
     end;
     LTCPComponent1.Host := lbIP.Caption;
     LUDPComponent1.Host:=lbIP.Caption;
     LTCPComponent1.Port:=strtoint(lbTCP.Caption);
     LUDPComponent1.Port:=strtoint(lbUDP.Caption);

end;


procedure TfrmConectionCX10W.InicioHandShake();
begin
     meLog.Append(datetimetostr(now)+': Hand Shake');
     lbStateConection.Caption:= 'Connecting...';
     LTCPComponent1.Connect(lbIP.Caption,strtoint(lbTCP.Caption));
     LUDPComponent1.Connect(lbIP.caption,strtoint(lbUDP.caption));
end;

end.

