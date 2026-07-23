#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0033 gate: H.264/VC-1 DXVA picture contracts exist and decoders consume readers.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$dxvaHeader = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaCodecContext.h'
$ffmpegHeader = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\FfmpegContext.h'
$ffmpegC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\FfmpegContext.c'
$h264LegacyGlueC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DxvaH264LegacyGlue.c'
$h264Cpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DXVADecoderH264.cpp'
$vc1Cpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\DXVADecoderVC1.cpp'
$auditScript = Join-Path $repoRoot 'src\BuildScript\audit-rfc0033-dxva-h264-vc1-refs.ps1'

function Assert-Contains {
  param([string]$Path, [string]$Pattern, [string]$Description)
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) {
    throw "RFC-0033 gate failed: missing $Description in $Path"
  }
}

foreach ($path in @($dxvaHeader, $ffmpegHeader, $ffmpegC, $h264LegacyGlueC, $h264Cpp, $vc1Cpp)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required file: $path"
  }
}

Assert-Contains -Path $dxvaHeader -Pattern 'DxvaH264PictureContext' -Description 'DxvaH264PictureContext'
Assert-Contains -Path $dxvaHeader -Pattern 'DxvaVc1PictureContext' -Description 'DxvaVc1PictureContext'
Assert-Contains -Path $ffmpegHeader -Pattern 'FFH264ReadPictureContext' -Description 'FFH264ReadPictureContext declaration'
Assert-Contains -Path $ffmpegHeader -Pattern 'FFVC1ReadPictureContext' -Description 'FFVC1ReadPictureContext declaration'
# RFC-0047 phase 3b moved H.264 readers into DxvaH264LegacyGlue.c; VC-1 remains in FfmpegContext.c.
Assert-Contains -Path $h264LegacyGlueC -Pattern 'FFH264ReadPictureContext' -Description 'FFH264ReadPictureContext implementation'
Assert-Contains -Path $ffmpegC -Pattern 'FFVC1ReadPictureContext' -Description 'FFVC1ReadPictureContext implementation'
Assert-Contains -Path $h264Cpp -Pattern 'FFH264ReadPictureContext' -Description 'H.264 decoder contract consumption'
Assert-Contains -Path $vc1Cpp -Pattern 'FFVC1ReadPictureContext' -Description 'VC-1 decoder contract consumption'

# H.264 decoder must not cast to H264Context directly (private struct isolation).
$h264Text = Get-Content -LiteralPath $h264Cpp -Raw
if ($h264Text -match '\bH264Context\b') {
  throw 'RFC-0033 gate failed: DXVADecoderH264.cpp still references H264Context'
}
$vc1Text = Get-Content -LiteralPath $vc1Cpp -Raw
if ($vc1Text -match '\bVC1Context\b') {
  throw 'RFC-0033 gate failed: DXVADecoderVC1.cpp still references VC1Context'
}

if (Test-Path -LiteralPath $auditScript) {
  & powershell -NoProfile -ExecutionPolicy Bypass -File $auditScript
  if ($LASTEXITCODE -ne 0) {
    throw "audit-rfc0033-dxva-h264-vc1-refs.ps1 failed with exit $LASTEXITCODE"
  }
}

Write-Host 'test-rfc0033-h264-dxva-selfcheck: PASS (contract + decoder wire-up + audit)' -ForegroundColor Green
exit 0
