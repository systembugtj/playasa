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
  Start-Sleep -Milliseconds 1500
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
    $stream = $null
    try {
      $stream = [System.IO.File]::Open($logPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    } catch {
      return ''
    }
    try {
      $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true)
      try {
        return $reader.ReadToEnd()
      } finally {
        $reader.Dispose()
      }
    } finally {
      $stream.Dispose()
    }
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

function Get-SplayerLogMatchCount {
  param(
    [Parameter(Mandatory = $true)][string]$Needle,
    [switch]$PatternIsRegex
  )

  $logText = Get-SplayerLogText
  if ($PatternIsRegex) {
    return [regex]::Matches($logText, $Needle).Count
  }

  return [regex]::Matches($logText, [regex]::Escape($Needle)).Count
}

function Wait-SplayerLogMatchCount {
  param(
    [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
    [Parameter(Mandatory = $true)][string]$Needle,
    [Parameter(Mandatory = $true)][int]$MinimumCount,
    [Parameter(Mandatory = $true)][datetime]$Deadline,
    [Parameter(Mandatory = $true)][string]$TimeoutMessage,
    [string[]]$FailureNeedles = @(),
    [switch]$PatternIsRegex
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

    $matchCount = if ($PatternIsRegex) {
      [regex]::Matches($logText, $Needle).Count
    } else {
      [regex]::Matches($logText, [regex]::Escape($Needle)).Count
    }
    if ($matchCount -ge $MinimumCount) {
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
    [DllImport("user32.dll")]
    public static extern bool EnumChildWindows(IntPtr hWndParent, EnumWindowsProc lpEnumFunc, IntPtr lParam);
}
'@
}

function Find-SplayerSeekBarElementFromWindowHandle {
  param(
    [IntPtr]$MainWindowHandle = [IntPtr]::Zero,
    [int]$ProcessId = 0
  )

  Initialize-SplayerUiAutomation
  Initialize-SplayerWin32Interop
  $script:splayerSeekBarElement = $null
  $script:splayerSeekBarEnumProcessId = $ProcessId
  $callback = {
    param([IntPtr]$hWnd, [IntPtr]$lParam)

    if ($script:splayerSeekBarEnumProcessId -gt 0) {
      [uint32]$windowProcessId = 0
      [SplayerWin32Interop]::GetWindowThreadProcessId($hWnd, [ref]$windowProcessId) | Out-Null
      if ($windowProcessId -ne $script:splayerSeekBarEnumProcessId) {
        return $true
      }
    }

    try {
      $element = [System.Windows.Automation.AutomationElement]::FromHandle($hWnd)
      if (-not $element) {
        return $true
      }

      if ($element.Current.AutomationId -eq 'SeekBar') {
        $script:splayerSeekBarElement = $element
        return $false
      }

      $rangeValuePattern = $null
      if ($element.TryGetCurrentPattern([System.Windows.Automation.RangeValuePattern]::Pattern, [ref]$rangeValuePattern)) {
        $script:splayerSeekBarElement = $element
        return $false
      }
    } catch {
      # Popup seek bar HWND may not expose a stable UIA provider yet.
    }

    return $true
  }

  [SplayerWin32Interop]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null
  return $script:splayerSeekBarElement
}

function Get-SplayerMainWindowHandle {
  param([Parameter(Mandatory = $true)][int]$ProcessId)

  Initialize-SplayerWin32Interop
  $script:splayerWindowHandle = [IntPtr]::Zero
  $script:splayerMainWindowEnumProcessId = $ProcessId
  $callback = {
    param([IntPtr]$hWnd, [IntPtr]$lParam)

    [uint32]$windowProcessId = 0
    [SplayerWin32Interop]::GetWindowThreadProcessId($hWnd, [ref]$windowProcessId) | Out-Null
    if ($windowProcessId -eq $script:splayerMainWindowEnumProcessId -and [SplayerWin32Interop]::IsWindowVisible($hWnd)) {
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

function Wait-SplayerUiaPlaybackReady {
  param(
    [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
    [Parameter(Mandatory = $true)][datetime]$Deadline,
    [Parameter(Mandatory = $true)][string]$TimeoutMessage,
    [string]$FirstFrameNeedle = 'Modern FFmpeg bridge first frame ready',
    [string[]]$FailureNeedles = @('Modern FFmpeg bridge decode failed'),
    [switch]$RequireSeekBar,
    [switch]$RequireVideoView
  )

  Wait-SplayerLogNeedle `
    -Process $Process `
    -Needle $FirstFrameNeedle `
    -Deadline $Deadline `
    -FailureNeedles $FailureNeedles `
    -TimeoutMessage $TimeoutMessage

  $uiDeadline = (Get-Date).AddSeconds([Math]::Max(45, ($Deadline - (Get-Date)).TotalSeconds))
  $windowHandle = Wait-SplayerMainWindowHandle -Process $Process -Deadline $uiDeadline
  Start-Sleep -Milliseconds 500
  $automationRoot = Get-SplayerAutomationRoot -WindowHandle $windowHandle
  $seekBar = $null
  if ($RequireSeekBar) {
    $seekBar = Assert-SplayerSeekBarAutomation -Root $automationRoot -ProcessId $Process.Id
  }

  if ($RequireVideoView) {
    Assert-SplayerVideoViewAutomation -Root $automationRoot -ProcessId $Process.Id | Out-Null
  }

  return [PSCustomObject]@{
    WindowHandle = $windowHandle
    AutomationRoot = $automationRoot
    SeekBar = $seekBar
  }
}

function Wait-SplayerSeekBarRangeReady {
  param(
    [Parameter(Mandatory = $true)][System.Windows.Automation.AutomationElement]$Root,
    [Parameter(Mandatory = $true)][int]$ProcessId,
    [Parameter(Mandatory = $true)][datetime]$Deadline,
    [System.Windows.Automation.AutomationElement]$SeekBar = $null
  )

  Initialize-SplayerUiAutomation
  while ((Get-Date) -lt $Deadline) {
    try {
      $resolved = Resolve-SplayerSeekBarForSeek -Root $Root -ProcessId $ProcessId -SeekBar $SeekBar
      return $resolved
    } catch {
      $SeekBar = $null
      Start-Sleep -Milliseconds 250
    }
  }

  throw 'UIA seek bar did not become ready for RangeValue seek; inspect UIA tree and playback state.'
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

function Find-SplayerAutomationElementByProcessAndId {
  param(
    [Parameter(Mandatory = $true)][int]$ProcessId,
    [Parameter(Mandatory = $true)][string]$AutomationId
  )

  Initialize-SplayerUiAutomation
  $processCondition = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ProcessIdProperty,
    $ProcessId
  )
  $automationIdCondition = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
    $AutomationId
  )
  $condition = New-Object System.Windows.Automation.AndCondition($processCondition, $automationIdCondition)
  return [System.Windows.Automation.AutomationElement]::RootElement.FindFirst(
    [System.Windows.Automation.TreeScope]::Descendants,
    $condition
  )
}

function Find-SplayerAutomationElementByProcessAndControlType {
  param(
    [Parameter(Mandatory = $true)][int]$ProcessId,
    [Parameter(Mandatory = $true)][System.Windows.Automation.ControlType]$ControlType
  )

  Initialize-SplayerUiAutomation
  $processCondition = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ProcessIdProperty,
    $ProcessId
  )
  $controlTypeCondition = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    $ControlType
  )
  $condition = New-Object System.Windows.Automation.AndCondition($processCondition, $controlTypeCondition)
  return [System.Windows.Automation.AutomationElement]::RootElement.FindFirst(
    [System.Windows.Automation.TreeScope]::Descendants,
    $condition
  )
}

function Get-SplayerMainWindowAutomationElement {
  param(
    [Parameter(Mandatory = $true)][System.Windows.Automation.AutomationElement]$Root,
    [int]$ProcessId = 0
  )

  $mainWindow = Find-SplayerAutomationElementById -Root $Root -AutomationId 'MainWindow'
  if ($mainWindow) {
    return $mainWindow
  }

  if ($ProcessId -gt 0) {
    $mainWindow = Find-SplayerAutomationElementByProcessAndId -ProcessId $ProcessId -AutomationId 'MainWindow'
    if ($mainWindow) {
      return $mainWindow
    }
  }

  return $Root
}

function Find-SplayerAutomationElementByTreeWalk {
  param(
    [Parameter(Mandatory = $true)][System.Windows.Automation.AutomationElement]$Root,
    [Parameter(Mandatory = $true)][string]$AutomationId
  )

  Initialize-SplayerUiAutomation
  try {
    $walker = [System.Windows.Automation.TreeWalker]::RawViewWalker
    $node = $walker.GetFirstChild($Root)
    while ($node) {
      try {
        if ($node.Current.AutomationId -eq $AutomationId) {
          return $node
        }

        $descendant = Find-SplayerAutomationElementByTreeWalk -Root $node -AutomationId $AutomationId
        if ($descendant) {
          return $descendant
        }
      } catch {
        # Fragment children can become stale while playback is starting.
      }

      try {
        $node = $walker.GetNextSibling($node)
      } catch {
        break
      }
    }
  } catch {
    return $null
  }

  return $null
}

function Add-SplayerSeekBarCandidate {
  param(
    [Parameter(Mandatory = $true)][System.Collections.Generic.Dictionary[string, System.Windows.Automation.AutomationElement]]$Candidates,
    [System.Windows.Automation.AutomationElement]$Element
  )

  if (-not $Element) {
    return
  }

  try {
    $runtimeId = $Element.GetRuntimeId()
    $runtimeKey = ($runtimeId | ForEach-Object { $_.ToString() }) -join '.'
    if (-not $Candidates.ContainsKey($runtimeKey)) {
      $Candidates.Add($runtimeKey, $Element)
    }
  } catch {
    $fallbackKey = "handle:$($Element.Current.NativeWindowHandle)"
    if (-not $Candidates.ContainsKey($fallbackKey)) {
      $Candidates.Add($fallbackKey, $Element)
    }
  }
}

function Get-SplayerSeekBarCandidates {
  param(
    [System.Windows.Automation.AutomationElement]$Root = $null,
    [int]$ProcessId = 0
  )

  Initialize-SplayerUiAutomation
  $candidates = New-Object 'System.Collections.Generic.Dictionary[string, System.Windows.Automation.AutomationElement]'
  if ($Root) {
    $searchRoot = Get-SplayerMainWindowAutomationElement -Root $Root -ProcessId $ProcessId
    Add-SplayerSeekBarCandidate -Candidates $candidates -Element (Find-SplayerAutomationElementById -Root $searchRoot -AutomationId 'SeekBar')
    Add-SplayerSeekBarCandidate -Candidates $candidates -Element (Find-SplayerAutomationElementByTreeWalk -Root $searchRoot -AutomationId 'SeekBar')
  }

  if ($ProcessId -gt 0) {
    Add-SplayerSeekBarCandidate -Candidates $candidates -Element (Find-SplayerAutomationElementByProcessAndId -ProcessId $ProcessId -AutomationId 'SeekBar')
    Add-SplayerSeekBarCandidate -Candidates $candidates -Element (Find-SplayerSeekBarElementFromWindowHandle -ProcessId $ProcessId)
  }

  $candidateList = @()
  foreach ($candidate in $candidates.Values) {
    if ($null -ne $candidate) {
      $candidateList += $candidate
    }
  }
  return $candidateList
}

function Resolve-SplayerSeekBarForSeek {
  param(
    [System.Windows.Automation.AutomationElement]$Root = $null,
    [int]$ProcessId = 0,
    [System.Windows.Automation.AutomationElement]$SeekBar = $null
  )

  Initialize-SplayerUiAutomation
  $candidateList = New-Object System.Collections.Generic.List[System.Windows.Automation.AutomationElement]
  if ($SeekBar) {
    [void]$candidateList.Add($SeekBar)
  }
  foreach ($candidate in (Get-SplayerSeekBarCandidates -Root $Root -ProcessId $ProcessId)) {
    if ($null -ne $candidate) {
      [void]$candidateList.Add($candidate)
    }
  }

  $lastError = $null
  foreach ($candidate in $candidateList) {
    try {
      if (-not $candidate.Current.IsEnabled) {
        throw 'UIA seek bar is not enabled.'
      }

      $rangeValuePattern = $null
      if (-not $candidate.TryGetCurrentPattern([System.Windows.Automation.RangeValuePattern]::Pattern, [ref]$rangeValuePattern)) {
        throw 'UIA seek bar does not expose RangeValuePattern.'
      }

      $minimum = $rangeValuePattern.Current.Minimum
      $maximum = $rangeValuePattern.Current.Maximum
      if ($maximum -le $minimum) {
        throw "UIA seek bar range is not ready: minimum=$minimum maximum=$maximum"
      }

      return [PSCustomObject]@{
        SeekBar = $candidate
        RangeValuePattern = $rangeValuePattern
        Minimum = $minimum
        Maximum = $maximum
      }
    } catch {
      $lastError = $_
    }
  }

  if ($lastError) {
    throw $lastError
  }

  throw 'UIA seek bar was not found. Expected virtual provider AutomationId=SeekBar.'
}

function Assert-SplayerSeekBarAutomation {
  param(
    [Parameter(Mandatory = $true)][System.Windows.Automation.AutomationElement]$Root,
    [int]$ProcessId = 0,
    [int]$MaxAttempts = 40,
    [int]$RetryDelayMilliseconds = 500
  )

  Initialize-SplayerUiAutomation
  $lastError = $null
  for ($attempt = 0; $attempt -lt $MaxAttempts; $attempt++) {
    try {
      $resolved = Resolve-SplayerSeekBarForSeek -Root $Root -ProcessId $ProcessId
      return $resolved.SeekBar
    } catch {
      $lastError = $_
      if ($attempt -ge ($MaxAttempts - 1)) {
        throw $lastError
      }
      Start-Sleep -Milliseconds $RetryDelayMilliseconds
    }
  }
}

function Assert-SplayerVideoViewAutomation {
  param(
    [Parameter(Mandatory = $true)][System.Windows.Automation.AutomationElement]$Root,
    [int]$ProcessId = 0
  )

  Initialize-SplayerUiAutomation
  $searchRoot = Get-SplayerMainWindowAutomationElement -Root $Root -ProcessId $ProcessId
  $videoView = Find-SplayerAutomationElementById -Root $searchRoot -AutomationId 'VideoView'
  if (-not $videoView -and $ProcessId -gt 0) {
    $videoView = Find-SplayerAutomationElementByProcessAndId -ProcessId $ProcessId -AutomationId 'VideoView'
  }
  if (-not $videoView) {
    throw 'UIA video view was not found. Expected AutomationId=VideoView.'
  }

  $boundingRect = $videoView.Current.BoundingRectangle
  if ($boundingRect.Width -le 0 -or $boundingRect.Height -le 0) {
    throw "UIA video view has an empty bounding rectangle: width=$($boundingRect.Width) height=$($boundingRect.Height)"
  }

  return $videoView
}

function Invoke-SplayerUiaSeek {
  param(
    [System.Windows.Automation.AutomationElement]$SeekBar = $null,
    [System.Windows.Automation.AutomationElement]$Root = $null,
    [IntPtr]$WindowHandle = [IntPtr]::Zero,
    [int]$ProcessId = 0,
    [Parameter(Mandatory = $true)][double]$TargetValue,
    [int]$MaxAttempts = 8,
    [int]$RetryDelayMilliseconds = 500
  )

  Initialize-SplayerUiAutomation
  $lastError = $null
  for ($attempt = 0; $attempt -lt $MaxAttempts; $attempt++) {
    try {
      $resolvedRoot = $Root
      if (-not $resolvedRoot -and $ProcessId -gt 0) {
        $latestHandle = Get-SplayerMainWindowHandle -ProcessId $ProcessId
        if ($latestHandle -ne [IntPtr]::Zero) {
          $WindowHandle = $latestHandle
        }
      }
      if (-not $resolvedRoot -and $WindowHandle -ne [IntPtr]::Zero) {
        try {
          $resolvedRoot = Get-SplayerAutomationRoot -WindowHandle $WindowHandle
        } catch {
          # HWND UIA root can briefly fail while the fragment tree reparents after playback events.
        }
      }

      $resolved = Resolve-SplayerSeekBarForSeek -Root $resolvedRoot -ProcessId $ProcessId -SeekBar $SeekBar
      $rangeValuePattern = $resolved.RangeValuePattern
      $minimum = $resolved.Minimum
      $maximum = $resolved.Maximum
      if ($TargetValue -lt $minimum -or $TargetValue -gt $maximum) {
        throw "UIA seek target $TargetValue is outside range [$minimum, $maximum]."
      }

      $rangeValuePattern.SetValue($TargetValue)
      return
    } catch {
      $lastError = $_
      if ($attempt -ge 1) {
        $SeekBar = $null
      }
      if ($attempt -ge ($MaxAttempts - 1)) {
        throw $lastError
      }
      Start-Sleep -Milliseconds $RetryDelayMilliseconds
    }
  }
}

function Get-SplayerSeekBarRangeValuePattern {
  param(
    [Parameter(Mandatory = $true)][System.Windows.Automation.AutomationElement]$Root,
    [int]$ProcessId = 0
  )

  $seekBar = Assert-SplayerSeekBarAutomation -Root $Root -ProcessId $ProcessId
  $rangeValuePattern = $null
  if (-not $seekBar.TryGetCurrentPattern([System.Windows.Automation.RangeValuePattern]::Pattern, [ref]$rangeValuePattern)) {
    throw 'UIA seek bar does not expose RangeValuePattern.'
  }
  return $rangeValuePattern
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
