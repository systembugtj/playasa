#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047: inventory remaining H.264 private-struct glue in FfmpegContext.c.

.DESCRIPTION
  Tracks H264Context / av_h264_decode_frame usage that blocks removing libavcodec_gcc.
  Writes src/Thirdparty/ffmpeg-modern/rfc0047-ffmpegcontext-h264-glue.txt
#>
[CmdletBinding()]
param(
  [switch]$FailIfEmpty
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$ffmpegC = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\FfmpegContext.c'
$outFile = Join-Path $repoRoot 'src\Thirdparty\ffmpeg-modern\rfc0047-ffmpegcontext-h264-glue.txt'

$patterns = @(
  @{ Name = 'H264Context'; Regex = '\bH264Context\b' },
  @{ Name = 'av_h264_decode_frame'; Regex = '\bav_h264_decode_frame\b' },
  @{ Name = 'h264.h'; Regex = '#\s*include\s+"h264\.h"' },
  @{ Name = 'FFH264DecodeBuffer'; Regex = '\bFFH264DecodeBuffer\b' },
  @{ Name = 'FFH264BuildPicParams'; Regex = '\bFFH264BuildPicParams\b' }
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
      $hits.Add(('{0}:{1}: {2}' -f $ffmpegC, $lineNo, $line.Trim()))
      break
    }
  }
}

$header = @(
  '# RFC-0047 FfmpegContext H.264 glue inventory'
  "# Generated: $(Get-Date -Format o)"
  "# Source: $ffmpegC"
  "# Hit count: $($hits.Count)"
  ''
)

$header + $hits | Set-Content -LiteralPath $outFile -Encoding UTF8

Write-Host "audit-rfc0047-ffmpegcontext-h264-glue: $($hits.Count) hits -> $outFile"

if ($FailIfEmpty -and $hits.Count -gt 0) {
  throw "RFC-0047 H.264 glue still present ($($hits.Count) hits)"
}

exit 0
