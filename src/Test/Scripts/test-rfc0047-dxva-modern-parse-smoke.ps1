#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 5a: DXVA modern parse ABI contract + MSVC runtime smoke via bridge DLL.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$bridgeDef = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\playasa_ffmpeg_modern_bridge.def'
$h264Header = Join-Path $repoRoot 'src\Thirdparty\pkg\ffmpeg_modern_dxva_h264.h'
$vc1Header = Join-Path $repoRoot 'src\Thirdparty\pkg\ffmpeg_modern_dxva_vc1.h'
$mpeg2Header = Join-Path $repoRoot 'src\Thirdparty\pkg\ffmpeg_modern_dxva_mpeg2.h'
$h264Parser = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegDxvaH264Parser.c'
$vc1Parser = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegDxvaVc1Parser.c'
$mpeg2Parser = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegDxvaMpeg2Parser.c'
$bridgeSmokeSource = Join-Path $repoRoot 'src\Test\MPCVideoDecModernBridgeSmoke\MPCVideoDecModernBridgeSmoke.cpp'
$bridgeSmokeScript = Join-Path $repoRoot 'src\Test\Scripts\test-rfc0024-modern-bridge-smoke.ps1'

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) { throw "RFC-0047 5a gate failed: $Message ($Path)" }
}

foreach ($path in @($bridgeDef, $h264Header, $vc1Header, $mpeg2Header, $h264Parser, $vc1Parser, $mpeg2Parser, $bridgeSmokeSource, $bridgeSmokeScript)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required file: $path"
  }
}

# Bridge DLL must export all DXVA parse entry points consumed by BridgeConsumer TUs.
Assert-FileContains $bridgeDef 'playasa_dxva_h264_parse_create' 'bridge def must export H.264 parse create'
Assert-FileContains $bridgeDef 'playasa_dxva_h264_parse_fill_picture_context' 'bridge def must export H.264 fill_picture_context'
Assert-FileContains $bridgeDef 'playasa_dxva_vc1_parse_buffer' 'bridge def must export VC-1 parse buffer'
Assert-FileContains $bridgeDef 'playasa_dxva_mpeg2_parse_open' 'bridge def must export MPEG-2 parse open'

# Public ABI headers must stay stable for MSVC consumers.
Assert-FileContains $h264Header 'PlayasaDxvaH264ParseOutput' 'H.264 DXVA header must define parse output'
Assert-FileContains $vc1Header 'PlayasaDxvaVc1ParseOutput' 'VC-1 DXVA header must define parse output'
Assert-FileContains $mpeg2Header 'PlayasaDxvaMpeg2ParseOutput' 'MPEG-2 DXVA header must define parse output'
Assert-FileContains $mpeg2Header 'PLAYASA_DXVA_MPEG2_MAX_SLICES' 'MPEG-2 DXVA header must cap slice table'

# Smoke executable must exercise runtime create/open for all three codecs.
Assert-FileContains $bridgeSmokeSource 'CheckDxvaParseExports' 'bridge smoke must runtime-test DXVA parse exports'
Assert-FileContains $bridgeSmokeSource 'playasa_dxva_h264_parse_create' 'bridge smoke must resolve H.264 DXVA parse export'
Assert-FileContains $bridgeSmokeSource 'playasa_dxva_vc1_parse_create' 'bridge smoke must resolve VC-1 DXVA parse export'
Assert-FileContains $bridgeSmokeSource 'playasa_dxva_mpeg2_parse_create' 'bridge smoke must resolve MPEG-2 DXVA parse export'

& powershell -NoProfile -ExecutionPolicy Bypass -File $bridgeSmokeScript
if ($LASTEXITCODE -ne 0) {
  throw "test-rfc0024-modern-bridge-smoke.ps1 failed with exit $LASTEXITCODE"
}

Write-Host 'test-rfc0047-dxva-modern-parse-smoke: PASS (contract + runtime)' -ForegroundColor Green
