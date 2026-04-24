#Requires -Version 5.1
<#
.SYNOPSIS
    Migrate MSBuild OutDir/IntDir and loose ..\out\bin library paths in .vcxproj / .props to match src/Source/common.props (RFC-0011).

.DESCRIPTION
    Canonical literals (must match common.props):
      OutDir: $(SolutionDir)..\out\bin\$(Platform)\$(Configuration)\
      IntDir: $(SolutionDir)..\out\obj\$(ProjectName)\$(Platform)\$(Configuration)\

    Safe to run from any cwd: repo root is derived from this script location (src/BuildScript -> repo).

.PARAMETER WhatIf
    List files that would change; do not write.

.PARAMETER SelfTest
    Run built-in string migration checks and exit.

.PARAMETER Backup
    Write .backup-<timestamp> before each modified file.
#>
param(
    [switch] $WhatIf,
    [switch] $SelfTest,
    [switch] $Backup
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Must match src/Source/common.props OutDir / IntDir (literal strings for .Replace)
$script:TargetOutDirLiteral = '$(SolutionDir)..\out\bin\$(Platform)\$(Configuration)\'
$script:TargetIntDirLiteral = '$(SolutionDir)..\out\obj\$(ProjectName)\$(Platform)\$(Configuration)\'

function Get-Rfc0011OrderedReplacements {
    $out = $script:TargetOutDirLiteral
    $int = $script:TargetIntDirLiteral
    return @(
        @{ Old = '$(SolutionDir)src\out\bin\$(Platform)\$(Configuration)\'; New = $out },
        @{ Old = '$(SolutionDir)src\out\bin\$(Configuration)\'; New = $out },
        @{ Old = '$(SolutionDir)src\out\bin\'; New = $out },
        @{ Old = '$(SolutionDir)src\out\bin'; New = $out },
        @{ Old = '$(SolutionDir)src\out\obj\$(ProjectName)\$(Platform)\$(Configuration)\'; New = $int },
        @{ Old = '$(SolutionDir)src\out\obj\$(ProjectName)\$(Configuration)\'; New = $int },
        @{ Old = '$(SolutionDir)src\out\obj\$(ProjectName)\'; New = $int },
        @{ Old = '$(SolutionDir)src\out\obj\$(ProjectName)'; New = $int },
        @{ Old = '$(SolutionDir)out\bin\$(Platform)\$(Configuration)\'; New = $out },
        @{ Old = '$(SolutionDir)out\obj\$(ProjectName)\$(Platform)\$(Configuration)\'; New = $int },
        @{ Old = '$(SolutionDir)out\obj\$(ProjectName)\$(Configuration)\'; New = $int },
        @{ Old = '$(SolutionDir)out\obj\$(ProjectName)\'; New = $int },
        @{ Old = '$(SolutionDir)out\obj\$(ProjectName)'; New = $int },
        @{ Old = '$(SolutionDir)\out\'; New = '$(SolutionDir)..\out\' },
        @{ Old = '$(SolutionDir)out\'; New = '$(SolutionDir)..\out\' },
        # Normalize ..\out\bin to per-config path (matches common.props Lib search); drop redundant duplicate segment
        @{ Old = '$(SolutionDir)..\out\bin\$(Platform)\$(Configuration)\;$(SolutionDir)..\out\bin;'; New = '$(SolutionDir)..\out\bin\$(Platform)\$(Configuration)\;' },
        @{ Old = '$(SolutionDir)..\out\bin\$(Platform)\$(Configuration)\;$(SolutionDir)..\out\bin\;'; New = '$(SolutionDir)..\out\bin\$(Platform)\$(Configuration)\;' },
        @{ Old = '$(SolutionDir)..\out\bin\;'; New = '$(SolutionDir)..\out\bin\$(Platform)\$(Configuration)\;' },
        @{ Old = '$(SolutionDir)..\out\bin;'; New = '$(SolutionDir)..\out\bin\$(Platform)\$(Configuration)\;' }
    )
}

function Invoke-Rfc0011MigrateText {
    param([string] $Content)
    $migrated = $Content
    foreach ($pair in Get-Rfc0011OrderedReplacements) {
        if ($pair.Old.Length -eq 0) { continue }
        $migrated = $migrated.Replace($pair.Old, $pair.New)
    }
    return $migrated
}

function Write-ProjectUtf8NoBom {
    param([string] $Path, [string] $Text)
    $enc = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Text, $enc)
}

if ($SelfTest) {
    $samples = @(
        @{
            Name = 'src-out-with-platform'
            In   = '<OutDir>$(SolutionDir)src\out\bin\$(Platform)\$(Configuration)\</OutDir>'
            Must = $TargetOutDirLiteral
        },
        @{
            Name = 'slash-out-prefix'
            In   = '$(SolutionDir)\out\obj\$(ProjectName)\x.obj'
            Must = '$(SolutionDir)..\out\obj\$(ProjectName)\x.obj'
        },
        @{
            Name = 'canonical-unchanged'
            In   = '<OutDir>$(SolutionDir)..\out\bin\$(Platform)\$(Configuration)\</OutDir>'
            Must = '<OutDir>$(SolutionDir)..\out\bin\$(Platform)\$(Configuration)\</OutDir>'
        },
        @{
            Name = 'dedupe-canonical-then-loose-bin'
            In   = '$(SolutionDir)..\out\bin\$(Platform)\$(Configuration)\;$(SolutionDir)..\out\bin;x'
            Must = '$(SolutionDir)..\out\bin\$(Platform)\$(Configuration)\;x'
        },
        @{
            Name = 'expand-loose-out-bin-semicolon'
            In   = '<T>$(SolutionDir)..\out\bin;</T>'
            Must = '$(SolutionDir)..\out\bin\$(Platform)\$(Configuration)\;'
        }
    )
    $failed = 0
    foreach ($s in $samples) {
        $got = Invoke-Rfc0011MigrateText -Content $s.In
        if ($got -notlike "*$($s.Must)*") {
            Write-Host "[FAIL] $($s.Name): expected fragment missing." -ForegroundColor Red
            Write-Host "  IN:  $($s.In)"
            Write-Host "  OUT: $got"
            $failed++
        }
        else {
            Write-Host "[OK]   $($s.Name)" -ForegroundColor Green
        }
    }
    if ($failed -gt 0) {
        throw "SelfTest failed: $failed case(s)."
    }
    Write-Host 'SelfTest passed.' -ForegroundColor Cyan
    return
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$srcRoot = Join-Path $repoRoot 'src'
if (-not (Test-Path -LiteralPath $srcRoot)) {
    throw "Expected directory not found: $srcRoot (this script must live under repo/src/BuildScript)."
}

$extensions = @('*.vcxproj', '*.props')
$projectFiles = @()
foreach ($ext in $extensions) {
    $projectFiles += Get-ChildItem -LiteralPath $srcRoot -Filter $ext -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch 'backup' }
}

Write-Host "RFC-0011 output path migration (repo: $repoRoot)" -ForegroundColor Cyan
Write-Host "Scanned $($projectFiles.Count) project/props files." -ForegroundColor Gray
Write-Host ""

$fixed = 0
foreach ($f in $projectFiles) {
    $raw = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    $newText = Invoke-Rfc0011MigrateText -Content $raw
    if ($newText -eq $raw) { continue }

    Write-Host "UPDATE $($f.FullName)" -ForegroundColor Yellow
    if ($WhatIf) {
        $fixed++
        continue
    }
    if ($Backup) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item -LiteralPath $f.FullName -Destination "$($f.FullName).backup-$stamp" -Force
    }
    Write-ProjectUtf8NoBom -Path $f.FullName -Text $newText
    $fixed++
}

Write-Host ""
if ($WhatIf) {
    Write-Host "WhatIf: $fixed file(s) would be modified (no writes)." -ForegroundColor Cyan
}
else {
    Write-Host "Done: wrote $fixed file(s)." -ForegroundColor Green
}
Write-Host "Target OutDir: $TargetOutDirLiteral" -ForegroundColor Gray
Write-Host "Target IntDir: $TargetIntDirLiteral" -ForegroundColor Gray
