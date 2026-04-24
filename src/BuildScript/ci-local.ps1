#Requires -Version 5.1
<#
.SYNOPSIS
  本地/CI 统一入口：RFC-0012 门闩、预构建、修订信息、MSBuild 全量构建，可选 sqlitepp 测试工程。

.DESCRIPTION
  设计为在 PowerShell 中直接运行（含 GitHub Actions），避免依赖交互式 cmd。
  在 Git Bash 中调用 MSBuild 时请勿使用本脚本外的裸 /m 参数；本脚本使用 PowerShell 调用无此问题。

.PARAMETER SkipVerify
  跳过 verify-rfc0012-all.ps1（CI 中可由前置 job 已跑过时使用）。

.PARAMETER SkipPreBuild
  跳过预构建（密钥占位与 out 目录）；一般不建议。

.PARAMETER SkipRevision
  跳过 revision.cmd（无 Mercurial 时）；将使用 revision_dummy.h 保证 revision.h 存在。

.PARAMETER SkipBuild
  仅跑门闩/预构建，不调用 MSBuild。

.PARAMETER RunSqliteppTest
  在全量构建成功后额外编译 sqliteppTest（Release|Win32）。

.EXAMPLE
  pwsh ./src/BuildScript/ci-local.ps1

.EXAMPLE
  pwsh ./src/BuildScript/ci-local.ps1 -SkipVerify -SkipRevision
#>
[CmdletBinding()]
param(
    [switch] $SkipVerify,
    [switch] $SkipPreBuild,
    [switch] $SkipRevision,
    [switch] $SkipBuild,
    [switch] $RunSqliteppTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 与 splayer.sln / MSBuild 调用保持一致
$script:CI_SOLUTION_CONFIGURATION = 'Release Unicode'
$script:CI_SOLUTION_PLATFORM = 'Win32'
$script:CI_SQLITEPP_CONFIGURATION = 'Release'
$script:CI_SQLITEPP_PLATFORM = 'Win32'

function Get-BuildScriptRoot {
    return $PSScriptRoot
}

function Get-SrcRoot {
    return (Split-Path -Parent (Get-BuildScriptRoot))
}

function Get-RepoRoot {
    return (Split-Path -Parent (Get-SrcRoot))
}

function Test-CommandExists {
    param([Parameter(Mandatory)][string] $Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-MsBuildPathFromVsWhere {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere)) {
        return $null
    }
    $found = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' 2>$null |
        Select-Object -First 1
    if ($found -and (Test-Path -LiteralPath $found)) {
        return $found
    }
    return $null
}

function Get-MsBuildPathFromWellKnown {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2026\Community\MSBuild\Current\Bin\MSBuild.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\2026\Community\MSBuild\Current\Bin\MSBuild.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe')
    )
    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p) {
            return $p
        }
    }
    return $null
}

function Get-MsBuildExecutable {
    $fromVsWhere = Get-MsBuildPathFromVsWhere
    if ($fromVsWhere) {
        return $fromVsWhere
    }
    return Get-MsBuildPathFromWellKnown
}

function Copy-IfMissing {
    param(
        [Parameter(Mandatory)][string] $SourcePath,
        [Parameter(Mandatory)][string] $DestinationPath
    )
    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
    }
}

function Invoke-RfcPreBuild {
    param(
        [Parameter(Mandatory)][string] $BuildScriptRoot,
        [Parameter(Mandatory)][string] $SrcRoot
    )
    $dummyClient = Join-Path $BuildScriptRoot 'shooterclient_dummy.key'
    $dummyApi = Join-Path $BuildScriptRoot 'shooterapi_dummy.key'
    if (-not (Test-Path -LiteralPath $dummyClient)) {
        Set-Content -LiteralPath $dummyClient -Value '# Dummy key file' -Encoding ascii
    }
    if (-not (Test-Path -LiteralPath $dummyApi)) {
        Set-Content -LiteralPath $dummyApi -Value '# Dummy key file' -Encoding ascii
    }
    $clientTargets = @(
        (Join-Path $SrcRoot 'Source\svplib\shooterclient.key'),
        (Join-Path $SrcRoot 'include\shooterclient.key')
    )
    foreach ($t in $clientTargets) {
        if (-not (Test-Path -LiteralPath $t)) {
            if (Test-Path -LiteralPath $dummyClient) {
                Copy-Item -LiteralPath $dummyClient -Destination $t -Force
            } else {
                Set-Content -LiteralPath $t -Value '# Dummy key' -Encoding ascii
            }
        }
    }
    $apiTarget = Join-Path $SrcRoot 'include\shooterapi.key'
    if (-not (Test-Path -LiteralPath $apiTarget)) {
        if (Test-Path -LiteralPath $dummyApi) {
            Copy-Item -LiteralPath $dummyApi -Destination $apiTarget -Force
        } else {
            Set-Content -LiteralPath $apiTarget -Value '# Dummy key' -Encoding ascii
        }
    }
    $outBin = Join-Path $SrcRoot 'out\bin'
    $outObj = Join-Path $SrcRoot 'out\obj'
    New-Item -ItemType Directory -Force -Path $outBin | Out-Null
    New-Item -ItemType Directory -Force -Path $outObj | Out-Null
}

function Invoke-RevisionStep {
    param(
        [Parameter(Mandatory)][string] $BuildScriptRoot,
        [Parameter(Mandatory)][string] $SrcRoot,
        [switch] $SkipRevision
    )
    $revFile = Join-Path $SrcRoot 'Source\apps\mplayerc\revision.h'
    $dummyFile = Join-Path $BuildScriptRoot 'revision_dummy.h'
    if ($SkipRevision) {
        if (-not (Test-Path -LiteralPath $revFile)) {
            if (-not (Test-Path -LiteralPath $dummyFile)) {
                throw "Missing revision_dummy.h; cannot generate revision.h (SkipRevision): $dummyFile"
            }
            Copy-Item -LiteralPath $dummyFile -Destination $revFile -Force
        }
        return
    }
    $hg = Join-Path $BuildScriptRoot 'hg_bin\hg.exe'
    $hgWorks = $false
    if (Test-Path -LiteralPath $hg) {
        $hgStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $hgStartInfo.FileName = $hg
        $hgStartInfo.Arguments = 'id -n'
        $hgStartInfo.WorkingDirectory = $BuildScriptRoot
        $hgStartInfo.UseShellExecute = $false
        $hgStartInfo.RedirectStandardOutput = $true
        $hgStartInfo.RedirectStandardError = $true
        try {
            $hgProc = [System.Diagnostics.Process]::Start($hgStartInfo)
            $hgProc.WaitForExit()
            if ($hgProc.ExitCode -eq 0) {
                $hgWorks = $true
            }
        } catch {
            $hgWorks = $false
        }
    }
    if (-not $hgWorks) {
        Copy-IfMissing -SourcePath $dummyFile -DestinationPath $revFile
        return
    }
    $revisionCmd = Join-Path $BuildScriptRoot 'revision.cmd'
    if (-not (Test-Path -LiteralPath $revisionCmd)) {
        Copy-IfMissing -SourcePath $dummyFile -DestinationPath $revFile
        return
    }
    $comSpec = $env:ComSpec
    if (-not $comSpec) {
        $comSpec = Join-Path $env:SystemRoot 'System32\cmd.exe'
    }
    # Git Bash PATH can contain MSYS find.exe; put System32 first for revision.cmd.
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $comSpec
    $startInfo.Arguments = '/c call revision.cmd'
    $startInfo.WorkingDirectory = $BuildScriptRoot
    $startInfo.UseShellExecute = $false
    $sys32 = [System.IO.Path]::Combine($env:SystemRoot, 'System32')
    $sysWow = [System.IO.Path]::Combine($env:SystemRoot, 'SysWOW64')
    $startInfo.EnvironmentVariables['PATH'] = "$sys32;$sysWow;" + $startInfo.EnvironmentVariables['PATH']
    $proc = [System.Diagnostics.Process]::Start($startInfo)
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) {
        Write-Warning "revision.cmd exited with $($proc.ExitCode); revision_dummy.h will be used if needed"
    }
    if (-not (Test-Path -LiteralPath $revFile)) {
        if (-not (Test-Path -LiteralPath $dummyFile)) {
            throw "revision step failed and revision_dummy.h is missing: $dummyFile"
        }
        Copy-Item -LiteralPath $dummyFile -Destination $revFile -Force
    }
}

function Invoke-SolutionBuild {
    param(
        [Parameter(Mandatory)][string] $MsBuild,
        [Parameter(Mandatory)][string] $SolutionPath
    )
    $msbuildArgs = @(
        $SolutionPath,
        "/p:Configuration=$script:CI_SOLUTION_CONFIGURATION",
        "/p:Platform=$script:CI_SOLUTION_PLATFORM",
        '/m',
        '/v:minimal',
        '/nologo'
    )
    Write-Host "MSBuild: $MsBuild $($msbuildArgs -join ' ')" -ForegroundColor Cyan
    & $MsBuild @msbuildArgs
    if ($LASTEXITCODE -ne 0) {
        throw "MSBuild solution failed with exit code $LASTEXITCODE"
    }
}

function Invoke-SqliteppTestBuild {
    param(
        [Parameter(Mandatory)][string] $MsBuild,
        [Parameter(Mandatory)][string] $SrcRoot
    )
    $proj = Join-Path $SrcRoot 'Test\sqliteppTest\sqliteppTest.vcxproj'
    if (-not (Test-Path -LiteralPath $proj)) {
        throw "sqliteppTest project not found: $proj"
    }
    $solutionDir = Join-Path $SrcRoot ''
    if (-not $solutionDir.EndsWith('\')) {
        $solutionDir = $solutionDir + '\'
    }
    $msbuildArgs = @(
        $proj,
        "/p:Configuration=$script:CI_SQLITEPP_CONFIGURATION",
        "/p:Platform=$script:CI_SQLITEPP_PLATFORM",
        "/p:SolutionDir=$solutionDir",
        '/m',
        '/v:minimal',
        '/nologo'
    )
    Write-Host "MSBuild (sqliteppTest): $MsBuild $($msbuildArgs -join ' ')" -ForegroundColor Cyan
    & $MsBuild @msbuildArgs
    if ($LASTEXITCODE -ne 0) {
        throw "MSBuild sqliteppTest failed with exit code $LASTEXITCODE"
    }
}

$buildScriptRoot = Get-BuildScriptRoot
$srcRoot = Get-SrcRoot
$repoRoot = Get-RepoRoot

Push-Location $repoRoot
try {
    if (-not $SkipVerify) {
        $verify = Join-Path $buildScriptRoot 'verify-rfc0012-all.ps1'
        Write-Host "Step: RFC-0012 verifier -> $verify" -ForegroundColor Yellow
        & $verify
    }

    if (-not $SkipPreBuild) {
        Write-Host 'Step: prebuild placeholders and out directories' -ForegroundColor Yellow
        Invoke-RfcPreBuild -BuildScriptRoot $buildScriptRoot -SrcRoot $srcRoot
    }

    Write-Host 'Step: revision.h' -ForegroundColor Yellow
    Invoke-RevisionStep -BuildScriptRoot $buildScriptRoot -SrcRoot $srcRoot -SkipRevision:$SkipRevision

    if (-not $SkipBuild) {
        $msbuild = Get-MsBuildExecutable
        if (-not $msbuild) {
            throw 'MSBuild was not found. Install Visual Studio / Build Tools or ensure vswhere is available.'
        }
        Write-Host "Using MSBuild: $msbuild" -ForegroundColor Green
        $solutionPath = Join-Path $srcRoot 'splayer.sln'
        if (-not (Test-Path -LiteralPath $solutionPath)) {
            throw "Solution not found: $solutionPath"
        }
        Write-Host 'Step: full build splayer.sln' -ForegroundColor Yellow
        Invoke-SolutionBuild -MsBuild $msbuild -SolutionPath $solutionPath
        if ($RunSqliteppTest) {
            Write-Host 'Step: build sqliteppTest' -ForegroundColor Yellow
            Invoke-SqliteppTestBuild -MsBuild $msbuild -SrcRoot $srcRoot
        }
    }

    Write-Host 'ci-local: completed' -ForegroundColor Green
}
finally {
    Pop-Location
}
