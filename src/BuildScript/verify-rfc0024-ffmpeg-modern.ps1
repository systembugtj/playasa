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
$installRoot = Join-Path $islandRoot 'install'
$downloadArchive = Join-Path $islandRoot 'download\ffmpeg-8.1.tar.xz'
$adapterHeader = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegDecodeAdapter.h'
$adapterSource = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegDecodeAdapter.cpp'
$bridgeHeader = Join-Path $repoRoot 'src\Thirdparty\pkg\ffmpeg_modern_bridge.h'
$bridgeSource = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegBridge.cpp'
$bridgeDef = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\playasa_ffmpeg_modern_bridge.def'
$bridgeConsumerHeader = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegBridgeConsumer.h'
$bridgeConsumerSource = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegBridgeConsumer.cpp'
$bridgeBuildScript = Join-Path $PSScriptRoot 'build-rfc0024-ffmpeg-bridge.ps1'
$legacyFilterSource = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\MPCVideoDecFilter.cpp'
$legacyFilterHeader = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\MPCVideoDecFilter.h'
$legacyFilterProject = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\MPCVideoDec.vcxproj'
$smokeSource = Join-Path $repoRoot 'src\Test\MPCVideoDecModernSmoke\MPCVideoDecModernSmoke.cpp'
$smokeScript = Join-Path $repoRoot 'src\Test\Scripts\test-rfc0024-modern-smoke.ps1'
$bridgeSmokeSource = Join-Path $repoRoot 'src\Test\MPCVideoDecModernBridgeSmoke\MPCVideoDecModernBridgeSmoke.cpp'
$bridgeSmokeScript = Join-Path $repoRoot 'src\Test\Scripts\test-rfc0024-modern-bridge-smoke.ps1'
$playerSelfcheckScript = Join-Path $repoRoot 'src\Test\Scripts\test-rfc0024-splayer-selfcheck.ps1'

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
Assert-FileExists $bridgeHeader
Assert-FileExists $bridgeSource
Assert-FileExists $bridgeDef
Assert-FileExists $bridgeConsumerHeader
Assert-FileExists $bridgeConsumerSource
Assert-FileExists $bridgeBuildScript
Assert-FileExists $legacyFilterSource
Assert-FileExists $legacyFilterHeader
Assert-FileExists $legacyFilterProject
Assert-FileExists $smokeSource
Assert-FileExists $smokeScript
Assert-FileExists $bridgeSmokeSource
Assert-FileExists $bridgeSmokeScript
Assert-FileExists $playerSelfcheckScript

Assert-Text $expectedFile 'Version:\s+8\.1' 'expected file must pin FFmpeg 8.1'
Assert-Text $expectedFile 'Source archive SHA-256:\s+b072aed6871998cce9b36e7774033105ca29e33632be5b6347f3206898e0756a' 'expected file must pin FFmpeg 8.1 archive hash'
Assert-Text $expectedFile 'Keep legacy src/Source/filters/transform/mpcvideodec/ffmpeg unchanged\.' 'expected file must preserve legacy FFmpeg boundary'
Assert-Text $expectedFile 'Do not link this island into MPCVideoDec until adapter smoke tests exist\.' 'expected file must preserve no-link boundary'
Assert-Text $expectedFile 'First-wave software codecs:' 'expected file must list first-wave software codecs'
Assert-Text $expectedFile 'Bridge is the only supported MSVC consumption boundary for FFmpeg modern island\.' 'expected file must pin bridge consumption boundary'
Assert-Text $expectedFile 'MPCVideoDec may only consume the bridge through dynamic loading' 'expected file must pin dynamic bridge loading'
Assert-Text $expectedFile 'First-wave software decode routes through ModernFfmpegBridgeDecode' 'expected file must pin first-wave bridge routing'

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
Assert-Text $adapterSource 'av_parser_parse2' 'adapter must parse VC-1/WMV3 packet boundaries before send_packet'
$h264BitstreamHeader = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\h264_bitstream\H264BitstreamUtils.h'
Assert-FileExists $h264BitstreamHeader
Assert-Text $h264BitstreamHeader 'NalLengthSizeFromExtradata' 'H264 bitstream utils must detect AVC length-prefixed packet format'
Assert-Text $h264BitstreamHeader 'DetectNalLengthSize' 'H264 bitstream utils must infer NAL length size from packets'
Assert-Text $h264BitstreamHeader 'ConvertAvcConfigurationToAnnexB' 'H264 bitstream utils must convert avcC extradata to Annex-B'
Assert-Text $h264BitstreamHeader 'ConvertLengthPrefixedParameterSetsToAnnexB' 'H264 bitstream utils must convert DirectShow SPS/PPS extradata'
Assert-Text $h264BitstreamHeader 'ConvertAvcLengthPrefixedToAnnexB' 'H264 bitstream utils must convert AVC length-prefixed packets'
Assert-Text $adapterSource 'h264_bitstream/H264BitstreamUtils.h' 'adapter must use shared H264 bitstream utils (RFC-0047 3a)'
Assert-Text $adapterSource 'PlayasaH264::NalLengthSizeFromExtradata' 'adapter must detect AVC length-prefixed H264 packet format'
Assert-Text $adapterSource 'PlayasaH264::DetectNalLengthSize' 'adapter must infer H264 NAL length size from packets when media type omits it'
Assert-Text $adapterSource 'PlayasaH264::ConvertAvcConfigurationToAnnexB' 'adapter must convert H264 avcC extradata to Annex-B parameter sets'
Assert-Text $adapterSource 'PlayasaH264::ConvertLengthPrefixedParameterSetsToAnnexB' 'adapter must convert DirectShow H264 SPS/PPS extradata to Annex-B parameter sets'
Assert-Text $adapterSource 'PlayasaH264::ConvertAvcLengthPrefixedToAnnexB' 'adapter must convert AVC length-prefixed H264 packets before modern decode'
Assert-Text $adapterSource 'h264PendingAccessUnit_' 'adapter must aggregate DirectShow chunked H264 NALs into access units'
Assert-Text $adapterSource 'AV_CODEC_ID_MPEG4' 'adapter must cover MPEG-4 first-wave codec'
Assert-Text $adapterSource 'AV_CODEC_ID_FLV1' 'adapter must cover FLV1 first-wave codec'
Assert-Text $adapterSource 'AV_CODEC_ID_VP6' 'adapter must cover VP6 first-wave codec'
Assert-Text $adapterSource 'AV_CODEC_ID_WMV1' 'adapter must cover WMV1 first-wave codec'
Assert-Text $adapterSource 'AV_CODEC_ID_WMV2' 'adapter must cover WMV2 first-wave codec'
Assert-Text $adapterSource 'AV_CODEC_ID_H264' 'adapter must cover H264 modern software codec'
Assert-Text $adapterSource 'AV_CODEC_ID_MPEG2VIDEO' 'adapter must cover MPEG-2 modern software codec'
Assert-Text $adapterSource 'AV_CODEC_ID_WMV3' 'adapter must cover WMV3 modern software codec'
Assert-Text $adapterSource 'AV_CODEC_ID_VC1' 'adapter must cover VC-1 modern software codec'
Assert-Text $adapterSource 'kFourccXVIX' 'adapter must cover XVIX MPEG-4 alias'
Assert-Text $adapterSource 'kFourccVP61' 'adapter must cover VP61 alias'
Assert-Text $adapterSource 'kFourccVP62' 'adapter must cover VP62 alias'
Assert-Text $adapterSource 'kFourccMPG2' 'adapter must cover MPEG-2 alias'
Assert-Text $adapterSource 'kFourccWMV3' 'adapter must cover WMV3 alias'
Assert-Text $adapterSource 'kFourccWVC1' 'adapter must cover VC-1 alias'
Assert-Text $bridgeHeader 'PLAYASA_FFMPEG_MODERN_API' 'bridge header must expose a C ABI import/export macro'
Assert-Text $bridgeHeader 'PlayasaFfmpegModernSession' 'bridge header must expose opaque session handle'
Assert-Text $bridgeHeader 'PLAYASA_FFMPEG_MODERN_CODEC_MPEG2' 'bridge header must expose MPEG-2 codec id'
Assert-Text $bridgeHeader 'PLAYASA_FFMPEG_MODERN_CODEC_WMV3' 'bridge header must expose WMV3 codec id'
Assert-Text $bridgeHeader 'PLAYASA_FFMPEG_MODERN_CODEC_VC1' 'bridge header must expose VC-1 codec id'
Assert-Text $bridgeHeader 'playasa_ffmpeg_modern_open_with_h264_nal_length_size' 'bridge header must expose H264 NAL length-size open option'
Assert-Text $bridgeHeader 'data\[4\]' 'bridge frame info must expose planes for MPCVideoDec output copy'
Assert-Text $bridgeHeader 'linesize\[4\]' 'bridge frame info must expose strides for MPCVideoDec output copy'
Assert-Text $bridgeSource 'extern "C"' 'bridge source must export a C ABI'
Assert-Text $bridgeSource 'playasa_ffmpeg_modern_create' 'bridge source must export create'
Assert-Text $bridgeSource 'OpenWithH264NalLengthSize' 'bridge source must pass H264 NAL length size into adapter'
Assert-Text $bridgeSource 'playasa_ffmpeg_modern_decode' 'bridge source must export decode'
Assert-Text $bridgeSource 'playasa_ffmpeg_modern_decode_with_pts' 'bridge source must export timestamp-aware decode'
Assert-Text $bridgeSource 'ToBridgePixelFormat' 'bridge source must map pixel formats to stable C ABI values'
Assert-Text $bridgeConsumerHeader 'class\s+Consumer' 'MSVC-side consumer must wrap dynamic bridge loading'
Assert-Text $bridgeConsumerSource 'LoadLibraryA' 'MSVC-side consumer must dynamically load the bridge DLL'
Assert-Text $bridgeConsumerSource 'GetProcAddress' 'MSVC-side consumer must resolve C ABI exports dynamically'
Assert-Text $bridgeBuildScript 'playasa_ffmpeg_modern_bridge\.dll' 'bridge build script must produce DLL'
Assert-Text $bridgeBuildScript 'playasa_ffmpeg_modern_bridge\.lib' 'bridge build script must produce MSVC import lib'
Assert-Text $bridgeBuildScript 'out\\bin\\Win32\\Release Unicode' 'bridge build script must deploy runtime DLLs for player smoke'
Assert-Text $bridgeDef 'playasa_ffmpeg_modern_decode' 'bridge def must list decode export'
Assert-Text $bridgeDef 'playasa_ffmpeg_modern_open_with_h264_nal_length_size' 'bridge def must list H264 NAL length-size open export'
Assert-Text $legacyFilterHeader 'ModernFfmpegBridgeConsumer\.h' 'MPCVideoDec must own the MSVC-side bridge consumer'
Assert-Text $legacyFilterSource 'ModernFfmpegBridgeDecode' 'MPCVideoDec must route first-wave software decode through bridge'
Assert-Text $legacyFilterSource 'IsModernFfmpegBridgeCodec' 'MPCVideoDec must restrict bridge use to first-wave codecs'
Assert-Text $legacyFilterSource 'av_log_set_callback\(LogLibAVCodec\)' 'MPCVideoDec must not let legacy FFmpeg log through CRT stderr'
Assert-Text $legacyFilterSource 'CODEC_ID_H264\)' 'MPCVideoDec must route H264 through bridge eligibility'
Assert-Text $legacyFilterSource 'CODEC_ID_MPEG2VIDEO' 'MPCVideoDec must route MPEG-2 through bridge eligibility'
Assert-Text $legacyFilterSource 'CODEC_ID_WMV3' 'MPCVideoDec must route WMV3 through bridge eligibility'
Assert-Text $legacyFilterSource 'CODEC_ID_VC1' 'MPCVideoDec must route VC-1 through bridge eligibility'
Assert-Text $legacyFilterSource 'm_bUseDXVA = false' 'MPCVideoDec must disable old H264 DXVA path after bridge activation'
Assert-Text $legacyFilterSource 'h264NalLengthSize' 'MPCVideoDec must pass H264 NAL length size into modern bridge'
Assert-Text $legacyFilterSource '!m_bUseModernFfmpegBridge' 'MPCVideoDec must not run legacy MPEG-2 DXVA setup for modern bridge'
Assert-Text $legacyFilterSource 'CODEC_ID_VC1 && !m_bUseModernFfmpegBridge && FFIsInterlaced' 'MPCVideoDec must not run old VC-1 interlace probe for modern bridge'
Assert-Text $adapterSource 'SendH264Packet' 'MPCVideoDec must keep H264 on modern bridge and convert AVC packets in the adapter'
Assert-Text $legacyFilterSource 'int avcRet = avcodec_open' 'MPCVideoDec must keep legacy decoder open isolated from modern bridge codecs'
Assert-Text $legacyFilterSource 'm_modernFfmpegBridge\.Close\(\)' 'MPCVideoDec must close failed modern bridge sessions before fail-closed or DXVA legacy open'
Assert-Text $legacyFilterSource 'bUseModernBridgeCodec && !m_bUseDXVA' 'MPCVideoDec must fail-closed for bridge codecs on software path (RFC-0035 Category B)'
Assert-Text $legacyFilterSource 'fail-closed \(no legacy software fallback\)' 'MPCVideoDec must log fail-closed when modern bridge open fails without DXVA'
Assert-Text $legacyFilterSource '!bUseModernBridgeCodec\s+&&\s+\(m_nThreadNumber > 1\)' 'MPCVideoDec must not initialize legacy decoder threads for modern bridge codecs'
Assert-Text $legacyFilterSource 'm_pAVCtx && m_bLegacyAvcodecOpened && !m_bUseModernFfmpegBridge' 'MPCVideoDec must not flush unopened legacy contexts (RFC-0047 4b legacy-open gate)'
Assert-Text $legacyFilterSource '!wasUsingModernFfmpegBridge\s+&&\s+\(m_nThreadNumber > 1\)' 'MPCVideoDec must not free legacy decoder threads for modern bridge codecs'
Assert-Text $legacyFilterSource "MAKEFOURCC\('X','V','I','X'\)" 'MPCVideoDec must route XVIX alias through bridge'
Assert-Text $legacyFilterSource "MAKEFOURCC\('V','P','6','1'\)" 'MPCVideoDec must route VP61 alias through bridge'
Assert-Text $legacyFilterSource "MAKEFOURCC\('V','P','6','2'\)" 'MPCVideoDec must route VP62 alias through bridge'
Assert-Text $legacyFilterSource "MAKEFOURCC\('W','M','V','3'\)" 'MPCVideoDec must route WMV3 alias through bridge'
Assert-Text $legacyFilterSource "MAKEFOURCC\('W','V','C','1'\)" 'MPCVideoDec must route VC-1 alias through bridge'
Assert-Text $legacyFilterProject 'ModernFfmpegBridgeConsumer\.cpp' 'MPCVideoDec project must compile bridge consumer'
Assert-Text $smokeSource 'avformat_open_input' 'smoke must open a real sample container'
Assert-Text $smokeSource 'DecodeSession' 'smoke must exercise the modern decode adapter'
Assert-Text $smokeSource 'Decoded first frame' 'smoke must verify first-frame decode'
Assert-Text $smokeScript 'MPCVideoDecModernSmoke\.exe' 'smoke script must build and run the smoke executable'
Assert-Text $smokeScript 'g\+\+' 'smoke script must use the same MinGW ABI as the FFmpeg island'
Assert-Text $smokeScript 'libavcodec\.a' 'smoke script must consume MinGW static FFmpeg libraries'
Assert-Text $bridgeSmokeSource 'ffmpeg_modern_bridge\.h' 'bridge smoke must use public C ABI header'
Assert-Text $bridgeSmokeSource 'kFourccWvc1' 'bridge smoke must verify VC-1 bridge mapping'
Assert-Text $bridgeSmokeSource 'kFourccWmv3' 'bridge smoke must verify WMV3 bridge mapping'
Assert-Text $bridgeSmokeScript 'cl\.exe' 'bridge smoke must verify MSVC consumer linking'
Assert-Text $playerSelfcheckScript 'Modern FFmpeg bridge first frame ready' 'player selfcheck must verify modern H264 playback reaches first frame'
if ((Get-Content -LiteralPath $legacyFilterSource -Raw) -match 'modern_ffmpeg|ModernFfmpegDecodeAdapter|src\\Thirdparty\\ffmpeg-modern') {
  throw 'RFC-0024 gate failed: legacy MPCVideoDecFilter.cpp must not include the modern island before smoke tests exist'
}

if (Test-Path -LiteralPath $installRoot) {
  Assert-FileExists (Join-Path $installRoot 'include\libavcodec\avcodec.h')
  Assert-FileExists (Join-Path $installRoot 'include\libavformat\avformat.h')
  Assert-FileExists (Join-Path $installRoot 'lib\libavcodec.a')
  Assert-FileExists (Join-Path $installRoot 'lib\libavformat.a')
  Assert-FileExists (Join-Path $installRoot 'lib\libavutil.a')
  Assert-FileExists (Join-Path $installRoot 'lib\pkgconfig\libavcodec.pc')
  Assert-FileExists (Join-Path $installRoot 'bin\playasa_ffmpeg_modern_bridge.dll')
  Assert-FileExists (Join-Path $installRoot 'bin\libiconv-2.dll')
  Assert-FileExists (Join-Path $installRoot 'bin\libwinpthread-1.dll')
  Assert-FileExists (Join-Path $installRoot 'lib\playasa_ffmpeg_modern_bridge.lib')
}

$runtimeBin = Join-Path $repoRoot 'out\bin\Win32\Release Unicode'
if (Test-Path -LiteralPath $runtimeBin) {
  Assert-FileExists (Join-Path $runtimeBin 'playasa_ffmpeg_modern_bridge.dll')
  Assert-FileExists (Join-Path $runtimeBin 'libiconv-2.dll')
  Assert-FileExists (Join-Path $runtimeBin 'libwinpthread-1.dll')
}

if (Test-Path -LiteralPath $downloadArchive) {
  $actualHash = (Get-FileHash -LiteralPath $downloadArchive -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actualHash -ne 'b072aed6871998cce9b36e7774033105ca29e33632be5b6347f3206898e0756a') {
    throw "RFC-0024 gate failed: archive hash changed to $actualHash"
  }
}

$configureOptions = @(
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
  '--enable-decoder=wmv3',
  '--enable-decoder=h264',
  '--enable-decoder=mpeg2video',
  '--enable-decoder=mpeg1video',
  '--enable-decoder=vc1',
  '--enable-decoder=cook',
  '--enable-decoder=sipr',
  '--enable-decoder=atrac3',
  '--enable-decoder=aac',
  '--enable-decoder=ra_144',
  '--enable-decoder=ra_288',
  '--enable-decoder=wmav1',
  '--enable-decoder=wmav2',
  '--enable-decoder=amrnb',
  '--enable-decoder=amrwb',
  '--enable-decoder=nellymoser',
  '--enable-decoder=qdm2',
  '--enable-decoder=eac3',
  '--enable-decoder=truehd',
  '--enable-decoder=mlp',
  '--enable-decoder=flac',
  '--enable-decoder=pcm_mulaw',
  '--enable-decoder=adpcm_ima_qt',
  '--enable-demuxer=avi',
  '--enable-demuxer=flv',
  '--enable-demuxer=matroska',
  '--enable-demuxer=mov',
  '--enable-parser=mpeg4video',
  '--enable-parser=h263',
  '--enable-parser=vp3',
  '--enable-parser=h264',
  '--enable-parser=mpegvideo',
  '--enable-parser=vc1'
)

$configureOptions | ForEach-Object {
  $configureOption = $_
  $escapedOption = [regex]::Escape($configureOption)
  Assert-Text -Path $expectedFile -Pattern $escapedOption -Description "missing configure option $configureOption"
}

Write-Host 'verify-rfc0024-ffmpeg-modern: OK (FFmpeg 8.1 island pins match)' -ForegroundColor Green
