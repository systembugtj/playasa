#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 5b: optional GPU selfcheck for MPCVideoDec DXVA + modern parse skip-open handoff.
  Defaults to observation/SKIP when graph does not reach MPCVideoDec DXVA (no GPU or system decoder wins).
#>
[CmdletBinding()]
param(
  [int]$TimeoutSeconds = 25,
  [int]$SteadyStateSeconds = 3,
  [int]$AllowedUnresponsiveSeconds = 5,
  [switch]$CheckWindowResponding,
  [switch]$RequireDxvaModernParseHandoff
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'TestSupport\SplayerTestSupport.psm1') -Force

$repoRoot = Get-SplayerRepoRoot
$selfcheckRoot = Join-Path $repoRoot 'out\selfcheck'

$sampleMatrix = @(
  @{
    Label = 'H.264'
    RelativePath = 'out\selfcheck\genius_party_sample.mkv'
    DecoderPatterns = @('DXVA selection:', 'MPC Video Decoder')
    SkipOpenNeedle = 'RFC-0047: skip legacy avcodec_open (DXVA modern parse)'
  },
  @{
    Label = 'MPEG-2'
    RelativePath = 'out\selfcheck\sample-mpeg2-dxva.mpg'
    DecoderPatterns = @('DXVA selection:', 'MPC Video Decoder')
    SkipOpenNeedle = 'RFC-0047: skip legacy avcodec_open (DXVA modern parse)'
  },
  @{
    Label = 'WMV3'
    RelativePath = 'out\selfcheck\sample-wmv3-dxva.wmv'
    DecoderPatterns = @('DXVA selection:', 'MPC Video Decoder')
    SkipOpenNeedle = 'RFC-0047: skip legacy avcodec_open (DXVA modern parse)'
  }
)

function Get-Rfc0047GpuSummary {
  $controllers = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
  if (-not $controllers) {
    return 'GPU information unavailable'
  }

  return (($controllers | ForEach-Object {
    "$($_.Name) vendor=$($_.AdapterCompatibility) driver=$($_.DriverVersion)"
  }) -join '; ')
}

function Get-Rfc0047SampleSummary {
  param([Parameter(Mandatory = $true)][string]$Path)

  $item = Get-Item -LiteralPath $Path
  return "$($item.FullName) size=$($item.Length)"
}

function Test-Rfc0047DxvaSampleHandoff {
  param(
    [Parameter(Mandatory = $true)][hashtable]$Sample,
    [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
    [Parameter(Mandatory = $true)][int]$SteadyStateSeconds,
    [Parameter(Mandatory = $true)][int]$AllowedUnresponsiveSeconds,
    [bool]$CheckWindowResponding
  )

  $samplePath = Join-Path $repoRoot $Sample.RelativePath
  if (-not (Test-Path -LiteralPath $samplePath)) {
    Write-Host "test-rfc0047-dxva-sample-handoff: SKIP $($Sample.Label) - missing sample $samplePath" -ForegroundColor Yellow
    return [PSCustomObject]@{
      Label = $Sample.Label
      Result = 'SkipMissingSample'
      Sample = $samplePath
    }
  }

  Stop-SplayerProcesses
  Clear-SplayerLog
  $process = Start-SplayerForSample -SamplePath $samplePath
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
      -FailureMessage "splayer UI stopped responding during RFC-0047 $($Sample.Label) DXVA handoff selfcheck"

    $logText = Get-SplayerLogText
    $decoderHit = @($Sample.DecoderPatterns | Where-Object { $logText -match [regex]::Escape($_) }).Count -gt 0
    $dxvaSelected = $logText -match 'DXVA selection:.*useDXVA=1'
    $skipOpenHit = $logText -match [regex]::Escape($Sample.SkipOpenNeedle)
    $dxvaConnectHit = $logText -match 'DXVA connect:'

    Write-Host "RFC-0047 $($Sample.Label) sample: $(Get-Rfc0047SampleSummary -Path $samplePath)"
    if ($dxvaSelected) {
      ($logText -split "`r?`n" | Where-Object { $_ -match 'DXVA selection:' }) | Select-Object -First 1 | ForEach-Object { Write-Host $_ }
    }
    if ($skipOpenHit) {
      ($logText -split "`r?`n" | Where-Object { $_ -match [regex]::Escape($Sample.SkipOpenNeedle) }) | Select-Object -First 1 | ForEach-Object { Write-Host $_ }
    }
    if ($dxvaConnectHit) {
      ($logText -split "`r?`n" | Where-Object { $_ -match 'DXVA connect:' }) | Select-Object -First 1 | ForEach-Object { Write-Host $_ }
    }

    if ($decoderHit -and $dxvaSelected -and $skipOpenHit) {
      Write-Host "test-rfc0047-dxva-sample-handoff: PASS $($Sample.Label) MPCVideoDec DXVA + modern parse skip-open" -ForegroundColor Green
      return [PSCustomObject]@{
        Label = $Sample.Label
        Result = 'Pass'
        Sample = $samplePath
      }
    }

    if ($decoderHit -and $dxvaSelected) {
      $message = "$($Sample.Label) reached MPCVideoDec DXVA but RFC-0047 skip-open needle was not observed"
      if ($RequireDxvaModernParseHandoff) {
        throw $message
      }
      Write-Host "test-rfc0047-dxva-sample-handoff: OBSERVE $message" -ForegroundColor Yellow
      return [PSCustomObject]@{
        Label = $Sample.Label
        Result = 'ObserveDxvaWithoutSkipOpen'
        Sample = $samplePath
      }
    }

    $message = "$($Sample.Label) did not reach MPCVideoDec DXVA path (GPU/graph routing)"
    if ($RequireDxvaModernParseHandoff) {
      throw $message
    }
    Write-Host "test-rfc0047-dxva-sample-handoff: SKIP $message" -ForegroundColor Yellow
    return [PSCustomObject]@{
      Label = $Sample.Label
      Result = 'SkipNoDxvaPath'
      Sample = $samplePath
    }
  }
  finally {
    Get-Process -Id $process.Id -ErrorAction SilentlyContinue | Stop-Process -Force
  }
}

Write-Host "RFC-0047 DXVA handoff GPU: $(Get-Rfc0047GpuSummary)"

$results = @($sampleMatrix | ForEach-Object {
  Test-Rfc0047DxvaSampleHandoff `
    -Sample $_ `
    -TimeoutSeconds $TimeoutSeconds `
    -SteadyStateSeconds $SteadyStateSeconds `
    -AllowedUnresponsiveSeconds $AllowedUnresponsiveSeconds `
    -CheckWindowResponding:$CheckWindowResponding.IsPresent
})

$passCount = @($results | Where-Object { $_.Result -eq 'Pass' }).Count
$observeCount = @($results | Where-Object { $_.Result -like 'Observe*' }).Count
$skipCount = @($results | Where-Object { $_.Result -like 'Skip*' }).Count

Write-Host "test-rfc0047-dxva-sample-handoff: summary pass=$passCount observe=$observeCount skip=$skipCount" -ForegroundColor Cyan

if ($RequireDxvaModernParseHandoff -and $passCount -eq 0) {
  throw 'RFC-0047 DXVA modern parse handoff required but no sample reached MPCVideoDec DXVA with skip-open needle'
}

Write-Host 'test-rfc0047-dxva-sample-handoff: OK (optional GPU observation gate)' -ForegroundColor Green
exit 0
