# 更新所有项目文件以遵循 Visual Studio 最佳实践
# 按配置分离输出目录：$(SolutionDir)src\out\bin\$(Platform)\$(Configuration)\

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fix Output Directories - VS Best Practice" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$targetOutDir = '$(SolutionDir)src\out\bin\$(Platform)\$(Configuration)\'
$targetIntDir = '$(SolutionDir)src\out\obj\$(ProjectName)\$(Platform)\$(Configuration)\'

$projectFiles = Get-ChildItem -Path "src" -Filter "*.vcxproj" -Recurse | Where-Object { $_.FullName -notmatch "backup" }

$fixedCount = 0
$checkedCount = 0

foreach ($projectFile in $projectFiles) {
    $checkedCount++
    $content = Get-Content $projectFile.FullName -Raw -Encoding UTF8
    $originalContent = $content
    
    # 跳过 common.props 本身
    if ($projectFile.Name -eq 'common.props') {
        continue
    }
    
    # 替换所有旧的输出目录路径
    $patterns = @(
        # 旧的统一路径（没有配置分离）
        @{ Pattern = '<OutDir>\$\(SolutionDir\)src\\out\\bin\\</OutDir>'; Replacement = "<OutDir>$targetOutDir</OutDir>" },
        @{ Pattern = '<OutDir>\$\(SolutionDir\)src\\out\\bin</OutDir>'; Replacement = "<OutDir>$targetOutDir</OutDir>" },
        
        # 旧的中间目录路径
        @{ Pattern = '<IntDir>\$\(SolutionDir\)src\\out\\obj\\\$\(ProjectName\)\\</IntDir>'; Replacement = "<IntDir>$targetIntDir</IntDir>" },
        @{ Pattern = '<IntDir>\$\(SolutionDir\)src\\out\\obj\\\$\(ProjectName\)</IntDir>'; Replacement = "<IntDir>$targetIntDir</IntDir>" },
        
        # 其他旧格式
        @{ Pattern = '<OutDir>\.\\Debug\\</OutDir>'; Replacement = "<OutDir>$targetOutDir</OutDir>" },
        @{ Pattern = '<OutDir>\$\(Configuration\)\\</OutDir>'; Replacement = "<OutDir>$targetOutDir</OutDir>" },
        @{ Pattern = '<OutDir>\$\(Configuration\)\$\(Platform\)\\</OutDir>'; Replacement = "<OutDir>$targetOutDir</OutDir>" },
        @{ Pattern = '<IntDir>\$\(Configuration\)\\</IntDir>'; Replacement = "<IntDir>$targetIntDir</IntDir>" },
        @{ Pattern = '<IntDir>\$\(Configuration\)\$\(Platform\)\\</IntDir>'; Replacement = "<IntDir>$targetIntDir</IntDir>" }
    )
    
    foreach ($pattern in $patterns) {
        $content = $content -replace $pattern.Pattern, $pattern.Replacement
    }
    
    if ($content -ne $originalContent) {
        Set-Content -Path $projectFile.FullName -Value $content -Encoding UTF8 -NoNewline
        Write-Host "  [FIXED] $($projectFile.Name)" -ForegroundColor Green
        $fixedCount++
    }
}

Write-Host ""
Write-Host "检查完成: $checkedCount 个项目文件" -ForegroundColor Cyan
Write-Host "修复完成: $fixedCount 个项目文件" -ForegroundColor Green
Write-Host ""
Write-Host "新的输出目录结构（遵循 VS 最佳实践）:" -ForegroundColor Yellow
Write-Host "  OutDir: $targetOutDir" -ForegroundColor Cyan
Write-Host "  IntDir: $targetIntDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "示例:" -ForegroundColor Yellow
Write-Host "  Debug|Win32:   src\out\bin\Win32\Debug\" -ForegroundColor White
Write-Host "  Release|Win32: src\out\bin\Win32\Release\" -ForegroundColor White
