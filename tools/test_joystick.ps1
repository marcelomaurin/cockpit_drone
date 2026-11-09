[CmdletBinding()]
param([string]$LazBuild='lazbuild', [string]$LazarusConfig='', [string]$Compiler='', [switch]$SkipDependencies)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$buildArgs=@()
if($LazarusConfig){$buildArgs+=('--pcp='+$LazarusConfig)}
if($Compiler){$buildArgs+=('--compiler='+$Compiler)}
if($SkipDependencies){$buildArgs+='--skip-dependencies'}
foreach($name in @('joystick_regression','profile_regression')){
 & $LazBuild @buildArgs (Join-Path $repo ('tests/'+$name+'.lpi'))
 if($LASTEXITCODE -ne 0){throw "Build failed: $name"}
}
foreach($name in @('test_xbox_cheerson','test_profile_settings')){
 & (Join-Path $repo ('build-diagnostics/joystick/'+$name+'.exe'))
 if($LASTEXITCODE -ne 0){throw "Test failed: $name"}
}
