#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 3f: legacy MPEG-2 glue compartmentalized; FfmpegContext.c no longer includes mpegvideo.h.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$ffmpegC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\FfmpegContext.c'
$glueC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaMpeg2LegacyGlue.c'
$h264GlueC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaH264LegacyGlue.c'
$mpeg2Cpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DXVADecoderMpeg2.cpp'

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) { throw "RFC-0047 3f gate failed: $Message ($Path)" }
}

function Assert-FileNotContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -match $Pattern) { throw "RFC-0047 3f gate failed: $Message ($Path)" }
}

Assert-FileNotContains $ffmpegC '#\s*include\s+"mpegvideo\.h"' 'FfmpegContext.c must not include legacy mpegvideo.h'
Assert-FileNotContains $ffmpegC '#\s*include\s+"dsputil\.h"' 'FfmpegContext.c must not include legacy dsputil.h'
Assert-FileNotContains $ffmpegC '\bMpeg1Context\b' 'FfmpegContext.c must not reference Mpeg1Context'
Assert-FileNotContains $ffmpegC 'avcodec_decode_video\b' 'FfmpegContext.c must not call avcodec_decode_video'
Assert-FileContains $glueC '#\s*include\s+"mpegvideo\.h"' 'DxvaMpeg2LegacyGlue.c must own legacy mpegvideo.h include'
Assert-FileContains $glueC 'FFMpeg2ReadPictureContext' 'MPEG-2 legacy glue must implement FFMpeg2ReadPictureContext'
Assert-FileContains $glueC 'FFMpeg2DecodeFrame' 'MPEG-2 legacy glue must implement FFMpeg2DecodeFrame'
Assert-FileContains $h264GlueC 'FFGetMpegEncMBNumber' 'H.264 legacy glue must provide MpegEncContext accessors'
Assert-FileContains $mpeg2Cpp 'FFMpeg2ReadPictureContext' 'MPEG-2 decoder must consume picture contract reader'

Write-Host 'test-rfc0047-mpeg2-dxva-legacy-glue-compartment.ps1: PASS'
