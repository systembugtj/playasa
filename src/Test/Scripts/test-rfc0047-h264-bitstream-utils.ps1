#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 3a: shared H.264 bitstream utils and DXVA session extradata cache.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$mpcvideodec = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec'
$utilsHeader = Join-Path $mpcvideodec 'h264_bitstream\H264BitstreamUtils.h'
$utilsCpp = Join-Path $mpcvideodec 'h264_bitstream\H264BitstreamUtils.cpp'
$sessionCpp = Join-Path $mpcvideodec 'DxvaH264Session.cpp'
$adapterCpp = Join-Path $mpcvideodec 'modern_ffmpeg\ModernFfmpegDecodeAdapter.cpp'
$vcxproj = Join-Path $mpcvideodec 'MPCVideoDec.vcxproj'

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "RFC-0047 phase 3a gate failed: missing $Path"
  }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) {
    throw "RFC-0047 phase 3a gate failed: $Message ($Path)"
  }
}

function Assert-FileNotContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "RFC-0047 phase 3a gate failed: missing $Path"
  }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -match $Pattern) {
    throw "RFC-0047 phase 3a gate failed: $Message ($Path)"
  }
}

Assert-FileContains $utilsHeader 'namespace PlayasaH264' 'H264BitstreamUtils must declare PlayasaH264 namespace'
Assert-FileContains $utilsHeader 'NalLengthSizeFromExtradata' 'H264BitstreamUtils must expose NalLengthSizeFromExtradata'
Assert-FileContains $utilsCpp 'ConvertAvcConfigurationToAnnexB' 'H264BitstreamUtils.cpp must implement AVC config conversion'
Assert-FileContains $sessionCpp 'FFH264CreateDxvaSession' 'DxvaH264Session.cpp must implement session API'
Assert-FileContains $sessionCpp 'DxvaH264SessionCacheExtradata' 'DxvaH264Session must cache extradata'
Assert-FileContains $sessionCpp 'PlayasaH264::NalLengthSizeFromExtradata' 'DxvaH264Session must parse nal length via shared utils'
Assert-FileContains $sessionCpp 'nal_length_size' 'DxvaH264Session must store cached nal_length_size'
Assert-FileContains $adapterCpp 'h264_bitstream/H264BitstreamUtils.h' 'ModernFfmpegDecodeAdapter must include shared H264 bitstream utils'
Assert-FileContains $adapterCpp 'PlayasaH264::NalLengthSizeFromExtradata' 'ModernFfmpegDecodeAdapter must use shared NalLengthSizeFromExtradata'
Assert-FileNotContains $adapterCpp 'int H264NalLengthSizeFromExtradata\(' 'adapter must not duplicate H264NalLengthSizeFromExtradata'
Assert-FileNotContains $adapterCpp 'bool IsAvcDecoderConfigurationRecord\(' 'adapter must not duplicate IsAvcDecoderConfigurationRecord'
Assert-FileContains $vcxproj 'h264_bitstream\\H264BitstreamUtils.cpp' 'MPCVideoDec.vcxproj must compile H264BitstreamUtils.cpp'
Assert-FileContains $vcxproj 'DxvaH264Session.cpp' 'MPCVideoDec.vcxproj must compile DxvaH264Session.cpp'

Write-Host 'test-rfc0047-h264-bitstream-utils: PASS'
