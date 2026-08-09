#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0035 gate: MPCVideoDec still documents legacy-only codecs that block ffmpeg tree deletion.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$filterCpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\MPCVideoDecFilter.cpp'
$auditScript = Join-Path $repoRoot 'src\BuildScript\audit-rfc0035-legacy-only-codecs.ps1'
$inventoryFile = Join-Path $repoRoot 'src\Thirdparty\ffmpeg-modern\rfc0035-legacy-only-codecs.txt'

# Codec ids that must remain legacy-only until migrated or removed from ffCodecs.
$requiredLegacyOnlyCodecIds = @(
  'CODEC_ID_VP5'
  'CODEC_ID_MSMPEG4V1'
  'CODEC_ID_MSMPEG4V2'
  'CODEC_ID_MSMPEG4V3'
  'CODEC_ID_AMV'
  'CODEC_ID_SVQ3'
  'CODEC_ID_SVQ1'
  'CODEC_ID_H263'
  'CODEC_ID_THEORA'
  'CODEC_ID_MPEG1VIDEO'
  'CODEC_ID_TSCC'
  'CODEC_ID_MJPEG'
  'CODEC_ID_SMC'
  'CODEC_ID_HUFFYUV'
  'CODEC_ID_CINEPAK'
  'CODEC_ID_QTRLE'
  'CODEC_ID_FRAPS'
)

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) { throw "RFC-0035 legacy-codec gate failed: $Message ($Path)" }
}

Assert-FileContains $filterCpp 'avcodec_decode_video' 'SoftwareDecode must retain legacy avcodec_decode_video path'
Assert-FileContains $filterCpp 'IsModernFfmpegBridgeCodec' 'filter must gate modern bridge codecs'
Assert-FileContains $filterCpp 'fail-closed \(no legacy software fallback\)' 'bridge codecs must fail-closed without legacy fallback'

foreach ($codecId in $requiredLegacyOnlyCodecIds) {
  if (-not (Select-String -LiteralPath $filterCpp -Pattern $codecId -Quiet)) {
    throw "RFC-0035 legacy-codec gate failed: missing expected legacy-only codec $codecId in ffCodecs"
  }
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $auditScript
if ($LASTEXITCODE -ne 0) {
  throw "audit-rfc0035-legacy-only-codecs.ps1 failed with exit $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $inventoryFile)) {
  throw "Missing inventory file: $inventoryFile"
}

$inventoryText = Get-Content -LiteralPath $inventoryFile -Raw
foreach ($codecId in $requiredLegacyOnlyCodecIds) {
  if ($inventoryText -notmatch [regex]::Escape($codecId)) {
    throw "RFC-0035 legacy-codec gate failed: inventory missing $codecId"
  }
}

Write-Host 'test-rfc0035-legacy-only-codec-contract: PASS' -ForegroundColor Green
