# Fix release.props and debug.props path references
# 修复 release.props 和 debug.props 路径引用

$ErrorActionPreference = "Continue"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcPath = Split-Path -Parent $scriptPath

Write-Host "Fixing props file path references..." -ForegroundColor Cyan
Write-Host ""

$projectFiles = Get-ChildItem -Path $srcPath -Filter "*.vcxproj" -Recurse -ErrorAction SilentlyContinue

$updated = 0
foreach ($file in $projectFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($content) {
        $originalContent = $content
        
        # Fix release.props
        $content = $content -replace '\$\(SolutionDir\)Source\\release\.props', '$(SolutionDir)src\Source\release.props'
        
        # Fix debug.props
        $content = $content -replace '\$\(SolutionDir\)Source\\debug\.props', '$(SolutionDir)src\Source\debug.props'
        
        if ($content -ne $originalContent) {
            [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
            Write-Host "  Fixed: $($file.Name)" -ForegroundColor Green
            $updated++
        }
    }
}

Write-Host ""
Write-Host "Updated $updated project files" -ForegroundColor Green
Write-Host ""
