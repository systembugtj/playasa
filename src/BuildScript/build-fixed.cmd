@echo off
REM 改进的构建脚本 - 支持多个 Visual Studio 版本
REM Fixed build script - supports multiple Visual Studio versions

setlocal enabledelayedexpansion

REM 检测 Visual Studio 版本
set VS_FOUND=0

REM Try VS2026 (may use different env var names)
if defined VS180COMNTOOLS (
    set "VSCOMNTOOLS=!VS180COMNTOOLS!"
    set "VS_VERSION=VS2026"
    set "VS_TOOLSET=v145"
    set VS_FOUND=1
) else if defined VS175COMNTOOLS (
    set "VSCOMNTOOLS=!VS175COMNTOOLS!"
    set "VS_VERSION=VS2026"
    set "VS_TOOLSET=v145"
    set VS_FOUND=1
) else if defined VS174COMNTOOLS (
    set "VSCOMNTOOLS=!VS174COMNTOOLS!"
    set "VS_VERSION=VS2026"
    set "VS_TOOLSET=v145"
    set VS_FOUND=1
) else if defined VS170COMNTOOLS (
    set "VSCOMNTOOLS=!VS170COMNTOOLS!"
    set "VS_VERSION=VS2022"
    set "VS_TOOLSET=v143"
    set VS_FOUND=1
) else if defined VS160COMNTOOLS (
    set "VSCOMNTOOLS=!VS160COMNTOOLS!"
    set "VS_VERSION=VS2019"
    set "VS_TOOLSET=v142"
    set VS_FOUND=1
) else if defined VS150COMNTOOLS (
    set "VSCOMNTOOLS=!VS150COMNTOOLS!"
    set "VS_VERSION=VS2017"
    set "VS_TOOLSET=v141"
    set VS_FOUND=1
) else if defined VS140COMNTOOLS (
    set "VSCOMNTOOLS=!VS140COMNTOOLS!"
    set "VS_VERSION=VS2015"
    set "VS_TOOLSET=v140"
    set VS_FOUND=1
) else if defined VS120COMNTOOLS (
    set "VSCOMNTOOLS=!VS120COMNTOOLS!"
    set "VS_VERSION=VS2013"
    set "VS_TOOLSET=v120"
    set VS_FOUND=1
)

REM If still not found, try to find VS2026 in common paths
if !VS_FOUND! EQU 0 (
    if exist "C:\Program Files\Microsoft Visual Studio\2026\Community\Common7\Tools\vsvars32.bat" (
        set "VSCOMNTOOLS=C:\Program Files\Microsoft Visual Studio\2026\Community\Common7\Tools\"
        set "VS_VERSION=VS2026"
        set "VS_TOOLSET=v144"
        set VS_FOUND=1
    ) else if exist "C:\Program Files\Microsoft Visual Studio\2026\Professional\Common7\Tools\vsvars32.bat" (
        set "VSCOMNTOOLS=C:\Program Files\Microsoft Visual Studio\2026\Professional\Common7\Tools\"
        set "VS_VERSION=VS2026"
        set "VS_TOOLSET=v144"
        set VS_FOUND=1
    ) else if exist "C:\Program Files\Microsoft Visual Studio\2026\Enterprise\Common7\Tools\vsvars32.bat" (
        set "VSCOMNTOOLS=C:\Program Files\Microsoft Visual Studio\2026\Enterprise\Common7\Tools\"
        set "VS_VERSION=VS2026"
        set "VS_TOOLSET=v144"
        set VS_FOUND=1
    ) else if exist "C:\Program Files (x86)\Microsoft Visual Studio\2026\Community\Common7\Tools\vsvars32.bat" (
        set "VSCOMNTOOLS=C:\Program Files (x86)\Microsoft Visual Studio\2026\Community\Common7\Tools\"
        set "VS_VERSION=VS2026"
        set "VS_TOOLSET=v144"
        set VS_FOUND=1
    )
)

if !VS_FOUND! EQU 0 (
    echo ERROR: Visual Studio not found!
    echo Please install Visual Studio 2013 or later (VS2026 recommended).
    echo.
    echo Try running: detect-vs2026.ps1 to find VS2026 installation
    pause
    exit /b 1
)

echo ========================================
echo Using !VS_VERSION! (!VS_TOOLSET!)
echo ========================================
echo.

set PATH=%CD%/hg_bin;%PATH%
set TOPDIR=%CD%/../

call "!VSCOMNTOOLS!vsvars32.bat"

REM 运行 pre-build
echo Running pre-build scripts...
if exist "pre-build-fixed.cmd" (
    call "pre-build-fixed.cmd"
) else (
    call "pre-build.cmd"
)
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: pre-build script failed, continuing...
)

call "revision.cmd"
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: revision.cmd failed, continuing...
)

echo.
echo Building SPlayer project ...
echo This may take a while...
echo.

REM Check if solution is in root or src directory
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

echo Using solution: %SOLUTION_PATH%
echo.

REM Try MSBuild first (faster and more reliable)
if exist "%ProgramFiles%\Microsoft Visual Studio\2025\Community\MSBuild\Current\Bin\MSBuild.exe" (
    "%ProgramFiles%\Microsoft Visual Studio\2025\Community\MSBuild\Current\Bin\MSBuild.exe" "%SOLUTION_PATH%" /p:Configuration="Release Unicode" /p:Platform=Win32 /m
) else if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2025\Community\MSBuild\Current\Bin\MSBuild.exe" (
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2025\Community\MSBuild\Current\Bin\MSBuild.exe" "%SOLUTION_PATH%" /p:Configuration="Release Unicode" /p:Platform=Win32 /m
) else if defined DevEnvDir (
    "%DevEnvDir%/devenv.com" "%SOLUTION_PATH%" /build "Release Unicode|Win32"
) else (
    echo ERROR: Cannot find MSBuild or DevEnv!
    echo Please install Visual Studio 2025 or set up build environment.
    pause
    exit /b 1
)
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ========================================
    echo ERROR: Build failed!
    echo ========================================
    echo.
    echo Common issues:
    echo 1. Missing dependencies (thirdparty/pkg, thirdparty/sinet)
    echo 2. Missing key files (run fix-build-issues.ps1)
    echo 3. Incorrect project toolset version
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo SPlayer built successfully!
echo ========================================
echo.
pause
