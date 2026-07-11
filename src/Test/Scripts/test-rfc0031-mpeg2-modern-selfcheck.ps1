#Requires -Version 5.1
<#
.SYNOPSIS
  Run the RFC-0031 modern-only MPEG-2 software decode smoke test.
#>
[CmdletBinding()]
param(
  [string[]]$StableSamplePaths = @(),
  [string[]]$ObservationSamplePaths = @(),
  [int]$TimeoutSeconds = 45,
  [int]$SteadyStateSeconds = 3
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$pathSelfcheck = Join-Path $PSScriptRoot 'test-rfc0031-mpeg2-path-selfcheck.ps1'
$defaultStableSamples = @(
  'out\selfcheck\sample-mpeg2-dxva.m2ts',
  'out\selfcheck\sample-mpeg2-dxva.ts',
  'out\selfcheck\sample-mpeg2-dxva.m2v',
  'out\selfcheck\sample-mpeg2-dxva.mpg'
)
$defaultObservationSamples = @(
  'out\selfcheck\sample-mpeg2-dxva.vob',
  'out\selfcheck\sample-mpeg-small.mpeg'
)

function ConvertTo-Rfc0031SampleList {
  param([string[]]$Paths)

  return (($Paths | ForEach-Object {
    if ([System.IO.Path]::IsPathRooted($_)) {
      $_
    } else {
      Join-Path $repoRoot $_
    }
  }) -join ',')
}

if ($StableSamplePaths.Count -eq 0) {
  $StableSamplePaths = $defaultStableSamples
}
if ($ObservationSamplePaths.Count -eq 0) {
  $ObservationSamplePaths = $defaultObservationSamples
}

$stableSampleList = ConvertTo-Rfc0031SampleList -Paths $StableSamplePaths
& $pathSelfcheck `
  -SamplePaths $stableSampleList `
  -EnableModernMpeg2 `
  -RequireKnownPath `
  -RequireModernMpeg2FirstFrame `
  -RequireNoModernMpeg2Fallback `
  -TimeoutSeconds $TimeoutSeconds `
  -SteadyStateSeconds $SteadyStateSeconds

if ($ObservationSamplePaths.Count -gt 0) {
  $observationSampleList = ConvertTo-Rfc0031SampleList -Paths $ObservationSamplePaths
  & $pathSelfcheck `
    -SamplePaths $observationSampleList `
    -EnableModernMpeg2 `
    -RequireKnownPath `
    -RequireNoModernMpeg2Fallback `
    -TimeoutSeconds $TimeoutSeconds `
    -SteadyStateSeconds $SteadyStateSeconds
}

Write-Host 'test-rfc0031-mpeg2-modern-selfcheck: OK' -ForegroundColor Green
