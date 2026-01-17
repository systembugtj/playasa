# Test build environment and attempt build
# 测试构建环境并尝试构建

$ErrorActionPreference = "Continue"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcPath = Split-Path -Parent $scriptPath
$rootPath = Split-Path -Parent $srcPath

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Build Test and Diagnostics" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check for MSBuild
Write-Host "[1] Checking for MSBuild..." -ForegroundColor Yellow

$msbuildPaths = @(
    "${env:ProgramFiles}\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe",
    "${env:ProgramFiles}\Microsoft Visual Studio\2026\Community\MSBuild\Current\Bin\MSBuild.exe",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2026\Community\MSBuild\Current\Bin\MSBuild.exe",
    "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
    "${env:ProgramFiles}\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe"
)

$msbuildPath = $null
foreach ($path in $msbuildPaths) {
    if (Test-Path $path) {
        Write-Host "  [OK] Found: $path" -ForegroundColor Green
        $msbuildPath = $path
        break
    }
}

if ($null -eq $msbuildPath) {
    Write-Host "  [X] MSBuild not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Please install Visual Studio Build Tools or Visual Studio" -ForegroundColor Yellow
    Write-Host "  Download from: https://visualstudio.microsoft.com/downloads/" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# 2. Check solution file
Write-Host "[2] Checking solution file..." -ForegroundColor Yellow

$solutionPaths = @(
    "$rootPath\splayer.sln",
    "$srcPath\splayer.sln"
)

$solutionPath = $null
foreach ($path in $solutionPaths) {
    if (Test-Path $path) {
        Write-Host "  [OK] Found: $path" -ForegroundColor Green
        $solutionPath = $path
        break
    }
}

if ($null -eq $solutionPath) {
    Write-Host "  [X] Solution file not found" -ForegroundColor Red
    Write-Host "  Searched:" -ForegroundColor Yellow
    foreach ($path in $solutionPaths) {
        Write-Host "    - $path" -ForegroundColor Gray
    }
    exit 1
}

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
