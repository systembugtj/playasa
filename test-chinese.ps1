# Test Chinese character display in PowerShell
# 测试 PowerShell 中文显示

# Apply UTF-8 encoding
if ($Host.Name -eq 'ConsoleHost') {
    chcp 65001 | Out-Null
}
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PowerShell Chinese Display Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Test Chinese: 你好，世界！" -ForegroundColor Green
Write-Host "Test encoding: UTF-8" -ForegroundColor Green
Write-Host ""

Write-Host "Current encoding settings:" -ForegroundColor Yellow
Write-Host "  OutputEncoding: $([Console]::OutputEncoding.EncodingName)" -ForegroundColor Gray
Write-Host "  InputEncoding: $([Console]::InputEncoding.EncodingName)" -ForegroundColor Gray
Write-Host "  CodePage: $([Console]::OutputEncoding.CodePage)" -ForegroundColor Gray
Write-Host ""

if ([Console]::OutputEncoding.CodePage -eq 65001) {
    Write-Host "[OK] UTF-8 encoding is correctly set" -ForegroundColor Green
} else {
    Write-Host "[WARNING] UTF-8 encoding is not correctly set" -ForegroundColor Yellow
}

Write-Host ""
