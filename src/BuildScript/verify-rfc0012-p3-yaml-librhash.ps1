#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0012 P3：无 MSBuild 时校验内嵌 yaml-cpp / librhash 钉扎（见各目录下 rfc0012-expected.txt）。

.DESCRIPTION
  yaml-cpp 首行 legacy-yaml-h-62b23520：校验 include/yaml.h 的 include guard（当前内嵌树）。
  librhash 首行 legacy-hash-count-22：校验 librhash/rhash.h 中 RHASH_HASH_COUNT 取值。
  P3 升级上游后请改写期望首行并扩展本脚本中对应分支（与 jsoncpp 脚本同一模式）。
#>
$ErrorActionPreference = 'Stop'

$REPO_ROOT = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$YAML_EXPECT_FILE = Join-Path $REPO_ROOT 'src/Thirdparty/yaml-cpp/rfc0012-expected.txt'
$YAML_H = Join-Path $REPO_ROOT 'src/Thirdparty/yaml-cpp/include/yaml.h'
$YAML_PROJ = Join-Path $REPO_ROOT 'src/Thirdparty/yaml-cpp/yamlcpp.vcxproj'

$RH_EXPECT_FILE = Join-Path $REPO_ROOT 'src/Thirdparty/librhash/rfc0012-expected.txt'
$RHASH_H = Join-Path $REPO_ROOT 'src/Thirdparty/librhash/librhash/rhash.h'
$RHASH_PROJ = Join-Path $REPO_ROOT 'src/Thirdparty/librhash/librhash/librhash.vcxproj'

function Read-FirstNonEmptyLine {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing file: $Path" }
    $line = (Get-Content -LiteralPath $Path -Encoding UTF8 | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1).Trim()
    if ([string]::IsNullOrWhiteSpace($line)) { throw "Empty expectation file: $Path" }
    return $line
}

function Test-RequiredFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing file: $Path" }
}

# --- yaml-cpp ---
Test-RequiredFile $YAML_EXPECT_FILE
Test-RequiredFile $YAML_H
Test-RequiredFile $YAML_PROJ
$yamlTag = Read-FirstNonEmptyLine $YAML_EXPECT_FILE
if ($yamlTag -eq 'legacy-yaml-h-62b23520') {
    $raw = Get-Content -LiteralPath $YAML_H -Raw -Encoding UTF8
    if ($raw -notmatch 'YAML_H_62B23520_7C8E_11DE_8A39_0800200C9A66') {
        throw 'yaml.h include guard changed; update rfc0012-expected.txt or upstream tree'
    }
}
else {
    throw "Unknown yaml-cpp rfc0012-expected.txt first line: '$yamlTag'. Add a branch in verify-rfc0012-p3-yaml-librhash.ps1 after P3 upgrade."
}

# --- librhash ---
Test-RequiredFile $RH_EXPECT_FILE
Test-RequiredFile $RHASH_H
Test-RequiredFile $RHASH_PROJ
$rhTag = Read-FirstNonEmptyLine $RH_EXPECT_FILE
if ($rhTag -eq 'legacy-hash-count-22') {
    $raw = Get-Content -LiteralPath $RHASH_H -Raw -Encoding UTF8
    if ($raw -notmatch 'RHASH_HASH_COUNT\s*=\s*22') {
        throw 'rhash.h RHASH_HASH_COUNT no longer 22; update rfc0012-expected.txt after P3 upgrade'
    }
}
else {
    throw "Unknown librhash rfc0012-expected.txt first line: '$rhTag'. Add a branch in verify-rfc0012-p3-yaml-librhash.ps1 after P3 upgrade."
}

Write-Host 'verify-rfc0012-p3-yaml-librhash: OK (yaml-cpp + librhash structural pins)' -ForegroundColor Green
