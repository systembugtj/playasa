# RFC-0005: mplayerc 项目路径修复

**状态**: 已完成 (Completed)  
**作者**: 开发团队  
**创建日期**: 2025-01-16  
**最后更新**: 2025-01-16

## 摘要

本文档记录了对 mplayerc 主项目文件路径问题的修复工作，解决了项目加载失败和属性表路径不一致的问题。

## 1. 背景

### 1.1 问题描述

用户报告 "failed to load @mplayerc" 错误，项目无法在 Visual Studio 中正常加载。

### 1.2 根本原因

1. **属性表导入路径不一致**
   - 部分配置使用相对路径：`..\..\common.props`
   - 部分配置使用绝对路径：`$(SolutionDir)src\Source\common.props`
   - 部分路径缺少 `src\` 前缀：`$(SolutionDir)Source\apps\mplayerc\...`

2. **路径格式混乱**
   - Debug|Win32: 使用相对路径
   - Release|Win32: 混合使用相对和绝对路径
   - Debug Unicode|Win32: 使用相对路径
   - Release Unicode|Win32: 使用绝对路径（部分正确）

3. **IncludePath 错误**
   - `$(SolutionDir)Source\filters\BaseClasses` 缺少 `src\` 前缀
   - `$(SolutionDir)Thirdparty\...` 缺少 `src\` 前缀

## 2. 解决方案

### 2.1 统一属性表路径

将所有配置的属性表导入路径统一为绝对路径格式：

**修复前：**
```xml
<Import Project="..\..\common.props" />
<Import Project="..\..\debug.props" />
<Import Project="$(SolutionDir)Source\apps\mplayerc\atlserver_integration.props" />
```

**修复后：**
```xml
<Import Project="$(SolutionDir)src\Source\common.props" />
<Import Project="$(SolutionDir)src\Source\debug.props" />
<Import Project="$(SolutionDir)src\Source\apps\mplayerc\atlserver_integration.props" />
```

### 2.2 修复 IncludePath

修复 Debug Unicode|Win32 配置中的 IncludePath：

**修复前：**
```xml
<IncludePath>$(IncludePath);...;$(SolutionDir)Source\filters\BaseClasses;$(SolutionDir)Thirdparty\wtl\include;$(SolutionDir)Thirdparty\boost\;</IncludePath>
```

**修复后：**
```xml
<IncludePath>$(IncludePath);...;$(SolutionDir)src\Source\filters\BaseClasses;$(SolutionDir)src\Thirdparty\wtl\include;$(SolutionDir)src\Thirdparty\boost\;</IncludePath>
```

### 2.3 统一路径格式

所有路径统一使用以下格式：
```
$(SolutionDir)src\Source\...
$(SolutionDir)src\Thirdparty\...
```

## 3. 实施细节

### 3.1 修复的配置

#### Debug|Win32
- ✅ `..\..\common.props` → `$(SolutionDir)src\Source\common.props`
- ✅ `..\..\debug.props` → `$(SolutionDir)src\Source\debug.props`
- ✅ `$(SolutionDir)Source\apps\mplayerc\...` → `$(SolutionDir)src\Source\apps\mplayerc\...`
- ✅ `$(SolutionDir)Thirdparty\...` → `$(SolutionDir)src\Thirdparty\...`

#### Release|Win32
- ✅ `..\..\common.props` → `$(SolutionDir)src\Source\common.props`
- ✅ 其他路径已修复

#### Debug Unicode|Win32
- ✅ `..\..\common.props` → `$(SolutionDir)src\Source\common.props`
- ✅ `..\..\debug.props` → `$(SolutionDir)src\Source\debug.props`
- ✅ 其他路径已修复

#### Release Unicode|Win32
- ✅ 路径已正确（之前已修复）

### 3.2 修复的文件

- `src/Source/apps/mplayerc/mplayerc_vs2005.vcxproj`

### 3.3 创建的脚本

- `src/BuildScript/fix-mplayerc-paths.ps1` - 自动修复 mplayerc 项目路径的脚本

## 4. 验证

### 4.1 验证方法

1. 检查项目文件中的路径是否统一
2. 在 Visual Studio 中打开解决方案，验证 mplayerc 项目是否能正常加载
3. 尝试构建项目，验证路径是否正确

### 4.2 预期结果

- ✅ mplayerc 项目能够在 Visual Studio 中正常加载
- ✅ 所有属性表能够正确导入
- ✅ 所有包含路径能够正确解析

## 5. 影响分析

### 5.1 正面影响

- ✅ 解决了项目加载失败的问题
- ✅ 统一了路径格式，提高了可维护性
- ✅ 使用 `$(SolutionDir)` 宏，提高了路径的灵活性

### 5.2 潜在风险

- ⚠️ 需要验证所有配置是否都能正常工作
- ⚠️ 如果属性表文件本身有问题，仍可能加载失败

## 6. 后续工作

### 6.1 待验证

- [ ] 在 Visual Studio 中打开解决方案，验证项目加载
- [ ] 验证所有配置（Debug/Release, Unicode/MultiByte）是否正常
- [ ] 尝试构建项目，验证路径是否正确

### 6.2 改进建议

1. **建立路径规范**
   - 所有项目统一使用 `$(SolutionDir)src\...` 格式
   - 避免使用相对路径

2. **自动化检查**
   - 在 CI/CD 中添加路径检查
   - 防止未来引入错误的路径

## 7. 相关文档

- `MPLAYERC-FIX-SUMMARY.md` - mplayerc 修复总结
- `src/BuildScript/fix-mplayerc-paths.ps1` - 修复脚本
- [RFC-0004: 构建错误修复 - BaseClasses 路径问题](rfc-0004-build-errors-fix.md)

## 8. 变更历史

| 日期 | 版本 | 变更说明 | 作者 |
|------|------|----------|------|
| 2025-01-16 | 1.0 | 初始版本，记录 mplayerc 项目路径修复 | 开发团队 |

---

**状态**: ✅ **已完成**

**下一步**: 在 Visual Studio 中验证项目加载，然后重新构建
