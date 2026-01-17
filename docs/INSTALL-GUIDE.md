# SPlayer 安装和构建指南

## 一、安装 Visual Studio

### 方法 1: 使用 Visual Studio Installer（推荐）

1. **下载 Visual Studio Installer**
   - 访问: https://visualstudio.microsoft.com/downloads/
   - 下载 Visual Studio 2022 Community（免费）或 Professional/Enterprise

2. **运行安装程序**
   - 启动 Visual Studio Installer
   - 选择 "修改" 或 "安装"

3. **选择工作负载**
   必需组件：
   - ✅ **Desktop development with C++**（桌面开发与 C++）
     - 包含 MFC 和 ATL 支持
     - Windows SDK
     - MSVC 编译器工具集

4. **完成安装**
   - 等待安装完成（可能需要 30-60 分钟）
   - 重启计算机（如提示）

### 方法 2: 使用命令行安装（自动化）

运行项目中的安装脚本：
```powershell
.\install-visual-studio.ps1
```

## 二、验证安装

运行验证脚本：
```powershell
cd src\BuildScript
.\fix-build-issues.ps1
```

应该看到：
```
[OK] Found: VS2022 (v143)
或
[OK] Found: VS2019 (v142)
```

## 三、配置构建环境

### 自动配置（推荐）

```powershell
cd src\BuildScript
.\fix-build-issues.ps1
```

这会自动：
- 创建缺失的 key 文件
- 创建 revision.h
- 创建输出目录
- 检查依赖

### 手动配置

如果需要手动配置，参考 [BUILD-FIXES.md](BUILD-FIXES.md)

## 四、构建项目

### 使用改进的构建脚本（推荐）

```batch
cd src\BuildScript
build-fixed.cmd
```

### 使用原始构建脚本

```batch
cd src\BuildScript
build.cmd
```

## 五、常见问题

### 问题 1: Visual Studio 安装后仍检测不到

**解决方案**:
1. 重启计算机
2. 重新打开命令提示符/PowerShell
3. 检查环境变量：
   ```powershell
   $env:VS160COMNTOOLS  # VS2019
   $env:VS170COMNTOOLS  # VS2022
   ```

### 问题 2: 缺少 MFC 支持

**解决方案**:
1. 打开 Visual Studio Installer
2. 选择 "修改"
3. 在 "Desktop development with C++" 中
4. 确保选中 "MFC and ATL support"

### 问题 3: 构建时找不到 Windows SDK

**解决方案**:
1. 在 Visual Studio Installer 中
2. 选择 "单个组件"
3. 搜索并安装 "Windows 10 SDK" 或 "Windows 11 SDK"

## 六、最小系统要求

- **操作系统**: Windows 7 或更高版本（推荐 Windows 10/11）
- **内存**: 至少 4GB RAM（推荐 8GB+）
- **磁盘空间**: 至少 20GB 可用空间
- **Visual Studio**: 2013 或更高版本（推荐 2019/2022）

## 七、快速开始清单

- [ ] 安装 Visual Studio 2019/2022
- [ ] 选择 "Desktop development with C++" 工作负载
- [ ] 确保包含 MFC 和 ATL 支持
- [ ] 运行 `fix-build-issues.ps1` 修复问题
- [ ] 运行 `build-fixed.cmd` 构建项目

## 相关文档

- [快速修复构建问题](../快速修复构建问题.md)
- [构建修复详细指南](BUILD-FIXES.md)
- [现代化实施计划](../analysis/现代化实施计划.md)
