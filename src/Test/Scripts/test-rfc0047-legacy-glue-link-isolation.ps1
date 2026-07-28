#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 4c-i: libavcodec_gcc linkage isolated in MPCVideoDecLegacyGlue.vcxproj.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$mpcDir = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec'
$filterProject = Join-Path $mpcDir 'MPCVideoDec.vcxproj'
$glueProject = Join-Path $mpcDir 'MPCVideoDecLegacyGlue.vcxproj'

function Assert-FileExists([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
}

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  Assert-FileExists $Path
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) { throw "RFC-0047 4c-i gate failed: $Message ($Path)" }
}

function Assert-FileNotContains([string]$Path, [string]$Pattern, [string]$Message) {
  Assert-FileExists $Path
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -match $Pattern) { throw "RFC-0047 4c-i gate failed: $Message ($Path)" }
}

Assert-FileExists $glueProject
Assert-FileContains $glueProject 'DxvaH264LegacyGlue\.c' 'glue project must compile H.264 legacy compartment'
Assert-FileContains $glueProject 'DxvaVc1LegacyGlue\.c' 'glue project must compile VC-1 legacy compartment'
Assert-FileContains $glueProject 'DxvaMpeg2LegacyGlue\.c' 'glue project must compile MPEG-2 legacy compartment'
Assert-FileContains $glueProject 'FfmpegContext\.c' 'glue project must compile FfmpegContext dispatch layer'
Assert-FileContains $glueProject 'libavcodec_gcc\.lib' 'glue project must link libavcodec_gcc'

Assert-FileContains $filterProject 'MPCVideoDecLegacyGlue\.vcxproj' 'MPCVideoDec must reference legacy glue static lib'
Assert-FileNotContains $filterProject 'libavcodec_gcc' 'MPCVideoDec must not link libavcodec_gcc directly'
Assert-FileNotContains $filterProject 'DxvaH264LegacyGlue\.c' 'legacy glue sources must not compile in MPCVideoDec'
Assert-FileNotContains $filterProject 'FfmpegContext\.c' 'FfmpegContext must compile only in legacy glue lib'

Write-Host 'test-rfc0047-legacy-glue-link-isolation.ps1: PASS'
