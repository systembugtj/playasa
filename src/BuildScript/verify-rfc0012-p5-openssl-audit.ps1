#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0012 P5：审计 OpenSSL 0.9.8x 的真实链接面，并钉住迁移委派结论。
#>
$ErrorActionPreference = 'Stop'

$REPO_ROOT = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$EXPECT_FILE = Join-Path $REPO_ROOT 'src/Thirdparty/openssl-0.9.8x/rfc0012-expected.txt'
$OPENSSL_README = Join-Path $REPO_ROOT 'src/Thirdparty/openssl-0.9.8x/README'
$MPLAYERC_PROJ = Join-Path $REPO_ROOT 'src/Source/apps/mplayerc/mplayerc_vs2005.vcxproj'
$UPDATER_PROJ = Join-Path $REPO_ROOT 'src/Updater/Updater.vcxproj'
$LIBRHASH_PROJ = Join-Path $REPO_ROOT 'src/Thirdparty/librhash/librhash/librhash.vcxproj'

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

function Get-ItemDefinitionGroup {
    param(
        [xml]$Project,
        [string]$Configuration,
        [string]$Platform
    )
    $condition = "'`$(Configuration)|`$(Platform)'=='$Configuration|$Platform'"
    $node = $Project.Project.ItemDefinitionGroup | Where-Object { $_.Condition -eq $condition } | Select-Object -First 1
    if (-not $node) {
        throw "Missing ItemDefinitionGroup: $Configuration|$Platform"
    }
    return $node
}

function Test-NoOpenSslLink {
    param(
        [xml]$Project,
        [string]$ProjectName,
        [string]$Configuration,
        [string]$Platform
    )
    $group = Get-ItemDefinitionGroup -Project $Project -Configuration $Configuration -Platform $Platform
    $deps = [string]$group.Link.AdditionalDependencies
    $delay = [string]$group.Link.DelayLoadDLLs
    if ($deps -match '(?i)(libeay32|ssleay32|openssl)') {
        throw "$ProjectName $Configuration|$Platform unexpectedly links OpenSSL: $deps"
    }
    if ($delay -match '(?i)(libeay32|ssleay32|openssl)') {
        throw "$ProjectName $Configuration|$Platform unexpectedly delay-loads OpenSSL: $delay"
    }
}

function Test-HasLegacyOpenSslLink {
    param(
        [xml]$Project,
        [string]$ProjectName,
        [string]$Configuration,
        [string]$Platform
    )
    $group = Get-ItemDefinitionGroup -Project $Project -Configuration $Configuration -Platform $Platform
    $deps = [string]$group.Link.AdditionalDependencies
    if ($deps -notmatch '(?i)libeay32\.lib' -or $deps -notmatch '(?i)ssleay32\.lib') {
        throw "$ProjectName $Configuration|$Platform no longer has the expected legacy OpenSSL debug link. Update P5 audit."
    }
}

function Test-NoDirectOpenSslIncludes {
    param([string[]]$Roots)
    foreach ($root in $Roots) {
        $files = Get-ChildItem -LiteralPath $root -Recurse -File -Include *.h,*.hpp,*.c,*.cc,*.cpp -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
            if ($text -match '(?im)^\s*#\s*include\s*[<"]openssl/') {
                throw "Unexpected direct OpenSSL include outside Thirdparty/openssl-0.9.8x: $($file.FullName)"
            }
        }
    }
}

foreach ($path in @($EXPECT_FILE, $OPENSSL_README, $MPLAYERC_PROJ, $UPDATER_PROJ, $LIBRHASH_PROJ)) {
    Test-RequiredFile $path
}

$tag = Read-FirstNonEmptyLine $EXPECT_FILE
if ($tag -ne 'openssl-0.9.8x-audit-delegated') {
    throw "Unknown OpenSSL P5 expectation tag: '$tag'. Update verify-rfc0012-p5-openssl-audit.ps1."
}

$readme = Get-Content -LiteralPath $OPENSSL_README -Raw -Encoding UTF8
if ($readme -notmatch 'OpenSSL 0\.9\.8x') {
    throw 'OpenSSL tree is no longer 0.9.8x; update P5 audit and migration plan.'
}

[xml]$mplayerc = Get-Content -LiteralPath $MPLAYERC_PROJ -Raw -Encoding UTF8
[xml]$updater = Get-Content -LiteralPath $UPDATER_PROJ -Raw -Encoding UTF8

Test-NoOpenSslLink -Project $mplayerc -ProjectName 'mplayerc' -Configuration 'Release Unicode' -Platform 'Win32'
Test-NoOpenSslLink -Project $mplayerc -ProjectName 'mplayerc' -Configuration 'Release' -Platform 'Win32'
Test-HasLegacyOpenSslLink -Project $mplayerc -ProjectName 'mplayerc' -Configuration 'Debug Unicode' -Platform 'Win32'

Test-NoOpenSslLink -Project $updater -ProjectName 'Updater' -Configuration 'Release' -Platform 'Win32'
Test-NoOpenSslLink -Project $updater -ProjectName 'Updater' -Configuration 'Debug Unicode' -Platform 'Win32'
Test-HasLegacyOpenSslLink -Project $updater -ProjectName 'Updater' -Configuration 'Debug' -Platform 'Win32'

$librhashProject = Get-Content -LiteralPath $LIBRHASH_PROJ -Raw -Encoding UTF8
if ($librhashProject -match '(?i)USE_OPENSSL|OPENSSL_RUNTIME|libeay32|ssleay32') {
    throw 'librhash.vcxproj enables or links OpenSSL; update P5 audit before merging.'
}

Test-NoDirectOpenSslIncludes -Roots @(
    (Join-Path $REPO_ROOT 'src/Source'),
    (Join-Path $REPO_ROOT 'src/Updater'),
    (Join-Path $REPO_ROOT 'src/Prototype'),
    (Join-Path $REPO_ROOT 'src/Test')
)

Write-Host 'verify-rfc0012-p5-openssl-audit: OK (Release mainline clean, legacy debug links delegated)' -ForegroundColor Green
