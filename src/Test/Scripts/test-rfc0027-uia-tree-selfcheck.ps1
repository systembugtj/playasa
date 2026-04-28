#Requires -Version 5.1
<#
.SYNOPSIS
  Launch splayer and verify the UI Automation tree needed by seek tests.
#>
[CmdletBinding()]
param(
  [string]$SamplePath = '',
  [int]$TimeoutSeconds = 45,
  [switch]$RequireSeekBar
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'TestSupport\SplayerTestSupport.psm1') -Force

$repoRoot = Get-SplayerRepoRoot
if ([string]::IsNullOrWhiteSpace($SamplePath)) {
  $SamplePath = Join-Path $repoRoot 'out\selfcheck\genius_party_sample.mkv'
}

$firstFrameNeedle = 'Modern FFmpeg bridge first frame ready'
$decodeFailureNeedle = 'Modern FFmpeg bridge decode failed'

Stop-SplayerProcesses
Clear-SplayerLog
$process = Start-SplayerForSample -SamplePath $SamplePath
try {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  Wait-SplayerLogNeedle `
    -Process $process `
    -Needle $firstFrameNeedle `
    -Deadline $deadline `
    -FailureNeedles @($decodeFailureNeedle) `
    -TimeoutMessage "Timed out waiting for first frame before UIA validation; inspect $(Get-SplayerLogPath)"

  $windowHandle = Wait-SplayerMainWindowHandle -Process $process -Deadline $deadline
  $automationRoot = Get-SplayerAutomationRoot -WindowHandle $windowHandle
  if (-not $automationRoot) {
    throw 'UIA root was not available for the splayer main window.'
  }

  if ($RequireSeekBar) {
    Assert-SplayerSeekBarAutomation -Root $automationRoot -ProcessId $process.Id | Out-Null
  }

  Write-Host 'test-rfc0027-uia-tree-selfcheck: OK' -ForegroundColor Green
} finally {
  Get-Process -Id $process.Id -ErrorAction SilentlyContinue | Stop-Process -Force
}
