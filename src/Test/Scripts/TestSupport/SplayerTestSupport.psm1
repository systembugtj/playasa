Set-StrictMode -Version Latest

function Get-SplayerRepoRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
}

function Get-SplayerSrcRoot {
  return (Join-Path (Get-SplayerRepoRoot) 'src')
}

function Get-SplayerPlayerPath {
  return (Join-Path (Get-SplayerRepoRoot) 'out\bin\Win32\Release Unicode\splayer.exe')
}

function Get-SplayerLogPath {
  return (Join-Path (Get-SplayerRepoRoot) 'out\bin\Win32\Release Unicode\SVPDebug.log')
}

function Assert-SplayerFileExists {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing required file: $Path"
  }
}

function Stop-SplayerProcesses {
  Get-Process -Name splayer -ErrorAction SilentlyContinue | Stop-Process -Force
}

function Clear-SplayerLog {
  $logPath = Get-SplayerLogPath
  Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue
}

function Start-SplayerForSample {
  param([Parameter(Mandatory = $true)][string]$SamplePath)

  $playerPath = Get-SplayerPlayerPath
  Assert-SplayerFileExists $playerPath
  Assert-SplayerFileExists $SamplePath
  return Start-Process -FilePath $playerPath -ArgumentList "`"$SamplePath`"" -PassThru
}

function Get-SplayerLogText {
  $logPath = Get-SplayerLogPath
  if (Test-Path -LiteralPath $logPath) {
    return Get-Content -LiteralPath $logPath -Raw
  }
  return ''
}

function Wait-SplayerLogNeedle {
  param(
    [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
    [Parameter(Mandatory = $true)][string]$Needle,
    [Parameter(Mandatory = $true)][datetime]$Deadline,
    [Parameter(Mandatory = $true)][string]$TimeoutMessage,
    [string[]]$FailureNeedles = @()
  )

  while ((Get-Date) -lt $Deadline) {
    Start-Sleep -Milliseconds 250
    if ($Process.HasExited) {
      throw "splayer exited early with code $($Process.ExitCode)"
    }

    $logText = Get-SplayerLogText
    foreach ($failureNeedle in $FailureNeedles) {
      if ($logText -match [regex]::Escape($failureNeedle)) {
        throw "splayer failure log found: $failureNeedle; inspect $(Get-SplayerLogPath)"
      }
    }
    if ($logText -match [regex]::Escape($Needle)) {
      return
    }
  }

  throw $TimeoutMessage
}

function Assert-SplayerResponsive {
  param(
    [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
    [Parameter(Mandatory = $true)][datetime]$Deadline,
    [int]$AllowedUnresponsiveSeconds = 5,
    [switch]$CheckWindowResponding,
    [string]$FailureMessage = 'splayer UI stopped responding'
  )

  $unresponsiveStartedAt = $null
  while ((Get-Date) -lt $Deadline) {
    Start-Sleep -Milliseconds 500
    $current = Get-Process -Id $Process.Id -ErrorAction SilentlyContinue
    if (-not $current) {
      throw 'splayer exited while responsiveness was being checked'
    }

    if ($CheckWindowResponding -and -not $current.Responding) {
      if (-not $unresponsiveStartedAt) {
        $unresponsiveStartedAt = Get-Date
      }
      if (((Get-Date) - $unresponsiveStartedAt).TotalSeconds -ge $AllowedUnresponsiveSeconds) {
        throw "$FailureMessage; inspect $(Get-SplayerLogPath)"
      }
    } else {
      $unresponsiveStartedAt = $null
    }
  }
}

function Initialize-SplayerWin32Interop {
  if ('SplayerWin32Interop' -as [type]) {
    return
  }

  Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class SplayerWin32Interop {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
}
'@
}

function Get-SplayerMainWindowHandle {
  param([Parameter(Mandatory = $true)][int]$ProcessId)

  Initialize-SplayerWin32Interop
  $script:splayerWindowHandle = [IntPtr]::Zero
  $callback = {
    param([IntPtr]$hWnd, [IntPtr]$lParam)

    [uint32]$windowProcessId = 0
    [SplayerWin32Interop]::GetWindowThreadProcessId($hWnd, [ref]$windowProcessId) | Out-Null
    if ($windowProcessId -eq $ProcessId -and [SplayerWin32Interop]::IsWindowVisible($hWnd)) {
      $script:splayerWindowHandle = $hWnd
      return $false
    }
    return $true
  }

  [SplayerWin32Interop]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null
  return $script:splayerWindowHandle
}

function Wait-SplayerMainWindowHandle {
  param(
    [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
    [Parameter(Mandatory = $true)][datetime]$Deadline
  )

  while ((Get-Date) -lt $Deadline) {
    Start-Sleep -Milliseconds 250
    if ($Process.HasExited) {
      throw "splayer exited before its main window was available: $($Process.ExitCode)"
    }

    $handle = Get-SplayerMainWindowHandle -ProcessId $Process.Id
    if ($handle -ne [IntPtr]::Zero) {
      return $handle
    }
  }

  throw 'Could not find splayer main window'
}

function Send-SplayerCommand {
  param(
    [Parameter(Mandatory = $true)][IntPtr]$WindowHandle,
    [Parameter(Mandatory = $true)][int]$CommandId
  )

  Initialize-SplayerWin32Interop
  $wmCommand = 0x0111
  [SplayerWin32Interop]::PostMessage($WindowHandle, $wmCommand, [IntPtr]$CommandId, [IntPtr]::Zero) | Out-Null
}

function Initialize-SplayerUiAutomation {
  Add-Type -AssemblyName UIAutomationClient
  Add-Type -AssemblyName UIAutomationTypes
}

function Get-SplayerAutomationRoot {
  param([Parameter(Mandatory = $true)][IntPtr]$WindowHandle)

  Initialize-SplayerUiAutomation
  return [System.Windows.Automation.AutomationElement]::FromHandle($WindowHandle)
}

function Find-SplayerAutomationElementById {
  param(
    [Parameter(Mandatory = $true)][System.Windows.Automation.AutomationElement]$Root,
    [Parameter(Mandatory = $true)][string]$AutomationId
  )

  Initialize-SplayerUiAutomation
  $condition = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
    $AutomationId
  )
  return $Root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
}

function Find-SplayerAutomationElementByControlType {
  param(
    [Parameter(Mandatory = $true)][System.Windows.Automation.AutomationElement]$Root,
    [Parameter(Mandatory = $true)][System.Windows.Automation.ControlType]$ControlType
  )

  Initialize-SplayerUiAutomation
  $condition = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    $ControlType
  )
  return $Root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
}

function Assert-SplayerSeekBarAutomation {
  param([Parameter(Mandatory = $true)][System.Windows.Automation.AutomationElement]$Root)

  Initialize-SplayerUiAutomation
  $seekBar = Find-SplayerAutomationElementById -Root $Root -AutomationId 'SeekBar'
  if (-not $seekBar) {
    $seekBar = Find-SplayerAutomationElementByControlType -Root $Root -ControlType ([System.Windows.Automation.ControlType]::Slider)
  }
  if (-not $seekBar) {
    throw 'UIA seek bar was not found. Expected AutomationId=SeekBar or ControlType.Slider.'
  }

  $rangeValuePattern = $null
  if (-not $seekBar.TryGetCurrentPattern([System.Windows.Automation.RangeValuePattern]::Pattern, [ref]$rangeValuePattern)) {
    throw 'UIA seek bar does not expose RangeValuePattern.'
  }

  return $seekBar
}

function Get-SplayerMsBuildPath {
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  if (Test-Path -LiteralPath $vswhere) {
    $found = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' 2>$null |
      Select-Object -First 1
    if ($found -and (Test-Path -LiteralPath $found)) {
      return $found
    }
  }

  $candidates = @(
    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2026\Community\MSBuild\Current\Bin\MSBuild.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\2026\Community\MSBuild\Current\Bin\MSBuild.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe')
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  throw 'MSBuild not found. Install Visual Studio Build Tools or update the well-known path list.'
}

function Get-SplayerVcVars32 {
  $candidates = @(
    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars32.bat'),
    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2026\Community\VC\Auxiliary\Build\vcvars32.bat'),
    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars32.bat')
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  throw 'Missing vcvars32.bat; install Visual Studio C++ tools.'
}

function Get-SplayerMsys2Root {
  $candidates = @(
    (Join-Path $env:USERPROFILE 'scoop\apps\msys2\current'),
    (Join-Path $env:USERPROFILE 'scoop\apps\msys2\2026-03-22')
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath (Join-Path $candidate 'usr\bin\bash.exe')) {
      return $candidate
    }
  }

  throw 'Missing MSYS2. Install it with: scoop install msys2'
}

function ConvertTo-SplayerMsysPath {
  param([Parameter(Mandatory = $true)][string]$Path)

  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $drive = $fullPath.Substring(0, 1).ToLowerInvariant()
  $rest = $fullPath.Substring(2).Replace('\', '/')
  return "/$drive$rest"
}

function Invoke-SplayerMsys2 {
  param(
    [Parameter(Mandatory = $true)][string]$Msys2Root,
    [Parameter(Mandatory = $true)][string]$Command
  )

  $bash = Join-Path $Msys2Root 'usr\bin\bash.exe'
  Assert-SplayerFileExists $bash

  $oldMsystem = $env:MSYSTEM
  $oldChere = $env:CHERE_INVOKING
  try {
    $env:MSYSTEM = 'MINGW32'
    $env:CHERE_INVOKING = '1'
    & $bash -lc $Command
    if ($LASTEXITCODE -ne 0) {
      throw "MSYS2 command failed with exit code $LASTEXITCODE"
    }
  } finally {
    $env:MSYSTEM = $oldMsystem
    $env:CHERE_INVOKING = $oldChere
  }
}

Export-ModuleMember -Function *-Splayer*
Export-ModuleMember -Function ConvertTo-SplayerMsysPath
