#Requires -Version 5.1
<#
.SYNOPSIS
  仓库根目录统一开发入口：门闩、构建、启动 splayer，一条命令 discoverable。

.DESCRIPTION
  在仓库根执行，例如: ./dev.ps1 run
  子命令之后的剩余参数由 ValueFromRemainingArguments 绑定到 $PassThroughArgs，会传给 splayer（仅 run / ship 有意义）。
  注意：本脚本不使用 [CmdletBinding]，否则与 ValueFromRemainingArguments 组合会触发参数集绑定错误。

.PARAMETER Command
  verify | build | buildFast | run | ship | help

.EXAMPLE
  ./dev.ps1 verify

.EXAMPLE
  ./dev.ps1 build

.EXAMPLE
  ./dev.ps1 run

.EXAMPLE
  ./dev.ps1 run -- D:\media\clip.mkv
#>
param(
    [Parameter(Position = 0)]
    [ValidateSet('verify', 'build', 'buildFast', 'run', 'ship', 'help')]
    [string] $Command = 'help',

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $PassThroughArgs
)

if ($null -eq $PassThroughArgs) {
    $PassThroughArgs = @()
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:DIR_OUT = 'out'
$script:DIR_BIN = 'bin'
$script:DIR_PLATFORM = 'Win32'
$script:CONFIG_RELEASE_UNICODE = 'Release Unicode'
$script:EXE_SPLAYER = 'splayer.exe'
$script:REL_BUILD_SCRIPT = Join-Path 'src' (Join-Path 'BuildScript' 'ci-local.ps1')
$script:REL_VERIFY_ALL = Join-Path 'src' (Join-Path 'BuildScript' 'verify-rfc0012-all.ps1')

# 以下辅助函数故意不用 Get-/Invoke-/Start- 前缀，避免被解析为内置 cmdlet 导致参数集绑定失败。
function dev_ReadRepoRoot {
    return $PSScriptRoot
}

function dev_SplayerReleaseExePath {
    param([Parameter(Mandatory)][string] $RepoRoot)
    $rel = Join-Path $script:DIR_OUT (Join-Path $script:DIR_BIN (Join-Path $script:DIR_PLATFORM $script:CONFIG_RELEASE_UNICODE))
    return Join-Path $RepoRoot (Join-Path $rel $script:EXE_SPLAYER)
}

function Write-PlayasaDevHelp {
    Write-Host @'
用法（在仓库根）:
  ./dev.ps1 verify      仅 RFC 汇总门闩（无 MSBuild）
  ./dev.ps1 build       门闩 + 预构建 + revision + 全量 MSBuild
  ./dev.ps1 buildFast   同 build，但跳过门闩（迭代编译）
  ./dev.ps1 run         启动 Release Unicode 构建的 splayer（工作目录为 exe 目录）
  ./dev.ps1 ship        build 成功后自动 run
  ./dev.ps1 help        显示本帮助

运行并打开文件（参数传给进程）:
  ./dev.ps1 run -- D:\path\file.mkv

底层脚本: src/BuildScript/ci-local.ps1（CI 与需细粒度参数时直接用）。
'@ -ForegroundColor Cyan
}

function dev_RunVerify {
    param([Parameter(Mandatory)][string] $RepoRoot)
    $verify = Join-Path $RepoRoot $script:REL_VERIFY_ALL
    & $verify
}

function dev_RunCiLocal {
    param(
        [Parameter(Mandatory)][string] $RepoRoot,
        [switch] $SkipVerify
    )
    $ci = Join-Path $RepoRoot $script:REL_BUILD_SCRIPT
    if ($SkipVerify) {
        & $ci -SkipVerify
    } else {
        & $ci
    }
}

function dev_NormalizePassThroughArgs {
    param(
        [AllowNull()]
        [string[]] $PassThroughList
    )
    if ($null -eq $PassThroughList -or $PassThroughList.Length -eq 0) {
        return [string[]]@()
    }
    $list = [string[]]@($PassThroughList)
    if ($list.Length -ge 1 -and $list[0] -eq '--') {
        if ($list.Length -le 1) {
            return [string[]]@()
        }
        return [string[]]@($list | Select-Object -Skip 1)
    }
    return $list
}

$repoRoot = dev_ReadRepoRoot
Push-Location $repoRoot
try {
    switch ($Command) {
        'help' { Write-PlayasaDevHelp }
        'verify' { dev_RunVerify -RepoRoot $repoRoot }
        'build' { dev_RunCiLocal -RepoRoot $repoRoot }
        'buildFast' { dev_RunCiLocal -RepoRoot $repoRoot -SkipVerify }
        'run' {
            $exePath = dev_SplayerReleaseExePath -RepoRoot $repoRoot
            if (-not (Test-Path -LiteralPath $exePath)) {
                throw "未找到 $exePath 。请先执行: ./dev.ps1 build"
            }
            # PS 7+ 中 Split-Path 不可同时使用 -LiteralPath 与 -Parent；用 API 取目录名
            $workDir = [System.IO.Path]::GetDirectoryName($exePath)
            $argsForExe = dev_NormalizePassThroughArgs -PassThroughList $PassThroughArgs
            $cleanArgs = [System.Collections.Generic.List[string]]::new()
            foreach ($item in $argsForExe) {
                if ($null -ne $item -and '' -ne $item) {
                    $cleanArgs.Add($item)
                }
            }
            if ($cleanArgs.Count -eq 0) {
                Start-Process -FilePath $exePath -WorkingDirectory $workDir
            } else {
                Start-Process -FilePath $exePath -WorkingDirectory $workDir -ArgumentList @($cleanArgs.ToArray())
            }
        }
        'ship' {
            dev_RunCiLocal -RepoRoot $repoRoot
            $argsForExe = dev_NormalizePassThroughArgs -PassThroughList $PassThroughArgs
            $exePath = dev_SplayerReleaseExePath -RepoRoot $repoRoot
            if (-not (Test-Path -LiteralPath $exePath)) {
                throw "未找到 $exePath 。请先执行: ./dev.ps1 build"
            }
            # 同 run：勿用 Split-Path -LiteralPath -Parent（PS 7+ 参数集不兼容）
            $workDir = [System.IO.Path]::GetDirectoryName($exePath)
            $cleanArgs = [System.Collections.Generic.List[string]]::new()
            foreach ($item in $argsForExe) {
                if ($null -ne $item -and '' -ne $item) {
                    $cleanArgs.Add($item)
                }
            }
            if ($cleanArgs.Count -eq 0) {
                Start-Process -FilePath $exePath -WorkingDirectory $workDir
            } else {
                Start-Process -FilePath $exePath -WorkingDirectory $workDir -ArgumentList @($cleanArgs.ToArray())
            }
        }
    }
}
finally {
    Pop-Location
}
