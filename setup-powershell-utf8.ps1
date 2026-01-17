# PowerShell UTF-8 编码配置脚本
# 用于支持中文字符显示

Write-Host "配置 PowerShell UTF-8 编码..." -ForegroundColor Green

# 设置控制台代码页为 UTF-8 (65001)
chcp 65001 | Out-Null

# 设置 PowerShell 输出编码为 UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 设置环境变量
$env:PYTHONIOENCODING = "utf-8"

Write-Host "✓ PowerShell UTF-8 编码已配置" -ForegroundColor Green
Write-Host "测试中文显示: 你好，世界！" -ForegroundColor Cyan

# 显示当前编码设置
Write-Host "`n当前编码设置:" -ForegroundColor Yellow
Write-Host "  OutputEncoding: $([Console]::OutputEncoding.EncodingName)"
Write-Host "  InputEncoding: $([Console]::InputEncoding.EncodingName)"
Write-Host "  CodePage: $([Console]::OutputEncoding.CodePage)"
