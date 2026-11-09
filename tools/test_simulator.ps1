[CmdletBinding()]
param([string]$Compiler='fpc',[string]$BuildDirectory='',[string]$Python='python',[string]$LazBuild='',[string]$LazarusConfig='')
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
if(-not $BuildDirectory){$BuildDirectory=Join-Path $repo 'build-diagnostics/simulator-tests'}
$BuildDirectory=[IO.Path]::GetFullPath($BuildDirectory)
$units=Join-Path $BuildDirectory 'units'
New-Item -ItemType Directory -Path $units -Force | Out-Null
$argsBuild=@('-Cr','-Co','-Ci','-gl',('-FU'+$units),('-FE'+$BuildDirectory))
foreach($folder in @('src','src/compat','simulador/src/nucleo','simulador/src/protocolos','simulador/src/mapa','simulador/src/visao')){
 $argsBuild+=('-Fu'+(Join-Path $repo $folder))
}
foreach($name in @('test_crash_recovery','test_buildings_3d','test_buildings_loader','test_infinite_signal','test_urban_terrain','test_vehicle_physics','test_real_map_raster')){
 & $Compiler @argsBuild (Join-Path $repo ('tests/'+$name+'.pas')) *> (Join-Path $BuildDirectory ($name+'-build.log'))
 if($LASTEXITCODE -ne 0){Get-Content (Join-Path $BuildDirectory ($name+'-build.log')) -Tail 20;throw "Build failed: $name"}
}
& (Join-Path $BuildDirectory 'test_vehicle_physics.exe')
if($LASTEXITCODE -ne 0){throw 'Vehicle physics test failed'}
& (Join-Path $BuildDirectory 'test_real_map_raster.exe') (Join-Path $repo 'tests/fixtures/osm_tiles17') (Join-Path $repo 'tests/fixtures/not_osm_project.json') (Join-Path $BuildDirectory 'real-map.png')
if($LASTEXITCODE -ne 0){throw 'Real map raster test failed'}
& (Join-Path $BuildDirectory 'test_infinite_signal.exe')
if($LASTEXITCODE -ne 0){throw 'Infinite signal test failed'}
& (Join-Path $BuildDirectory 'test_urban_terrain.exe') (Join-Path $repo 'tests/fixtures/osm_terrain.json')
if($LASTEXITCODE -ne 0){throw 'Urban terrain test failed'}
$fixture=Join-Path $repo 'tests/fixtures/osm_buildings.json'
& (Join-Path $BuildDirectory 'test_crash_recovery.exe')
if($LASTEXITCODE -ne 0){throw 'Crash recovery test failed'}
& (Join-Path $BuildDirectory 'test_buildings_3d.exe') $fixture (Join-Path $BuildDirectory 'camera-low.png') (Join-Path $BuildDirectory 'camera-high.png')
if($LASTEXITCODE -ne 0){throw '3D building test failed'}
& (Join-Path $BuildDirectory 'test_buildings_loader.exe') $fixture (Join-Path $BuildDirectory 'cache')
if($LASTEXITCODE -ne 0){throw 'Building loader test failed'}

$previous=$env:COCKPIT_BUILDINGS_LOADER_EXE
try {
 $env:COCKPIT_BUILDINGS_LOADER_EXE=Join-Path $BuildDirectory 'test_buildings_loader.exe'
 & $Python (Join-Path $repo 'tests/test_buildings_http.py') -v
 if($LASTEXITCODE -ne 0){throw 'Building HTTP/cache test failed'}
} finally { $env:COCKPIT_BUILDINGS_LOADER_EXE=$previous }

if($LazBuild){
 $cameraArgs=@('--skip-dependencies',('--compiler='+$Compiler))
 if($LazarusConfig){$cameraArgs+=('--pcp='+$LazarusConfig)}
 & $LazBuild @cameraArgs (Join-Path $repo 'tests/camera_export_regression.lpi') *> (Join-Path $BuildDirectory 'camera-export-build.log')
 if($LASTEXITCODE -ne 0){throw 'Camera export build failed'}
 & (Join-Path $repo 'build-diagnostics/simulator-tests/test_camera_export.exe') (Join-Path $repo 'tests/fixtures/osm_terrain.json') $BuildDirectory
 if($LASTEXITCODE -ne 0){throw 'Camera export test failed'}
}
