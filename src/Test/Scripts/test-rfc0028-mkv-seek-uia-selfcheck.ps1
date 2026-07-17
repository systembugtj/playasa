#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0028 wrapper: MKV seek via UIA RangeValuePattern.SetValue.
#>
[CmdletBinding()]
param(
  [string]$SamplePath = '',
  [int]$TimeoutSeconds = 120,
  [int]$SeekCount = 3,
  [int]$BetweenSeekMilliseconds = 2000,
  [int]$PostSeekSeconds = 10,
  [int]$AllowedUnresponsiveSeconds = 5,
  [switch]$CheckWindowResponding
)

$env:PLAYASA_TEST_UIA_SEEK = '1'
try {
  & (Join-Path $PSScriptRoot 'test-rfc0027-mkv-seek-selfcheck.ps1') `
    -SamplePath $SamplePath `
    -TimeoutSeconds $TimeoutSeconds `
    -SeekCount $SeekCount `
    -BetweenSeekMilliseconds $BetweenSeekMilliseconds `
    -PostSeekSeconds $PostSeekSeconds `
    -AllowedUnresponsiveSeconds $AllowedUnresponsiveSeconds `
    -CheckWindowResponding:$CheckWindowResponding
} finally {
  Remove-Item Env:PLAYASA_TEST_UIA_SEEK -ErrorAction SilentlyContinue
}
