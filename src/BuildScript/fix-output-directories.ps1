# Fix output directories in all project files
# 修复所有项目文件中的输出目录路径

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fix Output Directories" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Target paths (from common.props)
$targetOutDir = '$(SolutionDir)src\out\bin'
$targetIntDir = '$(SolutionDir)src\out\obj\$(ProjectName)'

$projectFiles = Get-ChildItem -Path "src" -Filter "*.vcxproj" -Recurse | Where-Object { $_.FullName -notmatch "backup" }

$fixedCount = 0
$checkedCount = 0
$fixedProjects = @()

foreach ($projectFile in $projectFiles) {
    $checkedCount++
    $content = Get-Content $projectFile.FullName -Raw -Encoding UTF8
    $originalContent = $content
    
    # Patterns to fix
    $patterns = @(
        # OutDir patterns
        @{ Pattern = '<OutDir>\$\(SolutionDir\)\\out\\bin\\</OutDir>'; Replacement = "<OutDir>$targetOutDir</OutDir>" },
        @{ Pattern = '<OutDir>\$\(SolutionDir\)out\\bin\\</OutDir>'; Replacement = "<OutDir>$targetOutDir</OutDir>" },
        @{ Pattern = '<OutDir>\$\(SolutionDir\)\$\(Configuration\)\\</OutDir>'; Replacement = "<OutDir>$targetOutDir</OutDir>" },
        @{ Pattern = '<OutDir>\$\(SolutionDir\)out\\lib\\\$\(Platform\)\\</OutDir>'; Replacement = "<OutDir>$targetOutDir</OutDir>" },
        
        # IntDir patterns
        @{ Pattern = '<IntDir>\$\(SolutionDir\)\\out\\obj\\\$\(ProjectName\)\\</IntDir>'; Replacement = "<IntDir>$targetIntDir</IntDir>" },
        @{ Pattern = '<IntDir>\$\(SolutionDir\)out\\obj\\\$\(ProjectName\)\\</IntDir>'; Replacement = "<IntDir>$targetIntDir</IntDir>" },
        @{ Pattern = '<IntDir>\$\(Configuration\)\\</IntDir>'; Replacement = "<IntDir>$targetIntDir</IntDir>" }
    )
    
    foreach ($pattern in $patterns) {
        if ($content -match $pattern.Pattern) {
            $content = $content -replace $pattern.Pattern, $pattern.Replacement
        }
    }
    
    if ($content -ne $originalContent) {
        # Backup
        $backupFile = "$($projectFile.FullName).backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $projectFile.FullName $backupFile -Force
        
        # Write fixed content
        $content | Out-File -FilePath $projectFile.FullName -Encoding UTF8 -NoNewline
        
        Write-Host "[FIXED] $($projectFile.FullName)" -ForegroundColor Green
        $fixedProjects += $projectFile.Name
        $fixedCount++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Checked: $checkedCount projects" -ForegroundColor Gray
Write-Host "  Fixed: $fixedCount projects" -ForegroundColor Green
Write-Host ""

if ($fixedCount -gt 0) {
    Write-Host "Fixed projects:" -ForegroundColor Yellow
    $fixedProjects | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
}

Write-Host ""
Write-Host "Target paths:" -ForegroundColor Yellow
Write-Host "  OutDir: $targetOutDir" -ForegroundColor Gray
Write-Host "  IntDir: $targetIntDir" -ForegroundColor Gray
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review the changes" -ForegroundColor White
Write-Host "2. Clean old output directories (bin/, Debug/, etc.)" -ForegroundColor White
Write-Host "3. Rebuild the solution" -ForegroundColor White
Write-Host "4. Verify output goes to src\out\bin\" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
