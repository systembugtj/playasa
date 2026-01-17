@echo off
REM SPlayer 编译环境检查脚本

echo ========================================
echo SPlayer 编译环境检查
echo ========================================
echo.

echo [1] 检查 Visual Studio 安装...
if defined VS160COMNTOOLS (
    echo   ✓ Visual Studio 2019 已安装
    set VS_FOUND=1
) else if defined VS150COMNTOOLS (
    echo   ✓ Visual Studio 2017 已安装
    set VS_FOUND=1
) else if defined VS140COMNTOOLS (
    echo   ✓ Visual Studio 2015 已安装
    set VS_FOUND=1
) else if defined VS120COMNTOOLS (
    echo   ✓ Visual Studio 2013 已安装
    set VS_FOUND=1
) else (
    echo   ✗ 未找到 Visual Studio
    set VS_FOUND=0
)

echo.
echo [2] 检查 MSBuild...
where msbuild.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo   ✓ MSBuild 已找到
    for /f "delims=" %%i in ('where msbuild.exe') do echo     路径: %%i
) else (
    echo   ✗ MSBuild 未找到
)

echo.
echo [3] 检查项目文件...
if exist "src\splayer.sln" (
    echo   ✓ 解决方案文件存在: src\splayer.sln
) else (
    echo   ✗ 解决方案文件不存在
)

if exist "src\Source\apps\mplayerc\mplayerc_vs2005.vcxproj" (
    echo   ✓ 主项目文件存在
) else (
    echo   ✗ 主项目文件不存在
)

echo.
echo [4] 检查依赖目录...
if exist "src\Thirdparty" (
    echo   ✓ Thirdparty 目录存在
) else (
    echo   ✗ Thirdparty 目录不存在
)

if exist "src\lib" (
    echo   ✓ lib 目录存在
) else (
    echo   ✗ lib 目录不存在
)

echo.
echo [5] 检查构建脚本...
if exist "src\BuildScript\build.cmd" (
    echo   ✓ 构建脚本存在
) else (
    echo   ✗ 构建脚本不存在
)

echo.
echo ========================================
echo 检查完成
echo ========================================

if %VS_FOUND% EQU 0 (
    echo.
    echo 警告: 未找到 Visual Studio，无法编译项目
    echo 建议: 安装 Visual Studio 2019 或 2022
)

pause
