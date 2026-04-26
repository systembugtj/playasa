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

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$ffmpegInstall = Join-Path $repoRoot 'src\Thirdparty\ffmpeg-modern\install'
$smokeRoot = Join-Path $repoRoot 'src\Test\MPCVideoDecModernSmoke'
$smokeSource = Join-Path $smokeRoot 'MPCVideoDecModernSmoke.cpp'
$adapterSource = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegDecodeAdapter.cpp'
$outputDir = Join-Path $repoRoot 'out\obj\MPCVideoDecModernSmoke'
$outputExe = Join-Path $outputDir 'MPCVideoDecModernSmoke.exe'

function Get-Msys2Root {
  $candidates = @(
    (Join-Path $env:USERPROFILE 'scoop\apps\msys2\current'),
    (Join-Path $env:USERPROFILE 'scoop\apps\msys2\2026-03-22')
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath (Join-Path $candidate 'usr\bin\bash.exe')) {
      return $candidate
    }
  }

  throw 'Missing MSYS2. Install it with: scoop install msys2'
}

function Convert-ToMsysPath {
  param([string]$Path)
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $drive = $fullPath.Substring(0, 1).ToLowerInvariant()
  $rest = $fullPath.Substring(2).Replace('\', '/')
  return "/$drive$rest"
}

function Invoke-Msys2 {
  param(
    [string]$Msys2Root,
    [string]$Command
  )

  $bash = Join-Path $Msys2Root 'usr\bin\bash.exe'
  if (-not (Test-Path -LiteralPath $bash)) {
    throw "Missing MSYS2 bash: $bash"
  }

  $oldMsystem = $env:MSYSTEM
  $oldChere = $env:CHERE_INVOKING
  try {
    $env:MSYSTEM = 'MINGW32'
    $env:CHERE_INVOKING = '1'
    & $bash -lc $Command
    if ($LASTEXITCODE -ne 0) {
      throw "MSYS2 command failed with exit code $LASTEXITCODE"
    }
  } finally {
    $env:MSYSTEM = $oldMsystem
    $env:CHERE_INVOKING = $oldChere
  }
}

function Assert-FileExists {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing required file: $Path"
  }
}

if (-not $BuildOnly) {
  if (-not $SamplePath) {
    throw 'SamplePath is required unless -BuildOnly is used.'
  }
  Assert-FileExists $SamplePath
}
Assert-FileExists $smokeSource
Assert-FileExists $adapterSource
Assert-FileExists (Join-Path $ffmpegInstall 'include\libavcodec\avcodec.h')
Assert-FileExists (Join-Path $ffmpegInstall 'include\libavformat\avformat.h')
Assert-FileExists (Join-Path $ffmpegInstall 'lib\libavcodec.a')
Assert-FileExists (Join-Path $ffmpegInstall 'lib\libavformat.a')
Assert-FileExists (Join-Path $ffmpegInstall 'lib\libavutil.a')
Assert-FileExists (Join-Path $ffmpegInstall 'lib\pkgconfig\libavcodec.pc')

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$msys2Root = Get-Msys2Root
$repoRootMsys = Convert-ToMsysPath $repoRoot
$ffmpegInstallMsys = Convert-ToMsysPath $ffmpegInstall
$smokeSourceMsys = Convert-ToMsysPath $smokeSource
$adapterSourceMsys = Convert-ToMsysPath $adapterSource
$outputExeMsys = Convert-ToMsysPath $outputExe
$samplePathMsys = if ($SamplePath) { Convert-ToMsysPath $SamplePath } else { '' }

$buildCommand = @"
export PATH=/mingw32/bin:/usr/bin:`$PATH
export PKG_CONFIG_PATH='$ffmpegInstallMsys/lib/pkgconfig'
g++ -std=c++11 -Wall -Wextra '$smokeSourceMsys' '$adapterSourceMsys' -o '$outputExeMsys' `$(pkg-config --cflags --libs libavformat libavcodec libavutil libswscale libswresample)
"@

Invoke-Msys2 -Msys2Root $msys2Root -Command $buildCommand

if (-not $BuildOnly) {
  Invoke-Msys2 -Msys2Root $msys2Root -Command "'$outputExeMsys' '$samplePathMsys'"
}

Write-Host 'test-rfc0024-modern-smoke: OK' -ForegroundColor Green
