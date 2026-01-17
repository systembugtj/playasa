@echo off
REM 安装 PowerShell 全局中文支持
REM Install PowerShell global Chinese character support

chcp 65001 >nul 2>&1

echo ========================================
echo PowerShell 全局中文支持安装
echo ========================================
echo.

cd /d "%~dp0"

echo 正在配置 PowerShell...
echo.

powershell -ExecutionPolicy Bypass -File "setup-powershell-chinese-global.ps1"

echo.
echo ========================================
echo 安装完成！
echo ========================================
echo.
echo 请重新启动 PowerShell 以使配置生效。
echo.
pause
