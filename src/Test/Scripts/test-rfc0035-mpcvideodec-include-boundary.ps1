#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0035 gate: MPCVideoDec include/link boundary while legacy ffmpeg tree remains.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$mpcDir = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec'
$filterProject = Join-Path $mpcDir 'MPCVideoDec.vcxproj'
$glueProject = Join-Path $mpcDir 'MPCVideoDecLegacyGlue.vcxproj'
$filterCpp = Join-Path $mpcDir 'MPCVideoDecFilter.cpp'
$glueC = Join-Path $mpcDir 'FfmpegContext.c'
$auditScript = Join-Path $repoRoot 'src\BuildScript\audit-rfc0035-legacy-ffmpeg-refs.ps1'

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) { throw "RFC-0035 include-boundary gate failed: $Message ($Path)" }
}

function Assert-FileNotContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -match $Pattern) { throw "RFC-0035 include-boundary gate failed: $Message ($Path)" }
}

# Link boundary: filter TU links glue lib only; glue owns libavcodec_gcc + legacy dispatch.
Assert-FileContains $filterProject 'MPCVideoDecLegacyGlue\.vcxproj' 'MPCVideoDec must reference legacy glue static lib'
Assert-FileNotContains $filterProject 'libavcodec_gcc' 'MPCVideoDec must not link libavcodec_gcc directly'
Assert-FileNotContains $filterProject 'FfmpegContext\.c' 'FfmpegContext.c must compile only in legacy glue lib'
Assert-FileContains $glueProject 'libavcodec_gcc\.lib' 'legacy glue must link libavcodec_gcc'
Assert-FileContains $glueProject 'FfmpegContext\.c' 'legacy glue must compile FfmpegContext dispatch'
Assert-FileContains $glueProject 'DxvaH264LegacyGlue\.c' 'legacy glue must compile H.264 compartment'
Assert-FileContains $glueProject 'DxvaVc1LegacyGlue\.c' 'legacy glue must compile VC-1 compartment'
Assert-FileContains $glueProject 'DxvaMpeg2LegacyGlue\.c' 'legacy glue must compile MPEG-2 compartment'

# Include boundary: both projects still include legacy ffmpeg headers until tree deletion.
Assert-FileContains $filterProject 'ffmpeg;ffmpeg\\libavcodec;ffmpeg\\libavutil' 'MPCVideoDec must pin legacy ffmpeg include paths'
Assert-FileContains $glueProject 'ffmpeg;ffmpeg\\libavcodec;ffmpeg\\libavutil' 'legacy glue must pin legacy ffmpeg include paths'

# Active legacy software decode path remains in filter until non-DXVA codecs retire.
Assert-FileContains $filterCpp 'avcodec_decode_video' 'MPCVideoDecFilter still owns legacy software decode path'
Assert-FileContains $filterCpp 'NeedsLegacyAvcodecOpen' 'MPCVideoDecFilter must gate legacy avcodec_open'
Assert-FileNotContains $glueC '#\s*include\s+"h264\.h"' 'FfmpegContext.c must not include legacy private codec headers'

& powershell -NoProfile -ExecutionPolicy Bypass -File $auditScript
if ($LASTEXITCODE -ne 0) {
  throw "audit-rfc0035-legacy-ffmpeg-refs.ps1 failed with exit $LASTEXITCODE"
}

Write-Host 'test-rfc0035-mpcvideodec-include-boundary: PASS' -ForegroundColor Green
