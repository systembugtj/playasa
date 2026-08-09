#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0035: inventory MPCVideoDec ffCodecs entries that still require legacy libavcodec software decode.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$filterCpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\MPCVideoDecFilter.cpp'
$outFile = Join-Path $repoRoot 'src\Thirdparty\ffmpeg-modern\rfc0035-legacy-only-codecs.txt'

if (-not (Test-Path -LiteralPath $filterCpp)) {
  throw "Missing MPCVideoDecFilter.cpp: $filterCpp"
}

$modernBridgeCodecIds = @(
  'CODEC_ID_MPEG4'
  'CODEC_ID_FLV1'
  'CODEC_ID_VP6'
  'CODEC_ID_VP6F'
  'CODEC_ID_VP6A'
  'CODEC_ID_WMV1'
  'CODEC_ID_WMV2'
  'CODEC_ID_WMV3'
  'CODEC_ID_H264'
  'CODEC_ID_MPEG2VIDEO'
  'CODEC_ID_VC1'
  'CODEC_ID_RV10'
  'CODEC_ID_RV20'
  'CODEC_ID_RV30'
  'CODEC_ID_RV40'
)

$text = Get-Content -LiteralPath $filterCpp -Raw
$ffCodecsBlock = if ($text -match '(?s)FFMPEG_CODECS\s+ffCodecs\[\]\s*=\s*\{(.*?)\n\};') { $Matches[1] } else { '' }
if (-not $ffCodecsBlock) {
  throw 'RFC-0035 audit failed: could not parse ffCodecs[] block'
}

$activeLines = @(
  ($ffCodecsBlock -split "`r?`n") |
  Where-Object { $_ -match 'CODEC_ID_' -and $_ -notmatch '^\s*//' }
)
$entries = [regex]::Matches(($activeLines -join "`n"), 'CODEC_ID_(\w+)') | ForEach-Object { $_.Value } | Sort-Object -Unique
$legacyOnly = @($entries | Where-Object { $modernBridgeCodecIds -notcontains $_ })
$modernCapable = @($entries | Where-Object { $modernBridgeCodecIds -contains $_ })

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# RFC-0035 legacy-only codec inventory')
[void]$sb.AppendLine("# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine("# Source: MPCVideoDecFilter.cpp ffCodecs[]")
[void]$sb.AppendLine('#')
[void]$sb.AppendLine("# Distinct codec ids in ffCodecs: $($entries.Count)")
[void]$sb.AppendLine("# Modern-bridge-capable ids: $($modernCapable.Count)")
[void]$sb.AppendLine("# Legacy-only ids (still block libavcodec_gcc removal): $($legacyOnly.Count)")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Modern-bridge-capable (software via bridge or DXVA modern parse)')
foreach ($id in $modernCapable) {
  [void]$sb.AppendLine($id)
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Legacy-only (still require mpcvideodec/ffmpeg + libavcodec_gcc)')
foreach ($id in $legacyOnly) {
  [void]$sb.AppendLine($id)
}

Set-Content -LiteralPath $outFile -Value $sb.ToString() -Encoding UTF8
Write-Host "audit-rfc0035-legacy-only-codecs: wrote $outFile (legacy-only=$($legacyOnly.Count))" -ForegroundColor Green
