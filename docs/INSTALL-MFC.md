# 安装 MFC 支持

## 问题

构建时出现错误：
```
MSB8041: MFC libraries are required for this project.
```

## 解决方案

### 方法 1: 使用 Visual Studio Installer（推荐）

1. **打开 Visual Studio Installer**
   - 在开始菜单搜索 "Visual Studio Installer"
   - 或运行：`C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe`

2. **修改 Visual Studio 2026**
   - 找到 Visual Studio 2026
   - 点击 "修改"

3. **安装 MFC 组件**
   - 选择 "单个组件" 标签
   - 搜索 "MFC"
   - 勾选以下组件：
     - ✅ **MFC 和 ATL 支持 (v145)** - 用于 v145 工具集
     - ✅ **MFC 和 ATL 支持 (v143)** - 用于 v143 工具集（可选）
     - ✅ **MFC 和 ATL 支持 (v142)** - 用于 v142 工具集（可选）

4. **安装**
   - 点击 "修改"
   - 等待安装完成
   - 重启计算机（如提示）

### 方法 2: 使用命令行

```powershell
# 找到 Visual Studio Installer
$installer = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe"

# 安装 MFC 组件（需要手动确认）
& $installer modify --installPath "C:\Program Files\Microsoft Visual Studio\18\Community" --add Microsoft.VisualStudio.Component.VC.ATLMFC --quiet
```

## 验证安装

安装完成后，重新运行构建：

```batch
cd src\BuildScript
build-with-msbuild.cmd
```

## 如果仍然失败

1. **检查工具集版本**
   - 确保安装的 MFC 版本与项目使用的工具集匹配
   - 项目使用 v145，需要安装 "MFC 和 ATL 支持 (v145)"

2. **重新启动**
   - 重启 Visual Studio（如果打开）
   - 重启计算机（推荐）

3. **检查安装路径**
   - MFC 库应位于：
     ```
     C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.50.xxxxx\atlmfc\
     ```

## 相关文档

- [构建修复指南](BUILD-FIXES.md)
- [构建状态报告](BUILD-STATUS.md)
