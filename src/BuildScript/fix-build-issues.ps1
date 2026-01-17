# PowerShell script to fix common build issues
# UTF-8 with BOM encoding required for Chinese characters

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SPlayer Build Issue Fixer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Continue"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcPath = Split-Path -Parent $scriptPath

# 1. Check missing key files
Write-Host "[1] Checking key files..." -ForegroundColor Yellow

$keyFiles = @(
    @{Path = "$srcPath\Source\svplib\shooterclient.key"; Dummy = "$scriptPath\shooterclient_dummy.key"},
    @{Path = "$srcPath\include\shooterclient.key"; Dummy = "$scriptPath\shooterclient_dummy.key"},
    @{Path = "$srcPath\include\shooterapi.key"; Dummy = "$scriptPath\shooterapi_dummy.key"}
)

foreach ($key in $keyFiles) {
    if (-not (Test-Path $key.Path)) {
        Write-Host "  [X] Missing: $($key.Path)" -ForegroundColor Red
        if (Test-Path $key.Dummy) {
            Copy-Item $key.Dummy $key.Path -Force
            Write-Host "    -> Created from dummy file" -ForegroundColor Green
        } else {
            Write-Host "    -> Warning: dummy file not found, creating empty file" -ForegroundColor Yellow
            "# Dummy key file" | Out-File -FilePath $key.Path -Encoding ASCII
            Write-Host "    -> Created empty file" -ForegroundColor Green
        }
    } else {
        Write-Host "  [OK] Exists: $($key.Path)" -ForegroundColor Green
    }
}

Write-Host ""

# 2. Check Visual Studio environment
Write-Host "[2] Checking Visual Studio environment..." -ForegroundColor Yellow

$vsVersions = @(
    @{Name = "VS2026"; Var = "VS180COMNTOOLS"; Toolset = "v144"},
    @{Name = "VS2022"; Var = "VS170COMNTOOLS"; Toolset = "v143"},
    @{Name = "VS2019"; Var = "VS160COMNTOOLS"; Toolset = "v142"},
    @{Name = "VS2017"; Var = "VS150COMNTOOLS"; Toolset = "v141"},
    @{Name = "VS2015"; Var = "VS140COMNTOOLS"; Toolset = "v140"},
    @{Name = "VS2013"; Var = "VS120COMNTOOLS"; Toolset = "v120"}
)

$foundVS = $null
foreach ($vs in $vsVersions) {
    $varValue = [Environment]::GetEnvironmentVariable($vs.Var, "Machine")
    if ([string]::IsNullOrEmpty($varValue)) {
        $varValue = [Environment]::GetEnvironmentVariable($vs.Var, "User")
    }
    
    if (-not [string]::IsNullOrEmpty($varValue) -and (Test-Path $varValue)) {
        Write-Host "  [OK] Found: $($vs.Name) ($($vs.Toolset))" -ForegroundColor Green
        if ($null -eq $foundVS) {
            $foundVS = $vs
        }
    } else {
        Write-Host "  [X] Not found: $($vs.Name)" -ForegroundColor Gray
    }
}

if ($null -eq $foundVS) {
    Write-Host "  [WARNING] No Visual Studio installation found" -ForegroundColor Red
    Write-Host "    Please install Visual Studio 2013 or later" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "  Recommended: $($foundVS.Name) ($($foundVS.Toolset))" -ForegroundColor Cyan
}

Write-Host ""

# 3. Check missing dependency directories
Write-Host "[3] Checking dependency directories..." -ForegroundColor Yellow

$deps = @(
    "$srcPath\..\thirdparty\pkg\trunk\sphash",
    "$srcPath\..\thirdparty\sinet\trunk\sinet",
    "$srcPath\..\thirdparty\pkg\trunk\unrar"
)

$missingDeps = @()
foreach ($dep in $deps) {
    if (Test-Path $dep) {
        Write-Host "  [OK] Exists: $dep" -ForegroundColor Green
    } else {
        Write-Host "  [X] Missing: $dep" -ForegroundColor Red
        $missingDeps += $dep
    }
}

if ($missingDeps.Count -gt 0) {
    Write-Host ""
    Write-Host "  [WARNING] Missing dependencies that may affect build:" -ForegroundColor Yellow
    foreach ($dep in $missingDeps) {
        Write-Host "    - $dep" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  These dependencies need to be obtained from other repositories" -ForegroundColor Yellow
}

Write-Host ""

# 4. Check revision.h file
Write-Host "[4] Checking revision.h file..." -ForegroundColor Yellow

$revisionFile = "$srcPath\Source\apps\mplayerc\revision.h"
if (Test-Path $revisionFile) {
    Write-Host "  [OK] Exists: $revisionFile" -ForegroundColor Green
} else {
    Write-Host "  [X] Missing: $revisionFile" -ForegroundColor Red
    $dummyRevision = "$scriptPath\revision_dummy.h"
    if (Test-Path $dummyRevision) {
        Copy-Item $dummyRevision $revisionFile -Force
        Write-Host "    -> Created from dummy file" -ForegroundColor Green
    } else {
        $revisionContent = @"
#pragma once
#define SVP_REV_STR     L"unknown"
#define SVP_REV_NUMBER  0
#define BRANCHVER       L"36"
"@
        $revisionContent | Out-File -FilePath $revisionFile -Encoding UTF8
        Write-Host "    -> Created default file" -ForegroundColor Green
    }
}

Write-Host ""

# 5. Check output directories
Write-Host "[5] Checking output directories..." -ForegroundColor Yellow

$outDirs = @(
    "$srcPath\out\bin",
    "$srcPath\out\obj"
)

foreach ($dir in $outDirs) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
        Write-Host "  [OK] Created: $dir" -ForegroundColor Green
    } else {
        Write-Host "  [OK] Exists: $dir" -ForegroundColor Green
    }
}

Write-Host ""

# 6. Check improved build script
Write-Host "[6] Checking build scripts..." -ForegroundColor Yellow

$newBuildPath = "$scriptPath\build-fixed.cmd"
if (Test-Path $newBuildPath) {
    Write-Host "  [OK] Exists: $newBuildPath" -ForegroundColor Green
} else {
    Write-Host "  [X] Missing: $newBuildPath" -ForegroundColor Yellow
    Write-Host "    Note: build-fixed.cmd should already exist" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fix completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. If dependencies are missing, get thirdparty/pkg and thirdparty/sinet" -ForegroundColor White
Write-Host "2. Run build script: build-fixed.cmd" -ForegroundColor White
Write-Host "   Or use original: build.cmd (requires VS2013)" -ForegroundColor White
Write-Host ""
