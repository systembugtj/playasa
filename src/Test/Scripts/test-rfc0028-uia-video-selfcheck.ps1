#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0028: verify MainWindow UIA tree exposes VideoView and SeekBar.
#>
[CmdletBinding()]
param(
  [string]$SamplePath = '',
  [int]$TimeoutSeconds = 60,
  [switch]$RequireSeekBar,
  [switch]$RequireVideoView
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'TestSupport\SplayerTestSupport.psm1') -Force

$repoRoot = Get-SplayerRepoRoot
if ([string]::IsNullOrWhiteSpace($SamplePath)) {
  $SamplePath = Join-Path $repoRoot 'out\selfcheck\genius_party_sample.mkv'
}

if (-not $RequireSeekBar -and -not $RequireVideoView) {
  $RequireSeekBar = $true
  $RequireVideoView = $true
}

Stop-SplayerProcesses
Clear-SplayerLog
$process = Start-SplayerForSample -SamplePath $SamplePath
try {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $harness = Wait-SplayerUiaPlaybackReady `
    -Process $process `
    -Deadline $deadline `
    -TimeoutMessage "Timed out waiting for first frame before UIA validation; inspect $(Get-SplayerLogPath)" `
    -RequireSeekBar:$RequireSeekBar `
    -RequireVideoView:$RequireVideoView

  if ($RequireSeekBar -and -not $harness.SeekBar) {
    throw 'UIA seek bar was not available after playback became ready.'
  }

  Write-Host 'test-rfc0028-uia-video-selfcheck: OK' -ForegroundColor Green
} finally {
  Get-Process -Id $process.Id -ErrorAction SilentlyContinue | Stop-Process -Force
}
