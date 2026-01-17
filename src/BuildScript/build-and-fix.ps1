# Build solution and fix errors
# 构建解决方案并修复错误

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Build Solution and Fix Errors" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$msbuild = "C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe"

if (-not (Test-Path $msbuild)) {
    Write-Host "[ERROR] MSBuild not found at: $msbuild" -ForegroundColor Red
    exit 1
}

Write-Host "MSBuild: $msbuild" -ForegroundColor Green
Write-Host "Configuration: Release Unicode" -ForegroundColor Green
Write-Host "Platform: Win32" -ForegroundColor Green
Write-Host ""

# Build the solution
Write-Host "Building solution..." -ForegroundColor Yellow
$result = & $msbuild "splayer.sln" /p:Configuration="Release Unicode" /p:Platform=Win32 /m /v:minimal /nologo 2>&1

# Capture all output
$output = $result | Out-String

# Check for errors
$errors = $result | Select-String -Pattern "error MSB|error C[0-9]|error LNK|error RC" 

# Check for build status
$buildStatus = $result | Select-String -Pattern "Build succeeded|Build FAILED"

Write-Host ""
if ($buildStatus) {
    Write-Host $buildStatus -ForegroundColor $(if ($buildStatus -match "succeeded") { "Green" } else { "Red" })
}

if ($errors) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Build Errors Found:" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    
    $errorCount = 0
    $errors | ForEach-Object {
        $errorCount++
        if ($errorCount -le 30) {
            Write-Host $_ -ForegroundColor Red
        }
    }
    
    if ($errorCount -gt 30) {
        Write-Host "... and $($errorCount - 30) more errors" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Total errors: $errorCount" -ForegroundColor Red
    
    # Analyze error types
    $msbErrors = $errors | Select-String -Pattern "error MSB"
    $compileErrors = $errors | Select-String -Pattern "error C[0-9]"
    $linkErrors = $errors | Select-String -Pattern "error LNK"
    $resourceErrors = $errors | Select-String -Pattern "error RC"
    
    Write-Host ""
    Write-Host "Error breakdown:" -ForegroundColor Yellow
    if ($msbErrors) { Write-Host "  MSBuild errors: $($msbErrors.Count)" -ForegroundColor Gray }
    if ($compileErrors) { Write-Host "  Compilation errors: $($compileErrors.Count)" -ForegroundColor Gray }
    if ($linkErrors) { Write-Host "  Link errors: $($linkErrors.Count)" -ForegroundColor Gray }
    if ($resourceErrors) { Write-Host "  Resource errors: $($resourceErrors.Count)" -ForegroundColor Gray }
    
    # Save errors to file
    $errorFile = "build-errors-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    $errors | Out-File -FilePath $errorFile -Encoding UTF8
    Write-Host ""
    Write-Host "Errors saved to: $errorFile" -ForegroundColor Yellow
    
    exit 1
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Build completed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    exit 0
}
