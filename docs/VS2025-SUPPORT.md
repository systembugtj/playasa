# Visual Studio 2025 支持指南

## ✅ 已完成的升级

项目已成功升级以支持 Visual Studio 2025！

### 升级内容

- ✅ **95 个项目文件**已升级到 v144 工具集
- ✅ **解决方案文件**已更新到 Visual Studio 2025 格式
- ✅ **Windows SDK**已更新到 Windows 10/11
- ✅ **构建脚本**已支持 VS2025 自动检测

### 备份文件

所有原始文件已备份，扩展名为 `.backup`：
- `*.vcxproj.backup` - 项目文件备份
- `splayer.sln.backup` - 解决方案文件备份
- `common.props.backup` - 属性文件备份

## 使用 Visual Studio 2025 构建

### 方法 1: 使用改进的构建脚本（推荐）

```batch
cd src\BuildScript
build-fixed.cmd
```

脚本会自动检测并使用 VS2025。

### 方法 2: 在 Visual Studio 中打开

1. **打开解决方案**:
   ```
   双击 src\splayer.sln
   ```

2. **重定向项目**（首次打开时）:
   - Visual Studio 会提示重定向项目
   - 点击 "确定" 或 "重定向"
   - 选择 Windows SDK 版本（推荐 10.0 或 11.0）

3. **构建**:
   - 选择配置: "Release Unicode"
   - 选择平台: "Win32" 或 "x64"
   - 生成 → 生成解决方案 (F7)

## 可能需要的额外配置

### 1. 更新 Windows SDK 版本

如果构建时提示找不到 Windows SDK：

1. 在 Visual Studio 中
2. 项目 → 属性 → 常规
3. Windows SDK 版本 → 选择已安装的版本（10.0 或 11.0）

### 2. 处理编译警告

VS2025 可能产生新的编译警告：

1. 查看输出窗口的警告信息
2. 逐步修复警告
3. 或暂时禁用特定警告（不推荐）

### 3. 更新第三方库

某些第三方库可能需要更新以支持 VS2025：

- 如果遇到链接错误，可能需要重新编译第三方库
- 或使用预编译的库文件

## 验证安装

运行验证脚本：

```powershell
cd src\BuildScript
.\fix-build-issues.ps1
```

应该看到：
```
[OK] Found: VS2025 (v144)
```

## 常见问题

### Q: 构建时提示 "找不到工具集 v144"

**解决方案**:
1. 确保 Visual Studio 2025 已完全安装
2. 在 Visual Studio Installer 中检查 "Desktop development with C++" 是否已安装
3. 重启计算机

### Q: 项目无法打开

**解决方案**:
1. 确保使用 Visual Studio 2025 打开
2. 如果提示升级，选择 "是"
3. 如果仍有问题，从备份恢复并手动升级

### Q: 编译错误：C++ 标准不支持

**解决方案**:
1. 项目属性 → C/C++ → 语言
2. C++ 语言标准 → 选择 "ISO C++14" 或 "ISO C++17"

### Q: MFC 相关错误

**解决方案**:
1. 确保在 Visual Studio Installer 中安装了 "MFC and ATL support"
2. 项目属性 → 常规 → 使用 MFC → 选择 "在静态库中使用 MFC"

## 回退到旧版本

如果需要回退到 Visual Studio 2013：

1. **恢复备份文件**:
   ```powershell
   Get-ChildItem -Path src -Filter "*.backup" -Recurse | ForEach-Object {
       $original = $_.FullName -replace '\.backup$', ''
       Copy-Item $_.FullName $original -Force
   }
   ```

2. **使用原始构建脚本**:
   ```batch
   cd src\BuildScript
   build.cmd
   ```

## 下一步

1. ✅ 项目已升级到 VS2025
2. ⏳ 安装 Visual Studio 2025（如果尚未安装）
3. ⏳ 运行 `fix-build-issues.ps1` 验证环境
4. ⏳ 尝试构建项目
5. ⏳ 修复任何编译错误

## 相关文档

- [快速开始](../快速开始.md)
- [构建修复指南](BUILD-FIXES.md)
- [安装指南](INSTALL-GUIDE.md)
