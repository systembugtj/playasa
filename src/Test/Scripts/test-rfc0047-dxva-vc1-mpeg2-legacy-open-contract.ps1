#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 4c contract: H.264/VC-1/MPEG-2 DXVA may skip legacy avcodec_open when modern parse bridge exists.
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

# H.264, VC-1, and MPEG-2 may skip open when modern parse is available.
Assert-FileContains $filterCpp 'codecId == CODEC_ID_H264 && FFH264IsModernDxvaParseAvailable' 'NeedsLegacyAvcodecOpen must gate H.264 skip on modern parse availability'
Assert-FileContains $filterCpp 'codecId == CODEC_ID_VC1 && FFVC1IsModernDxvaParseAvailable' 'NeedsLegacyAvcodecOpen must gate VC-1 skip on modern parse availability'
Assert-FileContains $filterCpp 'codecId == CODEC_ID_MPEG2VIDEO && FFMpeg2IsModernDxvaParseAvailable' 'NeedsLegacyAvcodecOpen must gate MPEG-2 skip on modern parse availability'

# Legacy glue still depends on libavcodec decode side effects when legacy path is used.
Assert-FileContains $vc1Glue 'av_vc1_decode_frame' 'VC-1 DXVA glue must still call av_vc1_decode_frame for legacy path'
Assert-FileContains $mpeg2Glue 'avcodec_decode_video' 'MPEG-2 DXVA glue must still call avcodec_decode_video'

# Modern bridge exports H.264, VC-1, and MPEG-2 parse.
Assert-FileContains $bridgeDef 'playasa_dxva_h264_parse_create' 'modern bridge must export H.264 DXVA parse'
Assert-FileContains $bridgeDef 'playasa_dxva_vc1_parse_create' 'modern bridge must export VC-1 DXVA parse'
Assert-FileContains $bridgeDef 'playasa_dxva_mpeg2_parse_create' 'modern bridge must export MPEG-2 DXVA parse'

Write-Host 'test-rfc0047-dxva-vc1-mpeg2-legacy-open-contract.ps1: PASS'
