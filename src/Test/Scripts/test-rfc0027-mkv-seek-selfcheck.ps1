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
$flushNeedle = 'Modern FFmpeg bridge flush on segment'
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
    -TimeoutMessage "Timed out waiting for first frame before seek; inspect $(Get-SplayerLogPath)"

  $windowHandle = Wait-SplayerMainWindowHandle -Process $process -Deadline $deadline
  if ($RequireUiAutomation) {
    $automationRoot = Get-SplayerAutomationRoot -WindowHandle $windowHandle
    Assert-SplayerSeekBarAutomation -Root $automationRoot -ProcessId $process.Id | Out-Null
  }

  for ($seekIndex = 1; $seekIndex -le $SeekCount; $seekIndex++) {
    Send-SplayerCommand -WindowHandle $windowHandle -CommandId $idPlaySeekForwardSmall

    $seekDeadline = (Get-Date).AddSeconds($TimeoutSeconds)
    Wait-SplayerLogMatchCount -Process $process -Needle $seekBeginNeedle -MinimumCount $seekIndex -Deadline $seekDeadline -FailureNeedles @($decodeFailureNeedle) -TimeoutMessage "Timed out waiting for SeekTo begin #$seekIndex; inspect $(Get-SplayerLogPath)"
    Wait-SplayerLogMatchCount -Process $process -Needle $seekEndNeedle -MinimumCount $seekIndex -Deadline $seekDeadline -FailureNeedles @($decodeFailureNeedle) -TimeoutMessage "Timed out waiting for SeekTo end #$seekIndex; inspect $(Get-SplayerLogPath)"
    Wait-SplayerLogMatchCount -Process $process -Needle $flushNeedle -MinimumCount $seekIndex -Deadline $seekDeadline -FailureNeedles @($decodeFailureNeedle) -TimeoutMessage "Timed out waiting for modern FFmpeg flush #$seekIndex after seek; inspect $(Get-SplayerLogPath)"

    if ($seekIndex -lt $SeekCount -and $BetweenSeekMilliseconds -gt 0) {
      Start-Sleep -Milliseconds $BetweenSeekMilliseconds
    }
  }

  $beginPositions = Get-SeekLogPositions -Pattern 'SeekTo begin pos=(?<pos>-?\d+) key=\d+'
  $endPositions = Get-SeekLogPositions -Pattern 'SeekTo end hr=[0-9a-fA-F]+ pos=(?<pos>-?\d+)'
  Assert-SeekBeginEndAlignment -BeginPositions $beginPositions -EndPositions $endPositions -ExpectedCount $SeekCount
  Assert-NondecreasingPositions -Positions $beginPositions -Description 'SeekTo begin positions'
  Assert-NondecreasingPositions -Positions $endPositions -Description 'SeekTo end positions'

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
