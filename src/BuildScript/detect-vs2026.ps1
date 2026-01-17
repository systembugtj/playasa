# Detect Visual Studio 2026 installation
# 检测 Visual Studio 2026 安装

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "Detecting Visual Studio 2026..." -ForegroundColor Cyan
Write-Host ""

# Method 1: Check environment variable
$vs2026Path = $null

# VS2026 uses VS180COMNTOOLS (version 18.0)
$envVars = @(
    "VS180COMNTOOLS",  # Expected for VS2026
    "VS175COMNTOOLS",  # Alternative
    "VS174COMNTOOLS"   # Alternative
)

foreach ($var in $envVars) {
    $path = [Environment]::GetEnvironmentVariable($var, "Machine")
    if ([string]::IsNullOrEmpty($path)) {
        $path = [Environment]::GetEnvironmentVariable($var, "User")
    }
    
    if (-not [string]::IsNullOrEmpty($path) -and (Test-Path $path)) {
        Write-Host "[OK] Found via environment variable: $var" -ForegroundColor Green
        Write-Host "     Path: $path" -ForegroundColor Gray
        $vs2026Path = $path
        break
    }
}

# Method 2: Check registry
if ($null -eq $vs2026Path) {
    Write-Host "Checking registry..." -ForegroundColor Yellow
    
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\VisualStudio\18.0\Setup\VS",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\18.0\Setup\VS",
        "HKLM:\SOFTWARE\Microsoft\VisualStudio\SxS\VS7",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\SxS\VS7"
    )
    
    foreach ($regPath in $regPaths) {
        if (Test-Path $regPath) {
            try {
                $installPath = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue)."18.0"
                if (-not [string]::IsNullOrEmpty($installPath) -and (Test-Path $installPath)) {
                    $commonTools = Join-Path $installPath "Common7\Tools"
                    if (Test-Path $commonTools) {
                        Write-Host "[OK] Found via registry: $regPath" -ForegroundColor Green
                        Write-Host "     Path: $commonTools" -ForegroundColor Gray
                        $vs2026Path = $commonTools
                        break
                    }
                }
            } catch {
                # Continue searching
            }
        }
    }
}

# Method 3: Check common installation paths
if ($null -eq $vs2026Path) {
    Write-Host "Checking common installation paths..." -ForegroundColor Yellow
    
    $commonPaths = @(
        "${env:ProgramFiles}\Microsoft Visual Studio\2026\Community\Common7\Tools",
        "${env:ProgramFiles}\Microsoft Visual Studio\2026\Professional\Common7\Tools",
        "${env:ProgramFiles}\Microsoft Visual Studio\2026\Enterprise\Common7\Tools",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2026\Community\Common7\Tools",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2026\Professional\Common7\Tools",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2026\Enterprise\Common7\Tools"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            Write-Host "[OK] Found in common path: $path" -ForegroundColor Green
            $vs2026Path = $path
            break
        }
    }
}

# Result
Write-Host ""
if ($null -ne $vs2026Path) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Visual Studio 2026 Found!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Path: $vs2026Path" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To use this installation, you can:" -ForegroundColor Yellow
    Write-Host "1. Set environment variable:" -ForegroundColor White
    Write-Host "   set VS180COMNTOOLS=$vs2026Path" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Or use build-fixed.cmd which will auto-detect" -ForegroundColor White
    Write-Host ""
    
    # Check for vsvars32.bat
    $vsvars = Join-Path $vs2026Path "vsvars32.bat"
    if (Test-Path $vsvars) {
        Write-Host "[OK] vsvars32.bat found" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] vsvars32.bat not found at expected location" -ForegroundColor Yellow
    }
    
    # Check for MSBuild
    $msbuild = Join-Path (Split-Path (Split-Path $vs2026Path)) "MSBuild\Current\Bin\MSBuild.exe"
    if (Test-Path $msbuild) {
        Write-Host "[OK] MSBuild found: $msbuild" -ForegroundColor Green
    }
} else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Visual Studio 2026 Not Found" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Visual Studio 2026 with:" -ForegroundColor Yellow
    Write-Host "- Desktop development with C++" -ForegroundColor White
    Write-Host "- MFC and ATL support" -ForegroundColor White
    Write-Host ""
    Write-Host "Download from: https://visualstudio.microsoft.com/downloads/" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host ""
