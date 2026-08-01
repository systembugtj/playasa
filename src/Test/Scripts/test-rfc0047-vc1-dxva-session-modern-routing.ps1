#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 4c-ii: DxvaVc1Session routes through modern parse bridge when available.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$sessionCpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaVc1Session.cpp'
$bridgeConsumerCpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegDxvaVc1BridgeConsumer.cpp'
$bridgeDef = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\playasa_ffmpeg_modern_bridge.def'
$dxvaHeader = Join-Path $repoRoot 'src\Thirdparty\pkg\ffmpeg_modern_dxva_vc1.h'
$parserCpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegDxvaVc1Parser.c'

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) { throw "RFC-0047 4c-ii gate failed: $Message ($Path)" }
}

Assert-FileContains $sessionCpp 'ModernFfmpegDxvaVc1BridgeConsumer' 'DxvaVc1Session must include modern bridge consumer'
Assert-FileContains $sessionCpp 'use_modern' 'DxvaVc1Session must track modern parse routing'
Assert-FileContains $sessionCpp 'ParseBuffer' 'DxvaVc1Session must call parse_buffer for modern path'
Assert-FileContains $bridgeConsumerCpp 'playasa_dxva_vc1_parse_buffer' 'bridge consumer must load parse_buffer export'
Assert-FileContains $bridgeDef 'playasa_dxva_vc1_parse_create' 'bridge def must export VC-1 parse create'
Assert-FileContains $bridgeDef 'playasa_dxva_vc1_parse_buffer' 'bridge def must export VC-1 parse buffer'
Assert-FileContains $dxvaHeader 'playasa_dxva_vc1_parse_buffer' 'DXVA VC-1 header must declare parse_buffer'
Assert-FileContains $parserCpp 'playasa_dxva_vc1_parse_buffer' 'modern island must implement VC-1 parse_buffer'

Write-Host 'test-rfc0047-vc1-dxva-session-modern-routing.ps1: PASS'
