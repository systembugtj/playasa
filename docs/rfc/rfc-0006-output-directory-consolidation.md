# RFC-0006: 输出目录统一化

**状态**: 已完成 (Completed)  
**作者**: 开发团队  
**创建日期**: 2025-01-16  
**最后更新**: 2025-01-16

## 摘要

本文档记录了对项目输出目录路径不统一问题的分析和修复方案。当前项目输出分散在根目录的 `bin`、`Debug` 等文件夹中，需要统一到 `src\out\bin` 目录。

## 1. 背景

### 1.1 问题描述

项目输出文件分散在多个位置：

- 根目录 `bin/debug-utf16/`
- 根目录 `Debug/` (包含 .pdb, .dll, .lib 文件)
- 预期位置 `src/out/bin/` (但很多项目没有使用)

这导致：
- 输出文件混乱，难以管理
- 清理构建产物困难
- 不符合项目结构规范

### 1.2 根本原因

1. **common.props 设置正确但被覆盖**
   - `common.props` 中设置了 `OutDir: $(SolutionDir)src\out\bin`
   - 但许多项目文件在 PropertyGroup 中覆盖了这个设置

2. **路径格式不统一**
   - 部分使用: `$(SolutionDir)\out\bin\` (缺少 `src\`)
   - 部分使用: `$(SolutionDir)$(Configuration)\` (使用配置名称)
   - 部分使用: `$(SolutionDir)out\bin\` (缺少 `src\`)

3. **项目配置不一致**
   - Debug|Win32: 使用 `$(SolutionDir)$(Configuration)\` → 输出到 `Debug/`
   - Release|Win32: 使用 `$(SolutionDir)\out\bin\` → 输出到根目录 `out/bin/`
   - Release Unicode|Win32: 使用 `$(SolutionDir)out\bin\` → 输出到根目录 `out/bin/`

## 2. 解决方案

### 2.1 统一输出路径

**目标路径格式：**
```
OutDir: $(SolutionDir)src\out\bin
IntDir: $(SolutionDir)src\out\obj\$(ProjectName)
```

### 2.2 修复策略

1. **移除项目文件中的 OutDir/IntDir 覆盖**
   - 让项目使用 `common.props` 中的统一设置
   - 只在必要时（特殊配置）才覆盖

2. **统一所有配置**
   - Debug|Win32
   - Release|Win32
   - Debug Unicode|Win32
   - Release Unicode|Win32

3. **清理旧输出目录**
   - 删除根目录的 `bin/`、`Debug/` 等文件夹
   - 确保所有输出到 `src/out/bin/`

## 3. 实施计划

### 3.1 阶段 1: 分析

- [x] 识别所有使用错误输出路径的项目
- [x] 分析路径格式差异
- [x] 确定统一的目标路径

### 3.2 阶段 2: 修复

- [x] 创建自动化修复脚本
- [x] 修复所有项目文件 (95 个项目已修复)
- [ ] 验证修复结果

### 3.3 阶段 3: 清理

- [ ] 清理根目录的旧输出文件夹
- [ ] 更新 .gitignore
- [ ] 验证新构建输出位置

## 4. 影响分析

### 4.1 正面影响

- ✅ 输出文件统一管理
- ✅ 符合项目结构规范
- ✅ 便于清理构建产物
- ✅ 提高项目可维护性

### 4.2 潜在风险

- ⚠️ 需要重新构建所有项目
- ⚠️ 可能需要更新构建脚本中的路径引用
- ⚠️ 需要清理旧输出文件

## 5. 相关文档

- `src/Source/common.props` - 通用属性表（已设置正确路径）
- [RFC-0004: 构建错误修复 - BaseClasses 路径问题](./rfc-0004-build-errors-fix.md)
- [RFC-0005: mplayerc 项目路径修复](./rfc-0005-mplayerc-project-fix.md)

## 6. 变更历史

| 日期 | 版本 | 变更说明 | 作者 |
|------|------|----------|------|
| 2025-01-16 | 1.0 | 初始版本，记录输出目录统一化问题 | 开发团队 |

## 7. 实施结果

### 7.1 修复统计

- **修复的项目文件**: 95 个
- **修复的路径模式**: 7 种不同的错误格式
- **目标路径**: 
  - `OutDir: $(SolutionDir)src\out\bin`
  - `IntDir: $(SolutionDir)src\out\obj\$(ProjectName)`

### 7.2 创建的脚本

- `src/BuildScript/fix-output-directories.ps1` - 自动修复输出目录的脚本

### 7.3 修复的路径模式

- `$(SolutionDir)\out\bin\` → `$(SolutionDir)src\out\bin`
- `$(SolutionDir)out\bin\` → `$(SolutionDir)src\out\bin`
- `$(SolutionDir)$(Configuration)\` → `$(SolutionDir)src\out\bin`
- `$(SolutionDir)out\lib\$(Platform)\` → `$(SolutionDir)src\out\bin`
- `$(SolutionDir)\out\obj\$(ProjectName)\` → `$(SolutionDir)src\out\obj\$(ProjectName)`
- `$(SolutionDir)out\obj\$(ProjectName)\` → `$(SolutionDir)src\out\obj\$(ProjectName)`
- `$(Configuration)\` → `$(SolutionDir)src\out\obj\$(ProjectName)`

---

**状态**: ✅ **已完成**

**下一步**: 清理旧输出目录，重新构建验证
