# RFC-0008: 编译错误修复

**状态**: 进行中 (In Progress)  
**作者**: 开发团队  
**创建日期**: 2025-01-16  
**最后更新**: 2025-01-16

## 摘要

本文档记录了对编译过程中出现的多个错误的修复工作，包括头文件缺失、API 调用错误、输出文件名不匹配和汇编代码兼容性问题。

## 1. 背景

### 1.1 问题描述

编译过程中出现以下错误：

1. **Strings.h 缺少 `<string>` 头文件**
   - 错误: `'wstring': is not a member of 'std'`
   - 影响: base/Strings 项目

2. **logging.cc API 调用错误**
   - 错误: `cannot convert argument 2 from 'wchar_t [260]' to 'LPSTR'`
   - 影响: base/logging.cc

3. **WavPackDSDecoder 缺少 BaseClasses 路径**
   - 错误: `Cannot open include file: 'streams.h'`
   - 影响: WavPackDSDecoder 项目

4. **id3lib 输出文件名不匹配**
   - 警告: `TargetPath does not match the Library's OutputFile property value`
   - 影响: id3lib 项目

5. **libmpeg2 MMX 汇编代码不兼容**
   - 错误: `'__asm__': undeclared identifier`
   - 影响: libmpeg2 项目（motion_comp_mmx.c, idct_mmx.c, cpu_accel.c）

6. **sqlitepp PTRDIFF_MAX 未定义**
   - 错误: `'PTRDIFF_MAX': undeclared identifier`
   - 影响: sqlitepp 项目

## 2. 解决方案

### 2.1 修复 Strings.h

**问题**: 缺少 `<string>` 头文件

**修复**:
```cpp
#include <vector>
#include <string>  // 添加此行
```

### 2.2 修复 logging.cc

**问题**: 使用了错误的 API（GetModuleFileNameA vs GetModuleFileNameW）

**修复**:
```cpp
// 修复前
GetModuleFileName(NULL, buff, MAX_PATH);

// 修复后
GetModuleFileNameW(NULL, buff, MAX_PATH);
```

### 2.3 修复 WavPackDSDecoder

**问题**: 缺少 BaseClasses 包含路径

**修复**: 在 Debug|Win32 配置中添加 BaseClasses 路径
```xml
<AdditionalIncludeDirectories>$(SolutionDir)src\Source\filters\BaseClasses;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
```

### 2.4 修复 id3lib

**问题**: TargetName 和 OutputFile 不匹配

**修复**: 在 Debug|Win32 配置中添加 TargetName
```xml
<TargetName>id3libD</TargetName>
```

### 2.5 处理 libmpeg2 MMX 汇编

**问题**: GCC 内联汇编语法，MSVC 不支持

**解决方案选项**:
1. **排除 MMX 文件**（推荐）- 从项目中排除这些文件
2. **条件编译** - 使用预处理器宏禁用 MMX 代码
3. **重写汇编** - 使用 MSVC 内联汇编语法重写（工作量大）

**推荐方案**: 从 Debug 配置中排除 MMX 文件，因为这些是性能优化代码，不是必需的。

### 2.6 处理 sqlitepp PTRDIFF_MAX

**问题**: 标准库头文件缺少 PTRDIFF_MAX 定义

**解决方案**: 在编译选项中添加 `<cstddef>` 或定义 `_CRT_STDINT_H`

## 3. 实施细节

### 3.1 修复的文件

- ✅ `src/Source/base/Strings.h` - 添加 `<string>` 头文件
- ✅ `src/Source/base/logging.cc` - 修复 API 调用
- ✅ `src/Source/filters/transform/WavPackDecoder/WavPackDecoder.vcxproj` - 添加 BaseClasses 路径
- ✅ `src/lib/id3lib/libprj/id3lib.vcxproj` - 添加 TargetName

### 3.2 待处理的文件

- ⏳ `src/Source/filters/transform/mpeg2decfilter/libmpeg2/vc++/libmpeg2.vcxproj` - 排除 MMX 文件
- ⏳ `src/Thirdparty/sqlitepp.vcxproj` - 添加 PTRDIFF_MAX 定义

## 4. 验证

### 4.1 验证方法

1. 重新编译项目
2. 检查错误是否消失
3. 验证功能是否正常

### 4.2 预期结果

- ✅ Strings.h 错误消失
- ✅ logging.cc 错误消失
- ✅ WavPackDSDecoder 错误消失
- ✅ id3lib 警告消失
- ⏳ libmpeg2 错误消失（需要排除 MMX 文件）
- ⏳ sqlitepp 错误消失（需要添加定义）

## 5. 影响分析

### 5.1 正面影响

- ✅ 修复编译错误，提高构建成功率
- ✅ 消除警告，提高代码质量

### 5.2 潜在风险

- ⚠️ 排除 MMX 文件可能影响性能（但功能不受影响）
- ⚠️ 需要测试确保功能正常

## 6. 相关文档

- [RFC-0007: 构建警告和错误修复](./rfc-0007-build-warnings-fix.md)

## 7. 变更历史

| 日期 | 版本 | 变更说明 | 作者 |
|------|------|----------|------|
| 2025-01-16 | 1.0 | 初始版本，记录编译错误修复 | 开发团队 |

---

**状态**: 🔄 **进行中**

**下一步**: 
1. 从 libmpeg2 项目中排除 MMX 文件
2. 修复 sqlitepp PTRDIFF_MAX 问题
3. 重新编译验证
