#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0033 phase 1: inventory H.264 / VC-1 DXVA touchpoints that still read
  FFmpeg private structs (H264Context / VC1Context).

.DESCRIPTION
  Scans mpcvideodec (excluding the vendored ffmpeg tree sources themselves for
  decoder internals) and writes a field-usage style inventory for contract design.

  Writes:
    src/Thirdparty/ffmpeg-modern/mpcvideodec-dxva-h264-vc1-refs.txt
#>
[CmdletBinding()]
param(
  [switch]$FailIfEmpty
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$scanRoot = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec'
$outFile = Join-Path $repoRoot 'src\Thirdparty\ffmpeg-modern\mpcvideodec-dxva-h264-vc1-refs.txt'

# Vendored FFmpeg internals are out of scope; we care about project glue that
# still reaches into private codec contexts.
$excludePathFragments = @(
  'mpcvideodec\ffmpeg\',
  'mpcvideodec\modern_ffmpeg\'
)

$patterns = @(
  @{ Name = 'H264Context'; Regex = '\bH264Context\b' },
  @{ Name = 'FFH264*'; Regex = '\bFFH264\w+\b' },
  @{ Name = 'DXVADecoderH264'; Regex = '\bDXVADecoderH264\b|CDXVADecoderH264\b' },
  @{ Name = 'DXVA_PicParams_H264'; Regex = '\bDXVA_PicParams_H264\b' },
  @{ Name = 'VC1Context'; Regex = '\bVC1Context\b' },
  @{ Name = 'FFVC1*'; Regex = '\bFFVC1\w+\b' },
  @{ Name = 'DXVADecoderVC1'; Regex = '\bDXVADecoderVC1\b|CDXVADecoderVC1\b' },
  @{ Name = 'DxvaMpeg2PictureContext'; Regex = '\bDxvaMpeg2PictureContext\b' }
)

function Test-ExcludedPath {
  param([string]$FullPath)
  $normalized = $FullPath.Replace('/', '\')
  foreach ($frag in $excludePathFragments) {
    if ($normalized -like "*$frag*") {
      return $true
    }
  }
  return $false
}

$extensions = @('*.c', '*.cpp', '*.h', '*.hpp')
$files = @()
foreach ($ext in $extensions) {
  $files += Get-ChildItem -Path $scanRoot -Recurse -File -Filter $ext -ErrorAction SilentlyContinue
}

$hits = New-Object System.Collections.Generic.List[string]
$total = 0
$fileSet = New-Object 'System.Collections.Generic.HashSet[string]'

foreach ($file in $files) {
  if (Test-ExcludedPath -FullPath $file.FullName) {
    continue
  }

  $rel = $file.FullName.Substring($repoRoot.Path.Length).TrimStart('\', '/')
  $lines = Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue
  if (-not $lines) {
    continue
  }

  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    foreach ($pat in $patterns) {
      if ($line -match $pat.Regex) {
        $hits.Add(("{0}:{1}: [{2}] {3}" -f $rel, ($i + 1), $pat.Name, $line.Trim()))
        [void]$fileSet.Add($rel)
        $total++
        break
      }
    }
  }
}

$header = @(
  "# RFC-0033 DXVA H.264 / VC-1 private-struct inventory",
  "# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
  "# Scan root: $scanRoot",
  "# Hits: $total  Files: $($fileSet.Count)",
  "# Next: design DxvaH264PictureContext / DxvaVc1PictureContext mirroring DxvaMpeg2PictureContext",
  ""
)

$dir = Split-Path -Parent $outFile
if (-not (Test-Path -LiteralPath $dir)) {
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

Set-Content -LiteralPath $outFile -Value ($header + $hits) -Encoding UTF8

Write-Host "RFC-0033 audit wrote $outFile ($total hits / $($fileSet.Count) files)"

if ($FailIfEmpty -and $total -eq 0) {
  throw 'Expected H.264/VC-1 DXVA references but found none.'
}

exit 0
