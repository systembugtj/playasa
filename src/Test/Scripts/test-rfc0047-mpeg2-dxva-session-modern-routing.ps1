#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 4c-ii: DxvaMpeg2Session routes through modern parse bridge when available.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$sessionCpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaMpeg2Session.cpp'
$bridgeConsumerCpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegDxvaMpeg2BridgeConsumer.cpp'
$bridgeDef = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\playasa_ffmpeg_modern_bridge.def'
$dxvaHeader = Join-Path $repoRoot 'src\Thirdparty\pkg\ffmpeg_modern_dxva_mpeg2.h'
$parserC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegDxvaMpeg2Parser.c'

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) { throw "RFC-0047 4c-ii gate failed: $Message ($Path)" }
}

Assert-FileContains $sessionCpp 'ModernFfmpegDxvaMpeg2BridgeConsumer' 'DxvaMpeg2Session must include modern bridge consumer'
Assert-FileContains $sessionCpp 'use_modern' 'DxvaMpeg2Session must track modern parse routing'
Assert-FileContains $sessionCpp 'ParseBuffer' 'DxvaMpeg2Session must call parse_buffer for modern path'
Assert-FileContains $bridgeConsumerCpp 'playasa_dxva_mpeg2_parse_buffer' 'bridge consumer must load parse_buffer export'
Assert-FileContains $bridgeDef 'playasa_dxva_mpeg2_parse_create' 'bridge def must export MPEG-2 parse create'
Assert-FileContains $bridgeDef 'playasa_dxva_mpeg2_parse_buffer' 'bridge def must export MPEG-2 parse buffer'
Assert-FileContains $dxvaHeader 'playasa_dxva_mpeg2_parse_buffer' 'DXVA MPEG-2 header must declare parse_buffer'
Assert-FileContains $parserC 'playasa_dxva_mpeg2_parse_buffer' 'modern island must implement MPEG-2 parse_buffer'

Write-Host 'test-rfc0047-mpeg2-dxva-session-modern-routing.ps1: PASS'
