unit cockpit_runtime_paths;
{$mode objfpc}{$H+}
interface
uses SysUtils;
function ResolveCockpitToolPath(const ToolName, ExecutableName: string): string;
function CockpitPythonExecutable: string;
implementation
function ResolveCockpitToolPath(const ToolName, ExecutableName: string): string;
var Base, Candidate: string;
begin
  Result := '';
  Base := ExtractFilePath(ExpandFileName(ExecutableName));
  Candidate := ExpandFileName(Base + 'tools' + DirectorySeparator + ToolName);
  if FileExists(Candidate) then Exit(Candidate);
  // Development executable lives in src/, with tools/ beside src/.
  Candidate := ExpandFileName(Base + '..' + DirectorySeparator + 'tools' +
    DirectorySeparator + ToolName);
  if FileExists(Candidate) then Result := Candidate;
end;
function CockpitPythonExecutable: string;
begin
  Result := Trim(GetEnvironmentVariable('COCKPIT_PYTHON'));
  if Result <> '' then Exit;
  {$IFDEF MSWINDOWS}
  Result := 'python';
  {$ELSE}
  Result := 'python3';
  {$ENDIF}
end;
end.
