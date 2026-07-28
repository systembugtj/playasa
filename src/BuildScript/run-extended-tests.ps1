#Requires -Version 5.1
<#
.SYNOPSIS
  Extended local test battery: gates, smoke exes, and optional splayer selfchecks.
#>
$ErrorActionPreference = 'Continue'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$scripts = Join-Path $repoRoot 'src\Test\Scripts'
$failed = New-Object System.Collections.Generic.List[string]
$passed = New-Object System.Collections.Generic.List[string]
$skipped = New-Object System.Collections.Generic.List[string]

function Invoke-TestStep {
    param(
        [string]$Name,
        [scriptblock]$Action,
        [switch]$Optional
    )
    Write-Host ""
    Write-Host "=== $Name ===" -ForegroundColor Cyan
    try {
        & $Action
        if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            throw "exit code $LASTEXITCODE"
        }
        Write-Host "PASS: $Name" -ForegroundColor Green
        [void]$passed.Add($Name)
    }
    catch {
        if ($Optional) {
            Write-Host "SKIP: $Name - $_" -ForegroundColor Yellow
            [void]$skipped.Add("$Name ($_)")
        }
        else {
            Write-Host "FAIL: $Name - $_" -ForegroundColor Red
            [void]$failed.Add($Name)
        }
    }
}

# --- Tier 1: no MSBuild / no GUI ---
Invoke-TestStep 'run-local-tests (gates + MPCVideoDec)' {
    & (Join-Path $repoRoot 'src\BuildScript\run-local-tests.ps1')
}

Invoke-TestStep 'verify-rfc0012-all' {
    & (Join-Path $repoRoot 'src\BuildScript\verify-rfc0012-all.ps1')
}

Invoke-TestStep 'verify-rfc0035-easplitter' {
    & (Join-Path $repoRoot 'src\BuildScript\verify-rfc0035-easplitter-no-legacy-ffmpeg.ps1')
}

# --- Tier 2: compile + run small smoke binaries ---
Invoke-TestStep 'test-rfc0024-modern-bridge-smoke' {
    & (Join-Path $scripts 'test-rfc0024-modern-bridge-smoke.ps1')
}

Invoke-TestStep 'test-rfc0045-realaudio-remaining-selfcheck' {
    & (Join-Path $scripts 'test-rfc0045-realaudio-remaining-selfcheck.ps1')
}

Invoke-TestStep 'test-zeromq-smoke' {
    & (Join-Path $scripts 'test-zeromq-smoke.ps1')
}

# --- Tier 3: splayer process selfchecks (need built splayer.exe + samples) ---
$splayerExe = Join-Path $repoRoot 'out\bin\Win32\Release Unicode\splayer.exe'
if (-not (Test-Path -LiteralPath $splayerExe)) {
    Write-Host "SKIP tier 3: splayer.exe not found at $splayerExe" -ForegroundColor Yellow
    [void]$skipped.Add('tier-3 splayer selfchecks (no exe)')
}
else {
    Invoke-TestStep 'test-rfc0031-mpeg2-modern-selfcheck' {
        & (Join-Path $scripts 'test-rfc0031-mpeg2-modern-selfcheck.ps1')
    }

    Invoke-TestStep 'test-rfc0024-splayer-selfcheck (120s timeout)' {
        & (Join-Path $scripts 'test-rfc0024-splayer-selfcheck.ps1') -TimeoutSeconds 120
    } -Optional

    Invoke-TestStep 'test-rfc0026-mkv-timing-selfcheck' {
        & (Join-Path $scripts 'test-rfc0026-mkv-timing-selfcheck.ps1')
    } -Optional

    # RealAudio + RMVB must run sequentially (parallel launches crash splayer).
    Invoke-TestStep 'splayer selfchecks sequential (0034 + rmvb seek)' {
        & (Join-Path $repoRoot 'src\BuildScript\run-splayer-selfchecks-sequential.ps1')
    }
}

Write-Host ""
Write-Host '========== EXTENDED TEST SUMMARY ==========' -ForegroundColor Cyan
Write-Host "Passed:  $($passed.Count)" -ForegroundColor Green
$passed | ForEach-Object { Write-Host "  + $_" }
if ($skipped.Count -gt 0) {
    Write-Host "Skipped: $($skipped.Count)" -ForegroundColor Yellow
    $skipped | ForEach-Object { Write-Host "  ~ $_" }
}
if ($failed.Count -gt 0) {
    Write-Host "Failed:  $($failed.Count)" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host 'Extended tests: all required steps passed.' -ForegroundColor Green
