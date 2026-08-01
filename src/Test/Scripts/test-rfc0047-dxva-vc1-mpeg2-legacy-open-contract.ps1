#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 4c contract: MPEG-2 DXVA still requires legacy avcodec_open until modern parse bridge exists.
  VC-1 may skip open when playasa_dxva_vc1_parse_* is available.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$filterCpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\MPCVideoDecFilter.cpp'
$vc1Glue = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaVc1LegacyGlue.c'
$mpeg2Glue = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaMpeg2LegacyGlue.c'
$bridgeDef = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\playasa_ffmpeg_modern_bridge.def'

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) { throw "RFC-0047 4c contract gate failed: $Message ($Path)" }
}

function Assert-FileNotContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -match $Pattern) { throw "RFC-0047 4c contract gate failed: $Message ($Path)" }
}

# H.264 and VC-1 may skip open when modern parse is available; MPEG-2 must not skip yet.
Assert-FileContains $filterCpp 'codecId == CODEC_ID_H264 && FFH264IsModernDxvaParseAvailable' 'NeedsLegacyAvcodecOpen must gate H.264 skip on modern parse availability'
Assert-FileContains $filterCpp 'codecId == CODEC_ID_VC1 && FFVC1IsModernDxvaParseAvailable' 'NeedsLegacyAvcodecOpen must gate VC-1 skip on modern parse availability'
Assert-FileNotContains $filterCpp 'CODEC_ID_MPEG2VIDEO.*IsModernDxvaParseAvailable' 'MPEG-2 must not skip legacy avcodec_open without a modern parse bridge'

# Legacy glue still depends on libavcodec decode side effects when legacy path is used.
Assert-FileContains $vc1Glue 'av_vc1_decode_frame' 'VC-1 DXVA glue must still call av_vc1_decode_frame for legacy path'
Assert-FileContains $mpeg2Glue 'avcodec_decode_video' 'MPEG-2 DXVA glue must still call avcodec_decode_video'

# Modern bridge exports H.264 and VC-1 parse; MPEG-2 parse is future work.
Assert-FileContains $bridgeDef 'playasa_dxva_h264_parse_create' 'modern bridge must export H.264 DXVA parse'
Assert-FileContains $bridgeDef 'playasa_dxva_vc1_parse_create' 'modern bridge must export VC-1 DXVA parse'
Assert-FileNotContains $bridgeDef 'playasa_dxva_mpeg2_parse' 'MPEG-2 DXVA parse is not implemented yet'

Write-Host 'test-rfc0047-dxva-vc1-mpeg2-legacy-open-contract.ps1: PASS'
