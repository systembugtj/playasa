#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 3e: legacy VC-1 glue compartmentalized; FfmpegContext.c no longer includes vc1.h.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$ffmpegC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\FfmpegContext.c'
$glueC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaVc1LegacyGlue.c'
$h264GlueC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaH264LegacyGlue.c'

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) { throw "RFC-0047 3e gate failed: $Message ($Path)" }
}

function Assert-FileNotContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -match $Pattern) { throw "RFC-0047 3e gate failed: $Message ($Path)" }
}

Assert-FileNotContains $ffmpegC '#\s*include\s+"vc1\.h"' 'FfmpegContext.c must not include legacy vc1.h'
Assert-FileNotContains $ffmpegC '\bVC1Context\b' 'FfmpegContext.c must not reference VC1Context'
Assert-FileNotContains $h264GlueC 'FFVC1UpdatePictureParam' 'H.264 legacy glue must not own VC-1 readers'
Assert-FileContains $glueC '#\s*include\s+"vc1\.h"' 'DxvaVc1LegacyGlue.c must own legacy vc1.h include'
Assert-FileContains $glueC 'FFVC1ReadPictureContext' 'VC-1 legacy glue must implement FFVC1ReadPictureContext'
Assert-FileContains $glueC 'FFVC1UpdatePictureParam' 'VC-1 legacy glue must implement FFVC1UpdatePictureParam'
Assert-FileContains $glueC 'FFIsSkipped' 'VC-1 legacy glue must implement FFIsSkipped'

Write-Host 'test-rfc0047-vc1-dxva-legacy-glue-compartment.ps1: PASS'
