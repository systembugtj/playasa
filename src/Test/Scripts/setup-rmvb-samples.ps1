#Requires -Version 5.1
<#
.SYNOPSIS
  Compatibility wrapper for the unified selfcheck sample setup.
#>
[CmdletBinding()]
param(
  [string]$OutputDirectory = '',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$setupScript = Join-Path $PSScriptRoot 'setup-selfcheck-samples.ps1'
$arguments = @()
if (-not [string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $arguments += @('-OutputDirectory', $OutputDirectory)
}
if ($Force) {
  $arguments += '-Force'
}

& $setupScript @arguments
