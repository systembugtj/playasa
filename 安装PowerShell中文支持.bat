@echo off
chcp 65001 >nul
echo ========================================
echo PowerShell UTF-8 中文支持安装
echo ========================================
echo.

echo [1] 检查 PowerShell 配置文件位置...
powershell -Command "if (Test-Path $PROFILE) { Write-Host '  配置文件存在:' $PROFILE } else { Write-Host '  配置文件不存在，将创建' }"

echo.
echo [2] 安装 UTF-8 支持到 PowerShell 配置文件...
powershell -Command ^
    "$profileContent = @'`n" ^
    "# UTF-8 Encoding Support`n" ^
    "if (`$Host.Name -eq 'ConsoleHost') { chcp 65001 | Out-Null }`n" ^
    "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`n" ^
    "[Console]::InputEncoding = [System.Text.Encoding]::UTF8`n" ^
    "`$OutputEncoding = [System.Text.Encoding]::UTF8`n" ^
    "`$env:PYTHONIOENCODING = 'utf-8'`n" ^
    "'@; `n" ^
    "if (-not (Test-Path `$PROFILE)) { `n" ^
    "    New-Item -Path `$PROFILE -ItemType File -Force | Out-Null `n" ^
    "    Write-Host '  已创建配置文件' `n" ^
    "} `n" ^
    "$existing = if (Test-Path `$PROFILE) { Get-Content `$PROFILE -Raw } else { '' } `n" ^
    "if (`$existing -notmatch 'UTF-8 Encoding Support') { `n" ^
    "    Add-Content -Path `$PROFILE -Value `$profileContent `n" ^
    "    Write-Host '  UTF-8 支持已添加到配置文件' `n" ^
    "} else { `n" ^
    "    Write-Host '  UTF-8 支持已存在' `n" ^
    "}"

echo.
echo [3] 测试 UTF-8 编码...
powershell -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; Write-Host '测试中文显示: 你好，世界！' -ForegroundColor Cyan"

echo.
echo ========================================
echo 安装完成！
echo ========================================
echo.
echo 请重启 PowerShell 以使配置生效。
echo 或者运行: powershell -NoProfile -File setup-powershell-utf8.ps1
echo.
pause
