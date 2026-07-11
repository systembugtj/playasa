#Requires -Version 5.1
<#
.SYNOPSIS
  Configure and build the RFC-0024 FFmpeg 8.1 software-decode island.
#>
[CmdletBinding()]
param(
  [switch]$ConfigureOnly
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$islandRoot = Join-Path $repoRoot 'src\Thirdparty\ffmpeg-modern'
$sourceRoot = Join-Path $islandRoot 'src'
$buildRoot = Join-Path $islandRoot 'build'
$installRoot = Join-Path $islandRoot 'install'

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

  $bash = Get-Command bash.exe -ErrorAction SilentlyContinue
  if ($bash) {
    $usrBin = Split-Path -Parent $bash.Source
    return Split-Path -Parent (Split-Path -Parent $usrBin)
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

function Assert-InstalledArtifact {
  param([string]$RelativePath)
  $path = Join-Path $installRoot $RelativePath
  if (-not (Test-Path -LiteralPath $path)) {
    throw "FFmpeg build did not produce expected artifact: $path"
  }
}

if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot 'configure'))) {
  throw "Missing FFmpeg configure script: $sourceRoot"
}

$msys2Root = Get-Msys2Root
$sourceRootMsys = Convert-ToMsysPath $sourceRoot
$buildRootMsys = Convert-ToMsysPath $buildRoot
$installRootMsys = Convert-ToMsysPath $installRoot

New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
New-Item -ItemType Directory -Force -Path $installRoot | Out-Null

$configureArgs = @(
  '--disable-programs',
  '--disable-doc',
  '--disable-debug',
  '--disable-avdevice',
  '--disable-avfilter',
  '--disable-network',
  '--disable-hwaccels',
  '--disable-encoders',
  '--disable-decoders',
  '--disable-demuxers',
  '--disable-parsers',
  '--disable-muxers',
  '--enable-avcodec',
  '--enable-avutil',
  '--enable-avformat',
  '--enable-swscale',
  '--enable-decoder=mpeg4',
  '--enable-decoder=flv',
  '--enable-decoder=vp6',
  '--enable-decoder=vp6a',
  '--enable-decoder=vp6f',
  '--enable-decoder=wmv1',
  '--enable-decoder=wmv2',
  '--enable-decoder=wmv3',
  '--enable-decoder=h264',
  '--enable-decoder=mpeg2video',
  '--enable-decoder=mpeg1video',
  '--enable-decoder=vc1',
  '--enable-decoder=rv10',
  '--enable-decoder=rv20',
  '--enable-decoder=rv30',
  '--enable-decoder=rv40',
  '--enable-demuxer=avi',
  '--enable-demuxer=flv',
  '--enable-demuxer=matroska',
  '--enable-demuxer=mov',
  '--enable-parser=mpeg4video',
  '--enable-parser=h263',
  '--enable-parser=vp3',
  '--enable-parser=h264',
  '--enable-parser=mpegvideo',
  '--enable-parser=vc1',
  '--disable-x86asm',
  "--prefix=$installRootMsys"
)

$quotedConfigureArgs = ($configureArgs | ForEach-Object { "'" + ($_ -replace "'", "'\''") + "'" }) -join ' '
$commonPrefix = "export PATH=/mingw32/bin:/usr/bin:`$PATH; cd '$buildRootMsys';"

Write-Host "Configuring FFmpeg 8.1 island with MSYS2 MINGW32: $msys2Root" -ForegroundColor Cyan
Invoke-Msys2 -Msys2Root $msys2Root -Command "$commonPrefix '$sourceRootMsys/configure' $quotedConfigureArgs"

if (-not $ConfigureOnly) {
  Write-Host 'Building FFmpeg 8.1 island with MSYS2 make' -ForegroundColor Cyan
  Invoke-Msys2 -Msys2Root $msys2Root -Command "$commonPrefix make -j2"
  Invoke-Msys2 -Msys2Root $msys2Root -Command "$commonPrefix make install"

  Assert-InstalledArtifact 'include\libavcodec\avcodec.h'
  Assert-InstalledArtifact 'include\libavformat\avformat.h'
  Assert-InstalledArtifact 'lib\libavcodec.a'
  Assert-InstalledArtifact 'lib\libavformat.a'
  Assert-InstalledArtifact 'lib\libavutil.a'
  Assert-InstalledArtifact 'lib\pkgconfig\libavcodec.pc'
}

Write-Host 'build-rfc0024-ffmpeg-modern: OK' -ForegroundColor Green
