#Requires -Version 5.1
<#
.SYNOPSIS
  依次运行当前无 MSBuild 校验脚本（RFC-0012 P1-P5 + RFC-0017 门闩）。
#>
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
& (Join-Path $here 'verify-rfc0012-zlib-libpng.ps1')
& (Join-Path $here 'verify-rfc0012-jsoncpp.ps1')
& (Join-Path $here 'verify-rfc0012-p3-yaml-librhash.ps1')
& (Join-Path $here 'verify-rfc0012-p4-sqlitepp.ps1')
& (Join-Path $here 'verify-rfc0012-p4-zeromq.ps1')
& (Join-Path $here 'verify-rfc0012-p5-openssl-audit.ps1')
& (Join-Path $here 'verify-rfc0017-ffmpeg-mpcvideodec.ps1')
Write-Host 'verify-rfc0012-all: OK (RFC-0012 P1-P5 + RFC-0017 pins)' -ForegroundColor Green
