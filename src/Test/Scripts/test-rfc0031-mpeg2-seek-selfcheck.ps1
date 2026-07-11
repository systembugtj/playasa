#Requires -Version 5.1
<#
.SYNOPSIS
  Launch splayer against an MPEG-2 sample, trigger player seeks, and verify modern MPEG-2 reset stays stable.
#>
[CmdletBinding()]
param(
  [string]$SamplePath = '',
  [int]$TimeoutSeconds = 45,
  [int]$SeekCount = 3,
  [int]$BetweenSeekMilliseconds = 750,
  [int]$PostSeekSeconds = 8,
  [int]$AllowedUnresponsiveSeconds = 5,
  [switch]$CheckWindowResponding
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'TestSupport\SplayerTestSupport.psm1') -Force

$repoRoot = Get-SplayerRepoRoot
if ([string]::IsNullOrWhiteSpace($SamplePath)) {
  $SamplePath = Join-Path $repoRoot 'out\selfcheck\sample-mpeg2-dxva.mpg'
}

$firstFrameNeedle = 'MPEG-2 modern FFmpeg first frame ready'
$decodeFailureNeedle = 'MPEG-2 modern FFmpeg failed'
$seekBeginNeedle = 'SeekTo begin'
$seekEndNeedle = 'SeekTo end'
$modernResetNeedle = 'MPEG-2 modern FFmpeg reset on segment'

function Get-SeekLogPositions {
  param([Parameter(Mandatory = $true)][string]$Pattern)

  $seekMatches = [regex]::Matches((Get-SplayerLogText), $Pattern)
  $positions = New-Object System.Collections.Generic.List[Int64]
  foreach ($match in $seekMatches) {
    $positions.Add([Int64]$match.Groups['pos'].Value)
  }
  return $positions
}

function Assert-SeekBeginEndAlignment {
  param(
    [Parameter(Mandatory = $true)][Int64[]]$BeginPositions,
    [Parameter(Mandatory = $true)][Int64[]]$EndPositions,
    [Parameter(Mandatory = $true)][int]$ExpectedCount
  )

  if ($BeginPositions.Count -lt $ExpectedCount) {
    throw "Expected at least $ExpectedCount SeekTo begin logs, found $($BeginPositions.Count)"
  }
  if ($EndPositions.Count -lt $ExpectedCount) {
    throw "Expected at least $ExpectedCount SeekTo end logs, found $($EndPositions.Count)"
  }
  for ($index = 0; $index -lt $ExpectedCount; $index++) {
    if ($BeginPositions[$index] -ne $EndPositions[$index]) {
      throw "SeekTo begin/end target mismatch at index ${index}: begin=$($BeginPositions[$index]) end=$($EndPositions[$index])"
    }
  }
}

if ($SeekCount -lt 1) {
  throw 'SeekCount must be at least 1.'
}

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
    -TimeoutMessage "Timed out waiting for MPEG-2 modern first frame before seek; inspect $(Get-SplayerLogPath)"

  $windowHandle = Wait-SplayerMainWindowHandle -Process $process -Deadline $deadline
  $automationRoot = Get-SplayerAutomationRoot -WindowHandle $windowHandle
  $seekBar = Assert-SplayerSeekBarAutomation -Root $automationRoot -ProcessId $process.Id
  $rangeValuePattern = $null
  if (-not $seekBar.TryGetCurrentPattern([System.Windows.Automation.RangeValuePattern]::Pattern, [ref]$rangeValuePattern)) {
    throw 'UIA seek bar does not expose RangeValuePattern.'
  }

  for ($seekIndex = 1; $seekIndex -le $SeekCount; $seekIndex++) {
    $minimum = $rangeValuePattern.Current.Minimum
    $maximum = $rangeValuePattern.Current.Maximum
    if ($maximum -le $minimum) {
      throw "Seek bar range is invalid: min=$minimum max=$maximum"
    }
    $targetRatio = [Math]::Min(0.85, 0.25 + (0.15 * $seekIndex))
    $targetValue = $minimum + (($maximum - $minimum) * $targetRatio)
    $rangeValuePattern.SetValue($targetValue)

    $seekDeadline = (Get-Date).AddSeconds($TimeoutSeconds)
    Wait-SplayerLogMatchCount -Process $process -Needle $seekBeginNeedle -MinimumCount $seekIndex -Deadline $seekDeadline -FailureNeedles @($decodeFailureNeedle) -TimeoutMessage "Timed out waiting for SeekTo begin #$seekIndex; inspect $(Get-SplayerLogPath)"
    Wait-SplayerLogMatchCount -Process $process -Needle $seekEndNeedle -MinimumCount $seekIndex -Deadline $seekDeadline -FailureNeedles @($decodeFailureNeedle) -TimeoutMessage "Timed out waiting for SeekTo end #$seekIndex; inspect $(Get-SplayerLogPath)"
    Wait-SplayerLogMatchCount -Process $process -Needle $modernResetNeedle -MinimumCount $seekIndex -Deadline $seekDeadline -FailureNeedles @($decodeFailureNeedle) -TimeoutMessage "Timed out waiting for MPEG-2 modern reset #$seekIndex after seek; inspect $(Get-SplayerLogPath)"

    if ($seekIndex -lt $SeekCount -and $BetweenSeekMilliseconds -gt 0) {
      Start-Sleep -Milliseconds $BetweenSeekMilliseconds
    }
  }

  $beginPositions = Get-SeekLogPositions -Pattern 'SeekTo begin pos=(?<pos>-?\d+) key=\d+'
  $endPositions = Get-SeekLogPositions -Pattern 'SeekTo end hr=[0-9a-fA-F]+ pos=(?<pos>-?\d+)'
  Assert-SeekBeginEndAlignment -BeginPositions $beginPositions -EndPositions $endPositions -ExpectedCount $SeekCount

  Assert-SplayerResponsive `
    -Process $process `
    -Deadline (Get-Date).AddSeconds($PostSeekSeconds) `
    -AllowedUnresponsiveSeconds $AllowedUnresponsiveSeconds `
    -CheckWindowResponding:$CheckWindowResponding `
    -FailureMessage 'splayer UI stopped responding after MPEG-2 seek'

  Write-Host 'test-rfc0031-mpeg2-seek-selfcheck: OK' -ForegroundColor Green
} finally {
  Get-Process -Id $process.Id -ErrorAction SilentlyContinue | Stop-Process -Force
}
