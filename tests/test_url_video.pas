program test_url_video;
{$mode objfpc}{$H+}
uses Interfaces,Forms,Classes,SysUtils,Graphics,cockpit_url_video;
var Source:TURLVideoSource;B:TBitmap;Deadline:QWord;FrameFile:string;OK:Boolean;
begin
 try
 Application.Initialize;B:=TBitmap.Create;FrameFile:=ExpandFileName(ParamStr(3));
 Source:=TURLVideoSource.Create(ParamStr(1),ParamStr(2),FrameFile);
 try Deadline:=GetTickCount64+15000;OK:=False;
 repeat Sleep(50);if Source.LoadFrame(B) then begin OK:=True;Break;end;until GetTickCount64>=Deadline;
 if not OK then raise Exception.Create('No decoded frame received from HTTP MJPEG');
 if (B.Width<>640) or (B.Height<>360) then raise Exception.Create('Wrong decoded frame dimensions');
 B.SaveToFile(ChangeFileExt(FrameFile,'.verified.bmp'));
 finally Source.Free;B.Free;end;
 if FileExists(FrameFile) then raise Exception.Create('Temporary frame not cleaned');
 WriteLn('PASS optional FPV URL: HTTP MJPEG > packaged FFmpeg > atomic BMP > cockpit bitmap (640x360) and process cleanup');
 except on E:Exception do begin WriteLn(StdErr,E.Message);Halt(1);end;end;
end.
