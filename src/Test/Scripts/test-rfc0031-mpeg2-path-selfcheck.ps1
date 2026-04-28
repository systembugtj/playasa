#Requires -Version 5.1
<#
.SYNOPSIS
  Classify MPEG/MPEG-2 playback graph paths for RFC-0031.
#>
[CmdletBinding()]
param(
  [string[]]$SamplePaths = @(),
  [int]$TimeoutSeconds = 30,
  [int]$SteadyStateSeconds = 2,
  [int]$AllowedUnresponsiveSeconds = 5,
  [switch]$CheckWindowResponding,
  [switch]$RequireKnownPath,
  [switch]$EnableModernMpeg2,
  [switch]$RequireModernMpeg2FirstFrame,
  [switch]$RequireNoModernMpeg2Fallback
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'TestSupport\SplayerTestSupport.psm1') -Force

$repoRoot = Get-SplayerRepoRoot
$previousLegacyMpeg2 = $env:PLAYASA_MPEG2_LEGACY
$defaultSamplePaths = @(
  'out\selfcheck\sample-mpeg2-dxva.m2ts',
  'out\selfcheck\sample-mpeg2-dxva.ts',
  'out\selfcheck\sample-mpeg2-dxva.m2v',
  'out\selfcheck\sample-mpeg2-dxva.vob',
  'out\selfcheck\sample-mpeg2-dxva.mpg',
  'out\selfcheck\sample-mpeg-small.mpeg'
)

$decoderPatterns = @(
  @{
    Name = 'MPCVideoDec'
    Pattern = 'DXVA selection:|MPC Video Decoder|MPC Video Decoder DXVA'
  },
  @{
    Name = 'CMpeg2DecFilter'
    Pattern = "MPEG-2 Video Decoder' \{39F498AF-1A09-4275-B193-673B0BA3D478\}"
  },
  @{
    Name = 'SystemMpegVideoDecoder'
    Pattern = "MPEG Video Decoder' \{FEB50740-7BEF-11CE-9BD9-0000E202599C\}"
  }
)

function Resolve-Rfc0031SamplePaths {
  param([string[]]$Paths)

  $selectedPaths = if ($Paths.Count -gt 0) { $Paths } else { $defaultSamplePaths }
  return @($selectedPaths |
    ForEach-Object { $_ -split ',' } |
    ForEach-Object { $_.Trim().Trim('"') } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object {
      if ([System.IO.Path]::IsPathRooted($_)) {
        $_
      } else {
        Join-Path $repoRoot $_
      }
    } |
    Where-Object { Test-Path -LiteralPath $_ })
}

function Get-Rfc0031GraphLines {
  param([Parameter(Mandatory = $true)][string]$LogText)

  return @($LogText -split "`r?`n" |
    Where-Object { $_ -match 'FGM: AddSourceFilter|FGM: Connecting|DXVA selection:|DXVA connect:|MPEG-2 modern FFmpeg' })
}

function Get-Rfc0031DecoderName {
  param([Parameter(Mandatory = $true)][string[]]$GraphLines)

  $joinedLines = $GraphLines -join "`n"
  foreach ($decoderPattern in $decoderPatterns) {
    if ($joinedLines -match $decoderPattern.Pattern) {
      return $decoderPattern.Name
    }
  }

  return 'Unknown'
}

function Invoke-Rfc0031SampleRun {
  param([Parameter(Mandatory = $true)][string]$SamplePath)

  Stop-SplayerProcesses
  Clear-SplayerLog
  if ($EnableModernMpeg2) {
    Remove-Item Env:\PLAYASA_MPEG2_LEGACY -ErrorAction SilentlyContinue
  }
  $process = Start-SplayerForSample -SamplePath $SamplePath
  try {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    Wait-SplayerLogNeedle `
      -Process $process `
      -Needle 'FGM: Connecting' `
      -Deadline $deadline `
      -TimeoutMessage "Timed out waiting for graph connection logs; inspect $(Get-SplayerLogPath)"

    Assert-SplayerResponsive `
      -Process $process `
      -Deadline (Get-Date).AddSeconds($SteadyStateSeconds) `
      -AllowedUnresponsiveSeconds $AllowedUnresponsiveSeconds `
      -CheckWindowResponding:$CheckWindowResponding `
      -FailureMessage 'splayer UI stopped responding during RFC-0031 MPEG-2 path selfcheck'

    $logText = Get-SplayerLogText
    $graphLines = Get-Rfc0031GraphLines -LogText $logText
    $decoderName = Get-Rfc0031DecoderName -GraphLines $graphLines
    $modernFirstFrame = $logText -match 'MPEG-2 modern FFmpeg first frame ready'
    $modernFallback = $logText -match 'MPEG-2 modern FFmpeg fallback'
    $modernFailure = $logText -match 'MPEG-2 modern FFmpeg failed without legacy fallback'
    if ($decoderName -eq 'Unknown' -and $modernFirstFrame) {
      $decoderName = 'CMpeg2DecFilter'
    }

    [PSCustomObject]@{
      Sample = $SamplePath
      Decoder = $decoderName
      ModernFirstFrame = $modernFirstFrame
      ModernFallback = $modernFallback
      ModernFailure = $modernFailure
      GraphLines = $graphLines
    }
  } finally {
    Get-Process -Id $process.Id -ErrorAction SilentlyContinue | Stop-Process -Force
    if ($EnableModernMpeg2) {
      if ($null -eq $previousLegacyMpeg2) {
        Remove-Item Env:\PLAYASA_MPEG2_LEGACY -ErrorAction SilentlyContinue
      } else {
        $env:PLAYASA_MPEG2_LEGACY = $previousLegacyMpeg2
      }
    }
  }
}

$resolvedSamplePaths = Resolve-Rfc0031SamplePaths -Paths $SamplePaths
if ($resolvedSamplePaths.Count -eq 0) {
  throw 'No RFC-0031 MPEG/MPEG-2 samples were found.'
}

$results = @($resolvedSamplePaths | ForEach-Object { Invoke-Rfc0031SampleRun -SamplePath $_ })
$unknownResults = @($results | Where-Object { $_.Decoder -eq 'Unknown' })

foreach ($result in $results) {
  $sampleItem = Get-Item -LiteralPath $result.Sample
  Write-Host "RFC-0031 sample: $($sampleItem.FullName) size=$($sampleItem.Length)"
  Write-Host "RFC-0031 decoder: $($result.Decoder)"
  Write-Host "RFC-0031 modern first frame: $($result.ModernFirstFrame)"
  Write-Host "RFC-0031 modern fallback: $($result.ModernFallback)"
  Write-Host "RFC-0031 modern failure: $($result.ModernFailure)"
  $result.GraphLines | Select-Object -Last 12 | ForEach-Object { Write-Host $_ }
}

if ($RequireKnownPath -and $unknownResults.Count -gt 0) {
  throw "RFC-0031 path selfcheck found $($unknownResults.Count) unknown decoder path(s). Inspect $(Get-SplayerLogPath)"
}

if ($RequireModernMpeg2FirstFrame -and @($results | Where-Object { -not $_.ModernFirstFrame }).Count -gt 0) {
  throw "RFC-0031 modern MPEG-2 first-frame check failed. Inspect $(Get-SplayerLogPath)"
}

if ($RequireNoModernMpeg2Fallback -and @($results | Where-Object { $_.ModernFallback }).Count -gt 0) {
  throw "RFC-0031 modern MPEG-2 fallback was observed. Inspect $(Get-SplayerLogPath)"
}

if (@($results | Where-Object { $_.ModernFailure }).Count -gt 0) {
  throw "RFC-0031 modern MPEG-2 failure was observed. Inspect $(Get-SplayerLogPath)"
}

Write-Host 'test-rfc0031-mpeg2-path-selfcheck: OK' -ForegroundColor Green
