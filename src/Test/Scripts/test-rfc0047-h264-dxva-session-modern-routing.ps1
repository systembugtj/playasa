#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 3c: DxvaH264Session routes through modern parse bridge when available.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$sessionCpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaH264Session.cpp'
$bridgeConsumerCpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegDxvaH264BridgeConsumer.cpp'
$bridgeDef = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\playasa_ffmpeg_modern_bridge.def'
$dxvaHeader = Join-Path $repoRoot 'src\Thirdparty\pkg\ffmpeg_modern_dxva_h264.h'

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) { throw "RFC-0047 3c gate failed: $Message ($Path)" }
}

Assert-FileContains $sessionCpp 'ModernFfmpegDxvaH264BridgeConsumer' 'DxvaH264Session must include modern bridge consumer'
Assert-FileContains $sessionCpp 'use_modern' 'DxvaH264Session must track modern parse routing'
Assert-FileContains $sessionCpp 'FillPictureContext' 'DxvaH264Session must call fill_picture_context for modern path'
Assert-FileContains $sessionCpp 'UpdateSliceLong' 'DxvaH264Session must route slice long updates'
Assert-FileContains $bridgeConsumerCpp 'playasa_dxva_h264_parse_fill_picture_context' 'bridge consumer must load fill_picture_context export'
Assert-FileContains $bridgeDef 'playasa_dxva_h264_parse_fill_picture_context' 'bridge def must export fill_picture_context'
Assert-FileContains $dxvaHeader 'playasa_dxva_h264_parse_fill_picture_context' 'DXVA H.264 header must declare fill_picture_context'

Write-Host 'test-rfc0047-h264-dxva-session-modern-routing.ps1: PASS'
