# Fix SolutionDir paths in project files
# SolutionDir resolves to root, so paths should be $(SolutionDir)src\Source\common.props
$ErrorActionPreference = "Continue"

Write-Host "Fixing SolutionDir paths..." -ForegroundColor Cyan
Write-Host ""

$projectFiles = Get-ChildItem -Path "src\Source" -Filter "*.vcxproj" -Recurse

$fixedCount = 0
foreach ($file in $projectFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    $originalContent = $content
    
    # Fix common.props paths - SolutionDir is root, so need src\Source\common.props
    $content = $content -replace '\$\(SolutionDir\)Source\\common\.props', '$(SolutionDir)src\Source\common.props'
    $content = $content -replace '\$\(SolutionDir\)Source\\debug\.props', '$(SolutionDir)src\Source\debug.props'
    $content = $content -replace '\$\(SolutionDir\)Source\\release\.props', '$(SolutionDir)src\Source\release.props'
    
    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -Encoding UTF8 -NoNewline
        Write-Host "  [FIXED] $($file.Name)" -ForegroundColor Green
        $fixedCount++
    }
}

Write-Host ""
Write-Host "Fixed: $fixedCount files" -ForegroundColor Green
