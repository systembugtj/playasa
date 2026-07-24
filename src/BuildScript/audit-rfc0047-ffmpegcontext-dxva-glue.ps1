#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047: inventory remaining DXVA private-struct glue in FfmpegContext.c.

.DESCRIPTION
  Tracks H264/VC-1/MPEG-2 private readers that must live in Dxva*LegacyGlue.c compartments.
  Writes src/Thirdparty/ffmpeg-modern/rfc0047-ffmpegcontext-dxva-glue.txt
#>
[CmdletBinding()]
param(
  [switch]$FailIfHits
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$ffmpegC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\FfmpegContext.c'
$outFile = Join-Path $repoRoot 'src\Thirdparty\ffmpeg-modern\rfc0047-ffmpegcontext-dxva-glue.txt'

$patterns = @(
  @{ Name = 'H264Context'; Regex = '\bH264Context\b' },
  @{ Name = 'VC1Context'; Regex = '\bVC1Context\b' },
  @{ Name = 'Mpeg1Context'; Regex = '\bMpeg1Context\b' },
  @{ Name = 'MpegEncContext'; Regex = '\bMpegEncContext\b' },
  @{ Name = 'h264.h'; Regex = '#\s*include\s+"h264\.h"' },
  @{ Name = 'vc1.h'; Regex = '#\s*include\s+"vc1\.h"' },
  @{ Name = 'mpegvideo.h'; Regex = '#\s*include\s+"mpegvideo\.h"' },
  @{ Name = 'avcodec.h'; Regex = '#\s*include\s+"avcodec\.h"' },
  @{ Name = 'avcodec_decode_video'; Regex = '\bavcodec_decode_video\b' },
  @{ Name = 'av_h264_decode_frame'; Regex = '\bav_h264_decode_frame\b' },
  @{ Name = 'av_vc1_decode_frame'; Regex = '\bav_vc1_decode_frame\b' },
  @{ Name = 'FFH264BuildPicParams'; Regex = '\bFFH264BuildPicParams\b' },
  @{ Name = 'FFMpeg2ReadPictureContext'; Regex = '\bFFMpeg2ReadPictureContext\b' },
  @{ Name = 'FFVC1UpdatePictureParam'; Regex = '\bFFVC1UpdatePictureParam\b' }
)

if (-not (Test-Path -LiteralPath $ffmpegC)) {
  throw "Missing FfmpegContext.c: $ffmpegC"
}

$lines = Get-Content -LiteralPath $ffmpegC
$hits = New-Object System.Collections.Generic.List[string]

for ($i = 0; $i -lt $lines.Count; $i++) {
  $lineNo = $i + 1
  $line = $lines[$i]
  foreach ($pattern in $patterns) {
    if ($line -match $pattern.Regex) {
      $hits.Add(('{0}:{1}: [{2}] {3}' -f $ffmpegC, $lineNo, $pattern.Name, $line.Trim()))
      break
    }
  }
}

$header = @(
  '# RFC-0047 FfmpegContext DXVA glue inventory'
  "# Generated: $(Get-Date -Format o)"
  "# Source: $ffmpegC"
  "# Hit count: $($hits.Count)"
  ''
)

$header + $hits | Set-Content -LiteralPath $outFile -Encoding UTF8

Write-Host "audit-rfc0047-ffmpegcontext-dxva-glue: $($hits.Count) hits -> $outFile"

if ($FailIfHits -and $hits.Count -gt 0) {
  throw "RFC-0047 FfmpegContext DXVA glue still present ($($hits.Count) hits)"
}

exit 0
