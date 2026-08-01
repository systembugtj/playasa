#Requires -Version 5.1
<#
.SYNOPSIS
  Build the RFC-0024 FFmpeg modern C ABI bridge DLL and MSVC import library.
#>
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$ffmpegInstall = Join-Path $repoRoot 'src\Thirdparty\ffmpeg-modern\install'
$modernFfmpegRoot = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg'
$packageHeader = Join-Path $repoRoot 'src\Thirdparty\pkg\ffmpeg_modern_bridge.h'
$adapterSource = Join-Path $modernFfmpegRoot 'ModernFfmpegDecodeAdapter.cpp'
$dxvaParserSource = Join-Path $modernFfmpegRoot 'ModernFfmpegDxvaH264Parser.c'
$dxvaVc1ParserSource = Join-Path $modernFfmpegRoot 'ModernFfmpegDxvaVc1Parser.c'
$bitstreamUtilsSource = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\h264_bitstream\H264BitstreamUtils.cpp'
$ffmpegModernSrc = Join-Path $repoRoot 'src\Thirdparty\ffmpeg-modern\src'
$ffmpegModernBuild = Join-Path $repoRoot 'src\Thirdparty\ffmpeg-modern\build'
$bridgeSource = Join-Path $modernFfmpegRoot 'ModernFfmpegBridge.cpp'
$bridgeDef = Join-Path $modernFfmpegRoot 'playasa_ffmpeg_modern_bridge.def'
$outputBin = Join-Path $ffmpegInstall 'bin'
$outputLib = Join-Path $ffmpegInstall 'lib'
$runtimeBin = Join-Path $repoRoot 'out\bin\Win32\Release Unicode'
$bridgeDll = Join-Path $outputBin 'playasa_ffmpeg_modern_bridge.dll'
$bridgeImportLib = Join-Path $outputLib 'playasa_ffmpeg_modern_bridge.lib'

function Assert-FileExists {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing required file: $Path"
  }
}

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

function Get-MsVcLibExe {
  $candidates = @(
    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.50.35717\bin\Hostx64\x86\lib.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2026\Community\VC\Tools\MSVC\14.50.35717\bin\Hostx64\x86\lib.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.50.35717\bin\Hostx64\x86\lib.exe')
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  $found = Get-ChildItem -LiteralPath (Join-Path $env:ProgramFiles 'Microsoft Visual Studio') -Recurse -Filter lib.exe -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\Hostx64\\x86\\lib\.exe$' } |
    Select-Object -First 1
  if ($found) {
    return $found.FullName
  }

  throw 'Missing MSVC lib.exe; install Visual Studio C++ tools.'
}

Assert-FileExists $packageHeader
Assert-FileExists $adapterSource
Assert-FileExists $dxvaParserSource
Assert-FileExists $dxvaVc1ParserSource
Assert-FileExists $bitstreamUtilsSource
Assert-FileExists $bridgeSource
Assert-FileExists $bridgeDef
Assert-FileExists (Join-Path $ffmpegInstall 'include\libavcodec\avcodec.h')
Assert-FileExists (Join-Path $ffmpegInstall 'lib\libavcodec.a')
Assert-FileExists (Join-Path $ffmpegInstall 'lib\pkgconfig\libavcodec.pc')
Assert-FileExists (Join-Path $ffmpegModernBuild 'config.h')

New-Item -ItemType Directory -Force -Path $outputBin | Out-Null
New-Item -ItemType Directory -Force -Path $outputLib | Out-Null
New-Item -ItemType Directory -Force -Path $runtimeBin | Out-Null

$msys2Root = Get-Msys2Root
$ffmpegInstallMsys = Convert-ToMsysPath $ffmpegInstall
$repoRootMsys = Convert-ToMsysPath $repoRoot
$adapterSourceMsys = Convert-ToMsysPath $adapterSource
$dxvaParserSourceMsys = Convert-ToMsysPath $dxvaParserSource
$dxvaVc1ParserSourceMsys = Convert-ToMsysPath $dxvaVc1ParserSource
$bitstreamUtilsSourceMsys = Convert-ToMsysPath $bitstreamUtilsSource
$ffmpegModernSrcMsys = Convert-ToMsysPath $ffmpegModernSrc
$ffmpegModernBuildMsys = Convert-ToMsysPath $ffmpegModernBuild
$bridgeSourceMsys = Convert-ToMsysPath $bridgeSource
$bridgeDllMsys = Convert-ToMsysPath $bridgeDll
$h264ParserObjMsys = Convert-ToMsysPath (Join-Path $outputBin '_dxva_h264_parser.o')
$vc1ParserObjMsys = Convert-ToMsysPath (Join-Path $outputBin '_dxva_vc1_parser.o')

$buildCommand = @"
export PATH=/mingw32/bin:/usr/bin:`$PATH
export PKG_CONFIG_PATH='$ffmpegInstallMsys/lib/pkgconfig'
PKG_CFLAGS=`$(pkg-config --cflags libavformat libavcodec libavutil libswscale libswresample)
PKG_LIBS=`$(pkg-config --libs libavformat libavcodec libavutil libswscale libswresample)
COMMON_INC='-I$repoRootMsys/src/Thirdparty/pkg -I$ffmpegModernBuildMsys -I$ffmpegModernSrcMsys -I$repoRootMsys/src/Source/filters/transform/mpcvideodec'
gcc -std=c11 -O2 -Wall `$PKG_CFLAGS `$COMMON_INC -c '$dxvaParserSourceMsys' -o '$h264ParserObjMsys'
gcc -std=c11 -O2 -Wall `$PKG_CFLAGS `$COMMON_INC -c '$dxvaVc1ParserSourceMsys' -o '$vc1ParserObjMsys'
g++ -std=c++11 -O2 -Wall -I'$repoRootMsys/src/Thirdparty/pkg' -I'$ffmpegModernBuildMsys' -I'$ffmpegModernSrcMsys' -I'$repoRootMsys/src/Source/filters/transform/mpcvideodec' -shared '$bridgeSourceMsys' '$adapterSourceMsys' '$bitstreamUtilsSourceMsys' '$h264ParserObjMsys' '$vc1ParserObjMsys' -o '$bridgeDllMsys' -static-libgcc -static-libstdc++ `$PKG_LIBS
"@

Invoke-Msys2 -Msys2Root $msys2Root -Command $buildCommand
Assert-FileExists $bridgeDll

foreach ($runtimeDll in @('libiconv-2.dll', 'libwinpthread-1.dll')) {
  $sourceDll = Join-Path $msys2Root (Join-Path 'mingw32\bin' $runtimeDll)
  Assert-FileExists $sourceDll
  Copy-Item -LiteralPath $sourceDll -Destination (Join-Path $outputBin $runtimeDll) -Force
}
Get-ChildItem -LiteralPath $outputBin -Filter '*.dll' |
  ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $runtimeBin $_.Name) -Force }

$libExe = Get-MsVcLibExe
& $libExe /nologo /machine:x86 /def:$bridgeDef /out:$bridgeImportLib
if ($LASTEXITCODE -ne 0) {
  throw "MSVC import library generation failed with exit code $LASTEXITCODE"
}
Assert-FileExists $bridgeImportLib

Write-Host 'build-rfc0024-ffmpeg-bridge: OK' -ForegroundColor Green
