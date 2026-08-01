#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047 phase 4b: MPCVideoDec DXVA H.264 may skip legacy avcodec_open when modern parse is available.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$filterCpp = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\MPCVideoDecFilter.cpp'
$filterHeader = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\MPCVideoDecFilter.h'

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) { throw "RFC-0047 4b gate failed: $Message ($Path)" }
}

Assert-FileContains $filterHeader 'm_bLegacyAvcodecOpened' 'filter must track legacy avcodec_open state'
Assert-FileContains $filterCpp 'NeedsLegacyAvcodecOpen' 'filter must gate legacy avcodec_open'
Assert-FileContains $filterCpp 'FFH264IsModernDxvaParseAvailable' 'filter must probe modern DXVA parse before skipping open'
Assert-FileContains $filterCpp 'FFVC1IsModernDxvaParseAvailable' 'filter must probe VC-1 modern DXVA parse before skipping open'
Assert-FileContains $filterCpp 'm_bLegacyAvcodecOpened' 'filter must guard avcodec_close/flush with open flag'
Assert-FileContains $filterCpp 'case MODE_SOFTWARE\s*:\s*\r?\n\s*hr = SoftwareDecode' 'DXVA path must not call SoftwareDecode directly'
Assert-FileContains $filterCpp 'skip legacy avcodec_open \(DXVA modern parse\)' 'filter must log skipped legacy open'

Write-Host 'test-rfc0047-mpcvideodec-dxva-skip-legacy-avcodec-open.ps1: PASS'
