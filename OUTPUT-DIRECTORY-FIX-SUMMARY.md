# 输出目录修复总结

## 问题

项目输出文件分散在多个位置：
- 根目录 `bin/debug-utf16/`
- 根目录 `Debug/` (包含 .pdb, .dll, .lib 文件)
- 预期位置 `src/out/bin/` (但很多项目没有使用)

## 原因

虽然 `common.props` 中设置了正确的输出路径 `$(SolutionDir)src\out\bin`，但许多项目文件在 PropertyGroup 中覆盖了这个设置，使用了错误的路径：
- `$(SolutionDir)\out\bin\` (缺少 `src\`)
- `$(SolutionDir)$(Configuration)\` (使用配置名称，如 Debug)
- `$(SolutionDir)out\bin\` (缺少 `src\`)

## 修复

### 修复统计

- ✅ **修复的项目文件**: 95 个
- ✅ **修复的路径模式**: 7 种不同的错误格式
- ✅ **统一的目标路径**:
  - `OutDir: $(SolutionDir)src\out\bin`
  - `IntDir: $(SolutionDir)src\out\obj\$(ProjectName)`

### 修复的路径模式

1. `$(SolutionDir)\out\bin\` → `$(SolutionDir)src\out\bin`
2. `$(SolutionDir)out\bin\` → `$(SolutionDir)src\out\bin`
3. `$(SolutionDir)$(Configuration)\` → `$(SolutionDir)src\out\bin`
4. `$(SolutionDir)out\lib\$(Platform)\` → `$(SolutionDir)src\out\bin`
5. `$(SolutionDir)\out\obj\$(ProjectName)\` → `$(SolutionDir)src\out\obj\$(ProjectName)`
6. `$(SolutionDir)out\obj\$(ProjectName)\` → `$(SolutionDir)src\out\obj\$(ProjectName)`
7. `$(Configuration)\` → `$(SolutionDir)src\out\obj\$(ProjectName)`

## 下一步

1. ✅ 所有项目文件已修复
2. ⚠️ **清理旧输出目录** (bin/, Debug/, 等)
3. ⚠️ **重新构建项目**，验证输出到 `src\out\bin\`
4. ⚠️ **更新 .gitignore**，确保忽略正确的输出目录

## 相关文档

- [RFC-0006: 输出目录统一化](docs/rfc/rfc-0006-output-directory-consolidation.md)
- `src/BuildScript/fix-output-directories.ps1` - 修复脚本

---

**状态**: ✅ **修复完成**

**注意**: 请清理根目录的旧输出文件夹，然后重新构建验证。
