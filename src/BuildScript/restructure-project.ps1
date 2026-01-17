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

# Option 1: Minimal change - just move solution file
Write-Host "[Option 1] Minimal Change - Move Solution File Only" -ForegroundColor Cyan
Write-Host "  This is the recommended approach for minimal risk." -ForegroundColor White
Write-Host ""

$solutionFile = Join-Path $srcPath "splayer.sln"
$newSolutionPath = Join-Path $rootPath "splayer.sln"

if (Test-Path $solutionFile) {
    Write-Host "  Solution file found: $solutionFile" -ForegroundColor Green
    
    # Check if already in root
    if (Test-Path $newSolutionPath) {
        Write-Host "  [INFO] Solution file already exists in root" -ForegroundColor Yellow
    } else {
        Write-Host "  Would move to: $newSolutionPath" -ForegroundColor Cyan
        
        # Read solution file and update paths
        $content = Get-Content $solutionFile -Raw -Encoding UTF8
        
        # Update project paths (add "src\" prefix)
        $content = $content -replace 'Source\\', 'src\Source\'
        $content = $content -replace 'lib\\', 'src\lib\'
        $content = $content -replace 'Thirdparty\\', 'src\Thirdparty\'
        $content = $content -replace 'Test\\', 'src\Test\'
        $content = $content -replace 'Updater\\', 'src\Updater\'
        
        # Backup original
        Copy-Item $solutionFile "$solutionFile.backup" -Force
        
        # Write to new location
        [System.IO.File]::WriteAllText($newSolutionPath, $content, [System.Text.Encoding]::UTF8)
        
        Write-Host "  [OK] Solution file moved and paths updated" -ForegroundColor Green
    }
} else {
    Write-Host "  [WARNING] Solution file not found" -ForegroundColor Yellow
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
Write-Host "For Windows projects, the solution file should be in the root." -ForegroundColor Yellow
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
