#Requires -Version 5.1
# Sanity check: in-tree zlib/libpng headers match RFC-0012 P1 expected versions (no MSBuild required).
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$zlibH = Join-Path $root 'src/Source/zlib/zlib.h'
$pngH = Join-Path $root 'src/Source/libpng/png.h'
foreach ($p in @($zlibH, $pngH)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Missing file: $p" }
}
$zh = Get-Content -LiteralPath $zlibH -Raw -Encoding UTF8
if ($zh -notmatch 'ZLIB_VERSION\s+"1\.3\.1"') {
    throw "src/Source/zlib/zlib.h does not declare ZLIB_VERSION 1.3.1"
}
$ph = Get-Content -LiteralPath $pngH -Raw -Encoding UTF8
if ($ph -notmatch 'libpng version 1\.6\.47') {
    throw "src/Source/libpng/png.h does not declare libpng 1.6.47"
}
Write-Host 'verify-rfc0012-zlib-libpng: OK (zlib 1.3.1, libpng 1.6.47)' -ForegroundColor Green
