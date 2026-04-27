#Requires -Version 5.1
<#
.SYNOPSIS
  Build and run the RFC-0024 MSVC consumer smoke for the FFmpeg modern bridge.
#>
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'TestSupport\SplayerTestSupport.psm1') -Force

$repoRoot = Get-SplayerRepoRoot
$ffmpegInstall = Join-Path $repoRoot 'src\Thirdparty\ffmpeg-modern\install'
$smokeRoot = Join-Path $repoRoot 'src\Test\MPCVideoDecModernBridgeSmoke'
$smokeSource = Join-Path $smokeRoot 'MPCVideoDecModernBridgeSmoke.cpp'
$outputDir = Join-Path $repoRoot 'out\obj\MPCVideoDecModernBridgeSmoke'
$outputExe = Join-Path $outputDir 'MPCVideoDecModernBridgeSmoke.exe'
$bridgeDll = Join-Path $ffmpegInstall 'bin\playasa_ffmpeg_modern_bridge.dll'
$bridgeImportLib = Join-Path $ffmpegInstall 'lib\playasa_ffmpeg_modern_bridge.lib'

Assert-SplayerFileExists $smokeSource
Assert-SplayerFileExists $bridgeDll
Assert-SplayerFileExists $bridgeImportLib

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
Get-ChildItem -LiteralPath (Join-Path $ffmpegInstall 'bin') -Filter '*.dll' |
  ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $outputDir $_.Name) -Force }

$vcvars = Get-SplayerVcVars32
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
