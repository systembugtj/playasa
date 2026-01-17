@echo off
REM 改进的 pre-build 脚本 - 自动创建缺失的 key 文件

chdir /D %~dp0

REM 创建缺失的 key 文件（如果不存在）
if not exist ".\shooterclient_dummy.key" (
    echo # Dummy key file > ".\shooterclient_dummy.key"
)

if not exist ".\shooterapi_dummy.key" (
    echo # Dummy key file > ".\shooterapi_dummy.key"
)

REM 复制 key 文件
if not exist "..\Source\svplib\shooterclient.key" (
    if exist ".\shooterclient_dummy.key" (
        copy ".\shooterclient_dummy.key" "..\Source\svplib\shooterclient.key" >nul
        echo Created: ..\Source\svplib\shooterclient.key
    ) else (
        echo # Dummy key > "..\Source\svplib\shooterclient.key"
        echo Created: ..\Source\svplib\shooterclient.key
    )
)

if not exist "..\include\shooterclient.key" (
    if exist ".\shooterclient_dummy.key" (
        copy ".\shooterclient_dummy.key" "..\include\shooterclient.key" >nul
        echo Created: ..\include\shooterclient.key
    ) else (
        echo # Dummy key > "..\include\shooterclient.key"
        echo Created: ..\include\shooterclient.key
    )
)

if not exist "..\include\shooterapi.key" (
    if exist ".\shooterapi_dummy.key" (
        copy ".\shooterapi_dummy.key" "..\include\shooterapi.key" >nul
        echo Created: ..\include\shooterapi.key
    ) else (
        echo # Dummy key > "..\include\shooterapi.key"
        echo Created: ..\include\shooterapi.key
    )
)

REM 创建输出目录
if not exist "..\out\bin" mkdir "..\out\bin"
if not exist "..\out\obj" mkdir "..\out\obj"

echo Pre-build completed.
