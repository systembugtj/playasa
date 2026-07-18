#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 1: DXVA decoder TUs must not include legacy avcodec.h.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$mpcvideodec = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec'
$h264Cpp = Join-Path $mpcvideodec 'DXVADecoderH264.cpp'
$vc1Cpp = Join-Path $mpcvideodec 'DXVADecoderVC1.cpp'
$mpeg2Cpp = Join-Path $mpcvideodec 'DXVADecoderMpeg2.cpp'
$ffmpegHeader = Join-Path $mpcvideodec 'FfmpegContext.h'
$ffmpegC = Join-Path $mpcvideodec 'FfmpegContext.c'

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "RFC-0047 gate failed: missing $Path"
  }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) {
    throw "RFC-0047 gate failed: $Message ($Path)"
  }
}

function Assert-FileNotContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "RFC-0047 gate failed: missing $Path"
  }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -match $Pattern) {
    throw "RFC-0047 gate failed: $Message ($Path)"
  }
}

Assert-FileContains $ffmpegHeader 'FFH264GetNalLengthSize' 'FfmpegContext.h must declare FFH264GetNalLengthSize'
Assert-FileContains $ffmpegHeader 'FFH264ApplyExtradata' 'FfmpegContext.h must declare FFH264ApplyExtradata'
Assert-FileContains $ffmpegC 'FFH264GetNalLengthSize' 'FfmpegContext.c must implement FFH264GetNalLengthSize'
Assert-FileContains $ffmpegC 'FFH264ApplyExtradata' 'FfmpegContext.c must implement FFH264ApplyExtradata'
Assert-FileContains $h264Cpp 'FFH264GetNalLengthSize' 'DXVADecoderH264 must use FFH264GetNalLengthSize'
Assert-FileContains $h264Cpp 'FFH264ApplyExtradata' 'DXVADecoderH264 must use FFH264ApplyExtradata'

Assert-FileNotContains $h264Cpp '#\s*include\s+"avcodec\.h"' 'DXVADecoderH264 must not include avcodec.h'
Assert-FileNotContains $h264Cpp '#\s*include\s+"PODtypes\.h"' 'DXVADecoderH264 must not include PODtypes.h'
Assert-FileNotContains $h264Cpp '\bAVCodecContext\s*\*' 'DXVADecoderH264 must not declare AVCodecContext locals'
Assert-FileNotContains $vc1Cpp '#\s*include\s+"avcodec\.h"' 'DXVADecoderVC1 must not include avcodec.h'
Assert-FileNotContains $mpeg2Cpp '#\s*include\s+"avcodec\.h"' 'DXVADecoderMpeg2 must not include avcodec.h'

Write-Host 'test-rfc0047-dxva-decoder-no-avcodec: PASS'
