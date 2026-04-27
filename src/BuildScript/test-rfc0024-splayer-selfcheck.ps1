#Requires -Version 5.1
<#
.SYNOPSIS
  Launch splayer against a sample and verify that MPCVideoDec delivers a modern FFmpeg frame.
#>
[CmdletBinding()]
param(
  [string]$SamplePath = '',
  [int]$TimeoutSeconds = 30,
  [int]$SteadyStateSeconds = 10,
  [int]$AllowedUnresponsiveSeconds = 5,
  [switch]$CheckWindowResponding
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
if ([string]::IsNullOrWhiteSpace($SamplePath)) {
  $SamplePath = Join-Path $repoRoot 'out\selfcheck\genius_party_sample.mkv'
}
$playerPath = Join-Path $repoRoot 'out\bin\Win32\Release Unicode\splayer.exe'
$logPath = Join-Path $repoRoot 'out\bin\Win32\Release Unicode\SVPDebug.log'
$firstFrameNeedle = 'Modern FFmpeg bridge first frame ready'
$failureNeedle = 'Modern FFmpeg bridge decode failed'
$hangEventStart = Get-Date

function Assert-FileExists {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing required file: $Path"
  }
}

Assert-FileExists $playerPath
Assert-FileExists $SamplePath

Get-Process -Name splayer -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue

$process = Start-Process -FilePath $playerPath -ArgumentList "`"$SamplePath`"" -PassThru
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
try {
  $sawFirstFrame = $false
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500

    if ($process.HasExited) {
      throw "splayer exited early with code $($process.ExitCode)"
    }

    if (Test-Path -LiteralPath $logPath) {
      $logText = Get-Content -LiteralPath $logPath -Raw
      if ($logText -match [regex]::Escape($failureNeedle)) {
        throw "splayer modern FFmpeg decode failed; inspect $logPath"
      }
      if ($logText -match [regex]::Escape($firstFrameNeedle)) {
        $sawFirstFrame = $true
        break
      }
    }
  }

  if (-not $sawFirstFrame) {
    throw "Timed out waiting for modern FFmpeg first frame; inspect $logPath"
  }

  $steadyDeadline = (Get-Date).AddSeconds($SteadyStateSeconds)
  $unresponsiveStartedAt = $null
  while ((Get-Date) -lt $steadyDeadline) {
    Start-Sleep -Milliseconds 500
    $current = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
    if (-not $current) {
      throw 'splayer exited during steady-state playback'
    }
    if ($CheckWindowResponding -and -not $current.Responding) {
      if (-not $unresponsiveStartedAt) {
        $unresponsiveStartedAt = Get-Date
      }
      if (((Get-Date) - $unresponsiveStartedAt).TotalSeconds -ge $AllowedUnresponsiveSeconds) {
        throw "splayer UI stopped responding during steady-state playback; inspect $logPath"
      }
    } else {
      $unresponsiveStartedAt = $null
    }
  }

  $hangEvents = Get-WinEvent -FilterHashtable @{LogName = 'Application'; StartTime = $hangEventStart} -ErrorAction SilentlyContinue |
    Where-Object { $_.ProviderName -in @('Application Hang', 'Windows Error Reporting') -and $_.Message -match 'splayer|AppHang' } |
    Select-Object -First 1
  if ($hangEvents) {
    throw "splayer generated an Application Hang report during playback; inspect Windows Application event log"
  }

  Write-Host 'test-rfc0024-splayer-selfcheck: OK' -ForegroundColor Green
} finally {
  Get-Process -Id $process.Id -ErrorAction SilentlyContinue | Stop-Process -Force
}
