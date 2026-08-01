#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 4c-ii: MPEG-2 DXVA session can bind without AVCodecContext when modern bridge is used.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$sessionCpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaMpeg2Session.cpp'
$mpeg2Cpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DXVADecoderMpeg2.cpp'
$ffmpegHeader = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\FfmpegContext.h'
$legacyGlueC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaMpeg2LegacyGlue.c'

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

Assert-FileContains $ffmpegHeader 'FFMpeg2IsModernDxvaParseAvailable' 'must declare MPEG-2 modern parse availability probe'
Assert-FileContains $sessionCpp 'FFMpeg2IsModernDxvaParseAvailable' 'session TU must implement availability probe'
Assert-FileContains $sessionCpp 'FFMpeg2ReadAvctxExtradata' 'session must seed extradata via legacy helper'
Assert-FileNotContains $sessionCpp '#\s*include\s+"avcodec\.h"' 'DxvaMpeg2Session must not include avcodec.h'
Assert-FileContains $mpeg2Cpp 'FFMpeg2IsModernDxvaParseAvailable' 'decoder must probe modern parse before session bind'
Assert-FileContains $mpeg2Cpp 'FFMpeg2CreateDxvaSession\s*\(\s*FFMpeg2IsModernDxvaParseAvailable' 'decoder must pass NULL avctx when modern parse is available'
Assert-FileContains $legacyGlueC 'FFMpeg2ReadAvctxExtradata' 'legacy glue must implement avctx extradata reader'

Write-Host 'test-rfc0047-mpeg2-dxva-session-no-avctx.ps1: PASS'
