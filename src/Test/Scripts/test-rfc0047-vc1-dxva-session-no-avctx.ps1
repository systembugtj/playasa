#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 4c-ii: VC-1 DXVA session can bind without AVCodecContext when modern bridge is used.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$sessionCpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaVc1Session.cpp'
$vc1Cpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DXVADecoderVC1.cpp'
$ffmpegHeader = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\FfmpegContext.h'
$legacyGlueC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaVc1LegacyGlue.c'

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) { throw "RFC-0047 4c-ii gate failed: $Message ($Path)" }
}

function Assert-FileNotContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -match $Pattern) { throw "RFC-0047 4c-ii gate failed: $Message ($Path)" }
}

Assert-FileContains $ffmpegHeader 'FFVC1IsModernDxvaParseAvailable' 'must declare VC-1 modern parse availability probe'
Assert-FileContains $sessionCpp 'FFVC1IsModernDxvaParseAvailable' 'session TU must implement availability probe'
Assert-FileContains $sessionCpp 'FFVC1ReadAvctxExtradata' 'session must seed extradata via legacy helper'
Assert-FileNotContains $sessionCpp '#\s*include\s+"avcodec\.h"' 'DxvaVc1Session must not include avcodec.h'
Assert-FileContains $vc1Cpp 'FFVC1IsModernDxvaParseAvailable' 'decoder must probe modern parse before session bind'
Assert-FileContains $vc1Cpp 'FFVC1CreateDxvaSession\s*\(\s*FFVC1IsModernDxvaParseAvailable' 'decoder must pass NULL avctx when modern parse is available'
Assert-FileContains $legacyGlueC 'FFVC1ReadAvctxExtradata' 'legacy glue must implement avctx extradata reader'

Write-Host 'test-rfc0047-vc1-dxva-session-no-avctx.ps1: PASS'
