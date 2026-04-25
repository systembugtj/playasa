#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0017 FFmpeg / mpcvideodec audit gate.
#>
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$mpcVideoDecDir = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec'
$expectedFile = Join-Path $mpcVideoDecDir 'rfc0017-expected.txt'
$configFile = Join-Path $mpcVideoDecDir 'ffmpeg\config.h'
$avcodecHeader = Join-Path $mpcVideoDecDir 'ffmpeg\libavcodec\avcodec.h'
$avutilHeader = Join-Path $mpcVideoDecDir 'ffmpeg\libavutil\avutil.h'
$projectFile = Join-Path $mpcVideoDecDir 'MPCVideoDec.vcxproj'
$defFile = Join-Path $mpcVideoDecDir 'MPCVideoDec.def'
$filterFile = Join-Path $mpcVideoDecDir 'MPCVideoDecFilter.cpp'

function Assert-FileExists {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing required file: $Path"
  }
}

function Assert-Text {
  param(
    [string]$Path,
    [string]$Pattern,
    [string]$Description
  )
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -notmatch $Pattern) {
    throw "RFC-0017 gate failed: $Description"
  }
}

foreach ($file in @($expectedFile, $configFile, $avcodecHeader, $avutilHeader, $projectFile, $defFile, $filterFile)) {
  Assert-FileExists $file
}

Assert-Text $expectedFile 'libavcodec version: 52\.32\.0' 'expected file must pin libavcodec 52.32.0'
Assert-Text $expectedFile 'Do not replace the FFmpeg tree in this RFC\.' 'expected file must preserve no-replace decision'
Assert-Text $expectedFile 'Stale libflac ProjectReference removed' 'expected file must record stale libflac reference decision'

Assert-Text $avcodecHeader '#define\s+LIBAVCODEC_VERSION_MAJOR\s+52' 'libavcodec major version changed'
Assert-Text $avcodecHeader '#define\s+LIBAVCODEC_VERSION_MINOR\s+32' 'libavcodec minor version changed'
Assert-Text $avcodecHeader '#define\s+LIBAVCODEC_VERSION_MICRO\s+0' 'libavcodec micro version changed'
Assert-Text $avcodecHeader 'GNU Lesser General Public' 'libavcodec LGPL header missing'

Assert-Text $avutilHeader '#define\s+LIBAVUTIL_VERSION_MAJOR\s+50' 'libavutil major version changed'
Assert-Text $avutilHeader '#define\s+LIBAVUTIL_VERSION_MINOR\s+2' 'libavutil minor version changed'
Assert-Text $avutilHeader '#define\s+LIBAVUTIL_VERSION_MICRO\s+0' 'libavutil micro version changed'
Assert-Text $avutilHeader 'GNU Lesser General Public' 'libavutil LGPL header missing'

Assert-Text $configFile '#define\s+CONFIG_GPL\s+1' 'CONFIG_GPL pin changed'
Assert-Text $configFile '#define\s+CONFIG_LIBAMR_NB\s+1' 'CONFIG_LIBAMR_NB pin changed'
Assert-Text $configFile '#define\s+ENABLE_LIBAMR_NB\s+1' 'ENABLE_LIBAMR_NB pin changed'
Assert-Text $configFile '#define\s+CONFIG_DECODERS\s+1' 'CONFIG_DECODERS pin changed'
Assert-Text $configFile '#define\s+CONFIG_ENCODERS\s+0' 'CONFIG_ENCODERS pin changed'
Assert-Text $configFile '#define\s+CONFIG_ZLIB\s+1' 'CONFIG_ZLIB pin changed'

Assert-Text $projectFile "<ConfigurationType>StaticLibrary</ConfigurationType>" 'Win32 Release Unicode must remain static library in current pin'
Assert-Text $projectFile '<PlatformToolset>v145</PlatformToolset>' 'MPCVideoDec toolset pin changed'
Assert-Text $projectFile '<UseOfMfc>Static</UseOfMfc>' 'MFC static pin changed'
Assert-Text $projectFile '<CharacterSet>Unicode</CharacterSet>' 'Unicode character set pin changed'
Assert-Text $projectFile 'libavcodec_gcc\.lib;libgcc\.a;libmingwex\.a' 'Win32 Release Unicode libavcodec dependency pin changed'
Assert-Text $projectFile 'ffmpeg;ffmpeg\\libavcodec;ffmpeg\\libavutil' 'FFmpeg include path pin changed'
if ((Get-Content -LiteralPath $projectFile -Raw) -match 'ProjectReference Include="..\\mpadecfilter\\libflac\\src\\libFLAC\\libflac\.vcxproj"') {
  throw 'RFC-0017 gate failed: stale libflac ProjectReference must not return'
}

Assert-Text $defFile 'DllCanUnloadNow' 'COM export DllCanUnloadNow missing'
Assert-Text $defFile 'DllGetClassObject' 'COM export DllGetClassObject missing'
Assert-Text $defFile 'DllRegisterServer' 'COM export DllRegisterServer missing'
Assert-Text $defFile 'DllUnregisterServer' 'COM export DllUnregisterServer missing'

Assert-Text $filterFile 'Mplayerc is free software; you can redistribute it and/or modify' 'MPCVideoDec project GPL header missing'

$licenseFiles = Get-ChildItem -LiteralPath $mpcVideoDecDir -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -in @('COPYING', 'LICENSE', 'LICENSE.txt', 'COPYING.txt') }
if ($licenseFiles.Count -ne 0) {
  throw "RFC-0017 expected no top-level FFmpeg license file in mpcvideodec tree; update audit before changing this state."
}

Write-Host 'verify-rfc0017-ffmpeg-mpcvideodec: OK (audit pins match)' -ForegroundColor Green
