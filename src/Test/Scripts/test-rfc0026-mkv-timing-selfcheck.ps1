#Requires -Version 5.1
<#
.SYNOPSIS
  Launch splayer against an MKV sample and validate Matroska video packet timing logs.
#>
[CmdletBinding()]
param(
  [string]$SamplePath = '',
  [int]$TimeoutSeconds = 45,
  [int]$MinimumTimingPackets = 20,
  [int64]$MinimumFrameDuration = 10000,
  [int64]$MaximumFrameDuration = 2000000,
  [int]$SteadyStateSeconds = 5,
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
$decodeFailureNeedle = 'Modern FFmpeg bridge decode failed'
$timingPattern = 'MKV timing track=(?<track>\d+) start=(?<start>-?\d+) stop=(?<stop>-?\d+) duration=(?<duration>-?\d+) blockDurationValid=(?<blockDurationValid>\d+) lacingCount=(?<lacingCount>\d+) keyframe=(?<keyframe>\d+)'

function Get-MatroskaTimingRecords {
  $matches = [regex]::Matches((Get-SplayerLogText), $timingPattern)
  $records = New-Object System.Collections.Generic.List[object]
  foreach ($match in $matches) {
    $records.Add([pscustomobject]@{
      Track = [int]$match.Groups['track'].Value
      Start = [int64]$match.Groups['start'].Value
      Stop = [int64]$match.Groups['stop'].Value
      Duration = [int64]$match.Groups['duration'].Value
      BlockDurationValid = [int]$match.Groups['blockDurationValid'].Value
      LacingCount = [int]$match.Groups['lacingCount'].Value
      Keyframe = [int]$match.Groups['keyframe'].Value
    })
  }
  return $records
}

function Wait-MatroskaTimingRecordCount {
  param(
    [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
    [Parameter(Mandatory = $true)][int]$MinimumCount,
    [Parameter(Mandatory = $true)][datetime]$Deadline
  )

  while ((Get-Date) -lt $Deadline) {
    Start-Sleep -Milliseconds 250
    if ($Process.HasExited) {
      throw "splayer exited early with code $($Process.ExitCode)"
    }

    $logText = Get-SplayerLogText
    if ($logText -match [regex]::Escape($decodeFailureNeedle)) {
      throw "splayer modern FFmpeg decode failed; inspect $(Get-SplayerLogPath)"
    }

    if ((Get-MatroskaTimingRecords).Count -ge $MinimumCount) {
      return
    }
  }

  throw "Timed out waiting for $MinimumCount MKV timing records; inspect $(Get-SplayerLogPath)"
}

function Assert-MatroskaTimingRecords {
  param([Parameter(Mandatory = $true)][object[]]$Records)

  if ($Records.Count -lt $MinimumTimingPackets) {
    throw "Expected at least $MinimumTimingPackets MKV timing records, found $($Records.Count)"
  }

  for ($index = 0; $index -lt $Records.Count; $index++) {
    $record = $Records[$index]
    if ($record.Stop -le $record.Start) {
      throw "MKV timing record ${index} has non-positive interval: start=$($record.Start) stop=$($record.Stop)"
    }
    if ($record.Duration -ne ($record.Stop - $record.Start)) {
      throw "MKV timing record ${index} duration mismatch: duration=$($record.Duration) start=$($record.Start) stop=$($record.Stop)"
    }
    if ($record.Duration -lt $MinimumFrameDuration) {
      throw "MKV timing record ${index} duration is too small: $($record.Duration). This may be a 100ns fallback regression."
    }
    if ($record.Duration -gt $MaximumFrameDuration) {
      throw "MKV timing record ${index} duration is too large: $($record.Duration)"
    }
    if ($record.LacingCount -lt 1) {
      throw "MKV timing record ${index} has invalid lacing count: $($record.LacingCount)"
    }
  }
}

if ($MinimumTimingPackets -lt 1) {
  throw 'MinimumTimingPackets must be at least 1.'
}
if ($MinimumFrameDuration -lt 1) {
  throw 'MinimumFrameDuration must be positive.'
}
if ($MaximumFrameDuration -lt $MinimumFrameDuration) {
  throw 'MaximumFrameDuration must be greater than or equal to MinimumFrameDuration.'
}

Stop-SplayerProcesses
Clear-SplayerLog
$process = Start-SplayerForSample -SamplePath $SamplePath
try {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  Wait-MatroskaTimingRecordCount -Process $process -MinimumCount $MinimumTimingPackets -Deadline $deadline
  $logText = Get-SplayerLogText
  if ($logText -notmatch [regex]::Escape($firstFrameNeedle)) {
    Write-Host "Warning: MKV timing records were available before the modern FFmpeg first-frame marker." -ForegroundColor Yellow
  }

  $records = @(Get-MatroskaTimingRecords | Select-Object -First $MinimumTimingPackets)
  Assert-MatroskaTimingRecords -Records $records

  Assert-SplayerResponsive `
    -Process $process `
    -Deadline (Get-Date).AddSeconds($SteadyStateSeconds) `
    -AllowedUnresponsiveSeconds $AllowedUnresponsiveSeconds `
    -CheckWindowResponding:$CheckWindowResponding `
    -FailureMessage 'splayer UI stopped responding during MKV timing selfcheck'

  Write-Host 'test-rfc0026-mkv-timing-selfcheck: OK' -ForegroundColor Green
} finally {
  Get-Process -Id $process.Id -ErrorAction SilentlyContinue | Stop-Process -Force
}
