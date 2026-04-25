#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0012 P4：无 MSBuild 时校验 sqlitepp 内嵌 SQLite 钉扎与测试工程迁移状态。
#>
$ErrorActionPreference = 'Stop'

$REPO_ROOT = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$EXPECT_FILE = Join-Path $REPO_ROOT 'src/Thirdparty/sqlitepp/rfc0012-expected.txt'
$SQLITE_H = Join-Path $REPO_ROOT 'src/Thirdparty/sqlitepp/sqlite/sqlite3.h'
$SQLITE_C = Join-Path $REPO_ROOT 'src/Thirdparty/sqlitepp/sqlite/sqlite3.c'
$SQLITE_EXT_H = Join-Path $REPO_ROOT 'src/Thirdparty/sqlitepp/sqlite/sqlite3ext.h'
$SQLITEPP_PROPS = Join-Path $REPO_ROOT 'src/Thirdparty/sqlitepp.props'
$SQLITEPP_PROJ = Join-Path $REPO_ROOT 'src/Thirdparty/sqlitepp.vcxproj'
$SQLITEPP_TEST_PROJ = Join-Path $REPO_ROOT 'src/Test/sqliteppTest/sqliteppTest.vcxproj'
$SQLITEPP_TEST_MAIN = Join-Path $REPO_ROOT 'src/Test/sqliteppTest/TestMain.cpp'
$APP_SQLITE = Join-Path $REPO_ROOT 'src/Source/apps/mplayerc/Model/appSQLlite.cc'

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

foreach ($path in @(
    $EXPECT_FILE,
    $SQLITE_H,
    $SQLITE_C,
    $SQLITE_EXT_H,
    $SQLITEPP_PROPS,
    $SQLITEPP_PROJ,
    $SQLITEPP_TEST_PROJ,
    $SQLITEPP_TEST_MAIN,
    $APP_SQLITE
)) {
    Test-RequiredFile $path
}

$tag = Read-FirstNonEmptyLine $EXPECT_FILE
if ($tag -ne 'sqlite-amalgamation-3.53.0') {
    throw "Unknown sqlitepp rfc0012-expected.txt first line: '$tag'. Add a branch in verify-rfc0012-p4-sqlitepp.ps1 after P4 upgrade."
}

$sqliteHeader = Get-Content -LiteralPath $SQLITE_H -Raw -Encoding UTF8
if ($sqliteHeader -notmatch '#define SQLITE_VERSION\s+"3\.53\.0"') {
    throw 'sqlite3.h does not declare SQLite 3.53.0'
}
if ($sqliteHeader -notmatch '#define SQLITE_VERSION_NUMBER\s+3053000') {
    throw 'sqlite3.h does not declare SQLITE_VERSION_NUMBER 3053000'
}
if ($sqliteHeader -notmatch '4525003a53a7fc63ca75c59b22c79608659ca12f0131f52c18637f829977f20b') {
    throw 'sqlite3.h source id does not match SQLite 3.53.0 pin'
}

$sqliteSource = Get-Content -LiteralPath $SQLITE_C -Raw -Encoding UTF8
if ($sqliteSource -notmatch 'version 3\.53\.0') {
    throw 'sqlite3.c is not the SQLite 3.53.0 amalgamation'
}

$props = Get-Content -LiteralPath $SQLITEPP_PROPS -Raw -Encoding UTF8
if ($props -match '\$\(SolutionDir\)') {
    throw 'sqlitepp.props still depends on SolutionDir'
}
foreach ($required in @(
    '$(MSBuildThisFileDirectory)sqlitepp\sqlitepp',
    '$(SqliteppLibraryName)',
    '$(SqliteppLibraryConfiguration)'
)) {
    if ($props -notlike "*$required*") {
        throw "sqlitepp.props missing expected stable entry: $required"
    }
}

$project = Get-Content -LiteralPath $SQLITEPP_PROJ -Raw -Encoding UTF8
foreach ($required in @(
    'SQLITEPP_UTF16',
    'MultiThreadedDebug',
    'sqlitepp\sqlite\sqlite3.c',
    'sqlitepp\sqlite\sqlite3.h',
    'sqlitepp\sqlite\sqlite3ext.h'
)) {
    if ($project -notlike "*$required*") {
        throw "sqlitepp.vcxproj missing expected P4 entry: $required"
    }
}

$testProject = Get-Content -LiteralPath $SQLITEPP_TEST_PROJ -Raw -Encoding UTF8
if ($testProject -match '\$\(SolutionDir\)Source|\$\(SolutionDir\)Thirdparty') {
    throw 'sqliteppTest.vcxproj still has unstable SolutionDir imports'
}
if ($testProject -notmatch 'MultiThreadedDebug') {
    throw 'sqliteppTest Debug Unicode CRT is not aligned to debug static runtime'
}

$testMain = Get-Content -LiteralPath $SQLITEPP_TEST_MAIN -Raw -Encoding UTF8
if ($testMain -match 'system\("pause"\)') {
    throw 'sqliteppTest is still interactive'
}
if ($testMain -notmatch 'SqliteGetProfileInt|SqliteWriteProfileInt') {
    throw 'sqliteppTest does not use Win32 macro-safe profile helpers'
}
if ($testMain -notmatch 'return all_passed \? 0 : 1;') {
    throw 'sqliteppTest does not fail the process on test failure'
}

$appSqlite = Get-Content -LiteralPath $APP_SQLITE -Raw -Encoding UTF8
if ($appSqlite -match 'str3\s*=\s*str2\s*=\s*ToSqliteString') {
    throw 'appSQLlite.cc still overwrites the section key when writing strings'
}

Write-Host 'verify-rfc0012-p4-sqlitepp: OK (SQLite 3.53.0 + sqlitepp test pins)' -ForegroundColor Green
