# Fix BaseClasses include paths in all project files
# 修复所有项目文件中的 BaseClasses 包含路径

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fix BaseClasses Include Paths" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$projectFiles = Get-ChildItem -Path "src" -Filter "*.vcxproj" -Recurse | Where-Object { $_.FullName -notmatch "backup" }

$fixedCount = 0
$checkedCount = 0

foreach ($projectFile in $projectFiles) {
    $checkedCount++
    $content = Get-Content $projectFile.FullName -Raw -Encoding UTF8
    $originalContent = $content
    
    # Fix various incorrect BaseClasses paths
    $patterns = @(
        @{ Pattern = '\.\.\\\.\.\\\.\.\\\.\.\\src\\filters\\BaseClasses'; Replacement = '$(SolutionDir)src\Source\filters\BaseClasses' },
        @{ Pattern = '\.\.\\\.\.\\BaseClasses'; Replacement = '$(SolutionDir)src\Source\filters\BaseClasses' },
        @{ Pattern = '\.\.\\\.\.\\\.\.\\BaseClasses'; Replacement = '$(SolutionDir)src\Source\filters\BaseClasses' },
        @{ Pattern = '\.\.\\BaseClasses'; Replacement = '$(SolutionDir)src\Source\filters\BaseClasses' },
        @{ Pattern = '\$\(SolutionDir\)Source\\filters\\BaseClasses'; Replacement = '$(SolutionDir)src\Source\filters\BaseClasses' }
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
        $fixedCount++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Checked: $checkedCount projects" -ForegroundColor Gray
Write-Host "  Fixed: $fixedCount projects" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
