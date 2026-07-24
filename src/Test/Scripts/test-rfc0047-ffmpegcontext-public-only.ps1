#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 4a: FfmpegContext.c is public dispatch only (no legacy codec private headers).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$ffmpegC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\FfmpegContext.c'
$h264GlueC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaH264LegacyGlue.c'
$vc1GlueC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaVc1LegacyGlue.c'
$mpeg2GlueC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaMpeg2LegacyGlue.c'
$auditScript = Join-Path $repoRoot 'src\BuildScript\audit-rfc0047-ffmpegcontext-dxva-glue.ps1'

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) { throw "RFC-0047 4a gate failed: $Message ($Path)" }
}

function Assert-FileNotContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -match $Pattern) { throw "RFC-0047 4a gate failed: $Message ($Path)" }
}

Assert-FileNotContains $ffmpegC '#\s*include\s+"avcodec\.h"' 'FfmpegContext.c must not include avcodec.h'
Assert-FileNotContains $ffmpegC '#\s*include\s+"mpegvideo\.h"' 'FfmpegContext.c must not include mpegvideo.h'
Assert-FileNotContains $ffmpegC '#\s*include\s+"h264\.h"' 'FfmpegContext.c must not include h264.h'
Assert-FileNotContains $ffmpegC '#\s*include\s+"vc1\.h"' 'FfmpegContext.c must not include vc1.h'
Assert-FileNotContains $ffmpegC '\bCODEC_ID_' 'FfmpegContext.c must not reference CODEC_ID_* directly'
Assert-FileContains $ffmpegC 'FFAvctxIsH264' 'FfmpegContext.c must dispatch via FFAvctxIs* helpers'
Assert-FileContains $h264GlueC 'FFAvctxIsH264' 'H.264 glue must implement FFAvctxIsH264'
Assert-FileContains $vc1GlueC 'FFAvctxIsVc1' 'VC-1 glue must implement FFAvctxIsVc1'
Assert-FileContains $mpeg2GlueC 'FFAvctxIsMpeg2Video' 'MPEG-2 glue must implement FFAvctxIsMpeg2Video'

& powershell -NoProfile -ExecutionPolicy Bypass -File $auditScript -FailIfHits
if ($LASTEXITCODE -ne 0) {
  throw "audit-rfc0047-ffmpegcontext-dxva-glue.ps1 failed with exit $LASTEXITCODE"
}

Write-Host 'test-rfc0047-ffmpegcontext-public-only.ps1: PASS'
