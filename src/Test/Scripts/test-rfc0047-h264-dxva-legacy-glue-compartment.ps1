#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 3b: legacy H.264 glue compartmentalized; FfmpegContext.c no longer includes h264.h.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$ffmpegC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\FfmpegContext.c'
$glueC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaH264LegacyGlue.c'
$dxvaHeader = Join-Path $repoRoot 'src\Thirdparty\pkg\ffmpeg_modern_dxva_h264.h'
$parserCpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegDxvaH264Parser.c'

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) { throw "RFC-0047 3b gate failed: $Message ($Path)" }
}

function Assert-FileNotContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -match $Pattern) { throw "RFC-0047 3b gate failed: $Message ($Path)" }
}

Assert-FileNotContains $ffmpegC '#\s*include\s+"h264\.h"' 'FfmpegContext.c must not include legacy h264.h'
Assert-FileContains $glueC '#\s*include\s+"h264\.h"' 'DxvaH264LegacyGlue.c must own legacy h264.h include'
Assert-FileContains $glueC 'FFH264BuildPicParams' 'legacy glue must implement FFH264BuildPicParams'
Assert-FileContains $dxvaHeader 'playasa_dxva_h264_parse_create' 'DXVA H.264 parse ABI must be declared'
Assert-FileContains $parserCpp 'playasa_dxva_h264_parse_create' 'ModernFfmpegDxvaH264Parser must export parse ABI'

Write-Host 'test-rfc0047-h264-dxva-legacy-glue-compartment.ps1: PASS'
