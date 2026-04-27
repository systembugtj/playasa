#Requires -Version 5.1
<#
.SYNOPSIS
  Build and run the RFC-0024 modern FFmpeg first-frame decode smoke test.
#>
[CmdletBinding()]
param(
  [string]$SamplePath,
  [switch]$BuildOnly
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'TestSupport\SplayerTestSupport.psm1') -Force

$repoRoot = Get-SplayerRepoRoot
$ffmpegInstall = Join-Path $repoRoot 'src\Thirdparty\ffmpeg-modern\install'
$smokeRoot = Join-Path $repoRoot 'src\Test\MPCVideoDecModernSmoke'
$smokeSource = Join-Path $smokeRoot 'MPCVideoDecModernSmoke.cpp'
$adapterSource = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegDecodeAdapter.cpp'
$outputDir = Join-Path $repoRoot 'out\obj\MPCVideoDecModernSmoke'
$outputExe = Join-Path $outputDir 'MPCVideoDecModernSmoke.exe'

if (-not $BuildOnly) {
  if (-not $SamplePath) {
    throw 'SamplePath is required unless -BuildOnly is used.'
  }
  Assert-SplayerFileExists $SamplePath
}
Assert-SplayerFileExists $smokeSource
Assert-SplayerFileExists $adapterSource
Assert-SplayerFileExists (Join-Path $ffmpegInstall 'include\libavcodec\avcodec.h')
Assert-SplayerFileExists (Join-Path $ffmpegInstall 'include\libavformat\avformat.h')
Assert-SplayerFileExists (Join-Path $ffmpegInstall 'lib\libavcodec.a')
Assert-SplayerFileExists (Join-Path $ffmpegInstall 'lib\libavformat.a')
Assert-SplayerFileExists (Join-Path $ffmpegInstall 'lib\libavutil.a')
Assert-SplayerFileExists (Join-Path $ffmpegInstall 'lib\pkgconfig\libavcodec.pc')

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$msys2Root = Get-SplayerMsys2Root
$ffmpegInstallMsys = ConvertTo-SplayerMsysPath $ffmpegInstall
$smokeSourceMsys = ConvertTo-SplayerMsysPath $smokeSource
$adapterSourceMsys = ConvertTo-SplayerMsysPath $adapterSource
$outputExeMsys = ConvertTo-SplayerMsysPath $outputExe
$samplePathMsys = if ($SamplePath) { ConvertTo-SplayerMsysPath $SamplePath } else { '' }

$buildCommand = @"
export PATH=/mingw32/bin:/usr/bin:`$PATH
export PKG_CONFIG_PATH='$ffmpegInstallMsys/lib/pkgconfig'
g++ -std=c++11 -Wall -Wextra '$smokeSourceMsys' '$adapterSourceMsys' -o '$outputExeMsys' `$(pkg-config --cflags --libs libavformat libavcodec libavutil libswscale libswresample)
"@

Invoke-SplayerMsys2 -Msys2Root $msys2Root -Command $buildCommand

if (-not $BuildOnly) {
  Invoke-SplayerMsys2 -Msys2Root $msys2Root -Command "'$outputExeMsys' '$samplePathMsys'"
}

Write-Host 'test-rfc0024-modern-smoke: OK' -ForegroundColor Green
