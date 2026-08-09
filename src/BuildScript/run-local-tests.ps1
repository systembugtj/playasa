#Requires -Version 5.1
<#
.SYNOPSIS
  Local test runner: Rust, RFC gates, audits, MPCVideoDec MSBuild.
#>
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$failed = New-Object System.Collections.Generic.List[string]
$passed = New-Object System.Collections.Generic.List[string]

function Invoke-TestStep {
    param(
        [string]$Name,
        [scriptblock]$Action
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
        Write-Host "FAIL: $Name - $_" -ForegroundColor Red
        [void]$failed.Add($Name)
    }
}

Invoke-TestStep 'cargo test --workspace' {
    Push-Location $repoRoot
    try { cargo test --workspace } finally { Pop-Location }
}

Invoke-TestStep 'verify-rfc-rust-crates' {
    & (Join-Path $repoRoot 'src\BuildScript\verify-rfc-rust-crates.ps1')
}

Invoke-TestStep 'verify-rfc0017' {
    & (Join-Path $repoRoot 'src\BuildScript\verify-rfc0017-ffmpeg-mpcvideodec.ps1')
}

Invoke-TestStep 'verify-rfc0024' {
    & (Join-Path $repoRoot 'src\BuildScript\verify-rfc0024-ffmpeg-modern.ps1')
}

Invoke-TestStep 'verify-rfc0035-easplitter' {
    & (Join-Path $repoRoot 'src\BuildScript\verify-rfc0035-easplitter-no-legacy-ffmpeg.ps1')
}

Invoke-TestStep 'test-rfc0035-mpcvideodec-include-boundary' {
    & (Join-Path $repoRoot 'src\Test\Scripts\test-rfc0035-mpcvideodec-include-boundary.ps1')
}

Invoke-TestStep 'audit-rfc0047' {
    & (Join-Path $repoRoot 'src\BuildScript\audit-rfc0047-ffmpegcontext-dxva-glue.ps1')
}

Invoke-TestStep 'audit-rfc0035' {
    & (Join-Path $repoRoot 'src\BuildScript\audit-rfc0035-legacy-ffmpeg-refs.ps1')
}

Get-ChildItem (Join-Path $repoRoot 'src\Test\Scripts\test-rfc0047-*.ps1') | Sort-Object Name | ForEach-Object {
    $stepName = $_.Name
    Invoke-TestStep $stepName { & $_.FullName }
}

Invoke-TestStep 'test-rfc0033-h264-dxva-selfcheck' {
    & (Join-Path $repoRoot 'src\Test\Scripts\test-rfc0033-h264-dxva-selfcheck.ps1')
}

Invoke-TestStep 'test-rfc0046-mpadec-modern-selfcheck' {
    & (Join-Path $repoRoot 'src\Test\Scripts\test-rfc0046-mpadec-modern-selfcheck.ps1')
}

$msbuildCandidates = @(
    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe')
)
$msbuild = $msbuildCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if ($msbuild) {
    Invoke-TestStep 'MSBuild MPCVideoDec' {
        & $msbuild `
            (Join-Path $repoRoot 'src\Source\filters\transform\mpcvideodec\MPCVideoDec.vcxproj') `
            '-p:Configuration=Release Unicode' `
            '-p:Platform=Win32' `
            -m -v:minimal -nologo
    }
}
else {
    Write-Host 'SKIP: MSBuild MPCVideoDec (MSBuild not found)' -ForegroundColor Yellow
}

Write-Host ""
Write-Host '========== SUMMARY ==========' -ForegroundColor Cyan
Write-Host "Passed: $($passed.Count)" -ForegroundColor Green
$passed | ForEach-Object { Write-Host "  + $_" }

if ($failed.Count -gt 0) {
    Write-Host "Failed: $($failed.Count)" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host 'All tests passed.' -ForegroundColor Green
