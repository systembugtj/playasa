#Requires -Version 5.1
<#
.SYNOPSIS
  Launch splayer against an MKV sample, trigger a real player seek, and verify the seek/flush path stays responsive.
#>
[CmdletBinding()]
param(
  [string]$SamplePath = '',
  [int]$TimeoutSeconds = 45,
  [int]$SeekCount = 3,
  [int]$BetweenSeekMilliseconds = 750,
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
$flushNeedle = 'Modern FFmpeg bridge flush on segment|segment: start=|tart=\d+ stop='
$idPlaySeekForwardSmall = 1010

function Get-SeekLogPositions {
  param([Parameter(Mandatory = $true)][string]$Pattern)

  $matches = [regex]::Matches((Get-SplayerLogText), $Pattern)
  $positions = New-Object System.Collections.Generic.List[Int64]
  foreach ($match in $matches) {
    $positions.Add([Int64]$match.Groups['pos'].Value)
  }
  return $positions
}

function Assert-NondecreasingPositions {
  param(
    [Parameter(Mandatory = $true)][Int64[]]$Positions,
    [Parameter(Mandatory = $true)][string]$Description
  )

  for ($index = 1; $index -lt $Positions.Count; $index++) {
    if ($Positions[$index] -lt $Positions[$index - 1]) {
      throw "$Description moved backwards at index ${index}: $($Positions[$index - 1]) -> $($Positions[$index])"
    }
  }
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

function Assert-SeekTargetMatchesBegin {
  param(
    [Parameter(Mandatory = $true)][Int64[]]$TargetPositions,
    [Parameter(Mandatory = $true)][Int64[]]$BeginPositions,
    [Parameter(Mandatory = $true)][int]$ExpectedCount,
    [Int64]$Tolerance = 1000000
  )

  for ($index = 0; $index -lt $ExpectedCount; $index++) {
    $delta = [Math]::Abs($BeginPositions[$index] - $TargetPositions[$index])
    if ($delta -gt $Tolerance) {
      throw "UIA seek target mismatch at index ${index}: target=$($TargetPositions[$index]) begin=$($BeginPositions[$index]) delta=$delta"
    }
  }
}

if ($SeekCount -lt 1) {
  throw 'SeekCount must be at least 1.'
}

$UseUiaSeek = $env:PLAYASA_TEST_UIA_SEEK -eq '1'
if ($UseUiaSeek) {
  $RequireUiAutomation = $true
}

$uiaSeekRatios = @(0.25, 0.50, 0.75)
if ($UseUiaSeek -and $uiaSeekRatios.Count -lt $SeekCount) {
  throw "Default UIA seek ratios must contain at least $SeekCount entries."
}

Stop-SplayerProcesses
Clear-SplayerLog
$process = Start-SplayerForSample -SamplePath $SamplePath
try {
  $startupDeadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $windowHandle = $null
  $automationRoot = $null
  $seekBar = $null
  $minimum = 0
  $maximum = 0

  if ($RequireUiAutomation -or $UseUiaSeek) {
    $harness = Wait-SplayerUiaPlaybackReady `
      -Process $process `
      -Deadline $startupDeadline `
      -TimeoutMessage "Timed out waiting for playback/UIA readiness before seek; inspect $(Get-SplayerLogPath)" `
      -RequireSeekBar
    $windowHandle = $harness.WindowHandle
    $automationRoot = $harness.AutomationRoot
    $seekBar = $harness.SeekBar
  } else {
    Wait-SplayerLogNeedle `
      -Process $process `
      -Needle $firstFrameNeedle `
      -Deadline $startupDeadline `
      -FailureNeedles @($decodeFailureNeedle) `
      -TimeoutMessage "Timed out waiting for first frame before seek; inspect $(Get-SplayerLogPath)"

    $windowHandle = Wait-SplayerMainWindowHandle -Process $process -Deadline $startupDeadline
    Start-Sleep -Milliseconds 500
  }

  if ($UseUiaSeek) {
    $rangeReady = Wait-SplayerSeekBarRangeReady `
      -Root $automationRoot `
      -ProcessId $process.Id `
      -SeekBar $seekBar `
      -Deadline (Get-Date).AddSeconds(30)
    $seekBar = $rangeReady.SeekBar
    $minimum = $rangeReady.Minimum
    $maximum = $rangeReady.Maximum
    Start-Sleep -Milliseconds 200
  }

  $targetPositions = $null
  if ($UseUiaSeek) {
    $targetPositions = New-Object System.Collections.Generic.List[Int64]
  }

  for ($seekIndex = 1; $seekIndex -le $SeekCount; $seekIndex++) {
    if ($UseUiaSeek) {
      $ratio = $uiaSeekRatios[$seekIndex - 1]
      if ($ratio -le 0 -or $ratio -ge 1) {
        throw "Seek ratio must be inside (0, 1): $ratio"
      }

      $targetValue = $minimum + (($maximum - $minimum) * $ratio)
      $targetPositions.Add([Int64][Math]::Round($targetValue))
      Invoke-SplayerUiaSeek `
        -WindowHandle $windowHandle `
        -Root $automationRoot `
        -ProcessId $process.Id `
        -SeekBar $seekBar `
        -TargetValue $targetValue
    } else {
      Send-SplayerCommand -WindowHandle $windowHandle -CommandId $idPlaySeekForwardSmall
    }

    $seekDeadline = (Get-Date).AddSeconds($TimeoutSeconds)
    Wait-SplayerLogMatchCount -Process $process -Needle $seekBeginNeedle -MinimumCount $seekIndex -Deadline $seekDeadline -FailureNeedles @($decodeFailureNeedle) -TimeoutMessage "Timed out waiting for SeekTo begin #$seekIndex; inspect $(Get-SplayerLogPath)"
    Wait-SplayerLogMatchCount -Process $process -Needle $seekEndNeedle -MinimumCount $seekIndex -Deadline $seekDeadline -FailureNeedles @($decodeFailureNeedle) -TimeoutMessage "Timed out waiting for SeekTo end #$seekIndex; inspect $(Get-SplayerLogPath)"
    Wait-SplayerLogMatchCount -Process $process -Needle $flushNeedle -MinimumCount $seekIndex -Deadline $seekDeadline -FailureNeedles @($decodeFailureNeedle) -PatternIsRegex -TimeoutMessage "Timed out waiting for modern FFmpeg flush #$seekIndex after seek; inspect $(Get-SplayerLogPath)"

    if ($seekIndex -lt $SeekCount -and $BetweenSeekMilliseconds -gt 0) {
      Start-Sleep -Milliseconds $BetweenSeekMilliseconds
    }
  }

  $beginPositions = Get-SeekLogPositions -Pattern 'SeekTo begin pos=(?<pos>-?\d+) key=\d+'
  $endPositions = Get-SeekLogPositions -Pattern 'SeekTo end hr=[0-9a-fA-F]+ pos=(?<pos>-?\d+)'
  Assert-SeekBeginEndAlignment -BeginPositions $beginPositions -EndPositions $endPositions -ExpectedCount $SeekCount
  if ($UseUiaSeek) {
    Assert-SeekTargetMatchesBegin -TargetPositions $targetPositions.ToArray() -BeginPositions $beginPositions -ExpectedCount $SeekCount
  }
  Assert-NondecreasingPositions -Positions $beginPositions -Description 'SeekTo begin positions'
  Assert-NondecreasingPositions -Positions $endPositions -Description 'SeekTo end positions'

  Assert-SplayerResponsive `
    -Process $process `
    -Deadline (Get-Date).AddSeconds($PostSeekSeconds) `
    -AllowedUnresponsiveSeconds $AllowedUnresponsiveSeconds `
    -CheckWindowResponding:$CheckWindowResponding `
    -FailureMessage 'splayer UI stopped responding after seek'

  Write-Host $(if ($UseUiaSeek) { 'test-rfc0028-mkv-seek-uia-selfcheck: OK' } else { 'test-rfc0027-mkv-seek-selfcheck: OK' }) -ForegroundColor Green
} finally {
  Get-Process -Id $process.Id -ErrorAction SilentlyContinue | Stop-Process -Force
}
