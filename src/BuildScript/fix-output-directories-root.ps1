# 更新所有项目文件，将输出目录从 src\out 移到根目录的 out
# 遵循 Visual Studio 最佳实践：$(SolutionDir)out\bin\$(Platform)\$(Configuration)\

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fix Output Directories - Move to Root" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$targetOutDir = '$(SolutionDir)out\bin\$(Platform)\$(Configuration)\'
$targetIntDir = '$(SolutionDir)out\obj\$(ProjectName)\$(Platform)\$(Configuration)\'

$projectFiles = Get-ChildItem -Path "src" -Filter "*.vcxproj" -Recurse | Where-Object { $_.FullName -notmatch "backup" }

$fixedCount = 0
$checkedCount = 0

foreach ($projectFile in $projectFiles) {
    $checkedCount++
    $content = Get-Content $projectFile.FullName -Raw -Encoding UTF8
    $originalContent = $content
    
    # 跳过 common.props 本身（已经手动更新）
    if ($projectFile.Name -eq 'common.props') {
        continue
    }
    
    # 替换所有旧的输出目录路径
    $patterns = @(
        # 旧的 src\out 路径（带配置）
        @{ Pattern = '<OutDir>\$\(SolutionDir\)src\\out\\bin\\\$\(Platform\)\\\$\(Configuration\)\\</OutDir>'; Replacement = "<OutDir>$targetOutDir</OutDir>" },
        @{ Pattern = '<OutDir>\$\(SolutionDir\)src\\out\\bin\\\$\(Configuration\)\\</OutDir>'; Replacement = "<OutDir>$targetOutDir</OutDir>" },
        @{ Pattern = '<OutDir>\$\(SolutionDir\)src\\out\\bin\\</OutDir>'; Replacement = "<OutDir>$targetOutDir</OutDir>" },
        @{ Pattern = '<OutDir>\$\(SolutionDir\)src\\out\\bin</OutDir>'; Replacement = "<OutDir>$targetOutDir</OutDir>" },
        
        # 旧的中间目录路径
        @{ Pattern = '<IntDir>\$\(SolutionDir\)src\\out\\obj\\\$\(ProjectName\)\\\$\(Platform\)\\\$\(Configuration\)\\</IntDir>'; Replacement = "<IntDir>$targetIntDir</IntDir>" },
        @{ Pattern = '<IntDir>\$\(SolutionDir\)src\\out\\obj\\\$\(ProjectName\)\\\$\(Configuration\)\\</IntDir>'; Replacement = "<IntDir>$targetIntDir</IntDir>" },
        @{ Pattern = '<IntDir>\$\(SolutionDir\)src\\out\\obj\\\$\(ProjectName\)\\</IntDir>'; Replacement = "<IntDir>$targetIntDir</IntDir>" },
        @{ Pattern = '<IntDir>\$\(SolutionDir\)src\\out\\obj\\\$\(ProjectName\)</IntDir>'; Replacement = "<IntDir>$targetIntDir</IntDir>" },
        
        # 其他旧格式
        @{ Pattern = '<OutDir>\.\\Debug\\</OutDir>'; Replacement = "<OutDir>$targetOutDir</OutDir>" },
        @{ Pattern = '<OutDir>\$\(Configuration\)\\</OutDir>'; Replacement = "<OutDir>$targetOutDir</OutDir>" },
        @{ Pattern = '<OutDir>\$\(Configuration\)\$\(Platform\)\\</OutDir>'; Replacement = "<OutDir>$targetOutDir</OutDir>" },
        @{ Pattern = '<IntDir>\$\(Configuration\)\\</IntDir>'; Replacement = "<IntDir>$targetIntDir</IntDir>" },
        @{ Pattern = '<IntDir>\$\(Configuration\)\$\(Platform\)\\</IntDir>'; Replacement = "<IntDir>$targetIntDir</IntDir>" },
        
        # 库搜索路径
        @{ Pattern = '<AdditionalLibraryDirectories>\$\(SolutionDir\)src\\out\\bin\\\$\(Platform\)\\\$\(Configuration\);'; Replacement = '<AdditionalLibraryDirectories>$(SolutionDir)out\bin\$(Platform)\$(Configuration);' },
        @{ Pattern = '<AdditionalLibraryDirectories>\$\(SolutionDir\)src\\out\\bin;'; Replacement = '<AdditionalLibraryDirectories>$(SolutionDir)out\bin\$(Platform)\$(Configuration);' }
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
Write-Host "新的输出目录结构（根目录）:" -ForegroundColor Yellow
Write-Host "  OutDir: $targetOutDir" -ForegroundColor Cyan
Write-Host "  IntDir: $targetIntDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "示例:" -ForegroundColor Yellow
Write-Host "  Debug|Win32:   out\bin\Win32\Debug\" -ForegroundColor White
Write-Host "  Release|Win32: out\bin\Win32\Release\" -ForegroundColor White
