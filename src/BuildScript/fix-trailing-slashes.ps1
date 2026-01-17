# Fix trailing slashes in OutDir and IntDir
# 修复 OutDir 和 IntDir 路径的尾部斜杠

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fix Trailing Slashes in Output Directories" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$projectFiles = Get-ChildItem -Path "src" -Filter "*.vcxproj" -Recurse | Where-Object { $_.FullName -notmatch "backup" }

$fixedCount = 0
$checkedCount = 0

foreach ($projectFile in $projectFiles) {
    $checkedCount++
    $content = Get-Content $projectFile.FullName -Raw -Encoding UTF8
    $originalContent = $content
    
    # Fix OutDir patterns (without trailing slash)
    $outDirPatterns = @(
        @{ Pattern = '<OutDir>(\$\(SolutionDir\)[^<]+[^\\])</OutDir>'; Replacement = '<OutDir>$1\</OutDir>' },
        @{ Pattern = '<OutDir>(\$\(SolutionDir\)src\\out\\bin)</OutDir>'; Replacement = '<OutDir>$1\</OutDir>' },
        @{ Pattern = '<OutDir>(\$\(SolutionDir\)src\\out\\obj\\[^<]+[^\\])</OutDir>'; Replacement = '<OutDir>$1\</OutDir>' }
    )
    
    # Fix IntDir patterns (without trailing slash)
    $intDirPatterns = @(
        @{ Pattern = '<IntDir>(\$\(SolutionDir\)[^<]+[^\\])</IntDir>'; Replacement = '<IntDir>$1\</IntDir>' },
        @{ Pattern = '<IntDir>(\$\(SolutionDir\)src\\out\\obj\\[^<]+[^\\])</IntDir>'; Replacement = '<IntDir>$1\</IntDir>' }
    )
    
    foreach ($pattern in $outDirPatterns) {
        if ($content -match $pattern.Pattern) {
            $content = $content -replace $pattern.Pattern, $pattern.Replacement
        }
    }
    
    foreach ($pattern in $intDirPatterns) {
        if ($content -match $pattern.Pattern) {
            $content = $content -replace $pattern.Pattern, $pattern.Replacement
        }
    }
    
    # Simple fix: ensure paths end with backslash if they don't
    # OutDir
    $content = $content -replace '<OutDir>(\$\(SolutionDir\)src\\out\\bin)</OutDir>', '<OutDir>$1\</OutDir>'
    $content = $content -replace '<OutDir>(\$\(SolutionDir\)src\\out\\obj\\\$\(ProjectName\))</OutDir>', '<OutDir>$1\</OutDir>'
    
    # IntDir
    $content = $content -replace '<IntDir>(\$\(SolutionDir\)src\\out\\obj\\\$\(ProjectName\))</IntDir>', '<IntDir>$1\</IntDir>'
    
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
