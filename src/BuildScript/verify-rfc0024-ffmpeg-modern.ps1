#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0024 FFmpeg 8.1 modern island gate.
#>
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$islandRoot = Join-Path $repoRoot 'src\Thirdparty\ffmpeg-modern'
$expectedFile = Join-Path $islandRoot 'rfc0024-expected.txt'
$sourceRoot = Join-Path $islandRoot 'src'
$downloadArchive = Join-Path $islandRoot 'download\ffmpeg-8.1.tar.xz'
$adapterHeader = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegDecodeAdapter.h'
$adapterSource = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegDecodeAdapter.cpp'
$legacyFilterSource = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\MPCVideoDecFilter.cpp'
$smokeSource = Join-Path $repoRoot 'src\Test\MPCVideoDecModernSmoke\MPCVideoDecModernSmoke.cpp'
$smokeScript = Join-Path $PSScriptRoot 'test-rfc0024-modern-smoke.ps1'

function Assert-FileExists {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing required file: $Path"
  }
}

function Assert-DirectoryExists {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "Missing required directory: $Path"
  }
}

function Assert-Text {
  param(
    [string]$Path,
    [string]$Pattern,
    [string]$Description
  )
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) {
    throw "RFC-0024 gate failed: $Description"
  }
}

Assert-DirectoryExists $islandRoot
Assert-DirectoryExists $sourceRoot
Assert-FileExists $expectedFile
Assert-FileExists (Join-Path $sourceRoot 'configure')
Assert-FileExists (Join-Path $sourceRoot 'RELEASE')
Assert-FileExists (Join-Path $sourceRoot 'LICENSE.md')
Assert-FileExists (Join-Path $sourceRoot 'COPYING.LGPLv2.1')
Assert-FileExists (Join-Path $sourceRoot 'COPYING.LGPLv3')
Assert-FileExists (Join-Path $sourceRoot 'COPYING.GPLv2')
Assert-FileExists (Join-Path $sourceRoot 'COPYING.GPLv3')
Assert-FileExists (Join-Path $sourceRoot 'libavcodec\version.h')
Assert-FileExists (Join-Path $sourceRoot 'libavcodec\version_major.h')
Assert-FileExists (Join-Path $sourceRoot 'libavutil\version.h')
Assert-FileExists $adapterHeader
Assert-FileExists $adapterSource
Assert-FileExists $legacyFilterSource
Assert-FileExists $smokeSource
Assert-FileExists $smokeScript

Assert-Text $expectedFile 'Version:\s+8\.1' 'expected file must pin FFmpeg 8.1'
Assert-Text $expectedFile 'Source archive SHA-256:\s+b072aed6871998cce9b36e7774033105ca29e33632be5b6347f3206898e0756a' 'expected file must pin FFmpeg 8.1 archive hash'
Assert-Text $expectedFile 'Keep legacy src/Source/filters/transform/mpcvideodec/ffmpeg unchanged\.' 'expected file must preserve legacy FFmpeg boundary'
Assert-Text $expectedFile 'Do not link this island into MPCVideoDec until adapter smoke tests exist\.' 'expected file must preserve no-link boundary'
Assert-Text $expectedFile 'First-wave software codecs:' 'expected file must list first-wave software codecs'

$release = (Get-Content -LiteralPath (Join-Path $sourceRoot 'RELEASE') -Raw).Trim()
if ($release -ne '8.1') {
  throw "RFC-0024 gate failed: RELEASE changed to $release"
}

Assert-Text (Join-Path $sourceRoot 'libavcodec\version_major.h') '#define\s+LIBAVCODEC_VERSION_MAJOR\s+62' 'libavcodec major version changed'
Assert-Text (Join-Path $sourceRoot 'libavcodec\version.h') '#define\s+LIBAVCODEC_VERSION_MINOR\s+28' 'libavcodec minor version changed'
Assert-Text (Join-Path $sourceRoot 'libavcodec\version.h') '#define\s+LIBAVCODEC_VERSION_MICRO\s+100' 'libavcodec micro version changed'
Assert-Text (Join-Path $sourceRoot 'libavutil\version.h') '#define\s+LIBAVUTIL_VERSION_MAJOR\s+60' 'libavutil major version changed'
Assert-Text (Join-Path $sourceRoot 'libavutil\version.h') '#define\s+LIBAVUTIL_VERSION_MINOR\s+26' 'libavutil minor version changed'
Assert-Text (Join-Path $sourceRoot 'libavutil\version.h') '#define\s+LIBAVUTIL_VERSION_MICRO\s+100' 'libavutil micro version changed'
Assert-Text $adapterHeader 'class\s+DecodeSession' 'adapter must define DecodeSession'
Assert-Text $adapterHeader 'DecodeCodecFromFourcc' 'adapter must expose first-wave codec mapping'
Assert-Text $adapterSource 'avcodec_send_packet' 'adapter must use modern send_packet API'
Assert-Text $adapterSource 'avcodec_receive_frame' 'adapter must use modern receive_frame API'
Assert-Text $adapterSource 'AV_CODEC_ID_MPEG4' 'adapter must cover MPEG-4 first-wave codec'
Assert-Text $adapterSource 'AV_CODEC_ID_FLV1' 'adapter must cover FLV1 first-wave codec'
Assert-Text $adapterSource 'AV_CODEC_ID_VP6' 'adapter must cover VP6 first-wave codec'
Assert-Text $adapterSource 'AV_CODEC_ID_WMV1' 'adapter must cover WMV1 first-wave codec'
Assert-Text $adapterSource 'AV_CODEC_ID_WMV2' 'adapter must cover WMV2 first-wave codec'
Assert-Text $smokeSource 'avformat_open_input' 'smoke must open a real sample container'
Assert-Text $smokeSource 'DecodeSession' 'smoke must exercise the modern decode adapter'
Assert-Text $smokeSource 'Decoded first frame' 'smoke must verify first-frame decode'
Assert-Text $smokeScript 'MPCVideoDecModernSmoke\.exe' 'smoke script must build and run the smoke executable'
if ((Get-Content -LiteralPath $legacyFilterSource -Raw) -match 'modern_ffmpeg|ModernFfmpegDecodeAdapter|src\\Thirdparty\\ffmpeg-modern') {
  throw 'RFC-0024 gate failed: legacy MPCVideoDecFilter.cpp must not include the modern island before smoke tests exist'
}

if (Test-Path -LiteralPath $downloadArchive) {
  $actualHash = (Get-FileHash -LiteralPath $downloadArchive -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actualHash -ne 'b072aed6871998cce9b36e7774033105ca29e33632be5b6347f3206898e0756a') {
    throw "RFC-0024 gate failed: archive hash changed to $actualHash"
  }
}

foreach ($option in @(
  '--disable-programs',
  '--disable-doc',
  '--disable-debug',
  '--disable-avdevice',
  '--disable-avfilter',
  '--disable-network',
  '--disable-hwaccels',
  '--disable-encoders',
  '--disable-decoders',
  '--disable-demuxers',
  '--disable-parsers',
  '--disable-muxers',
  '--enable-avcodec',
  '--enable-avutil',
  '--enable-avformat',
  '--enable-swscale',
  '--enable-decoder=mpeg4',
  '--enable-decoder=flv',
  '--enable-decoder=vp6',
  '--enable-decoder=vp6a',
  '--enable-decoder=vp6f',
  '--enable-decoder=wmv1',
  '--enable-decoder=wmv2',
  '--enable-demuxer=avi',
  '--enable-demuxer=flv',
  '--enable-demuxer=matroska',
  '--enable-demuxer=mov',
  '--enable-parser=mpeg4video',
  '--enable-parser=h263',
  '--enable-parser=vp3'
)) {
  Assert-Text $expectedFile ([regex]::Escape($option)) "missing configure option $option"
}

Write-Host 'verify-rfc0024-ffmpeg-modern: OK (FFmpeg 8.1 island pins match)' -ForegroundColor Green
