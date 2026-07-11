#Requires -Version 5.1
<#
.SYNOPSIS
  Launch splayer against an RMVB sample, trigger player seeks, and verify RealMedia playback stays responsive.
#>
[CmdletBinding()]
param(
  [string]$SamplePath = '',
  [int]$TimeoutSeconds = 45,
  [int]$InitialPlaybackSeconds = 1,
  [int]$PostSeekSeconds = 8,
  [int]$AllowedUnresponsiveSeconds = 5,
  [double[]]$SeekRatios = @(0.25, 0.50),
  [switch]$CheckWindowResponding
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'TestSupport\SplayerTestSupport.psm1') -Force

$repoRoot = Get-SplayerRepoRoot
$defaultSamplePath = Join-Path $repoRoot 'out\selfcheck\sample-rmvb-rv40-test.rmvb'
$sourceFilterNeedle = 'CRealMediaSourceFilter'
$videoDecoderNeedle = 'SVP RealVideo Decoder 2.0'
$modernBridgeNeedle = 'Modern FFmpeg bridge open OK'
$modernFlushNeedle = 'Modern FFmpeg bridge flush on BeginFlush'
$seekForwardMedCommandId = 1012

function Assert-RmvbSeekRatios {
  param([Parameter(Mandatory = $true)][double[]]$Ratios)

  if ($Ratios.Count -lt 1) {
    throw 'SeekRatios must contain at least one target.'
  }

  foreach ($ratio in $Ratios) {
    if ($ratio -le 0 -or $ratio -ge 1) {
      throw "Seek ratio must be inside (0, 1): $ratio"
    }
  }
}

function Assert-RmvbLogNeedle {
  param(
    [Parameter(Mandatory = $true)][string]$LogText,
    [Parameter(Mandatory = $true)][string]$Needle
  )

  if ($LogText -notmatch [regex]::Escape($Needle)) {
    throw "Expected RMVB playback log was not found: $Needle"
  }
}

function Assert-RmvbModernSeekLogCount {
  param(
    [Parameter(Mandatory = $true)][string]$LogText,
    [Parameter(Mandatory = $true)][int]$ExpectedCount
  )

  $modernFlushCount = [regex]::Matches($LogText, [regex]::Escape($modernFlushNeedle)).Count
  if ($modernFlushCount -lt $ExpectedCount) {
    throw "Expected at least $ExpectedCount modern seek flushes, found flush=$modernFlushCount"
  }
}

function Invoke-RmvbSeek {
  param(
    [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
    [Parameter(Mandatory = $true)][IntPtr]$WindowHandle,
    [Parameter(Mandatory = $true)][double]$Ratio,
    [Parameter(Mandatory = $true)][datetime]$Deadline
  )

  if ($Process.HasExited) {
    throw "splayer exited before RMVB seek ratio=$Ratio with code $($Process.ExitCode)"
  }

  if ($WindowHandle -eq [IntPtr]::Zero) {
    throw "Unable to set RMVB seek ratio=$Ratio; missing player window."
  }

  Send-SplayerCommand -WindowHandle $WindowHandle -CommandId $seekForwardMedCommandId
}

if ([string]::IsNullOrWhiteSpace($SamplePath)) {
  $SamplePath = $defaultSamplePath
}

Assert-RmvbSeekRatios -Ratios $SeekRatios
Stop-SplayerProcesses
Clear-SplayerLog
$process = Start-SplayerForSample -SamplePath $SamplePath
try {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $windowHandle = Wait-SplayerMainWindowHandle -Process $process -Deadline $deadline

  Wait-SplayerLogNeedle `
    -Process $process `
    -Needle $sourceFilterNeedle `
    -Deadline $deadline `
    -TimeoutMessage "Timed out waiting for RealMedia source filter; inspect $(Get-SplayerLogPath)"

  Wait-SplayerLogNeedle `
    -Process $process `
    -Needle $videoDecoderNeedle `
    -Deadline $deadline `
    -TimeoutMessage "Timed out waiting for RealVideo decoder; inspect $(Get-SplayerLogPath)"

  Wait-SplayerLogNeedle `
    -Process $process `
    -Needle $modernBridgeNeedle `
    -Deadline $deadline `
    -TimeoutMessage "Timed out waiting for modern RealVideo FFmpeg bridge; inspect $(Get-SplayerLogPath)"

  if ($InitialPlaybackSeconds -gt 0) {
    Assert-SplayerResponsive `
      -Process $process `
      -Deadline (Get-Date).AddSeconds($InitialPlaybackSeconds) `
      -AllowedUnresponsiveSeconds $AllowedUnresponsiveSeconds `
      -CheckWindowResponding:$CheckWindowResponding `
      -FailureMessage 'splayer UI stopped responding before RMVB seek'
  }

  for ($seekIndex = 0; $seekIndex -lt $SeekRatios.Count; $seekIndex++) {
    $ratio = $SeekRatios[$seekIndex]
    Invoke-RmvbSeek `
      -Process $process `
      -WindowHandle $windowHandle `
      -Ratio $ratio `
      -Deadline (Get-Date).AddSeconds($TimeoutSeconds)

    $seekDeadline = (Get-Date).AddSeconds($TimeoutSeconds)
    Wait-SplayerLogMatchCount -Process $process -Needle $modernFlushNeedle -MinimumCount ($seekIndex + 1) -Deadline $seekDeadline -TimeoutMessage "Timed out waiting for modern RMVB decoder flush #$($seekIndex + 1); inspect $(Get-SplayerLogPath)"

    Assert-SplayerResponsive `
      -Process $process `
      -Deadline (Get-Date).AddSeconds($PostSeekSeconds) `
      -AllowedUnresponsiveSeconds $AllowedUnresponsiveSeconds `
      -CheckWindowResponding:$CheckWindowResponding `
      -FailureMessage "splayer UI stopped responding after RMVB seek ratio=$ratio"
  }

  $finalLogText = Get-SplayerLogText
  Assert-RmvbLogNeedle -LogText $finalLogText -Needle $modernBridgeNeedle
  Assert-RmvbModernSeekLogCount -LogText $finalLogText -ExpectedCount $SeekRatios.Count

  Write-Host 'test-rmvb-seek-selfcheck: OK' -ForegroundColor Green
} finally {
  Get-Process -Id $process.Id -ErrorAction SilentlyContinue | Stop-Process -Force
}
