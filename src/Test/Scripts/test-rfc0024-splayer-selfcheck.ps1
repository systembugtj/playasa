#Requires -Version 5.1
<#
.SYNOPSIS
  Launch splayer against a sample and verify that MPCVideoDec delivers a modern FFmpeg frame.
#>
[CmdletBinding()]
param(
  [string]$SamplePath = '',
  [int]$TimeoutSeconds = 30,
  [int]$SteadyStateSeconds = 10,
  [int]$AllowedUnresponsiveSeconds = 5,
  [switch]$CheckWindowResponding
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'TestSupport\SplayerTestSupport.psm1') -Force

$repoRoot = Get-SplayerRepoRoot
if ([string]::IsNullOrWhiteSpace($SamplePath)) {
  $SamplePath = Join-Path $repoRoot 'out\selfcheck\genius_party_sample.mkv'
}
$firstFrameNeedle = 'Modern FFmpeg bridge first frame ready'
$failureNeedle = 'Modern FFmpeg bridge decode failed'
$hangEventStart = Get-Date

Stop-SplayerProcesses
Clear-SplayerLog
$process = Start-SplayerForSample -SamplePath $SamplePath
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
try {
  Wait-SplayerLogNeedle `
    -Process $process `
    -Needle $firstFrameNeedle `
    -Deadline $deadline `
    -FailureNeedles @($failureNeedle) `
    -TimeoutMessage "Timed out waiting for modern FFmpeg first frame; inspect $(Get-SplayerLogPath)"

  Assert-SplayerResponsive `
    -Process $process `
    -Deadline (Get-Date).AddSeconds($SteadyStateSeconds) `
    -AllowedUnresponsiveSeconds $AllowedUnresponsiveSeconds `
    -CheckWindowResponding:$CheckWindowResponding `
    -FailureMessage 'splayer UI stopped responding during steady-state playback'

  $hangEvents = Get-WinEvent -FilterHashtable @{LogName = 'Application'; StartTime = $hangEventStart} -ErrorAction SilentlyContinue |
    Where-Object { $_.ProviderName -in @('Application Hang', 'Windows Error Reporting') -and $_.Message -match 'splayer|AppHang' } |
    Select-Object -First 1
  if ($hangEvents) {
    throw "splayer generated an Application Hang report during playback; inspect Windows Application event log"
  }

  Write-Host 'test-rfc0024-splayer-selfcheck: OK' -ForegroundColor Green
} finally {
  Get-Process -Id $process.Id -ErrorAction SilentlyContinue | Stop-Process -Force
}
