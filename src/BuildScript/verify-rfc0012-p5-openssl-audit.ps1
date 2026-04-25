#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0012 P5：确认活跃工程已从 OpenSSL 0.9.8x 迁出，缺失的旧 curl 库不再阻塞构建。
#>
$ErrorActionPreference = 'Stop'

$REPO_ROOT = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$EXPECT_FILE = Join-Path $REPO_ROOT 'src/Thirdparty/openssl-rfc0012-expected.txt'
$OPENSSL_TREE = Join-Path $REPO_ROOT 'src/Thirdparty/openssl-0.9.8x'
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

function Get-OptionalChildText {
    param(
        $Node,
        [string]$ChildName
    )
    $child = $Node.ChildNodes | Where-Object { $_.LocalName -eq $ChildName } | Select-Object -First 1
    if (-not $child) {
        return ''
    }
    return [string]$child.InnerText
}

function Test-NoOpenSslLink {
    param(
        [xml]$Project,
        [string]$ProjectName,
        [string]$Configuration,
        [string]$Platform
    )
    $group = Get-ItemDefinitionGroup -Project $Project -Configuration $Configuration -Platform $Platform
    $deps = Get-OptionalChildText -Node $group.Link -ChildName 'AdditionalDependencies'
    $delay = Get-OptionalChildText -Node $group.Link -ChildName 'DelayLoadDLLs'
    if ($deps -match '(?i)(libeay32|ssleay32|openssl)') {
        throw ($ProjectName + ' ' + $Configuration + '|' + $Platform + ' unexpectedly links OpenSSL: ' + $deps)
    }
    if ($delay -match '(?i)(libeay32|ssleay32|openssl)') {
        throw ($ProjectName + ' ' + $Configuration + '|' + $Platform + ' unexpectedly delay-loads OpenSSL: ' + $delay)
    }
}

function Test-HasSchannelSystemLink {
    param(
        [xml]$Project,
        [string]$ProjectName,
        [string]$Configuration,
        [string]$Platform
    )
    $group = Get-ItemDefinitionGroup -Project $Project -Configuration $Configuration -Platform $Platform
    $deps = Get-OptionalChildText -Node $group.Link -ChildName 'AdditionalDependencies'
    $schannelCurlLibs = @('Crypt32.lib', 'Secur32.lib', 'Wldap32.lib', 'Normaliz.lib', 'Ws2_32.lib')
    foreach ($lib in $schannelCurlLibs) {
        $escapedLib = [regex]::Escape($lib)
        if ($deps -notmatch $escapedLib) {
            throw ($ProjectName + ' ' + $Configuration + '|' + $Platform + ' is missing Schannel system dependency: ' + $lib)
        }
    }
    if ($deps -match '(?i)curllibd?\.lib') {
        throw ($ProjectName + ' ' + $Configuration + '|' + $Platform + ' still links a missing legacy curl library: ' + $deps)
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

foreach ($path in @($EXPECT_FILE, $MPLAYERC_PROJ, $UPDATER_PROJ, $LIBRHASH_PROJ)) {
    Test-RequiredFile $path
}

$tag = Read-FirstNonEmptyLine $EXPECT_FILE
if ($tag -ne 'openssl-0.9.8x-dropped') {
    throw "Unknown OpenSSL P5 expectation tag: '$tag'. Update verify-rfc0012-p5-openssl-audit.ps1."
}

if (Test-Path -LiteralPath $OPENSSL_TREE) {
    throw "OpenSSL 0.9.8x tree still exists: $OPENSSL_TREE"
}

[xml]$mplayerc = Get-Content -LiteralPath $MPLAYERC_PROJ -Raw -Encoding UTF8
[xml]$updater = Get-Content -LiteralPath $UPDATER_PROJ -Raw -Encoding UTF8

Test-NoOpenSslLink -Project $mplayerc -ProjectName 'mplayerc' -Configuration 'Release Unicode' -Platform 'Win32'
Test-NoOpenSslLink -Project $mplayerc -ProjectName 'mplayerc' -Configuration 'Release' -Platform 'Win32'
Test-NoOpenSslLink -Project $mplayerc -ProjectName 'mplayerc' -Configuration 'Debug Unicode' -Platform 'Win32'

Test-NoOpenSslLink -Project $updater -ProjectName 'Updater' -Configuration 'Release' -Platform 'Win32'
Test-NoOpenSslLink -Project $updater -ProjectName 'Updater' -Configuration 'Debug Unicode' -Platform 'Win32'
Test-NoOpenSslLink -Project $updater -ProjectName 'Updater' -Configuration 'Debug' -Platform 'Win32'
Test-HasSchannelSystemLink -Project $updater -ProjectName 'Updater' -Configuration 'Debug' -Platform 'Win32'

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

Write-Host 'verify-rfc0012-p5-openssl-audit: OK (OpenSSL dropped from active links, missing legacy curl lib removed)' -ForegroundColor Green
