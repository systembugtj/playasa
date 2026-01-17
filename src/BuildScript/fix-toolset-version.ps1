# Fix toolset version - VS2026 might use v143 instead of v144
# 修复工具集版本 - VS2026 可能使用 v143 而不是 v144

$ErrorActionPreference = "Continue"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcPath = Split-Path -Parent $scriptPath

Write-Host "Checking available toolsets..." -ForegroundColor Cyan
Write-Host ""

# Check what toolset versions are available
$vsPath = "C:\Program Files\Microsoft Visual Studio\18\Community"
$vcToolsPath = Join-Path $vsPath "VC\Auxiliary\Build"

if (Test-Path $vcToolsPath) {
    $toolsets = Get-ChildItem $vcToolsPath -Directory -ErrorAction SilentlyContinue
    Write-Host "Available toolsets:" -ForegroundColor Yellow
    foreach ($toolset in $toolsets) {
        Write-Host "  - $($toolset.Name)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Check for v143 or v144
    $hasV143 = Test-Path (Join-Path $vcToolsPath "v143")
    $hasV144 = Test-Path (Join-Path $vcToolsPath "v144")
    
    if ($hasV144) {
        Write-Host "[OK] v144 toolset found" -ForegroundColor Green
        $targetToolset = "v144"
    } elseif ($hasV143) {
        Write-Host "[WARNING] v144 not found, but v143 is available" -ForegroundColor Yellow
        Write-Host "  VS2026 might use v143 toolset" -ForegroundColor Yellow
        $targetToolset = "v143"
    } else {
        Write-Host "[WARNING] Neither v143 nor v144 found" -ForegroundColor Yellow
        Write-Host "  Available toolsets: $($toolsets.Name -join ', ')" -ForegroundColor Gray
        $targetToolset = $null
    }
} else {
    Write-Host "[ERROR] VC Tools path not found: $vcToolsPath" -ForegroundColor Red
    $targetToolset = $null
}

Write-Host ""

# Always update to the found toolset if different from v144
if ($null -ne $targetToolset) {
    Write-Host "Updating project files to use $targetToolset..." -ForegroundColor Yellow
    
    $projectFiles = Get-ChildItem -Path $srcPath -Filter "*.vcxproj" -Recurse -ErrorAction SilentlyContinue
    
    $updated = 0
    foreach ($file in $projectFiles) {
        $content = Get-Content $file.FullName -Raw -Encoding UTF8
        $originalContent = $content
        
        # Replace v144 with the actual toolset
        if ($content -match '<PlatformToolset>v144</PlatformToolset>') {
            $newContent = $content -replace '<PlatformToolset>v144</PlatformToolset>', "<PlatformToolset>$targetToolset</PlatformToolset>"
            [System.IO.File]::WriteAllText($file.FullName, $newContent, [System.Text.Encoding]::UTF8)
            $updated++
        }
    }
    
    if ($updated -gt 0) {
        Write-Host "Updated $updated project files to use $targetToolset" -ForegroundColor Green
    } else {
        Write-Host "No files needed updating" -ForegroundColor Gray
    }
} else {
    Write-Host "[ERROR] Could not determine toolset version!" -ForegroundColor Red
    Write-Host "  Please check Visual Studio installation" -ForegroundColor Yellow
}

Write-Host ""
