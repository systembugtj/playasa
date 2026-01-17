# 构建问题修复指南

## 常见构建问题及解决方案

### 问题 1: Visual Studio 未找到

**错误信息**:
```
ERROR: Visual Studio not found!
```

**解决方案**:

1. **使用修复脚本**（推荐）:
   ```powershell
   cd src\BuildScript
   .\fix-build-issues.ps1
   ```

2. **手动检查**:
   - 确保已安装 Visual Studio 2013 或更高版本
   - 检查环境变量 `VS120COMNTOOLS` (VS2013) 或 `VS160COMNTOOLS` (VS2019)

3. **使用改进的构建脚本**:
   ```batch
   cd src\BuildScript
   build-fixed.cmd
   ```
   此脚本会自动检测已安装的 Visual Studio 版本。

### 问题 2: 缺失 key 文件

**错误信息**:
```
找不到文件: shooterclient.key
找不到文件: shooterapi.key
```

**解决方案**:

运行修复脚本会自动创建这些文件：
```powershell
.\fix-build-issues.ps1
```

或手动创建：
```batch
cd src\BuildScript
copy shooterclient_dummy.key ..\Source\svplib\shooterclient.key
copy shooterclient_dummy.key ..\include\shooterclient.key
copy shooterapi_dummy.key ..\include\shooterapi.key
```

### 问题 3: 缺失依赖库

**错误信息**:
```
找不到 thirdparty/pkg/trunk/sphash
找不到 thirdparty/sinet/trunk/sinet
```

**解决方案**:

这些依赖需要从其他仓库获取：

1. **检查依赖是否存在**:
   ```powershell
   Test-Path ..\thirdparty\pkg\trunk\sphash
   Test-Path ..\thirdparty\sinet\trunk\sinet
   ```

2. **如果缺失，需要**:
   - 从原始仓库获取这些依赖
   - 或跳过依赖构建，直接构建主项目（如果依赖已预编译）

3. **修改构建脚本**:
   编辑 `build.cmd`，注释掉依赖构建部分：
   ```batch
   REM echo Building sphash project of splayer-pkg ...
   REM "%DevEnvDir%/devenv.com" ../thirdparty/pkg/trunk/sphash/sphash.sln /build "Release|Win32"
   ```

### 问题 4: revision.h 文件缺失

**错误信息**:
```
找不到 revision.h
```

**解决方案**:

1. **自动修复**:
   ```powershell
   .\fix-build-issues.ps1
   ```

2. **手动创建**:
   ```batch
   cd src\BuildScript
   copy revision_dummy.h ..\Source\apps\mplayerc\revision.h
   ```

3. **或手动创建内容**:
   创建 `src\Source\apps\mplayerc\revision.h`:
   ```cpp
   #pragma once
   #define SVP_REV_STR     L"unknown"
   #define SVP_REV_NUMBER  0
   #define BRANCHVER       L"36"
   ```

### 问题 5: 工具集版本不匹配

**错误信息**:
```
error MSB8020: The build tools for v120 cannot be found.
```

**解决方案**:

1. **升级项目文件**（推荐）:
   - 使用 Visual Studio 打开 `src\splayer.sln`
   - 右键解决方案 → 重定向项目
   - 选择已安装的 Visual Studio 版本

2. **手动修改**:
   编辑 `.vcxproj` 文件，将 `PlatformToolset` 从 `v120` 改为：
   - `v142` (VS2019)
   - `v143` (VS2022)

3. **使用改进的构建脚本**:
   `build-fixed.cmd` 会自动检测并使用正确的工具集。

### 问题 6: 输出目录不存在

**错误信息**:
```
无法创建输出目录
```

**解决方案**:

运行修复脚本会自动创建：
```powershell
.\fix-build-issues.ps1
```

或手动创建：
```batch
mkdir src\out\bin
mkdir src\out\obj
```

## 快速修复步骤

### 步骤 1: 运行修复脚本

```powershell
cd src\BuildScript
.\fix-build-issues.ps1
```

### 步骤 2: 检查输出

脚本会显示：
- ✓ 已修复的问题
- ✗ 需要手动处理的问题
- ⚠ 警告信息

### 步骤 3: 构建项目

使用改进的构建脚本：
```batch
.\build-fixed.cmd
```

或使用原始脚本（需要 VS2013）:
```batch
.\build.cmd
```

## 构建脚本说明

### build.cmd
- 原始构建脚本
- 仅支持 Visual Studio 2013
- 需要 thirdparty 依赖

### build-fixed.cmd
- 改进的构建脚本
- 支持多个 Visual Studio 版本（2013-2022）
- 自动检测已安装的版本
- 更好的错误处理

### fix-build-issues.ps1
- PowerShell 诊断和修复脚本
- 自动修复常见问题
- 检查依赖和配置

## 依赖说明

### 必需依赖
- Visual Studio 2013 或更高版本
- Windows SDK
- DirectShow SDK
- MFC 库

### 可选依赖（如果缺失，某些功能可能不可用）
- `thirdparty/pkg/trunk/sphash` - 哈希库
- `thirdparty/sinet/trunk/sinet` - 网络库
- `thirdparty/pkg/trunk/unrar` - RAR 解压库

## 故障排除

### 如果构建仍然失败

1. **检查详细错误信息**:
   - 在 Visual Studio 中打开项目
   - 查看输出窗口的详细错误

2. **检查项目配置**:
   - 确保选择了正确的配置（Release Unicode）
   - 确保选择了正确的平台（Win32）

3. **清理并重新构建**:
   ```batch
   "%DevEnvDir%/devenv.com" ../splayer.sln /clean "Release Unicode|Win32"
   "%DevEnvDir%/devenv.com" ../splayer.sln /rebuild "Release Unicode|Win32"
   ```

4. **检查日志文件**:
   - 查看 `src\out\obj\` 目录下的构建日志

## 相关文档

- [编译与现代化分析](../analysis/编译与现代化分析.md)
- [现代化实施计划](../analysis/现代化实施计划.md)
- [RFC-0002: 编译环境与技术栈分析](../rfc/rfc-0002-build-environment-analysis.md)
