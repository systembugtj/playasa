#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 3d: H.264 DXVA session can bind without AVCodecContext when modern bridge is used.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$sessionCpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaH264Session.cpp'
$h264Cpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DXVADecoderH264.cpp'
$ffmpegHeader = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\FfmpegContext.h'
$legacyGlueC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaH264LegacyGlue.c'

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) { throw "RFC-0047 3d gate failed: $Message ($Path)" }
}

function Assert-FileNotContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -match $Pattern) { throw "RFC-0047 3d gate failed: $Message ($Path)" }
}

Assert-FileContains $ffmpegHeader 'FFH264IsModernDxvaParseAvailable' 'must declare modern parse availability probe'
Assert-FileContains $sessionCpp 'FFH264IsModernDxvaParseAvailable' 'session TU must implement availability probe'
Assert-FileContains $sessionCpp 'FFH264ReadAvctxExtradata' 'session must seed extradata via legacy helper'
Assert-FileNotContains $sessionCpp '#\s*include\s+"avcodec\.h"' 'DxvaH264Session must not include avcodec.h'
Assert-FileContains $h264Cpp 'FFH264IsModernDxvaParseAvailable' 'decoder must probe modern parse before session bind'
Assert-FileContains $h264Cpp 'FFH264CreateDxvaSession\s*\(\s*FFH264IsModernDxvaParseAvailable' 'decoder must pass NULL avctx when modern parse is available'
Assert-FileContains $legacyGlueC 'FFH264ReadAvctxExtradata' 'legacy glue must implement avctx extradata reader'

Write-Host 'test-rfc0047-h264-dxva-session-no-avctx.ps1: PASS'
