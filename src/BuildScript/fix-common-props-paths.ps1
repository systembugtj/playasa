# Fix common.props path references in project files
# 修复项目文件中的 common.props 路径引用

$ErrorActionPreference = "Continue"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcPath = Split-Path -Parent $scriptPath

Write-Host "Fixing common.props path references..." -ForegroundColor Cyan
Write-Host ""

# Find all project files with incorrect common.props path
$projectFiles = Get-ChildItem -Path $srcPath -Filter "*.vcxproj" -Recurse -ErrorAction SilentlyContinue

$updated = 0
foreach ($file in $projectFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($content) {
        $originalContent = $content
        
        # Fix: $(SolutionDir)Source\common.props -> $(SolutionDir)src\Source\common.props
        $content = $content -replace '\$\(SolutionDir\)Source\\common\.props', '$(SolutionDir)src\Source\common.props'
        
        # Fix: $(SolutionDir)src\common.props -> $(SolutionDir)src\Source\common.props
        $content = $content -replace '\$\(SolutionDir\)src\\common\.props', '$(SolutionDir)src\Source\common.props'
        
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
