#Requires -Version 5.1
<#
.SYNOPSIS
  Verify RealAudio remaining modern codecs (AAC / RA144 / RA288) open via the FFmpeg modern bridge.
  Full-file AAC RMVB selfcheck is optional when SamplePath is provided.
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
$bridgeSmoke = Join-Path $repoRoot 'src\Test\Scripts\test-rfc0024-modern-bridge-smoke.ps1'
$cookSelfcheck = Join-Path $repoRoot 'src\Test\Scripts\test-rfc0034-realaudio-selfcheck.ps1'
$sourceFilterNeedle = 'CRealMediaSourceFilter'
$realAudioOpenNeedle = 'RealAudio modern FFmpeg bridge open OK codec='

Write-Host 'test-rfc0045: running cook regression (RFC-0034)...'
try {
  & $cookSelfcheck
}
catch {
  throw "Cook regression failed: $_"
}

Write-Host 'test-rfc0045: running modern bridge smoke (includes AAC/RA144/RA288 open)...'
try {
  & $bridgeSmoke
}
catch {
  throw "Bridge smoke failed: $_"
}

if (-not [string]::IsNullOrWhiteSpace($SamplePath)) {
  if (-not (Test-Path -LiteralPath $SamplePath)) {
    throw "AAC/RA sample not found: $SamplePath"
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
      -TimeoutMessage "Timed out waiting for RealAudio modern open; inspect $(Get-SplayerLogPath)"

    if ($InitialPlaybackSeconds -gt 0) {
      Assert-SplayerResponsive `
        -Process $process `
        -Deadline (Get-Date).AddSeconds($InitialPlaybackSeconds) `
        -AllowedUnresponsiveSeconds $AllowedUnresponsiveSeconds `
        -CheckWindowResponding:$CheckWindowResponding `
        -FailureMessage 'splayer UI stopped responding during RFC-0045 sample playback'
    }
  }
  finally {
    Stop-SplayerProcesses -Process $process
  }
}

Write-Host 'test-rfc0045-realaudio-remaining-selfcheck: PASS'
