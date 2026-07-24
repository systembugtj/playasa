#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0047: backward-compatible wrapper for unified FfmpegContext DXVA glue audit.
#>
[CmdletBinding()]
param(
  [switch]$FailIfEmpty
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$auditScript = Join-Path $repoRoot 'src\BuildScript\audit-rfc0047-ffmpegcontext-dxva-glue.ps1'

& powershell -NoProfile -ExecutionPolicy Bypass -File $auditScript @(
  $(if ($FailIfEmpty) { '-FailIfHits' })
)
exit $LASTEXITCODE
