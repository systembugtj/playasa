@echo off
REM Build using MSBuild directly (works without full VS installation)
REM 使用 MSBuild 直接构建（不需要完整 VS 安装）

setlocal enabledelayedexpansion

echo ========================================
echo Building SPlayer with MSBuild
echo ========================================
echo.

REM Find MSBuild
set MSBUILD_PATH=

REM Check for VS2026 MSBuild (version 18)
if exist "%ProgramFiles%\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe" (
    set "MSBUILD_PATH=%ProgramFiles%\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe"
    set "VS_VERSION=VS2026"
) else if exist "%ProgramFiles%\Microsoft Visual Studio\2026\Community\MSBuild\Current\Bin\MSBuild.exe" (
    set "MSBUILD_PATH=%ProgramFiles%\Microsoft Visual Studio\2026\Community\MSBuild\Current\Bin\MSBuild.exe"
    set "VS_VERSION=VS2026"
) else if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2026\Community\MSBuild\Current\Bin\MSBuild.exe" (
    set "MSBUILD_PATH=%ProgramFiles(x86)%\Microsoft Visual Studio\2026\Community\MSBuild\Current\Bin\MSBuild.exe"
    set "VS_VERSION=VS2026"
) else if exist "%ProgramFiles%\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" (
    set "MSBUILD_PATH=%ProgramFiles%\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
    set "VS_VERSION=VS2022"
) else if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" (
    set "MSBUILD_PATH=%ProgramFiles(x86)%\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
    set "VS_VERSION=VS2022"
) else if exist "%ProgramFiles%\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" (
    set "MSBUILD_PATH=%ProgramFiles%\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe"
    set "VS_VERSION=VS2019"
) else if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" (
    set "MSBUILD_PATH=%ProgramFiles(x86)%\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe"
    set "VS_VERSION=VS2019"
) else if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2017\Community\MSBuild\15.0\Bin\MSBuild.exe" (
    set "MSBUILD_PATH=%ProgramFiles(x86)%\Microsoft Visual Studio\2017\Community\MSBuild\15.0\Bin\MSBuild.exe"
    set "VS_VERSION=VS2017"
) else if exist "%ProgramFiles(x86)%\MSBuild\14.0\Bin\MSBuild.exe" (
    set "MSBUILD_PATH=%ProgramFiles(x86)%\MSBuild\14.0\Bin\MSBuild.exe"
    set "VS_VERSION=VS2015"
)

if "!MSBUILD_PATH!"=="" (
    echo ERROR: MSBuild not found!
    echo Please install Visual Studio Build Tools or Visual Studio.
    echo.
    echo You can download Build Tools from:
    echo https://visualstudio.microsoft.com/downloads/
    echo.
    pause
    exit /b 1
)

echo Found MSBuild: !MSBUILD_PATH!
echo Using: !VS_VERSION!
echo.

REM Find solution file
set SOLUTION_PATH=..\splayer.sln
if not exist "%SOLUTION_PATH%" (
    set SOLUTION_PATH=..\..\splayer.sln
)

if not exist "%SOLUTION_PATH%" (
    echo ERROR: Solution file not found!
    echo Looking for: %SOLUTION_PATH%
    pause
    exit /b 1
)

echo Solution: %SOLUTION_PATH%
echo.

REM Run pre-build
echo Running pre-build scripts...
if exist "pre-build-fixed.cmd" (
    call "pre-build-fixed.cmd"
) else (
    call "pre-build.cmd"
)

call "revision.cmd"

echo.
echo Building project...
echo This may take a while...
echo.

REM Build with MSBuild
"!MSBUILD_PATH!" "!SOLUTION_PATH!" /p:Configuration="Release Unicode" /p:Platform=Win32 /m /v:minimal /nologo

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ========================================
    echo ERROR: Build failed!
    echo ========================================
    echo.
    echo Try building with more verbose output:
    echo   "!MSBUILD_PATH!" "!SOLUTION_PATH!" /p:Configuration="Release Unicode" /p:Platform=Win32 /v:detailed
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo Build completed successfully!
echo ========================================
echo.
echo Output should be in: src\out\bin\Release Unicode\
echo.

pause
