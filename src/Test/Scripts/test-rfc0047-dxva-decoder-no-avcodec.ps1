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

Assert-FileContains $ffmpegHeader 'FFH264CreateDxvaSession' 'FfmpegContext.h must declare FFH264CreateDxvaSession'
Assert-FileContains $ffmpegHeader 'FFH264ReadPictureContextSession' 'FfmpegContext.h must declare session-based ReadPictureContext'
Assert-FileContains $ffmpegC 'FFH264CreateDxvaSession' 'FfmpegContext.c must implement FFH264CreateDxvaSession'
Assert-FileContains $ffmpegC 'FFH264ReadPictureContextSession' 'FfmpegContext.c must implement session APIs'
Assert-FileContains $h264Cpp 'FFH264CreateDxvaSession' 'DXVADecoderH264 must create DXVA session'
Assert-FileContains $h264Cpp 'FFH264ReadPictureContextSession' 'DXVADecoderH264 must use session ReadPictureContext'
Assert-FileContains $h264Cpp 'FFH264SetCurrentPictureSession' 'DXVADecoderH264 must use session SetCurrentPicture'
Assert-FileContains $h264Cpp 'FFH264UpdateRefFramesListSession' 'DXVADecoderH264 must use session UpdateRefFramesList'
Assert-FileContains $h264Cpp 'FFH264IsRefFrameInUseSession' 'DXVADecoderH264 must use session IsRefFrameInUse'
Assert-FileContains $h264Cpp 'FF264UpdateRefFrameSliceLongSession' 'DXVADecoderH264 must use session UpdateRefFrameSliceLong'

Assert-FileNotContains $h264Cpp '#\s*include\s+"avcodec\.h"' 'DXVADecoderH264 must not include avcodec.h'
Assert-FileNotContains $h264Cpp '#\s*include\s+"PODtypes\.h"' 'DXVADecoderH264 must not include PODtypes.h'
Assert-FileNotContains $h264Cpp '\bAVCodecContext\s*\*' 'DXVADecoderH264 must not declare AVCodecContext locals'
Assert-FileNotContains $h264Cpp 'FFH264DecodeBuffer\s*\(\s*m_pFilter->GetAVCtx' 'DXVADecoderH264 must not call legacy DecodeBuffer with GetAVCtx'
Assert-FileNotContains $h264Cpp 'FFH264ReadPictureContext\s*\(\s*&' 'DXVADecoderH264 must not call legacy ReadPictureContext directly'
Assert-FileNotContains $h264Cpp 'FFH264SetCurrentPicture\s*\(' 'DXVADecoderH264 must not call legacy SetCurrentPicture directly'
Assert-FileNotContains $h264Cpp 'FFH264UpdateRefFramesList\s*\(' 'DXVADecoderH264 must not call legacy UpdateRefFramesList directly'
Assert-FileNotContains $h264Cpp 'FFH264IsRefFrameInUse\s*\(' 'DXVADecoderH264 must not call legacy IsRefFrameInUse directly'
Assert-FileNotContains $vc1Cpp '#\s*include\s+"avcodec\.h"' 'DXVADecoderVC1 must not include avcodec.h'
Assert-FileNotContains $mpeg2Cpp '#\s*include\s+"avcodec\.h"' 'DXVADecoderMpeg2 must not include avcodec.h'

Write-Host 'test-rfc0047-dxva-decoder-no-avcodec: PASS'
