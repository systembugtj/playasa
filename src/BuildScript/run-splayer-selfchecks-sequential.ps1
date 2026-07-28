#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$scripts = Join-Path $PSScriptRoot '..\Test\Scripts'
Import-Module (Join-Path $scripts 'TestSupport\SplayerTestSupport.psm1') -Force

Write-Host '=== test-rfc0034-realaudio-selfcheck (300s) ===' -ForegroundColor Cyan
& (Join-Path $scripts 'test-rfc0034-realaudio-selfcheck.ps1') -TimeoutSeconds 300

# Let DirectShow graph teardown finish before the next splayer launch (parallel graphs crash).
Stop-SplayerProcesses
Start-Sleep -Seconds 3

Write-Host '=== test-rmvb-seek-selfcheck (300s) ===' -ForegroundColor Cyan
& (Join-Path $scripts 'test-rmvb-seek-selfcheck.ps1') -TimeoutSeconds 300

Write-Host 'splayer selfchecks sequential: OK' -ForegroundColor Green
