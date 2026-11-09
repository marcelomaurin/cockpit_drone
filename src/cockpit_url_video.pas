unit cockpit_url_video;
{$mode objfpc}{$H+}
interface
uses Classes,SysUtils,Process,Graphics;
type
 TURLVideoSource=class
 private FProcess:TProcess;FFile:string;
 public
  constructor Create(const URL,FFmpegExecutable,OutputFile:string);
  destructor Destroy;override;
  function LoadFrame(Bitmap:TBitmap):Boolean;
  function Running:Boolean;
  property FrameFile:string read FFile;
 end;
function FindCockpitFFmpeg:string;
implementation
function FindCockpitFFmpeg:string;
var Base,Candidate:string;
begin
 Base:=ExtractFilePath(ExpandFileName(ParamStr(0)));Candidate:=Base+'ffmpeg.exe';if FileExists(Candidate) then Exit(Candidate);
 Candidate:=ExpandFileName(Base+'../install/redist/ffmpeg.exe');if FileExists(Candidate) then Exit(Candidate);
 Candidate:=ExpandFileName(Base+'../bin/ffmpeg.exe');if FileExists(Candidate) then Exit(Candidate);
 Result:=FileSearch('ffmpeg.exe',GetEnvironmentVariable('PATH'));
end;
constructor TURLVideoSource.Create(const URL,FFmpegExecutable,OutputFile:string);
var S:string;
 procedure Arg(const V:string);begin FProcess.Parameters.Add(V);end;
begin
 inherited Create;S:=LowerCase(URL);
 if (Pos('http://',S)<>1) and (Pos('https://',S)<>1) and (Pos('rtsp://',S)<>1) and (Pos('udp://',S)<>1) then
  raise EArgumentException.Create('Video: use URL HTTP(S), RTSP ou UDP do fluxo identificado');
 if not FileExists(FFmpegExecutable) then raise Exception.Create('ffmpeg.exe nao encontrado no pacote');
 FFile:=OutputFile;if FileExists(FFile) then DeleteFile(FFile);
 FProcess:=TProcess.Create(nil);FProcess.Executable:=FFmpegExecutable;FProcess.Options:=[poUsePipes,poNoConsole];FProcess.ShowWindow:=swoHIDE;
 Arg('-hide_banner');Arg('-loglevel');Arg('error');Arg('-nostdin');Arg('-rw_timeout');Arg('5000000');
 Arg('-i');Arg(URL);Arg('-an');Arg('-vf');Arg('scale=640:360');Arg('-r');Arg('10');
 Arg('-c:v');Arg('bmp');Arg('-f');Arg('image2');Arg('-update');Arg('1');Arg('-atomic_writing');Arg('1');Arg('-y');Arg(FFile);
 FProcess.Execute;
end;
destructor TURLVideoSource.Destroy;
begin if Assigned(FProcess) then begin if FProcess.Running then FProcess.Terminate(0);FProcess.Free;end;
 if (FFile<>'') and FileExists(FFile) then DeleteFile(FFile);inherited Destroy;end;
function TURLVideoSource.Running:Boolean;
var Buffer:array[0..2047]of Byte;
begin Result:=Assigned(FProcess) and FProcess.Running;
 if Assigned(FProcess) then while FProcess.Stderr.NumBytesAvailable>0 do FProcess.Stderr.Read(Buffer,SizeOf(Buffer));
end;
function TURLVideoSource.LoadFrame(Bitmap:TBitmap):Boolean;
var Age:TDateTime;Stream:TFileStream;
begin
 Result:=False;if not Assigned(Bitmap) or not Running then Exit;
 if not FileAge(FFile,Age) or ((Now-Age)*86400>3) then Exit;
 try Stream:=TFileStream.Create(FFile,fmOpenRead or fmShareDenyNone);
  try Bitmap.LoadFromStream(Stream);Result:=(Bitmap.Width>0) and (Bitmap.Height>0);finally Stream.Free;end;
 except Result:=False;end;
end;
end.
