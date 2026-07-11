#Requires -Version 5.1
<#
.SYNOPSIS
  Download public media samples used by the selfcheck scripts.
#>
[CmdletBinding()]
param(
  [string]$OutputDirectory = '',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'TestSupport\SplayerTestSupport.psm1') -Force

$repoRoot = Get-SplayerRepoRoot
$defaultOutputDirectory = Join-Path $repoRoot 'out\selfcheck'
$defaultMinimumBytes = 128 * 1024

function New-SelfcheckSample {
  param(
    [Parameter(Mandatory = $true)][string]$FileName,
    [Parameter(Mandatory = $true)][string]$Uri,
    [int]$MinimumBytes = $defaultMinimumBytes
  )

  return [PSCustomObject]@{
    FileName = $FileName
    Uri = $Uri
    MinimumBytes = $MinimumBytes
  }
}

function Assert-SelfcheckSampleFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][int]$MinimumBytes
  )

  $item = Get-Item -LiteralPath $Path -ErrorAction Stop
  if ($item.Length -lt $MinimumBytes) {
    throw "Downloaded selfcheck sample is unexpectedly small: $Path ($($item.Length) bytes)"
  }
}

function Save-SelfcheckSample {
  param(
    [Parameter(Mandatory = $true)]$Sample,
    [Parameter(Mandatory = $true)][string]$Directory,
    [Parameter(Mandatory = $true)][bool]$Overwrite
  )

  $targetPath = Join-Path $Directory $Sample.FileName
  if ((Test-Path -LiteralPath $targetPath) -and -not $Overwrite) {
    Assert-SelfcheckSampleFile -Path $targetPath -MinimumBytes $Sample.MinimumBytes
    Write-Host "setup-selfcheck-samples: exists $targetPath" -ForegroundColor DarkGray
    return $targetPath
  }

  Write-Host "setup-selfcheck-samples: downloading $($Sample.Uri)" -ForegroundColor Cyan
  Invoke-WebRequest -Uri $Sample.Uri -OutFile $targetPath
  Assert-SelfcheckSampleFile -Path $targetPath -MinimumBytes $Sample.MinimumBytes
  return $targetPath
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $OutputDirectory = $defaultOutputDirectory
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$samples = @(
  New-SelfcheckSample -FileName 'genius_party_sample.mkv' -Uri 'https://samples.ffmpeg.org/Matroska/Mushishi24-head.mkv' -MinimumBytes (1024 * 1024)

  New-SelfcheckSample -FileName 'sample-mpeg2-dxva.m2ts' -Uri 'https://samples.ffmpeg.org/archive/video/mpeg2video/mpegts+mpeg2video+ac3++Eragon.m2ts' -MinimumBytes (512 * 1024)
  New-SelfcheckSample -FileName 'sample-mpeg2-dxva.ts' -Uri 'https://samples.ffmpeg.org/MPEG2/mpeg2_field_encoding.ts' -MinimumBytes (512 * 1024)
  New-SelfcheckSample -FileName 'sample-mpeg2-dxva.m2v' -Uri 'https://samples.ffmpeg.org/MPEG2/test422.m2v' -MinimumBytes (512 * 1024)
  New-SelfcheckSample -FileName 'sample-mpeg2-dxva.vob' -Uri 'https://samples.ffmpeg.org/MPEG2/TITLE01-ANGLE1.VOB' -MinimumBytes (512 * 1024)
  New-SelfcheckSample -FileName 'sample-mpeg2-dxva.mpg' -Uri 'https://samples.ffmpeg.org/MPEG2/mm-short.mpg' -MinimumBytes (1024 * 1024)
  New-SelfcheckSample -FileName 'sample-mpeg-small.mpeg' -Uri 'https://samples.ffmpeg.org/MPEG-VOB/eof.mpeg' -MinimumBytes (512 * 1024)

  New-SelfcheckSample -FileName 'sample-rmvb-rv40-test.rmvb' -Uri 'https://samples.ffmpeg.org/real/VC-RV40/test.rmvb' -MinimumBytes (1024 * 1024)
  New-SelfcheckSample -FileName 'sample-rmvb-rv40-spygames-2mb.rmvb' -Uri 'https://samples.ffmpeg.org/real/VC-RV40/spygames-2MB.rmvb' -MinimumBytes (1024 * 1024)
  New-SelfcheckSample -FileName 'sample-rmvb-rv40-packet-timestamp.rmvb' -Uri 'https://samples.ffmpeg.org/real/VC-RV40/packet_timestamp.rmvb' -MinimumBytes (1024 * 1024)
)

$downloadedPaths = @($samples | ForEach-Object {
  Save-SelfcheckSample -Sample $_ -Directory $OutputDirectory -Overwrite:$Force.IsPresent
})

Write-Host 'setup-selfcheck-samples: OK' -ForegroundColor Green
$downloadedPaths | ForEach-Object { Write-Host "  $_" }
