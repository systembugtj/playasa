# Test build environment and attempt build
# 测试构建环境并尝试构建

$ErrorActionPreference = "Continue"
Import-Module (Join-Path $PSScriptRoot 'TestSupport\SplayerTestSupport.psm1') -Force

$srcPath = Get-SplayerSrcRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Build Test and Diagnostics" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check for MSBuild
Write-Host "[1] Checking for MSBuild..." -ForegroundColor Yellow

$msbuildPath = $null
try {
    $msbuildPath = Get-SplayerMsBuildPath
    Write-Host "  [OK] Found: $msbuildPath" -ForegroundColor Green
} catch {
    Write-Host "  [X] MSBuild not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Please install Visual Studio Build Tools or Visual Studio" -ForegroundColor Yellow
    Write-Host "  Download from: https://visualstudio.microsoft.com/downloads/" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# 2. Check solution file
Write-Host "[2] Checking solution file..." -ForegroundColor Yellow

# 唯一支持的解决方案在 src/
$solutionPath = Join-Path $srcPath "splayer.sln"

if (-not (Test-Path $solutionPath)) {
    Write-Host "  [X] Solution file not found: $solutionPath" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Found: $solutionPath" -ForegroundColor Green

# 3. Check project files
Write-Host "[3] Checking project files..." -ForegroundColor Yellow

$projectFiles = Get-ChildItem -Path $srcPath -Filter "*.vcxproj" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 5
if ($projectFiles.Count -gt 0) {
    Write-Host "  [OK] Found $($projectFiles.Count) project files (showing first 5)" -ForegroundColor Green
    foreach ($file in $projectFiles) {
        Write-Host "    - $($file.Name)" -ForegroundColor Gray
    }
} else {
    Write-Host "  [WARNING] No project files found" -ForegroundColor Yellow
}

# 4. Try to build
Write-Host ""
Write-Host "[4] Attempting build..." -ForegroundColor Yellow
Write-Host ""

$buildArgs = @(
    $solutionPath,
    "/p:Configuration=Release Unicode",
    "/p:Platform=Win32",
    "/m",
    "/v:minimal",
    "/nologo"
)

Write-Host "Running: $msbuildPath $($buildArgs -join ' ')" -ForegroundColor Cyan
Write-Host ""

try {
    & $msbuildPath $buildArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Build completed successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Output should be in: src\out\bin\Release Unicode\" -ForegroundColor Cyan
    } else {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "Build failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "Try building with verbose output:" -ForegroundColor Yellow
        Write-Host "  $msbuildPath `"$solutionPath`" /p:Configuration=`"Release Unicode`" /p:Platform=Win32 /v:detailed" -ForegroundColor Gray
    }
} catch {
    Write-Host ""
    Write-Host "ERROR: Build failed with exception:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Stack trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}

Write-Host ""
