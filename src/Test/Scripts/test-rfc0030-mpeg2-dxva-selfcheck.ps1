#Requires -Version 5.1
<#
.SYNOPSIS
  Validate whether an MPEG-2 sample reaches the RFC-0030 MPCVideoDec DXVA path.
#>
[CmdletBinding()]
param(
  [string]$SamplePath = '',
  [int]$TimeoutSeconds = 20,
  [int]$SteadyStateSeconds = 5,
  [int]$AllowedUnresponsiveSeconds = 5,
  [switch]$RequireMpcVideoDecDxva,
  [switch]$CheckWindowResponding
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'TestSupport\SplayerTestSupport.psm1') -Force

$repoRoot = Get-SplayerRepoRoot
if ([string]::IsNullOrWhiteSpace($SamplePath)) {
  $SamplePath = Join-Path $repoRoot 'out\selfcheck\sample-mpeg2-dxva.m2ts'
}

$targetNeedles = @(
  'DXVA selection:',
  'DXVA connect:'
)
$knownNonTargetNeedles = @(
  'MPEG-2 Video Decoder'' {39F498AF-1A09-4275-B193-673B0BA3D478}',
  'MPEG Video Decoder'' {FEB50740-7BEF-11CE-9BD9-0000E202599C}'
)

function Get-Rfc0030GpuSummary {
  $controllers = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
  if (-not $controllers) {
    return 'GPU information unavailable'
  }

  return (($controllers | ForEach-Object {
    "$($_.Name) vendor=$($_.AdapterCompatibility) device=$($_.PNPDeviceID) driver=$($_.DriverVersion)"
  }) -join '; ')
}

function Get-Rfc0030SampleSummary {
  param([Parameter(Mandatory = $true)][string]$Path)

  $item = Get-Item -LiteralPath $Path
  return "$($item.FullName) size=$($item.Length)"
}

Stop-SplayerProcesses
Clear-SplayerLog
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
    -FailureMessage 'splayer UI stopped responding during RFC-0030 MPEG-2 DXVA selfcheck'

  $logText = Get-SplayerLogText
  $targetLines = @($targetNeedles | ForEach-Object {
    $needle = $_
    ($logText -split "`r?`n") | Where-Object { $_ -match [regex]::Escape($needle) }
  })
  $nonTargetLines = @($knownNonTargetNeedles | ForEach-Object {
    $needle = $_
    ($logText -split "`r?`n") | Where-Object { $_ -match [regex]::Escape($needle) }
  })

  Write-Host "RFC-0030 sample: $(Get-Rfc0030SampleSummary -Path $SamplePath)"
  Write-Host "RFC-0030 GPU: $(Get-Rfc0030GpuSummary)"

  if ($targetLines.Count -gt 0) {
    $targetLines | ForEach-Object { Write-Host $_ }
    Write-Host 'test-rfc0030-mpeg2-dxva-selfcheck: MPCVideoDec DXVA path observed' -ForegroundColor Green
    return
  }

  if ($nonTargetLines.Count -gt 0) {
    $nonTargetLines | ForEach-Object { Write-Host $_ }
    $message = 'MPEG-2 sample did not reach MPCVideoDec; graph used a different MPEG-2 decoder.'
    if ($RequireMpcVideoDecDxva) {
      throw "$message Inspect $(Get-SplayerLogPath)"
    }
    Write-Host "test-rfc0030-mpeg2-dxva-selfcheck: SKIP - $message" -ForegroundColor Yellow
    return
  }

  $message = 'MPEG-2 decoder path could not be classified from the graph log.'
  if ($RequireMpcVideoDecDxva) {
    throw "$message Inspect $(Get-SplayerLogPath)"
  }
  Write-Host "test-rfc0030-mpeg2-dxva-selfcheck: SKIP - $message" -ForegroundColor Yellow
} finally {
  Get-Process -Id $process.Id -ErrorAction SilentlyContinue | Stop-Process -Force
}
