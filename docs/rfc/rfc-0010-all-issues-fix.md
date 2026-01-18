# RFC-0010: 全面修复所有编译问题

**状态**: 进行中 (In Progress)  
**作者**: 开发团队  
**创建日期**: 2025-01-16  
**最后更新**: 2025-01-16 (更新：库依赖和未解析符号修复完成)

## 摘要

本文档记录全面修复所有编译错误的工作，包括库依赖、字符类型、未解析符号等问题。

## 1. 背景

在 RFC-0009 修复后，仍存在以下问题需要解决：

### 1.1 剩余问题类别

1. **库依赖问题**
   - `dsutilD.lib` 和 `asyncreaderD.lib` 找不到
   - 库输出路径不正确

2. **字符类型混用**
   - `TCHAR` 和 `wchar_t` 混用
   - `wcscpy`, `wcscmp` 参数类型不匹配

3. **未解析的外部符号**
   - `CSVPEqualizer` 相关符号
   - `Utility` 类相关符号（`SysUtil` 全局变量）
   - DirectShow 工具函数

4. **其他编译错误**
   - `modf` 未解析
   - `av_h264_decode_frame` 未解析
   - `wcscpy` 等函数的安全警告

## 2. 解决方案

### 2.1 库依赖修复（已完成）

**问题**: `dsutilD.lib` 和 `asyncreaderD.lib` 找不到，因为：
1. 库输出路径不正确（使用相对路径 `../../lib/`）
2. `asyncreader` 项目缺少 Debug|Win32 和 Release|Win32 配置
3. `common.props` 路径不正确

**修复**:
1. **dsutil.vcxproj**:
   - 修复所有配置的 `common.props` 路径为 `$(SolutionDir)src\Source\common.props`
   - 修复 Debug|Win32 和 Release|Win32 的输出路径为 `$(OutDir)$(TargetName)$(TargetExt)`
   - 添加 Debug|Win32 的 `TargetName` 为 `$(ProjectName)D`
   - 修复 Release Unicode|Win32 的包含路径和输出路径

2. **asyncreader.vcxproj**:
   - 添加 Debug|Win32 和 Release|Win32 配置
   - 修复所有配置的 `common.props` 路径为 `$(SolutionDir)src\Source\common.props`
   - 添加所有配置的 `OutDir` 和 `IntDir` 属性
   - 添加 Debug|Win32 的 `TargetName` 为 `$(ProjectName)D`
   - 添加所有配置的 `ItemDefinitionGroup` 和预编译头设置

**文件**:
- `src/Source/dsutil/dsutil_vs2005.vcxproj`
- `src/Source/filters/reader/asyncreader/asyncreader_vs2005.vcxproj`

### 2.2 字符类型统一（待处理）

**问题**: `TCHAR` 和 `wchar_t` 混用导致类型不匹配。

**解决方案**:
- 统一使用 `wchar_t` 和宽字符 API
- 替换 `TCHAR` 为 `wchar_t`
- 使用 `wcscpy_s`, `wcscmp` 等安全函数

### 2.3 未解析符号修复（已完成）

**问题**: 
- `CSVPEqualizer` 类在 `svplib` 项目中定义，但链接时找不到
- `Utility` 类和 `SysUtil` 全局变量在 `sharedlib` 项目中定义，但链接时找不到
- DirectShow 工具函数（`GetCLSID`, `GetUpStreamPin` 等）在 `dsutil` 项目中定义，但链接时找不到

**修复**:
1. **svplib.vcxproj**:
   - 添加 Debug|Win32 的 `common.props` 导入
   - 修复所有配置的库输出路径为 `$(OutDir)$(TargetName)$(TargetExt)`
   - 修复 `sharedlibDU.lib` 依赖为 `sharedlibD.lib`
   - 修复库目录路径为 `$(SolutionDir)src\out\bin\`

2. **sharedlib.vcxproj**:
   - 修复 Debug|Win32 的 `TargetName` 为 `$(ProjectName)D`（从 `DU` 改为 `D`）
   - 添加所有配置的 `common.props` 导入
   - 添加所有配置的 `sharedlib` 包含路径

3. **audioswitcher.vcxproj**:
   - 修复所有配置的 `common.props` 路径为 `$(SolutionDir)src\Source\common.props`
   - 添加所有配置的 `sharedlib` 包含路径：`$(SolutionDir)src\Source\apps\shared\sharedlib`
   - 添加所有配置的库依赖：
     - Debug|Win32: `dsutilD.lib`, `svplibD.lib`, `sharedlibD.lib`
     - Debug Unicode|Win32: `dsutilDU.lib`, `svplibD.lib`, `sharedlibD.lib`
     - Release|Win32: `dsutilR.lib`, `svplibR.lib`, `sharedlibR.lib`
     - Release Unicode|Win32: `dsutilRU.lib`, `svplibRU.lib`, `sharedlibRU.lib`
   - 修复所有配置的库目录路径为 `$(SolutionDir)src\out\bin\`

**文件**:
- `src/Source/svplib/svplib.vcxproj`
- `src/Source/apps/shared/sharedlib/sharedlib.vcxproj`
- `src/Source/filters/switcher/audioswitcher/audioswitcher_vs2005.vcxproj`

### 2.4 其他编译错误（待处理）

**问题**: 
- `modf` 未解析 - 需要链接数学库
- `av_h264_decode_frame` 未解析 - FFmpeg 相关函数
- `wcscpy` 等函数的安全警告

**解决方案**:
- 添加 `msvcrt.lib` 或 `ucrt.lib` 到链接器依赖
- 检查 FFmpeg 库的链接
- 使用安全函数（`wcscpy_s`）或添加 `_CRT_SECURE_NO_WARNINGS`

## 3. 实施计划

### 阶段 1: 库依赖修复（已完成）

- [x] 修复 `dsutil` 项目配置
- [x] 修复 `asyncreader` 项目配置
- [x] 验证库文件输出路径
- [x] 修复 `svplib` 项目配置
  - [x] 添加 Debug|Win32 的 `common.props` 导入
  - [x] 修复所有配置的库输出路径
  - [x] 修复 `sharedlibDU.lib` 依赖为 `sharedlibD.lib`
- [x] 修复 `sharedlib` 项目配置
  - [x] 修复 Debug|Win32 的 `TargetName`（从 `DU` 改为 `D`）
  - [x] 添加所有配置的 `common.props` 导入
- [x] 修复 `audioswitcher` 项目配置
  - [x] 修复所有配置的 `common.props` 路径为 `$(SolutionDir)src\Source\common.props`
  - [x] 添加所有配置的 `sharedlib` 包含路径
  - [x] 添加所有配置的库依赖（`dsutil`, `svplib`, `sharedlib`）

### 阶段 2: 字符类型统一（待处理）

- [ ] 修复 `TCHAR`/`wchar_t` 混用
- [ ] 统一使用宽字符 API

### 阶段 3: 未解析符号（已完成）

- [x] 检查 `CSVPEqualizer` 链接
  - [x] 修复 `svplib` 项目配置和输出路径
  - [x] 在 `audioswitcher` 中添加 `svplibD.lib` 依赖
- [x] 检查 `Utility` 类链接
  - [x] 修复 `sharedlib` 项目配置和输出路径
  - [x] 在 `audioswitcher` 中添加 `sharedlibD.lib` 依赖
  - [x] 添加 `sharedlib` 包含路径
- [x] 检查 DirectShow 工具函数链接
  - [x] 在 `audioswitcher` 中添加 `dsutilD.lib` 依赖
  - [x] 修复所有配置的库目录路径

### 阶段 4: 其他编译错误（待处理）

- [ ] 修复 `modf` 未解析
- [ ] 修复 `av_h264_decode_frame` 未解析
- [ ] 修复 `wcscpy` 等函数的安全警告

## 4. 验证

修复后应验证：
1. 所有库文件可以正确链接
2. 字符类型错误消失
3. 未解析符号错误消失
4. 其他编译错误消失

## 5. 相关文件

- `src/Source/dsutil/dsutil_vs2005.vcxproj` - dsutil 项目
- `src/Source/filters/reader/asyncreader/asyncreader_vs2005.vcxproj` - asyncreader 项目
- `src/Source/svplib/svplib.vcxproj` - svplib 项目（包含 CSVPEqualizer）
- `src/Source/apps/shared/sharedlib/sharedlib.vcxproj` - sharedlib 项目（包含 Utility）

## 6. 参考

- [RFC-0009: 编译错误修复 - 第二阶段](rfc-0009-compilation-errors-fix-phase2.md)
