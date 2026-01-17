# Visual Studio 安装助手脚本
# Visual Studio Installation Helper Script

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Visual Studio Installation Helper" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查是否已安装 Visual Studio
Write-Host "[1] Checking for existing Visual Studio installations..." -ForegroundColor Yellow

$vsVersions = @(
    @{Name = "VS2026"; Var = "VS180COMNTOOLS"; Version = "18.0" },
    @{Name = "VS2022"; Var = "VS170COMNTOOLS"; Version = "17.0" },
    @{Name = "VS2019"; Var = "VS160COMNTOOLS"; Version = "16.0" },
    @{Name = "VS2017"; Var = "VS150COMNTOOLS"; Version = "15.0" },
    @{Name = "VS2015"; Var = "VS140COMNTOOLS"; Version = "14.0" },
    @{Name = "VS2013"; Var = "VS120COMNTOOLS"; Version = "12.0" }
)

$installedVS = @()
foreach ($vs in $vsVersions) {
    $varValue = [Environment]::GetEnvironmentVariable($vs.Var, "Machine")
    if ([string]::IsNullOrEmpty($varValue)) {
        $varValue = [Environment]::GetEnvironmentVariable($vs.Var, "User")
    }
    
    if (-not [string]::IsNullOrEmpty($varValue) -and (Test-Path $varValue)) {
        Write-Host "  [OK] Found: $($vs.Name)" -ForegroundColor Green
        $installedVS += $vs
    }
}

if ($installedVS.Count -gt 0) {
    Write-Host ""
    Write-Host "Visual Studio is already installed!" -ForegroundColor Green
    Write-Host "You can proceed to build the project." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To build, run:" -ForegroundColor Yellow
    Write-Host "  cd src\BuildScript" -ForegroundColor White
    Write-Host "  .\build-fixed.cmd" -ForegroundColor White
    Write-Host ""
    exit 0
}

Write-Host "  [X] No Visual Studio installation found" -ForegroundColor Red
Write-Host ""

# 检查 Visual Studio Installer
Write-Host "[2] Checking for Visual Studio Installer..." -ForegroundColor Yellow

$installerPaths = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe",
    "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vs_installer.exe",
    "${env:LOCALAPPDATA}\Microsoft\VisualStudio\Installer\vs_installer.exe"
)

$installerPath = $null
foreach ($path in $installerPaths) {
    if (Test-Path $path) {
        $installerPath = $path
        Write-Host "  [OK] Found installer: $path" -ForegroundColor Green
        break
    }
}

if ($null -eq $installerPath) {
    Write-Host "  [X] Visual Studio Installer not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please download and install Visual Studio Installer:" -ForegroundColor Yellow
    Write-Host "  https://visualstudio.microsoft.com/downloads/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Recommended: Visual Studio 2026 Community (Free)" -ForegroundColor Cyan
    Write-Host ""
    
    $openBrowser = Read-Host "Open download page in browser? (Y/N)"
    if ($openBrowser -eq "Y" -or $openBrowser -eq "y") {
        Start-Process "https://visualstudio.microsoft.com/downloads/"
    }
    exit 1
}

Write-Host ""

# 提供安装指导
Write-Host "[3] Installation Instructions" -ForegroundColor Yellow
Write-Host ""
Write-Host "To install Visual Studio with C++ support:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Open Visual Studio Installer" -ForegroundColor White
Write-Host "2. Click 'Modify' or 'Install'" -ForegroundColor White
Write-Host "3. Select 'Desktop development with C++' workload" -ForegroundColor White
Write-Host "4. Ensure 'MFC and ATL support' is checked" -ForegroundColor White
Write-Host "5. Click 'Install' and wait for completion" -ForegroundColor White
Write-Host "6. Restart your computer if prompted" -ForegroundColor White
Write-Host ""

$openInstaller = Read-Host "Open Visual Studio Installer now? (Y/N)"
if ($openInstaller -eq "Y" -or $openInstaller -eq "y") {
    Write-Host "Opening Visual Studio Installer..." -ForegroundColor Cyan
    Start-Process $installerPath
    Write-Host ""
    Write-Host "After installation, run this script again to verify." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Guide Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
