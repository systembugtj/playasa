# 构建修复总结

> 本文档自 **`src/BuildScript/BUILD-FIXES-SUMMARY.md`** 迁入此处（2026-04），与脚本目录解耦。  
> **输出目录（OutDir/IntDir）现行契约** 以 **[.spec/rfc/rfc-0011-windows-repository-layout.md](../../.spec/rfc/rfc-0011-windows-repository-layout.md)** 与 **`src/Source/common.props`** 为准；维护脚本为 **`src/BuildScript/fix-output-directories-rfc0011.ps1`**。

## 已修复的问题

### 1. mplayerc 项目路径问题 ✅
- 修复了属性表导入路径不一致的问题
- 统一使用 `$(SolutionDir)src\Source\...` 格式

### 2. BaseClasses 包含路径问题 ✅
- 在 `common.props` 中添加了 BaseClasses 路径
- 修复了 50 个项目文件中的错误 BaseClasses 路径
- 统一使用 `$(SolutionDir)src\Source\filters\BaseClasses`

## 修复脚本

- `fix-mplayerc-paths.ps1` - 修复 mplayerc 项目路径
- `fix-baseclasses-paths.ps1` - 修复所有项目的 BaseClasses 路径

## 下一步

重新构建项目以验证修复。
