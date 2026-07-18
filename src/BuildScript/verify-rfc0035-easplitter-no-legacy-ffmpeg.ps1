#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0035 gate: EASplitter must not depend on legacy mpcvideodec/ffmpeg headers.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$eaDir = Join-Path $repoRoot 'src\Source\filters\parser\EASplitter'
$compatHeader = Join-Path $eaDir 'EaFfmpegCompat.h'
$source = Join-Path $eaDir 'EASpliter.cpp'
$vcxproj = Join-Path $eaDir 'EASplitter.vcxproj'
$vcproj = Join-Path $eaDir 'EASplitter.vcproj'

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "RFC-0035 EASplitter gate failed: missing $Path"
  }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) {
    throw "RFC-0035 EASplitter gate failed: $Message ($Path)"
  }
}

function Assert-FileNotContains([string]$Path, [string]$Pattern, [string]$Message) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "RFC-0035 EASplitter gate failed: missing $Path"
  }
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -match $Pattern) {
    throw "RFC-0035 EASplitter gate failed: $Message ($Path)"
  }
}

Assert-FileContains $compatHeader 'enum CodecID' 'compat header must own local CodecID'
Assert-FileContains $compatHeader 'typedef struct AVPacket' 'compat header must own local AVPacket'
Assert-FileContains $source 'EaFfmpegCompat\.h' 'EASpliter.cpp must include local compat header'
Assert-FileNotContains $source 'avcodec\.h' 'EASpliter.cpp must not include legacy avcodec.h'
Assert-FileNotContains $source 'avformat\.h' 'EASpliter.cpp must not include legacy avformat.h'
Assert-FileNotContains $source 'PODtypes\.h' 'EASpliter.cpp must not include legacy PODtypes.h'
Assert-FileNotContains $source 'intreadwrite\.h' 'EASpliter.cpp must not include legacy intreadwrite.h'
Assert-FileNotContains $vcxproj 'mpcvideodec[\\/]+ffmpeg' 'EASplitter.vcxproj must not add legacy ffmpeg include paths'
Assert-FileNotContains $vcproj 'mpcvideodec[\\/]+ffmpeg' 'EASplitter.vcproj must not add legacy ffmpeg include paths'

Write-Host 'verify-rfc0035-easplitter-no-legacy-ffmpeg: OK'
