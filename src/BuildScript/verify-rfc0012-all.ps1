#Requires -Version 5.1
<#
.SYNOPSIS
  依次运行 RFC-0012 下所有无 MSBuild 校验脚本（P1 + P2 + P3 + P4 门闩）。
#>
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
& (Join-Path $here 'verify-rfc0012-zlib-libpng.ps1')
& (Join-Path $here 'verify-rfc0012-jsoncpp.ps1')
& (Join-Path $here 'verify-rfc0012-p3-yaml-librhash.ps1')
& (Join-Path $here 'verify-rfc0012-p4-sqlitepp.ps1')
& (Join-Path $here 'verify-rfc0012-p4-zeromq.ps1')
Write-Host 'verify-rfc0012-all: OK (P1 + P2 + P3 + P4 pins)' -ForegroundColor Green
