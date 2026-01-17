# Upgrade project files to support Visual Studio 2025
# 升级项目文件以支持 Visual Studio 2025

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Upgrading Projects to VS2025 (v144)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcPath = Split-Path -Parent $scriptPath

# Find all .vcxproj files
Write-Host "[1] Finding project files..." -ForegroundColor Yellow

$projectFiles = Get-ChildItem -Path $srcPath -Filter "*.vcxproj" -Recurse

Write-Host "  Found $($projectFiles.Count) project files" -ForegroundColor Green
Write-Host ""

# Upgrade each project file
Write-Host "[2] Upgrading project files..." -ForegroundColor Yellow

$upgradedCount = 0
$skippedCount = 0

foreach ($projectFile in $projectFiles) {
    $content = Get-Content $projectFile.FullName -Raw -Encoding UTF8
    $originalContent = $content
    $modified = $false
    
    # Replace PlatformToolset v120 with v144
    if ($content -match '<PlatformToolset>v120</PlatformToolset>') {
        $content = $content -replace '<PlatformToolset>v120</PlatformToolset>', '<PlatformToolset>v144</PlatformToolset>'
        $modified = $true
    }
    
    # Also update other old toolsets to v144
    if ($content -match '<PlatformToolset>v(140|141|142|143)</PlatformToolset>') {
        $content = $content -replace '<PlatformToolset>v(140|141|142|143)</PlatformToolset>', '<PlatformToolset>v144</PlatformToolset>'
        $modified = $true
    }
    
    if ($modified) {
        try {
            # Backup original file
            $backupPath = $projectFile.FullName + ".backup"
            Copy-Item $projectFile.FullName $backupPath -Force
            
            # Write updated content
            [System.IO.File]::WriteAllText($projectFile.FullName, $content, [System.Text.Encoding]::UTF8)
            
            Write-Host "  [OK] Upgraded: $($projectFile.Name)" -ForegroundColor Green
            $upgradedCount++
        } catch {
            Write-Host "  [ERROR] Failed to upgrade: $($projectFile.Name)" -ForegroundColor Red
            Write-Host "    Error: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  [SKIP] Already updated: $($projectFile.Name)" -ForegroundColor Gray
        $skippedCount++
    }
}

Write-Host ""
Write-Host "  Summary:" -ForegroundColor Cyan
Write-Host "    Upgraded: $upgradedCount files" -ForegroundColor Green
Write-Host "    Skipped: $skippedCount files" -ForegroundColor Gray
Write-Host ""

# Update solution file
Write-Host "[3] Checking solution file..." -ForegroundColor Yellow

$solutionFile = Join-Path $srcPath "splayer.sln"
if (Test-Path $solutionFile) {
    $solContent = Get-Content $solutionFile -Raw -Encoding UTF8
    
    # Update Visual Studio version in solution file
    if ($solContent -match 'VisualStudioVersion = 12\.0') {
        $solContent = $solContent -replace 'VisualStudioVersion = 12\.0', 'VisualStudioVersion = 18.0'
        $solContent = $solContent -replace '# Visual Studio 2013', '# Visual Studio 2025'
        
        # Backup
        Copy-Item $solutionFile "$solutionFile.backup" -Force
        
        # Write updated
        [System.IO.File]::WriteAllText($solutionFile, $solContent, [System.Text.Encoding]::UTF8)
        
        Write-Host "  [OK] Upgraded solution file" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] Solution file already updated" -ForegroundColor Gray
    }
} else {
    Write-Host "  [WARNING] Solution file not found" -ForegroundColor Yellow
}

Write-Host ""

# Update common.props
Write-Host "[4] Updating common.props..." -ForegroundColor Yellow

$commonProps = Join-Path $srcPath "Source\common.props"
if (Test-Path $commonProps) {
    $propsContent = Get-Content $commonProps -Raw -Encoding UTF8
    
    # Update Windows SDK version to Windows 10/11
    if ($propsContent -match 'WINVER=0x0601') {
        $propsContent = $propsContent -replace 'WINVER=0x0601', 'WINVER=0x0A00'
        $propsContent = $propsContent -replace '_WIN32_WINNT=0x0601', '_WIN32_WINNT=0x0A00'
        $propsContent = $propsContent -replace 'NTDDI_VERSION=NTDDI_WIN7', 'NTDDI_VERSION=NTDDI_WIN10_RS1'
        
        # Backup
        Copy-Item $commonProps "$commonProps.backup" -Force
        
        # Write updated
        [System.IO.File]::WriteAllText($commonProps, $propsContent, [System.Text.Encoding]::UTF8)
        
        Write-Host "  [OK] Updated Windows SDK version" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] common.props already updated" -ForegroundColor Gray
    }
} else {
    Write-Host "  [WARNING] common.props not found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Upgrade Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Open the solution in Visual Studio 2025" -ForegroundColor White
Write-Host "2. Right-click solution -> Retarget Projects" -ForegroundColor White
Write-Host "3. Select Windows SDK version 10.0 or 11.0" -ForegroundColor White
Write-Host "4. Try building the project" -ForegroundColor White
Write-Host ""
Write-Host "Backup files created with .backup extension" -ForegroundColor Cyan
Write-Host ""
