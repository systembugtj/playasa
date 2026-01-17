# Fix mplayerc project file paths
# 修复 mplayerc 项目文件路径

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fix mplayerc Project Paths" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$projectFile = "src\Source\apps\mplayerc\mplayerc_vs2005.vcxproj"

if (-not (Test-Path $projectFile)) {
    Write-Host "[ERROR] Project file not found: $projectFile" -ForegroundColor Red
    exit 1
}

Write-Host "Reading project file: $projectFile" -ForegroundColor Yellow

$content = Get-Content $projectFile -Raw -Encoding UTF8
$originalContent = $content

# Fix paths
# 1. Fix $(SolutionDir)Source\apps\mplayerc\atlserver_integration.props
#    Should be: $(SolutionDir)src\Source\apps\mplayerc\atlserver_integration.props
$content = $content -replace '\$\(SolutionDir\)Source\\apps\\mplayerc\\atlserver_integration\.props', '$(SolutionDir)src\Source\apps\mplayerc\atlserver_integration.props'

# 2. Fix $(SolutionDir)Thirdparty\ paths
#    Should be: $(SolutionDir)src\Thirdparty\
$content = $content -replace '\$\(SolutionDir\)Thirdparty\\', '$(SolutionDir)src\Thirdparty\'

# 3. Fix relative paths for common.props, debug.props, release.props
#    For Debug|Win32 and Debug Unicode|Win32: ..\..\common.props -> $(SolutionDir)src\Source\common.props
#    For Release|Win32: ..\..\common.props -> $(SolutionDir)src\Source\common.props
#    For Release Unicode|Win32: already correct

# Actually, let's keep relative paths where they work, but fix the inconsistent ones
# The issue is that some use $(SolutionDir)Source\ and some use $(SolutionDir)src\Source\

# Check if content changed
if ($content -ne $originalContent) {
    # Backup original
    $backupFile = "$projectFile.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $projectFile $backupFile -Force
    Write-Host "[OK] Created backup: $backupFile" -ForegroundColor Green
    
    # Write fixed content
    $content | Out-File -FilePath $projectFile -Encoding UTF8 -NoNewline
    Write-Host "[OK] Fixed project file paths" -ForegroundColor Green
} else {
    Write-Host "[INFO] No path issues found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Checking for common path issues..." -ForegroundColor Yellow

# Check for specific problematic patterns
$issues = @()

if ($content -match '\$\(SolutionDir\)Source\\') {
    $issues += "Found $(SolutionDir)Source\ paths (should be $(SolutionDir)src\Source\)"
}

if ($content -match '\$\(SolutionDir\)Thirdparty\\') {
    $issues += "Found $(SolutionDir)Thirdparty\ paths (should be $(SolutionDir)src\Thirdparty\)"
}

if ($issues.Count -gt 0) {
    Write-Host "[WARNING] Found potential path issues:" -ForegroundColor Yellow
    foreach ($issue in $issues) {
        Write-Host "  - $issue" -ForegroundColor Gray
    }
} else {
    Write-Host "[OK] No obvious path issues found" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Done!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
