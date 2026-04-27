#Requires -Version 5.1
<#
.SYNOPSIS
  Launch splayer against an MKV sample, trigger a real player seek, and verify the seek/flush path stays responsive.
#>
[CmdletBinding()]
param(
  [string]$SamplePath = '',
  [int]$TimeoutSeconds = 45,
  [int]$PostSeekSeconds = 10,
  [int]$AllowedUnresponsiveSeconds = 5,
  [switch]$RequireUiAutomation,
  [switch]$CheckWindowResponding
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'TestSupport\SplayerTestSupport.psm1') -Force

$repoRoot = Get-SplayerRepoRoot
if ([string]::IsNullOrWhiteSpace($SamplePath)) {
  $SamplePath = Join-Path $repoRoot 'out\selfcheck\genius_party_sample.mkv'
}

$firstFrameNeedle = 'Modern FFmpeg bridge first frame ready'
$decodeFailureNeedle = 'Modern FFmpeg bridge decode failed'
$seekBeginNeedle = 'SeekTo begin'
$seekEndNeedle = 'SeekTo end'
$flushNeedle = 'Modern FFmpeg bridge flush on segment'
$idPlaySeekForwardSmall = 1010

Stop-SplayerProcesses
Clear-SplayerLog
$process = Start-SplayerForSample -SamplePath $SamplePath
try {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  Wait-SplayerLogNeedle `
    -Process $process `
    -Needle $firstFrameNeedle `
    -Deadline $deadline `
    -FailureNeedles @($decodeFailureNeedle) `
    -TimeoutMessage "Timed out waiting for first frame before seek; inspect $(Get-SplayerLogPath)"

  $windowHandle = Wait-SplayerMainWindowHandle -Process $process -Deadline $deadline
  if ($RequireUiAutomation) {
    $automationRoot = Get-SplayerAutomationRoot -WindowHandle $windowHandle
    Assert-SplayerSeekBarAutomation -Root $automationRoot | Out-Null
  }

  Send-SplayerCommand -WindowHandle $windowHandle -CommandId $idPlaySeekForwardSmall

  $seekDeadline = (Get-Date).AddSeconds($TimeoutSeconds)
  Wait-SplayerLogNeedle -Process $process -Needle $seekBeginNeedle -Deadline $seekDeadline -FailureNeedles @($decodeFailureNeedle) -TimeoutMessage "Timed out waiting for SeekTo begin; inspect $(Get-SplayerLogPath)"
  Wait-SplayerLogNeedle -Process $process -Needle $seekEndNeedle -Deadline $seekDeadline -FailureNeedles @($decodeFailureNeedle) -TimeoutMessage "Timed out waiting for SeekTo end; inspect $(Get-SplayerLogPath)"
  Wait-SplayerLogNeedle -Process $process -Needle $flushNeedle -Deadline $seekDeadline -FailureNeedles @($decodeFailureNeedle) -TimeoutMessage "Timed out waiting for modern FFmpeg flush after seek; inspect $(Get-SplayerLogPath)"

  Assert-SplayerResponsive `
    -Process $process `
    -Deadline (Get-Date).AddSeconds($PostSeekSeconds) `
    -AllowedUnresponsiveSeconds $AllowedUnresponsiveSeconds `
    -CheckWindowResponding:$CheckWindowResponding `
    -FailureMessage 'splayer UI stopped responding after seek'

  Write-Host 'test-rfc0027-mkv-seek-selfcheck: OK' -ForegroundColor Green
} finally {
  Get-Process -Id $process.Id -ErrorAction SilentlyContinue | Stop-Process -Force
}
