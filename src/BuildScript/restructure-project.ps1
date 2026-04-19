# Restructure project to standard Windows layout
# 重构项目为标准 Windows 布局

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Project Restructure Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcPath = Split-Path -Parent $scriptPath
$rootPath = Split-Path -Parent $srcPath

Write-Host "Current structure:" -ForegroundColor Yellow
Write-Host "  Root: $rootPath" -ForegroundColor Gray
Write-Host "  Source: $srcPath" -ForegroundColor Gray
Write-Host ""

# Option 1: 规范位置为 src\splayer.sln；若仅有根目录旧方案则迁入 src
Write-Host "[Option 1] Solution file location (canonical: src\splayer.sln)" -ForegroundColor Cyan
Write-Host ""

$canonicalSln = Join-Path $srcPath "splayer.sln"
$rootSln = Join-Path $rootPath "splayer.sln"

if (Test-Path $canonicalSln) {
    Write-Host "  [INFO] Canonical solution present: $canonicalSln" -ForegroundColor Green
} elseif (Test-Path $rootSln) {
    Write-Host "  [INFO] Found root-level solution; converting paths for src layout..." -ForegroundColor Yellow
    $content = Get-Content $rootSln -Raw -Encoding UTF8
    $content = $content -replace 'src\\Source\\', 'Source\\'
    $content = $content -replace 'src\\lib\\', 'lib\\'
    $content = $content -replace 'src\\Thirdparty\\', 'Thirdparty\\'
    $content = $content -replace 'src\\Test\\', 'Test\\'
    $content = $content -replace 'src\\Prototype\\', 'Prototype\\'
    Copy-Item $rootSln "$rootSln.backup" -Force
    [System.IO.File]::WriteAllText($canonicalSln, $content, [System.Text.Encoding]::UTF8)
    Write-Host "  [OK] Wrote: $canonicalSln (root file backed up)" -ForegroundColor Green
} else {
    Write-Host "  [WARNING] No splayer.sln under src or repo root" -ForegroundColor Yellow
}

Write-Host ""

# Option 2: Full restructure (commented out - requires user confirmation)
Write-Host "[Option 2] Full Restructure (Not Recommended)" -ForegroundColor Yellow
Write-Host "  This would move:" -ForegroundColor White
Write-Host "    - BuildScript/ → build/" -ForegroundColor Gray
Write-Host "    - out/ → output/" -ForegroundColor Gray
Write-Host "    - lib/ → libs/ (root)" -ForegroundColor Gray
Write-Host "    - Thirdparty/ → thirdparty/ (root)" -ForegroundColor Gray
Write-Host ""
Write-Host "  [WARNING] This requires updating many path references!" -ForegroundColor Red
Write-Host "  [WARNING] Only proceed if you understand the implications!" -ForegroundColor Red
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Recommendation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This repo keeps splayer.sln under src\ (see BuildScript *.cmd / *.ps1)." -ForegroundColor Yellow
Write-Host ""
Write-Host "Current structure is acceptable if:" -ForegroundColor White
Write-Host "  - The project is already working" -ForegroundColor Gray
Write-Host "  - Team is familiar with current structure" -ForegroundColor Gray
Write-Host "  - No need for major changes" -ForegroundColor Gray
Write-Host ""
Write-Host "Consider restructuring if:" -ForegroundColor White
Write-Host "  - Starting fresh or major modernization" -ForegroundColor Gray
Write-Host "  - Need to match company standards" -ForegroundColor Gray
Write-Host "  - Preparing for open source release" -ForegroundColor Gray
Write-Host ""
