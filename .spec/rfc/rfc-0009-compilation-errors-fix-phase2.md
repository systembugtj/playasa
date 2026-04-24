# RFC-0009: 编译错误修复 - 第二阶段

**状态**: 进行中 (In Progress)  
**作者**: 开发团队  
**创建日期**: 2025-01-16  
**最后更新**: 2025-01-16

## 摘要

本文档记录第二阶段编译错误的修复工作，包括 DirectX 7、入口点、库依赖、字符类型混用等问题。

## 1. 背景

在第一阶段修复后，仍存在以下编译错误：

### 1.1 主要错误类别

1. **入口点错误**
   - `entry point must be defined` - WavPackSplitter 项目配置错误

2. **DirectX 7 相关错误**
   - `'IDirect3DDevice7': undeclared identifier`
   - `'IDirect3D7': undeclared identifier`
   - `'IDirectDrawSurface7': undeclared identifier`
   - DirectX 7 常量未定义（D3DRENDERSTATE_*, D3DTSS_* 等）

3. **库文件缺失**
   - `cannot open file 'dsutilD.lib'`
   - `cannot open file 'asyncreaderD.lib'`

4. **PTRDIFF_MAX 未定义**
   - 在多个文件中仍然出现

5. **字符类型混用**
   - `TCHAR` 和 `wchar_t` 混用
   - `wcscpy`, `wcscmp` 参数类型不匹配

6. **ATL 相关错误**
   - `CImage::Load` 参数类型不匹配
   - `CStringT` 格式化函数参数类型问题

7. **宏冲突**
   - `snprintf` 宏定义与标准库函数冲突

8. **未解析的外部符号**
   - `CSVPEqualizer` 相关符号
   - `Utility` 类相关符号
   - DirectShow 工具函数

## 2. 解决方案

### 2.1 入口点错误修复

**问题**: WavPackSplitter 在 Debug|Win32 配置中被设置为 `Application`，但没有入口点。

**修复**:
- 将 `ConfigurationType` 从 `Application` 改为 `StaticLibrary`

**文件**: `src/Source/filters/parser/WavPackSplitter/WavPackSplitter.vcxproj`

### 2.2 DirectX 7 头文件修复

**问题**: DirectX 7 接口未定义，因为缺少正确的头文件包含和版本定义。

**修复**:
1. 在 `common.props` 中添加 `$(SolutionDir)src\include\dx` 到包含路径
2. 添加 `DIRECT3D_VERSION=0x0700` 预处理器定义
3. 确保 `DX7SubPic.cpp` 使用系统包含路径（`<ddraw.h>`, `<d3d.h>`）

**文件**:
- `src/Source/common.props`
- `src/Source/subpic/DX7SubPic.cpp`

### 2.3 PTRDIFF_MAX 修复

**问题**: 虽然已添加 `_CRT_STDINT_H`，但 `PTRDIFF_MAX` 仍然未定义。

**修复**:
- 在 `common.props` 中添加 `PTRDIFF_MAX=0x7fffffff` 预处理器定义

**文件**: `src/Source/common.props`

### 2.4 库文件依赖

**问题**: `dsutilD.lib` 和 `asyncreaderD.lib` 找不到。

**原因**: 这些库需要先构建依赖项目。

**解决方案**:
- 确保项目依赖顺序正确
- 检查库文件输出路径是否正确
- 可能需要先单独构建这些库项目

### 2.5 字符类型统一

**问题**: `TCHAR` 和 `wchar_t` 混用导致类型不匹配。

**解决方案**:
- 统一使用 `wchar_t` 和宽字符 API
- 替换 `TCHAR` 为 `wchar_t`
- 使用 `wcscpy_s`, `wcscmp` 等安全函数

### 2.6 ATL CImage::Load 修复

**问题**: `CImage::Load` 参数类型不匹配。

**解决方案**:
- 确保传递 `const wchar_t*` 参数
- 检查 `CImage` 的包含和链接

### 2.7 snprintf 宏冲突

**问题**: 宏定义与标准库函数冲突。

**解决方案**:
- 在包含冲突头文件之前取消宏定义
- 或使用 `#undef snprintf` 后重新定义

## 3. 实施计划

### 阶段 1: 关键错误修复（已完成）

- [x] 修复 WavPackSplitter 入口点错误（改为 StaticLibrary）
- [x] 修复 base.vcxproj 入口点错误（改为 StaticLibrary，添加 common.props）
- [x] 修复 wavpacklib.vcxproj 入口点错误（改为 StaticLibrary，添加 common.props）
- [x] 修复 DirectX 7 头文件包含（mplayerc 和 subpic 项目）
  - [x] mplayerc/stdafx.h - 添加 DirectX 7 头文件
  - [x] mplayerc/DX7AllocatorPresenter.cpp - 添加 DIRECT3D_VERSION 定义
  - [x] mplayerc/mplayerc_vs2005.vcxproj - 所有配置添加 DIRECT3D_VERSION=0x0700
  - [x] subpic/stdafx.h - 添加 DirectX 7 头文件
  - [x] subpic/subpic_vs2005.vcxproj - 修复 common.props 路径和 DirectX 7 定义
- [x] 添加 PTRDIFF_MAX 定义到 common.props
- [x] 修复 SubWCRev 命令错误处理（mplayerc PreBuildEvent）
- [x] 修复 CImage::Load 字符类型问题（ResLoader.cc）
- [x] 修复 snprintf 宏冲突
  - [x] Ap4Config.h - 仅在 MSVC < 1900 时定义 snprintf
  - [x] libavutil/internal.h - 仅在 MSVC < 1900 时定义 snprintf

### 阶段 2: 库依赖修复（已完成）

- [x] 检查并修复 `dsutil` 项目配置
  - [x] 修复所有配置的 `common.props` 路径为 `$(SolutionDir)src\Source\common.props`
  - [x] 修复 Debug|Win32 和 Release|Win32 的输出路径为 `$(OutDir)$(TargetName)$(TargetExt)`
  - [x] 添加 Debug|Win32 的 `TargetName` 为 `$(ProjectName)D`
  - [x] 修复 Release Unicode|Win32 的包含路径和输出路径
- [x] 检查并修复 `asyncreader` 项目配置
  - [x] 添加 Debug|Win32 和 Release|Win32 配置
  - [x] 修复所有配置的 `common.props` 路径为 `$(SolutionDir)src\Source\common.props`
  - [x] 添加 Debug|Win32 的 `TargetName` 为 `$(ProjectName)D`
  - [x] 添加所有配置的 `OutDir` 和 `IntDir` 属性
  - [x] 添加所有配置的 `ItemDefinitionGroup` 和预编译头设置
- [x] 验证库文件输出路径（统一输出到 `$(SolutionDir)src\out\bin\`）

### 阶段 3: 字符类型统一（待处理）

- [ ] 修复 `TCHAR`/`wchar_t` 混用
- [ ] 统一使用宽字符 API

### 阶段 4: ATL 相关问题（待处理）

- [ ] 修复 `CImage::Load` 参数类型
- [ ] 修复 `CStringT` 格式化函数

### 阶段 5: 宏冲突（已完成）

- [x] 修复 `snprintf` 宏冲突（Ap4Config.h 和 libavutil/internal.h）

### 阶段 6: 未解析符号（待处理）

- [ ] 检查 `CSVPEqualizer` 链接
- [ ] 检查 `Utility` 类链接
- [ ] 检查 DirectShow 工具函数链接

## 4. 验证

修复后应验证：
1. 所有 DirectX 7 相关错误消失
2. 入口点错误消失
3. PTRDIFF_MAX 错误消失
4. 库文件可以正确链接

## 5. 相关文件

- `src/Source/common.props` - 通用属性表
- `src/Source/filters/parser/WavPackSplitter/WavPackSplitter.vcxproj` - WavPackSplitter 项目
- `src/Source/subpic/DX7SubPic.cpp` - DirectX 7 子图片实现
- `src/include/dx/d3d.h` - DirectX 7 头文件

## 6. 参考

- [RFC-0008: 编译错误修复 - 第一阶段](rfc-0008-compilation-errors-fix.md)
- [DirectX 7 SDK 文档](https://docs.microsoft.com/en-us/windows/win32/direct3d)
