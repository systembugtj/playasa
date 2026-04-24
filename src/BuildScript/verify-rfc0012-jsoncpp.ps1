#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0012 P2：无 MSBuild 时校验内嵌 jsoncpp 形态与钉扎版本（见 src/Thirdparty/jsoncpp/rfc0012-expected.txt）。

.DESCRIPTION
  - 期望文件首行 legacy-cpptl：匹配当前 CppTL 时代树（无 version.h）。
  - 期望文件首行为 x.y.z：要求存在 include/json/version.h 且 JSONCPP_VERSION_STRING 与之一致（P2 升级后改 rfc0012-expected.txt）。
#>
$ErrorActionPreference = 'Stop'

$REPO_ROOT = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$JSONCPP_DIR = Join-Path $REPO_ROOT 'src/Thirdparty/jsoncpp'
$EXPECTED_FILE = Join-Path $JSONCPP_DIR 'rfc0012-expected.txt'
$PROPS_FILE = Join-Path $REPO_ROOT 'src/Thirdparty/jsoncpp.props'
$LIB_JSON_PROJ = Join-Path $JSONCPP_DIR 'makefiles/vs71/lib_json.vcxproj'
$VALUE_H = Join-Path $JSONCPP_DIR 'include/json/value.h'
$READER_CPP = Join-Path $JSONCPP_DIR 'src/lib_json/json_reader.cpp'

function Test-RequiredFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing file: $Path" }
}

Test-RequiredFile $EXPECTED_FILE
Test-RequiredFile $PROPS_FILE
Test-RequiredFile $LIB_JSON_PROJ
Test-RequiredFile $VALUE_H
Test-RequiredFile $READER_CPP

$expectedLine = (Get-Content -LiteralPath $EXPECTED_FILE -Encoding UTF8 | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1).Trim()
if ([string]::IsNullOrWhiteSpace($expectedLine)) {
    throw "rfc0012-expected.txt is empty; set first line to legacy-cpptl or SemVer (e.g. 1.9.5)"
}

# jsoncpp.props 须仍指向 Thirdparty\jsoncpp\include（与 mplayerc 引用一致）
$propsRaw = Get-Content -LiteralPath $PROPS_FILE -Raw -Encoding UTF8
if ($propsRaw -notmatch 'Thirdparty\\jsoncpp\\include') {
    throw "jsoncpp.props must keep AdditionalIncludeDirectories for Thirdparty\jsoncpp\include"
}

if ($expectedLine -eq 'legacy-cpptl') {
    $vh = Get-Content -LiteralPath $VALUE_H -Raw -Encoding UTF8
    if ($vh -notmatch 'CPPTL_JSON_H_INCLUDED') {
        throw "value.h no longer matches legacy-cpptl fingerprint; update rfc0012-expected.txt after P2 upgrade"
    }
    Write-Host 'verify-rfc0012-jsoncpp: OK (legacy-cpptl bundle, structural + props check)' -ForegroundColor Green
    exit 0
}

if ($expectedLine -notmatch '^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?$') {
    throw "Bad rfc0012-expected.txt first line: '$expectedLine'. Use legacy-cpptl or SemVer like 1.9.5"
}

$VERSION_H = Join-Path $JSONCPP_DIR 'include/json/version.h'
Test-RequiredFile $VERSION_H
$verRaw = Get-Content -LiteralPath $VERSION_H -Raw -Encoding UTF8
$escaped = [regex]::Escape($expectedLine)
if ($verRaw -notmatch "JSONCPP_VERSION_STRING\s+`"$escaped`"") {
    throw "include/json/version.h does not declare JSONCPP_VERSION_STRING `"$expectedLine`""
}
Write-Host "verify-rfc0012-jsoncpp: OK (JSONCPP_VERSION_STRING $expectedLine)" -ForegroundColor Green
