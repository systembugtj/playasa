# RFC-0010: 全面修复所有编译问题

**状态**: 进行中 (In Progress)  
**作者**: 开发团队  
**创建日期**: 2025-01-16  
**最后更新**: 2025-01-16 (更新：DirectX 7/9 头文件冲突修复)

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

4. **DirectX 7/9 头文件冲突**
   - 全局 `DIRECT3D_VERSION=0x0700` 定义导致 DirectX 9 类型未定义
   - 预编译头中包含 DirectX 7 头文件
   - 多个文件直接包含 `d3d9.h` 但未清除 `DIRECT3D_VERSION`

5. **其他编译错误**
   - `modf` 未解析
   - `av_h264_decode_frame` 未解析
   - `wcscpy` 等函数的安全警告
   - `std::basic_ostream` 未定义（需要包含 `<iostream>`）

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

### 阶段 4: DirectX 7/9 头文件冲突修复（已完成）

- [x] 移除全局 `DIRECT3D_VERSION` 定义
  - [x] 从 `mplayerc_vs2005.vcxproj` 中移除
  - [x] 从 `subpic_vs2005.vcxproj` 中移除
- [x] 清理预编译头
  - [x] 从 `subpic/stdafx.h` 中移除 DirectX 7 头文件
- [x] 局部化 DirectX 7 定义
  - [x] 在 `DX7SubPic.h` 中添加 DirectX 7 头文件
  - [x] 在 `DX7SubPic.cpp` 中局部定义 `DIRECT3D_VERSION`
- [x] 修复所有直接包含 `d3d9.h` 的文件
  - [x] `mplayerc.cpp`
  - [x] `EVRAllocatorPresenter.cpp`
  - [x] `PixelShaderCompiler.h`
  - [x] `GraphCore.h`
  - [x] `IPinHook.cpp`
  - [x] `PPageFileInfoDetails.cpp`
  - [x] `FGManager.cpp`

### 阶段 5: 其他编译错误（待处理）

**问题**: 全局 `DIRECT3D_VERSION=0x0700` 定义导致所有使用 DirectX 9 的文件无法正确识别 DirectX 9 类型，出现 `'virtual' not permitted on data declarations` 和 `identifier 'IDirect3D9'` 等错误。

**修复**:
1. **移除全局 DIRECT3D_VERSION 定义**:
   - `mplayerc_vs2005.vcxproj`: 从 Release 和 Debug 配置中移除 `DIRECT3D_VERSION=0x0700`
   - `subpic_vs2005.vcxproj`: 从所有配置中移除 `DIRECT3D_VERSION=0x0700`

2. **清理预编译头**:
   - `subpic/stdafx.h`: 移除 DirectX 7 头文件包含，添加注释说明如何局部包含

3. **局部化 DirectX 7 定义**:
   - `DX7SubPic.h`: 添加 DirectX 7 头文件包含和 `DIRECT3D_VERSION=0x0700` 定义
   - `DX7SubPic.cpp`: 局部定义 `DIRECT3D_VERSION=0x0700`

4. **修复所有直接包含 d3d9.h 的文件**:
   - `mplayerc.cpp`: 清除 `DIRECT3D_VERSION` 后包含 `d3d9.h`
   - `EVRAllocatorPresenter.cpp`: 清除 `DIRECT3D_VERSION` 后包含 `d3d9.h`
   - `PixelShaderCompiler.h`: 清除 `DIRECT3D_VERSION` 后包含 `d3d9.h`
   - `GraphCore.h`: 清除 `DIRECT3D_VERSION` 后包含 `d3d9.h`
   - `IPinHook.cpp`: 移除重复的 `d3d9.h` 包含（已通过 `DX9AllocatorPresenter.h` 包含）
   - `PPageFileInfoDetails.cpp`: 清除 `DIRECT3D_VERSION` 后包含 `d3d9.h`
   - `FGManager.cpp`: 清除 `DIRECT3D_VERSION` 后包含 `d3d9.h`

**文件**:
- `src/Source/apps/mplayerc/mplayerc_vs2005.vcxproj`
- `src/Source/subpic/subpic_vs2005.vcxproj`
- `src/Source/subpic/stdafx.h`
- `src/Source/subpic/DX7SubPic.h`
- `src/Source/subpic/DX7SubPic.cpp`
- `src/Source/apps/mplayerc/mplayerc.cpp`
- `src/Source/apps/mplayerc/EVRAllocatorPresenter.cpp`
- `src/Source/apps/mplayerc/PixelShaderCompiler.h`
- `src/Source/apps/mplayerc/GraphCore.h`
- `src/Source/apps/mplayerc/IPinHook.cpp`
- `src/Source/apps/mplayerc/PPageFileInfoDetails.cpp`
- `src/Source/apps/mplayerc/FGManager.cpp`

**重要提示**: 修复后需要清理并重新编译预编译头文件。在 Visual Studio 中执行 `Build -> Clean Solution`，然后 `Build -> Rebuild Solution`。

### 阶段 5: 其他编译错误修复（进行中）

#### 5.1 已修复的问题

- [x] **FfmpegCompiler 未定义** - 在 `CompilatorVersion.c` 中添加了 VS 2026 支持
- [x] **Utility.h 路径错误** - 修复了 4 个文件的路径：
  - `RTS.cpp`: `..\apps\shared` → `..\..\apps\shared`
  - `ISubPic.cpp`: `..\apps\shared` → `..\..\apps\shared`
  - `SVPSubFilter.cpp`: `..\apps\shared` → `..\..\..\apps\shared`
  - `BaseVideoFilter.cpp`: `..\apps\shared` → `..\..\..\apps\shared`
- [x] **modf 类型不匹配** - 在 `Subtitle.cpp` 中将 `float n` 改为 `double n`，并使用 `modf((double)t, &n)`
- [x] **jsoncpp 路径错误** - 修复了 `FontParamsManage.cpp` 中的反斜杠问题
- [x] **atlrx.h 路径错误** - 修复了 `ContentType.cc` 中的路径
- [x] **sinet.props 路径错误** - 更新为 `$(SolutionDir)src\Thirdparty\sinet`
- [x] **DirectX 7 IID 未定义** - 在 `DX7SubPic.cpp` 中添加了 `<initguid.h>`
- [x] **unrar.hpp 路径错误** - 修复了 `SubTransFormat.cc` 中的路径
- [x] **std::transform 未定义** - 在 `SubTransFormat.cc` 中添加了 `<algorithm>` 头文件
- [x] **d3dx9.h 找不到** - 创建了 `d3dx9_compat.h` 兼容头文件，提供 `D3DXCOLOR`、`D3DXVECTOR2` 等类型定义
- [x] **pool.h 找不到** - 在 `common.props` 中添加了 `$(SolutionDir)src\Thirdparty\sinet` 到包含路径

#### 5.2 待处理的问题

- [ ] 修复 `av_h264_decode_frame` 未解析
- [ ] 修复 `wcscpy` 等函数的安全警告
- [ ] 修复 `std::basic_ostream` 未定义（需要包含 `<iostream>`）
- [ ] 修复 `boost/filesystem.hpp` 找不到
- [ ] 修复 `pcid/pcid/PCIDCalculator.h` 路径错误
- [ ] 修复大量 TCHAR/wchar_t 混用错误

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
