#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 4c-iii: H.264/VC-1/MPEG-2 DXVA may skip legacy avcodec_open when modern parse is available;
  legacy libavcodec symbols remain in MPCVideoDecLegacyGlue for software/fallback paths.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$mpcDir = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec'
$filterCpp = Join-Path $mpcDir 'MPCVideoDecFilter.cpp'
$filterHeader = Join-Path $mpcDir 'MPCVideoDecFilter.h'
$filterProject = Join-Path $mpcDir 'MPCVideoDec.vcxproj'
$glueProject = Join-Path $mpcDir 'MPCVideoDecLegacyGlue.vcxproj'
$ffmpegHeader = Join-Path $mpcDir 'FfmpegContext.h'
$h264Cpp = Join-Path $mpcDir 'DXVADecoderH264.cpp'
$vc1Cpp = Join-Path $mpcDir 'DXVADecoderVC1.cpp'
$mpeg2Cpp = Join-Path $mpcDir 'DXVADecoderMpeg2.cpp'

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) { throw "RFC-0047 4c-iii gate failed: $Message ($Path)" }
}

function Assert-FileNotContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -match $Pattern) { throw "RFC-0047 4c-iii gate failed: $Message ($Path)" }
}

# Filter: unified skip-open gate for all DXVA codecs with modern parse.
Assert-FileContains $filterHeader 'm_bLegacyAvcodecOpened' 'filter must track legacy avcodec_open state'
Assert-FileContains $filterCpp 'NeedsLegacyAvcodecOpen' 'filter must gate legacy avcodec_open'
Assert-FileContains $filterCpp 'CODEC_ID_H264 && FFH264IsModernDxvaParseAvailable' 'H.264 skip-open must probe modern parse'
Assert-FileContains $filterCpp 'CODEC_ID_VC1 && FFVC1IsModernDxvaParseAvailable' 'VC-1 skip-open must probe modern parse'
Assert-FileContains $filterCpp 'CODEC_ID_MPEG2VIDEO && FFMpeg2IsModernDxvaParseAvailable' 'MPEG-2 skip-open must probe modern parse'
Assert-FileContains $filterCpp 'm_bLegacyAvcodecOpened = true' 'filter must set legacy-open flag when avcodec_open runs'
Assert-FileContains $filterCpp 'skip legacy avcodec_open \(DXVA modern parse\)' 'filter must log skipped legacy open'

# H.264 compatibility check must also skip when modern parse is available.
Assert-FileContains $filterCpp 'FFH264IsModernDxvaParseAvailable\(\)\) \{\s*\r?\n\s*ModernFfmpegSelfcheckLog\(_T\("RFC-0047: skip FFH264CheckCompatibility' 'H.264 must skip FFH264CheckCompatibility on modern DXVA parse'

# DXVA thread init only when legacy decoder was opened.
Assert-FileContains $filterCpp 'if \(m_bLegacyAvcodecOpened\) \{\s*\r?\n\s*avcodec_thread_init' 'DXVA must only thread-init legacy decoder when opened'

# Public session API surface for all three codecs.
Assert-FileContains $ffmpegHeader 'FFH264IsModernDxvaParseAvailable' 'FfmpegContext.h must export H.264 modern parse probe'
Assert-FileContains $ffmpegHeader 'FFVC1IsModernDxvaParseAvailable' 'FfmpegContext.h must export VC-1 modern parse probe'
Assert-FileContains $ffmpegHeader 'FFMpeg2IsModernDxvaParseAvailable' 'FfmpegContext.h must export MPEG-2 modern parse probe'
Assert-FileContains $ffmpegHeader 'FFH264CreateDxvaSession' 'FfmpegContext.h must export H.264 DXVA session'
Assert-FileContains $ffmpegHeader 'FFVC1CreateDxvaSession' 'FfmpegContext.h must export VC-1 DXVA session'
Assert-FileContains $ffmpegHeader 'FFMpeg2CreateDxvaSession' 'FfmpegContext.h must export MPEG-2 DXVA session'

# Decoder TUs bind session without requiring GetAVCtx() when modern parse is available.
Assert-FileContains $h264Cpp 'FFH264CreateDxvaSession\s*\(\s*FFH264IsModernDxvaParseAvailable' 'H.264 decoder must pass NULL avctx when modern parse is available'
Assert-FileContains $vc1Cpp 'FFVC1CreateDxvaSession\s*\(\s*FFVC1IsModernDxvaParseAvailable' 'VC-1 decoder must pass NULL avctx when modern parse is available'
Assert-FileContains $mpeg2Cpp 'FFMpeg2CreateDxvaSession\s*\(\s*FFMpeg2IsModernDxvaParseAvailable' 'MPEG-2 decoder must pass NULL avctx when modern parse is available'
Assert-FileContains $h264Cpp 'FFH264ReadPictureContextSession' 'H.264 decoder must use session picture context'
Assert-FileContains $vc1Cpp 'FFVC1ReadPictureContextSession' 'VC-1 decoder must use session picture context'
Assert-FileContains $mpeg2Cpp 'FFMpeg2ReadPictureContextSession' 'MPEG-2 decoder must use session picture context'

# Software / legacy paths still resolve libavcodec via glue static lib, not MPCVideoDec TU.
Assert-FileContains $glueProject 'libavcodec_gcc\.lib' 'legacy glue lib must link libavcodec_gcc'
Assert-FileContains $filterProject 'MPCVideoDecLegacyGlue\.vcxproj' 'MPCVideoDec must reference legacy glue lib'
Assert-FileNotContains $filterProject 'libavcodec_gcc' 'MPCVideoDec must not link libavcodec_gcc directly'

Write-Host 'test-rfc0047-dxva-skip-open-all-codecs.ps1: PASS'
