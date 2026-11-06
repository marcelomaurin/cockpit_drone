[CmdletBinding()]
param(
    [string]$Compiler = 'fpc',
    [string]$Python = 'python',
    [string]$BuildDirectory = '',
    [switch]$MavlinkIntegration
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (-not $BuildDirectory) { $BuildDirectory = Join-Path $repo 'build-diagnostics\local-tests' }
$BuildDirectory = [IO.Path]::GetFullPath($BuildDirectory)
$units = Join-Path $BuildDirectory 'units'
New-Item -ItemType Directory -Path $units -Force | Out-Null
$extension = if ([Environment]::OSVersion.Platform -eq 'Win32NT') { '.exe' } else { '' }
$previousBridge = $env:COCKPIT_BRIDGE_TEST_EXE
$previousBytecode = $env:PYTHONDONTWRITEBYTECODE
$results = @()
function Run-Checked([string]$Label, [string]$Executable, [string[]]$Arguments) {
    $log = Join-Path $BuildDirectory ($Label + '.log')
    & $Executable @Arguments *> $log
    if ($LASTEXITCODE -ne 0) {
        Get-Content -LiteralPath $log -Tail 30
        throw "$Label failed (exit $LASTEXITCODE); see $log"
    }
    Write-Output "PASS $Label"
}
Push-Location $repo
try {
    $env:PYTHONDONTWRITEBYTECODE = '1'
    $tests = @('test_sitl_telemetry_state','test_sitl_telemetry_bridge',
        'test_mavlink_validation','test_input_mapping','test_flightplan_validation',
        'test_runtime_paths','test_sitl_bridge_loopback')
    foreach ($name in $tests) {
        Run-Checked ($name + '-build') $Compiler @('-Cr','-Co','-Ci','-gl',
            ('-Fu' + (Join-Path $repo 'src')), ('-FU' + $units),
            ('-FE' + $BuildDirectory), (Join-Path $repo ('tests\' + $name + '.pas')))
        if ($name -ne 'test_sitl_bridge_loopback') {
            Run-Checked $name (Join-Path $BuildDirectory ($name + $extension)) @()
            $results += @{ test=$name; result='passed' }
        }
    }
    if ($MavlinkIntegration) {
        Run-Checked 'pymavlink-import' $Python @('-c','from pymavlink import mavutil; print(mavutil.__file__)')
        $env:COCKPIT_BRIDGE_TEST_EXE = Join-Path $BuildDirectory ('test_sitl_bridge_loopback' + $extension)
    } else {
        Remove-Item Env:COCKPIT_BRIDGE_TEST_EXE -ErrorAction SilentlyContinue
    }
    Run-Checked 'python-tests' $Python @('-m','unittest','discover','-s','tests','-p','test_*.py','-v')
    $results += @{ test='python'; result='passed'; mavlink_integration=[bool]$MavlinkIntegration }
    $results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $BuildDirectory 'results.json') -Encoding utf8
} finally {
    $env:COCKPIT_BRIDGE_TEST_EXE = $previousBridge
    $env:PYTHONDONTWRITEBYTECODE = $previousBytecode
    Pop-Location
}
