# 构建错误修复总结

## 问题描述

构建时出现以下错误：
- `cannot open source file "streams.h"`
- `identifier "CMediaType" is undefined`
- `identifier "CUnknown" is undefined`
- `identifier "CBaseFilter" is undefined`
- `identifier "CBasePin" is undefined`
- `identifier "CAutoLock" is undefined`
- `identifier "CheckPointer" is undefined`

这些错误表明 DirectShow BaseClasses 的头文件路径不正确。

## 修复内容

### 1. 修复 common.props

在 `src/Source/common.props` 中添加了 BaseClasses 包含路径：

```xml
<AdditionalIncludeDirectories>$(SolutionDir)src\include\;$(SolutionDir)src\Source\base;$(SolutionDir)src\Source\filters\BaseClasses;$(SolutionDir)src\Thirdparty\sqlitepp;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
```

### 2. 修复项目文件中的 BaseClasses 路径

使用脚本 `fix-baseclasses-paths.ps1` 自动修复了 50 个项目文件中的错误路径：

**修复的路径模式：**
- `..\..\..\..\src\filters\BaseClasses` → `$(SolutionDir)src\Source\filters\BaseClasses`
- `..\..\BaseClasses` → `$(SolutionDir)src\Source\filters\BaseClasses`
- `..\..\..\BaseClasses` → `$(SolutionDir)src\Source\filters\BaseClasses`
- `..\BaseClasses` → `$(SolutionDir)src\Source\filters\BaseClasses`
- `$(SolutionDir)Source\filters\BaseClasses` → `$(SolutionDir)src\Source\filters\BaseClasses`

**修复的项目（50个）：**
- decss, dsutil
- 所有 filters 子项目（parser, muxer, transform, source, reader, renderer 等）
- subpic, subtitles, libssf
- 等等

### 3. 修复 BaseMuxer 项目

手动修复了 `BaseMuxer_vs2005.vcxproj` 中的包含路径。

## 验证

所有项目现在应该能够正确找到 `streams.h` 和其他 BaseClasses 头文件。

## 下一步

1. ✅ BaseClasses 路径已修复
2. ⚠️ 需要重新构建以验证修复
3. ⚠️ 如果仍有错误，可能需要先构建 BaseClasses 项目

## 相关文件

- `src/Source/common.props` - 通用属性表（已更新）
- `src/BuildScript/fix-baseclasses-paths.ps1` - 自动修复脚本
- `src/Source/filters/BaseClasses/` - BaseClasses 源代码目录

---

**状态**: ✅ **BaseClasses 路径问题已修复**

**建议**: 重新构建项目以验证修复是否成功。
