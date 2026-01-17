# Check project files for common issues
# 检查项目文件的常见问题

$ErrorActionPreference = "Continue"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcPath = Split-Path -Parent $scriptPath

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Project Files Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check for project files with old toolset
Write-Host "[1] Checking for old toolset versions..." -ForegroundColor Yellow

$projectFiles = Get-ChildItem -Path $srcPath -Filter "*.vcxproj" -Recurse -ErrorAction SilentlyContinue
$oldToolset = 0
$newToolset = 0

foreach ($file in $projectFiles) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        if ($content -match '<PlatformToolset>v120</PlatformToolset>') {
            Write-Host "  [X] Old toolset (v120): $($file.Name)" -ForegroundColor Red
            $oldToolset++
        } elseif ($content -match '<PlatformToolset>v144</PlatformToolset>') {
            $newToolset++
        }
    }
}

Write-Host ""
Write-Host "  Summary:" -ForegroundColor Cyan
Write-Host "    Files with v144: $newToolset" -ForegroundColor Green
if ($oldToolset -gt 0) {
    Write-Host "    Files with v120: $oldToolset" -ForegroundColor Red
    Write-Host ""
    Write-Host "  [WARNING] Some files still use old toolset!" -ForegroundColor Yellow
    Write-Host "  Run upgrade-to-vs2025.ps1 to fix." -ForegroundColor Yellow
} else {
    Write-Host "    All files upgraded!" -ForegroundColor Green
}

Write-Host ""

# Check for missing include directories
Write-Host "[2] Checking include directories..." -ForegroundColor Yellow

$includeDirs = @(
    "$srcPath\include",
    "$srcPath\Source\base"
)

foreach ($dir in $includeDirs) {
    if (Test-Path $dir) {
        Write-Host "  [OK] $dir" -ForegroundColor Green
    } else {
        Write-Host "  [X] Missing: $dir" -ForegroundColor Red
    }
}

Write-Host ""

# Check for solution file
Write-Host "[3] Checking solution file..." -ForegroundColor Yellow

$rootPath = Split-Path -Parent $srcPath
$solutionPaths = @(
    "$rootPath\splayer.sln",
    "$srcPath\splayer.sln"
)

$found = $false
foreach ($path in $solutionPaths) {
    if (Test-Path $path) {
        Write-Host "  [OK] Found: $path" -ForegroundColor Green
        $found = $true
        break
    }
}

if (-not $found) {
    Write-Host "  [X] Solution file not found!" -ForegroundColor Red
    Write-Host "  Searched:" -ForegroundColor Yellow
    foreach ($path in $solutionPaths) {
        Write-Host "    - $path" -ForegroundColor Gray
    }
}

Write-Host ""

# Check common.props
Write-Host "[4] Checking common.props..." -ForegroundColor Yellow

$commonProps = "$srcPath\Source\common.props"
if (Test-Path $commonProps) {
    $content = Get-Content $commonProps -Raw
    if ($content -match 'WINVER=0x0A00') {
        Write-Host "  [OK] Windows SDK version updated (Windows 10)" -ForegroundColor Green
    } elseif ($content -match 'WINVER=0x0601') {
        Write-Host "  [WARNING] Still using Windows 7 SDK" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [X] common.props not found" -ForegroundColor Red
}

Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Check Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
