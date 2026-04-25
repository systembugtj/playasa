#Requires -Version 5.1
<#
.SYNOPSIS
  Build and run the RFC-0024 modern FFmpeg first-frame decode smoke test.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$SamplePath
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$ffmpegInstall = Join-Path $repoRoot 'src\Thirdparty\ffmpeg-modern\install'
$smokeRoot = Join-Path $repoRoot 'src\Test\MPCVideoDecModernSmoke'
$smokeSource = Join-Path $smokeRoot 'MPCVideoDecModernSmoke.cpp'
$adapterSource = Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\modern_ffmpeg\ModernFfmpegDecodeAdapter.cpp'
$outputDir = Join-Path $repoRoot 'out\obj\MPCVideoDecModernSmoke'
$outputExe = Join-Path $outputDir 'MPCVideoDecModernSmoke.exe'

function Assert-FileExists {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing required file: $Path"
  }
}

Assert-FileExists $SamplePath
Assert-FileExists $smokeSource
Assert-FileExists $adapterSource
Assert-FileExists (Join-Path $ffmpegInstall 'include\libavcodec\avcodec.h')
Assert-FileExists (Join-Path $ffmpegInstall 'include\libavformat\avformat.h')
Assert-FileExists (Join-Path $ffmpegInstall 'lib\avcodec.lib')
Assert-FileExists (Join-Path $ffmpegInstall 'lib\avformat.lib')
Assert-FileExists (Join-Path $ffmpegInstall 'lib\avutil.lib')

$cl = Get-Command cl.exe -ErrorAction SilentlyContinue
if (-not $cl) {
  throw 'Missing cl.exe. Run this smoke test from a Visual Studio Developer PowerShell.'
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$includeArg = "/I$(Join-Path $ffmpegInstall 'include')"
$libPathArg = "/LIBPATH:$(Join-Path $ffmpegInstall 'lib')"
$compileArgs = @(
  '/nologo',
  '/EHsc',
  '/W4',
  $includeArg,
  $smokeSource,
  $adapterSource,
  '/Fe:' + $outputExe,
  '/link',
  $libPathArg,
  'avcodec.lib',
  'avformat.lib',
  'avutil.lib'
)

& $cl.Source @compileArgs
if ($LASTEXITCODE -ne 0) {
  throw "MPCVideoDecModernSmoke build failed with exit code $LASTEXITCODE"
}

& $outputExe $SamplePath
if ($LASTEXITCODE -ne 0) {
  throw "MPCVideoDecModernSmoke failed with exit code $LASTEXITCODE"
}

Write-Host 'test-rfc0024-modern-smoke: OK (decoded first frame)' -ForegroundColor Green
