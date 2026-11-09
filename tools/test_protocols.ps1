[CmdletBinding()]
param([string]$LazBuild='lazbuild',[string]$Compiler='fpc',[string]$LazarusConfig='',
 [string]$Python='python',[string]$FFmpeg='', [string]$BuildDirectory='')
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
if(-not $BuildDirectory){$BuildDirectory=Join-Path $repo 'build-diagnostics/protocol046'}
$BuildDirectory=[IO.Path]::GetFullPath($BuildDirectory)
New-Item -ItemType Directory -Path $BuildDirectory -Force | Out-Null
if(-not $FFmpeg){$FFmpeg=Join-Path $repo 'install/redist/ffmpeg.exe'}
$buildArgs=@('--skip-dependencies',('--compiler='+$Compiler))
if($LazarusConfig){$buildArgs+=('--pcp='+$LazarusConfig)}
foreach($project in @('binary_vehicle','config046','url_video','camera_real_map')){
 $log=Join-Path $BuildDirectory ($project+'-build.log')
 & $LazBuild @buildArgs (Join-Path $repo ('tests/'+$project+'_regression.lpi')) *> $log
 if($LASTEXITCODE -ne 0){Get-Content $log -Tail 25;throw "Build failed: $project"}
}
& (Join-Path $repo 'build-diagnostics/binary-pipeline/test_binary_vehicle_pipeline.exe')
if($LASTEXITCODE -ne 0){throw 'Cockpit/simulator protocol pipeline failed'}
& (Join-Path $repo 'build-diagnostics/config046/test_config_046.exe')
if($LASTEXITCODE -ne 0){throw 'Configuration persistence failed'}
& $Python (Join-Path $repo 'tests/run_url_video.py') (Join-Path $repo 'build-diagnostics/simulator-tests/test_url_video.exe') $FFmpeg (Join-Path $repo 'simulador/docs/camera-mapa-real.png') (Join-Path $BuildDirectory 'video')
if($LASTEXITCODE -ne 0){throw 'Optional video URL pipeline failed'}
$camera=Join-Path $BuildDirectory 'real-camera'
foreach($tile in Get-ChildItem (Join-Path $repo 'tests/fixtures/osm_tiles17') -Filter '*.png'){
 $xy=$tile.BaseName.Split('-');$dir=Join-Path $camera ('cache/osm/17/'+$xy[0])
 New-Item -ItemType Directory -Path $dir -Force | Out-Null
 Copy-Item -LiteralPath $tile.FullName -Destination (Join-Path $dir ($xy[1]+'.img')) -Force
 [IO.File]::WriteAllText((Join-Path $dir ($xy[1]+'.meta')), "expira=4102444800`n")
}
& (Join-Path $repo 'build-diagnostics/simulator-tests/test_camera_real_map.exe') $camera (Join-Path $repo 'tests/fixtures/not_osm_project.json')
if($LASTEXITCODE -ne 0){throw 'Real-map camera export failed'}
