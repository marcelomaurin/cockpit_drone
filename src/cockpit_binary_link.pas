unit cockpit_binary_link;
{$mode objfpc}{$H+}
interface
uses Classes,SysUtils,Sockets,SyncObjs{$IFDEF WINDOWS},Windows{$ENDIF}{$IFDEF UNIX},BaseUnix{$ENDIF};
type
 TBinaryLink=class
  function Write(const B:TBytes):Boolean;virtual;abstract;
  function Read(out B:TBytes):Boolean;virtual;abstract;
 end;
 TUDPBinaryLink=class(TBinaryLink)
 private FSock:LongInt;FPeer:TInetSockAddr;FPort:Integer;
 public
  constructor Create(const Host:string;Port:Word;const BindIP:string='127.0.0.1';BindPort:Word=0);
  destructor Destroy;override;
  function Write(const B:TBytes):Boolean;override;
  function WritePort(const B:TBytes;Port:Word):Boolean;
  function Read(out B:TBytes):Boolean;override;
  property LocalPort:Integer read FPort;
 end;
 TSerialBinaryLink=class(TBinaryLink)
 private {$IFDEF WINDOWS}FHandle:THandle;{$ENDIF}
 public
  constructor Create(const Device:string;Baud:Integer;EvenParity:Boolean=False;TwoStopBits:Boolean=False);
  destructor Destroy;override;
  function Write(const B:TBytes):Boolean;override;
  function Read(out B:TBytes):Boolean;override;
 end;
implementation
{$IFDEF WINDOWS}
function BinarySocketAvailable(Socket:NativeUInt;Command:LongInt;var Bytes:LongWord):LongInt;stdcall;external 'ws2_32.dll' name 'ioctlsocket';
{$ENDIF}
constructor TUDPBinaryLink.Create(const Host:string;Port:Word;const BindIP:string;BindPort:Word);
var Addr:TInetSockAddr;Size:TSockLen;
 {$IFDEF WINDOWS}Timeout:DWORD;{$ELSE}Timeout:TTimeVal;{$ENDIF}
begin
 inherited Create;FSock:=-1;
 if (Trim(Host)='') or (Port=0) then raise EArgumentException.Create('IP e porta UDP precisam estar definidos');
 FillChar(FPeer,SizeOf(FPeer),0);FPeer.sin_family:=AF_INET;FPeer.sin_port:=htons(Port);FPeer.sin_addr:=StrToNetAddr(Host);
 if FPeer.sin_addr.s_addr=0 then raise EArgumentException.Create('Use um endereco IPv4 valido');
 FSock:=fpsocket(AF_INET,SOCK_DGRAM,0);if FSock=-1 then raise Exception.Create('Nao foi possivel abrir UDP');
 FillChar(Addr,SizeOf(Addr),0);Addr.sin_family:=AF_INET;Addr.sin_port:=htons(BindPort);
 if BindIP<>'' then Addr.sin_addr:=StrToNetAddr(BindIP);
 if fpbind(FSock,@Addr,SizeOf(Addr))<>0 then raise Exception.Create('Nao foi possivel vincular o IP/porta local UDP');
 Size:=SizeOf(Addr);if fpgetsockname(FSock,@Addr,@Size)=0 then FPort:=ntohs(Addr.sin_port);
 {$IFDEF WINDOWS}Timeout:=1;{$ELSE}Timeout.tv_sec:=0;Timeout.tv_usec:=1000;{$ENDIF}
 fpsetsockopt(FSock,SOL_SOCKET,SO_RCVTIMEO,@Timeout,SizeOf(Timeout));
end;
destructor TUDPBinaryLink.Destroy;
begin if FSock<>-1 then CloseSocket(FSock);inherited Destroy;end;
function TUDPBinaryLink.Write(const B:TBytes):Boolean;
begin Result:=(Length(B)>0) and (fpsendto(FSock,@B[0],Length(B),0,@FPeer,SizeOf(FPeer))=Length(B));end;
function TUDPBinaryLink.WritePort(const B:TBytes;Port:Word):Boolean;
var Target:TInetSockAddr;
begin Target:=FPeer;Target.sin_port:=htons(Port);
 Result:=(Length(B)>0) and (fpsendto(FSock,@B[0],Length(B),0,@Target,SizeOf(Target))=Length(B));end;
function TUDPBinaryLink.Read(out B:TBytes):Boolean;
var Buffer:array[0..4095]of Byte;Peer:TInetSockAddr;Size:TSockLen;N:Integer;{$IFDEF WINDOWS}Available:LongWord;{$ENDIF}
begin
 B:=nil;
 {$IFDEF WINDOWS}Available:=0;if (BinarySocketAvailable(NativeUInt(FSock),$4004667F,Available)<>0) or (Available=0) then Exit(False);{$ENDIF}Size:=SizeOf(Peer);N:=fprecvfrom(FSock,@Buffer,SizeOf(Buffer),0,@Peer,@Size);
 Result:=(N>0) and (Peer.sin_addr.s_addr=FPeer.sin_addr.s_addr) and (Peer.sin_port=FPeer.sin_port);
 if Result then begin SetLength(B,N);Move(Buffer[0],B[0],N);end;
end;
constructor TSerialBinaryLink.Create(const Device:string;Baud:Integer;EvenParity:Boolean;TwoStopBits:Boolean);
{$IFDEF WINDOWS}var Config:TDCB;Timeouts:TCOMMTIMEOUTS;Name:UnicodeString;N:Integer;{$ENDIF}
begin
 inherited Create;
 {$IFDEF WINDOWS}
 FHandle:=INVALID_HANDLE_VALUE;
 if not SameText(Copy(Device,1,3),'COM') or not TryStrToInt(Copy(Device,4,16),N) or (N<1) then
  raise EArgumentException.Create('Selecione a porta COM do receptor/controladora');
 Name:='\\.\'+UnicodeString(Device);
 FHandle:=CreateFileW(PWideChar(Name),GENERIC_READ or GENERIC_WRITE,0,nil,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
 if FHandle=INVALID_HANDLE_VALUE then raise Exception.Create('Falha ao abrir '+Device+': '+SysErrorMessage(GetLastError));
 FillChar(Config,SizeOf(Config),0);Config.DCBlength:=SizeOf(Config);
 if not GetCommState(FHandle,Config) then RaiseLastOSError;
 Config.BaudRate:=Baud;Config.ByteSize:=8;Config.Flags:=1;Config.Parity:=NOPARITY;Config.StopBits:=ONESTOPBIT;
 if EvenParity then begin Config.Flags:=Config.Flags or 2;Config.Parity:=Windows.EVENPARITY;end;
 if TwoStopBits then Config.StopBits:=Windows.TWOSTOPBITS;
 if not SetCommState(FHandle,Config) then raise Exception.Create('Driver recusou baud/paridade: '+SysErrorMessage(GetLastError));
 FillChar(Timeouts,SizeOf(Timeouts),0);Timeouts.ReadIntervalTimeout:=MAXDWORD;Timeouts.WriteTotalTimeoutConstant:=100;
 if not SetCommTimeouts(FHandle,Timeouts) then RaiseLastOSError;
 PurgeComm(FHandle,PURGE_RXCLEAR or PURGE_TXCLEAR);
 {$ELSE}
 raise Exception.Create('Transporte serial RC desta entrega disponivel no Windows');
 {$ENDIF}
end;
destructor TSerialBinaryLink.Destroy;
begin {$IFDEF WINDOWS}if FHandle<>INVALID_HANDLE_VALUE then CloseHandle(FHandle);{$ENDIF}inherited Destroy;end;
function TSerialBinaryLink.Write(const B:TBytes):Boolean;
{$IFDEF WINDOWS}var N:DWORD;{$ENDIF}
begin Result:=False;{$IFDEF WINDOWS}if Length(B)>0 then Result:=WriteFile(FHandle,B[0],Length(B),N,nil) and (N=DWORD(Length(B)));{$ENDIF}end;
function TSerialBinaryLink.Read(out B:TBytes):Boolean;
{$IFDEF WINDOWS}var Buf:array[0..4095]of Byte;N:DWORD;{$ENDIF}
begin B:=nil;Result:=False;
 {$IFDEF WINDOWS}if ReadFile(FHandle,Buf,SizeOf(Buf),N,nil) and (N>0) then begin SetLength(B,N);Move(Buf[0],B[0],N);Result:=True;end;{$ENDIF}
end;
end.
