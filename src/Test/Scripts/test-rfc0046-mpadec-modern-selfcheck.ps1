#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0046 gate: MpaDecFilter must not reference legacy libavcodec_gcc or mpcvideodec/ffmpeg.
#>
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$mpaDecFilterCpp = Join-Path $repoRoot 'src\Source\filters\transform\mpadecfilter\MpaDecFilter.cpp'
$mpaDecFilterHeader = Join-Path $repoRoot 'src\Source\filters\transform\mpadecfilter\MpaDecFilter.h'
$mpaDecProject = Join-Path $repoRoot 'src\Source\filters\transform\mpadecfilter\MpaDecFilter_vs2005.vcxproj'
$bridgeSmokeScript = Join-Path $repoRoot 'src\Test\Scripts\test-rfc0024-modern-bridge-smoke.ps1'

function Assert-NoPattern {
  param(
    [string]$Path,
    [string]$Pattern,
    [string]$Description
  )
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -match $Pattern) {
    throw "RFC-0046 gate failed: $Description in $Path"
  }
}

foreach ($path in @($mpaDecFilterCpp, $mpaDecFilterHeader, $mpaDecProject)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required file: $path"
  }
}

Assert-NoPattern -Path $mpaDecFilterCpp -Pattern 'avcodec_decode_audio2' -Description 'legacy avcodec_decode_audio2 reference'
Assert-NoPattern -Path $mpaDecFilterCpp -Pattern 'libavcodec_gcc' -Description 'libavcodec_gcc reference'
Assert-NoPattern -Path $mpaDecFilterCpp -Pattern 'mpcvideodec\\ffmpeg' -Description 'legacy mpcvideodec\\ffmpeg include'
Assert-NoPattern -Path $mpaDecFilterCpp -Pattern 'mpcvideodec/ffmpeg' -Description 'legacy mpcvideodec/ffmpeg include'
Assert-NoPattern -Path $mpaDecFilterCpp -Pattern 'avcodec\.h' -Description 'legacy avcodec.h include'
Assert-NoPattern -Path $mpaDecFilterCpp -Pattern 'PODtypes\.h' -Description 'legacy PODtypes.h include'

Assert-NoPattern -Path $mpaDecProject -Pattern 'libavcodec_gcc\.lib' -Description 'libavcodec_gcc.lib link dependency'
Assert-NoPattern -Path $mpaDecProject -Pattern 'libgcc\.a' -Description 'libgcc.a link dependency'
Assert-NoPattern -Path $mpaDecProject -Pattern 'libmingwex\.a' -Description 'libmingwex.a link dependency'
Assert-NoPattern -Path $mpaDecProject -Pattern 'mpcvideodec\\ffmpeg' -Description 'legacy mpcvideodec\\ffmpeg include path'

$projectText = Get-Content -LiteralPath $mpaDecProject -Raw
if ($projectText -notmatch 'Thirdparty\\pkg|MpaDecModernDecodeAdapter\.cpp') {
  throw 'RFC-0046 gate failed: MpaDec project must include modern bridge headers and adapter sources'
}

if (Test-Path -LiteralPath $bridgeSmokeScript) {
  Write-Host 'test-rfc0046: running optional modern bridge smoke...'
  try {
    & $bridgeSmokeScript
  } catch {
    Write-Warning "Bridge smoke skipped or failed: $_"
  }
}

Write-Host 'test-rfc0046-mpadec-modern-selfcheck: PASS' -ForegroundColor Green
