program test_runtime_paths;
{$mode objfpc}{$H+}
uses Classes, SysUtils, cockpit_runtime_paths;
procedure Check(Ok: Boolean; const Text: string);
begin if not Ok then raise Exception.Create(Text); end;
procedure Touch(const Name: string);
var F: TFileStream;
begin F := TFileStream.Create(Name, fmCreate); F.Free; end;
var Root, ExeName, Installed, Development: string;
begin
  Root := ExtractFilePath(ExpandFileName(ParamStr(0))) + 'tool-paths-fixture';
  Check(not DirectoryExists(Root), 'fixture directory already exists');
  ForceDirectories(Root + DirectorySeparator + 'bin' + DirectorySeparator + 'tools');
  ForceDirectories(Root + DirectorySeparator + 'tools');
  ExeName := Root + DirectorySeparator + 'bin' + DirectorySeparator + 'drone.exe';
  Installed := Root + DirectorySeparator + 'bin' + DirectorySeparator + 'tools' + DirectorySeparator + 'sitl_heartbeat_monitor.py';
  Development := Root + DirectorySeparator + 'tools' + DirectorySeparator + 'sitl_heartbeat_monitor.py';
  try
    Check(ResolveCockpitToolPath('sitl_heartbeat_monitor.py', ExeName) = '', 'missing script');
    Touch(Development);
    Check(ResolveCockpitToolPath('sitl_heartbeat_monitor.py', ExeName) = Development, 'development layout');
    Touch(Installed);
    Check(ResolveCockpitToolPath('sitl_heartbeat_monitor.py', ExeName) = Installed, 'installed layout takes precedence');
    Check(CockpitPythonExecutable <> '', 'Python selection');
    WriteLn('PASS: runtime tool discovery for development and installation');
  finally
    DeleteFile(Installed); DeleteFile(Development);
    RemoveDir(Root + DirectorySeparator + 'bin' + DirectorySeparator + 'tools');
    RemoveDir(Root + DirectorySeparator + 'bin');
    RemoveDir(Root + DirectorySeparator + 'tools'); RemoveDir(Root);
  end;
end.
