# Find MSBuild on the system
# 在系统中查找 MSBuild

$ErrorActionPreference = "Continue"

Write-Host "Searching for MSBuild..." -ForegroundColor Cyan
Write-Host ""

# Common MSBuild locations
$searchPaths = @(
    "${env:ProgramFiles}\Microsoft Visual Studio",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio",
    "${env:ProgramFiles}\MSBuild",
    "${env:ProgramFiles(x86)}\MSBuild",
    "${env:ProgramFiles}\Windows Kits",
    "${env:ProgramFiles(x86)}\Windows Kits"
)

$foundMsbuilds = @()

foreach ($basePath in $searchPaths) {
    if (Test-Path $basePath) {
        Write-Host "Searching: $basePath" -ForegroundColor Yellow
        $msbuilds = Get-ChildItem -Path $basePath -Filter "MSBuild.exe" -Recurse -ErrorAction SilentlyContinue -Depth 5
        foreach ($msbuild in $msbuilds) {
            $foundMsbuilds += $msbuild
            Write-Host "  [FOUND] $($msbuild.FullName)" -ForegroundColor Green
        }
    }
}

Write-Host ""

if ($foundMsbuilds.Count -eq 0) {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "MSBuild Not Found" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Visual Studio or Build Tools:" -ForegroundColor Yellow
    Write-Host "  https://visualstudio.microsoft.com/downloads/" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Found $($foundMsbuilds.Count) MSBuild installation(s)" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    # Try to determine VS version
    foreach ($msbuild in $foundMsbuilds) {
        $path = $msbuild.FullName
        Write-Host "Path: $path" -ForegroundColor Cyan
        
        # Extract version info from path
        if ($path -match '2026') {
            Write-Host "  Version: Visual Studio 2026" -ForegroundColor Green
        } elseif ($path -match '2022') {
            Write-Host "  Version: Visual Studio 2022" -ForegroundColor Green
        } elseif ($path -match '2019') {
            Write-Host "  Version: Visual Studio 2019" -ForegroundColor Green
        } elseif ($path -match '2017') {
            Write-Host "  Version: Visual Studio 2017" -ForegroundColor Green
        }
        
        # Test if it works
        Write-Host "  Testing..." -ForegroundColor Yellow
        try {
            $version = & $path -version 2>&1
            Write-Host "  Version: $version" -ForegroundColor Gray
        } catch {
            Write-Host "  [WARNING] Could not get version" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    # Suggest using the first one
    if ($foundMsbuilds.Count -gt 0) {
        $recommended = $foundMsbuilds[0].FullName
        Write-Host "Recommended MSBuild:" -ForegroundColor Cyan
        Write-Host "  $recommended" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can use it with:" -ForegroundColor Yellow
        Write-Host "  `"$recommended`" `"$((Get-Location).Path)\..\..\splayer.sln`" /p:Configuration=`"Release Unicode`" /p:Platform=Win32" -ForegroundColor White
    }
}

Write-Host ""
