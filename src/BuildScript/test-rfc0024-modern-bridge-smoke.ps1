#Requires -Version 5.1
<#
.SYNOPSIS
  Build and run the RFC-0024 MSVC consumer smoke for the FFmpeg modern bridge.
#>
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$ffmpegInstall = Join-Path $repoRoot 'src\Thirdparty\ffmpeg-modern\install'
$smokeRoot = Join-Path $repoRoot 'src\Test\MPCVideoDecModernBridgeSmoke'
$smokeSource = Join-Path $smokeRoot 'MPCVideoDecModernBridgeSmoke.cpp'
$outputDir = Join-Path $repoRoot 'out\obj\MPCVideoDecModernBridgeSmoke'
$outputExe = Join-Path $outputDir 'MPCVideoDecModernBridgeSmoke.exe'
$bridgeDll = Join-Path $ffmpegInstall 'bin\playasa_ffmpeg_modern_bridge.dll'
$bridgeImportLib = Join-Path $ffmpegInstall 'lib\playasa_ffmpeg_modern_bridge.lib'

function Assert-FileExists {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing required file: $Path"
  }
}

function Get-VcVars32 {
  $candidates = @(
    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars32.bat'),
    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2026\Community\VC\Auxiliary\Build\vcvars32.bat'),
    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars32.bat')
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  throw 'Missing vcvars32.bat; install Visual Studio C++ tools.'
}

Assert-FileExists $smokeSource
Assert-FileExists $bridgeDll
Assert-FileExists $bridgeImportLib

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
Get-ChildItem -LiteralPath (Join-Path $ffmpegInstall 'bin') -Filter '*.dll' |
  ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $outputDir $_.Name) -Force }

$vcvars = Get-VcVars32
$includeArg = "/I`"$repoRoot\src\Thirdparty\pkg`""
$outArg = "/Fe:`"$outputExe`""
$sourceArg = "`"$smokeSource`""
$linkLib = "`"$bridgeImportLib`""
$command = "call `"$vcvars`" >nul && cl.exe /nologo /EHsc /W4 $includeArg $sourceArg $outArg /link $linkLib"

cmd.exe /c $command
if ($LASTEXITCODE -ne 0) {
  throw "MPCVideoDecModernBridgeSmoke build failed with exit code $LASTEXITCODE"
}

& $outputExe
if ($LASTEXITCODE -ne 0) {
  throw "MPCVideoDecModernBridgeSmoke failed with exit code $LASTEXITCODE"
}

Write-Host 'test-rfc0024-modern-bridge-smoke: OK' -ForegroundColor Green
