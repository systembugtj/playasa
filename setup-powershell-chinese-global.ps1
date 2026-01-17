# PowerShell Global Chinese Support Configuration
# PowerShell 全局中文支持配置脚本

$ErrorActionPreference = "Continue"

# Set UTF-8 encoding first for this script
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
if ($Host.Name -eq 'ConsoleHost') {
    chcp 65001 | Out-Null
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PowerShell Global Chinese Support Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Get PowerShell profile path
Write-Host "[1] Configuring PowerShell profile..." -ForegroundColor Yellow

# Try to get profile path
$mainProfile = $null
try {
    $mainProfile = $PROFILE.CurrentUserAllHosts
} catch {
    try {
        $mainProfile = $PROFILE
    } catch {
        $mainProfile = "$env:USERPROFILE\Documents\WindowsPowerShell\profile.ps1"
    }
}

if ([string]::IsNullOrEmpty($mainProfile)) {
    $mainProfile = "$env:USERPROFILE\Documents\WindowsPowerShell\profile.ps1"
}

Write-Host "  Profile path: $mainProfile" -ForegroundColor Gray

# Create profile directory if needed
$profileDir = Split-Path -Parent $mainProfile
if (-not (Test-Path $profileDir)) {
    New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
    Write-Host "  [OK] Created profile directory" -ForegroundColor Green
}

# UTF-8 configuration content
$utf8Config = @"

# PowerShell UTF-8 Chinese Support Configuration
# Auto-generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

# Set console code page to UTF-8
if (`$Host.Name -eq 'ConsoleHost') {
    chcp 65001 | Out-Null
}

# Set encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
`$OutputEncoding = [System.Text.Encoding]::UTF8

# Set environment variables
`$env:PYTHONIOENCODING = 'utf-8'
"@

# Check if profile exists
if (Test-Path $mainProfile) {
    $existingContent = Get-Content $mainProfile -Raw -ErrorAction SilentlyContinue
    
    # Check if UTF-8 config already exists
    if ($existingContent -and $existingContent -match "UTF-8|UTF8|chcp 65001") {
        Write-Host "  [INFO] Profile already contains UTF-8 settings" -ForegroundColor Yellow
        Write-Host "  Do you want to update? (Y/N): " -NoNewline -ForegroundColor Yellow
        $response = Read-Host
        if ($response -eq "Y" -or $response -eq "y") {
            # Backup
            $backupFile = "$mainProfile.backup"
            Copy-Item $mainProfile $backupFile -Force
            Write-Host "  [OK] Backed up to: $backupFile" -ForegroundColor Green
            
            # Add UTF-8 config if not present
            if ($existingContent -notmatch "PowerShell UTF-8 Chinese Support") {
                Add-Content -Path $mainProfile -Value $utf8Config -Encoding UTF8
                Write-Host "  [OK] Added UTF-8 configuration" -ForegroundColor Green
            } else {
                Write-Host "  [OK] UTF-8 configuration already exists" -ForegroundColor Green
            }
        } else {
            Write-Host "  [SKIP] Keeping existing configuration" -ForegroundColor Gray
        }
    } else {
        # Add UTF-8 config
        Add-Content -Path $mainProfile -Value $utf8Config -Encoding UTF8
        Write-Host "  [OK] Added UTF-8 configuration" -ForegroundColor Green
    }
} else {
    # Create new profile
    $utf8Config | Out-File -FilePath $mainProfile -Encoding UTF8
    Write-Host "  [OK] Created profile with UTF-8 support" -ForegroundColor Green
}

Write-Host ""

# 2. Check execution policy
Write-Host "[2] Checking execution policy..." -ForegroundColor Yellow

try {
    $executionPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
    if ($null -eq $executionPolicy) {
        $executionPolicy = "Unknown"
    }
    Write-Host "  Current policy: $executionPolicy" -ForegroundColor Gray

    if ($executionPolicy -eq "Restricted") {
        Write-Host "  [WARNING] Execution policy is Restricted" -ForegroundColor Yellow
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
            Write-Host "  [OK] Set execution policy to RemoteSigned" -ForegroundColor Green
        } catch {
            Write-Host "  [ERROR] Cannot set execution policy: $_" -ForegroundColor Red
            Write-Host "    Please run as administrator" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [OK] Execution policy allows script execution" -ForegroundColor Green
    }
} catch {
    Write-Host "  [INFO] Cannot check execution policy: $_" -ForegroundColor Yellow
    Write-Host "    This is usually OK" -ForegroundColor Gray
}

Write-Host ""

# 3. System-level UTF-8 support (optional, requires admin)
Write-Host "[3] System-level UTF-8 support (optional)..." -ForegroundColor Yellow

$isAdmin = $false
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {
    # Ignore errors
}

if ($isAdmin) {
    Write-Host "  [OK] Administrator privileges detected" -ForegroundColor Green
    
    try {
        [System.Environment]::SetEnvironmentVariable("PYTHONIOENCODING", "utf-8", "Machine")
        Write-Host "  [OK] Set system environment variable PYTHONIOENCODING" -ForegroundColor Green
    } catch {
        Write-Host "  [WARNING] Cannot set system environment variable: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [INFO] Administrator privileges required for system-level configuration" -ForegroundColor Yellow
    Write-Host "    Current configuration applies to current user only" -ForegroundColor Gray
}

Write-Host ""

# 4. Test configuration
Write-Host "[4] Testing Chinese display..." -ForegroundColor Yellow

Write-Host "  Test Chinese: 你好，世界！" -ForegroundColor Cyan
Write-Host "  Test encoding: UTF-8 (Code Page 65001)" -ForegroundColor Cyan
Write-Host ""

# 5. Show current encoding settings
Write-Host "[5] Current encoding settings..." -ForegroundColor Yellow
Write-Host "  OutputEncoding: $([Console]::OutputEncoding.EncodingName) ($([Console]::OutputEncoding.CodePage))" -ForegroundColor Gray
Write-Host "  InputEncoding: $([Console]::InputEncoding.EncodingName) ($([Console]::InputEncoding.CodePage))" -ForegroundColor Gray

try {
    $codePageOutput = chcp.com 2>&1
    $codePage = $codePageOutput | Select-String '\d+'
    if ($codePage) {
        Write-Host "  CodePage: $($codePage.Matches.Value)" -ForegroundColor Gray
    }
} catch {
    Write-Host "  CodePage: 65001 (UTF-8)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Configuration Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Important:" -ForegroundColor Yellow
Write-Host "1. Please RESTART PowerShell for changes to take effect" -ForegroundColor White
Write-Host "2. Profile location: $mainProfile" -ForegroundColor White
Write-Host "3. If you encounter issues, you can edit the profile manually" -ForegroundColor White
Write-Host ""
Write-Host "Verify configuration:" -ForegroundColor Yellow
Write-Host "  After restarting PowerShell, run:" -ForegroundColor White
Write-Host "  Write-Host 'Test Chinese: 你好，世界！' -ForegroundColor Cyan" -ForegroundColor Gray
Write-Host ""
