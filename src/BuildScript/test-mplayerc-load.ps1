# Test mplayerc project load
# 测试 mplayerc 项目加载

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test mplayerc Project Load" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$msbuild = "C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe"

if (-not (Test-Path $msbuild)) {
    Write-Host "[ERROR] MSBuild not found at: $msbuild" -ForegroundColor Red
    exit 1
}

Write-Host "MSBuild found: $msbuild" -ForegroundColor Green
Write-Host ""

# Test loading the solution
Write-Host "Testing solution load..." -ForegroundColor Yellow

$solutionFile = "splayer.sln"
if (-not (Test-Path $solutionFile)) {
    Write-Host "[ERROR] Solution file not found: $solutionFile" -ForegroundColor Red
    exit 1
}

# Try to load and validate the solution
$result = & $msbuild $solutionFile /p:Configuration="Release Unicode" /p:Platform=Win32 /t:splayer /v:minimal /nologo 2>&1

$errors = $result | Select-String -Pattern "error MSB"
$warnings = $result | Select-String -Pattern "warning"

if ($errors) {
    Write-Host "[ERROR] Found errors:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
} else {
    Write-Host "[OK] No errors found" -ForegroundColor Green
}

if ($warnings) {
    Write-Host "[WARNING] Found warnings:" -ForegroundColor Yellow
    $warnings | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
}

# Check for specific mplayerc errors
$mplayercErrors = $result | Select-String -Pattern "mplayerc.*error|failed to load.*mplayerc" -CaseSensitive:$false

if ($mplayercErrors) {
    Write-Host ""
    Write-Host "[ERROR] mplayerc specific errors:" -ForegroundColor Red
    $mplayercErrors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Done!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
