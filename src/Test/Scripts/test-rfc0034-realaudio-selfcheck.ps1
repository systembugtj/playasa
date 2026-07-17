#Requires -Version 5.1
<#
.SYNOPSIS
  Verify RMVB RealAudio playback uses the modern FFmpeg bridge (cook/sipr/atrac3).
#>
[CmdletBinding()]
param(
  [string]$SamplePath = '',
  [int]$TimeoutSeconds = 180,
  [int]$InitialPlaybackSeconds = 2,
  [int]$AllowedUnresponsiveSeconds = 5,
  [switch]$CheckWindowResponding
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'TestSupport\SplayerTestSupport.psm1') -Force

$repoRoot = Get-SplayerRepoRoot
$defaultSamplePath = Join-Path $repoRoot 'out\selfcheck\sample-rmvb-rv40-test.rmvb'
$sourceFilterNeedle = 'CRealMediaSourceFilter'
$realAudioOpenNeedle = 'RealAudio modern FFmpeg bridge open OK'
$realAudioPcmNeedle = 'RealAudio modern FFmpeg bridge first PCM frame'

if ([string]::IsNullOrWhiteSpace($SamplePath)) {
  $SamplePath = $defaultSamplePath
}

if (-not (Test-Path -LiteralPath $SamplePath)) {
  throw "RMVB sample not found: $SamplePath. Run src/Test/Scripts/setup-rmvb-samples.ps1 first."
}

Stop-SplayerProcesses
Clear-SplayerLog
$process = Start-SplayerForSample -SamplePath $SamplePath
try {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

  Wait-SplayerLogNeedle `
    -Process $process `
    -Needle $sourceFilterNeedle `
    -Deadline $deadline `
    -TimeoutMessage "Timed out waiting for RealMedia source filter; inspect $(Get-SplayerLogPath)"

  Wait-SplayerLogNeedle `
    -Process $process `
    -Needle $realAudioOpenNeedle `
    -Deadline $deadline `
    -TimeoutMessage "Timed out waiting for RealAudio modern bridge open; inspect $(Get-SplayerLogPath)"

  Wait-SplayerLogNeedle `
    -Process $process `
    -Needle $realAudioPcmNeedle `
    -Deadline $deadline `
    -TimeoutMessage "Timed out waiting for RealAudio PCM output; inspect $(Get-SplayerLogPath)"

  if ($InitialPlaybackSeconds -gt 0) {
    Assert-SplayerResponsive `
      -Process $process `
      -Deadline (Get-Date).AddSeconds($InitialPlaybackSeconds) `
      -AllowedUnresponsiveSeconds $AllowedUnresponsiveSeconds `
      -CheckWindowResponding:$CheckWindowResponding `
      -FailureMessage 'splayer UI stopped responding during RealAudio playback'
  }

  if ($process.HasExited) {
    throw "splayer exited during RealAudio selfcheck with code $($process.ExitCode)"
  }

  Write-Host 'test-rfc0034-realaudio-selfcheck: PASS'
}
finally {
  Stop-SplayerProcesses -Process $process
}
