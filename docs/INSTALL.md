# 安装与首次构建准备

本项目是 Windows 桌面程序，主入口为 `src\splayer.sln`。推荐使用 Visual Studio 2022/2026 系列工具链；实际工具集以 `.vcxproj` 中的 `PlatformToolset` 为准。

## 必需组件

安装 Visual Studio 或 Build Tools 时至少选择：

1. `Desktop development with C++`
2. MSVC C++ 编译工具集
3. Windows 10/11 SDK
4. MFC and ATL support

如果只需要命令行构建，可以安装 Visual Studio Build Tools，但仍必须包含 C++、Windows SDK 和 MFC/ATL。

## 推荐安装方式

从仓库根目录运行：

```powershell
.\script\install-visual-studio.ps1
```

如果使用 Visual Studio Installer 手动安装，请在“单个组件”中搜索并勾选与当前工具集匹配的 MFC/ATL 支持。例如项目使用 v145 时，需要安装 v145 对应的 MFC/ATL 组件；兼容旧配置时可同时安装 v143/v142。

## 验证安装

```powershell
cd src\BuildScript
.\detect-vs2026.ps1
.\find-msbuild.ps1
```

检测脚本应能找到 MSBuild、Windows SDK 和对应工具集。若 PowerShell 中文或 UTF-8 输出异常，先按 [POWERSHELL.md](POWERSHELL.md) 配置控制台编码。

## 首次构建

```batch
cd src\BuildScript
build-with-msbuild.cmd
```

备用入口：

```batch
cd src\BuildScript
build-fixed.cmd
```

构建输出应落在仓库根 `out\` 下；目录契约见 [PROJECT-STRUCTURE.md](PROJECT-STRUCTURE.md) 与 RFC-0011。

## 常见安装问题

### 缺少 MFC

错误通常类似：

```text
MSB8041: MFC libraries are required for this project.
```

处理步骤：

1. 打开 Visual Studio Installer。
2. 选择当前安装实例并点击“修改”。
3. 在“单个组件”中搜索 `MFC`。
4. 安装与当前工具集匹配的 `MFC and ATL support`。
5. 重启终端后重新运行构建。

### 找不到 Windows SDK

在 Visual Studio Installer 的“单个组件”中安装 Windows 10 SDK 或 Windows 11 SDK，然后重新打开终端。

### 找不到 Visual Studio

优先运行：

```powershell
cd src\BuildScript
.\find-msbuild.ps1
```

如果脚本找不到 MSBuild，说明 Visual Studio/Build Tools 未安装完整，或当前终端没有刷新环境变量。

## 相关文档

- [BUILD.md](BUILD.md)：构建命令和排障。
- [PROJECT-STRUCTURE.md](PROJECT-STRUCTURE.md)：仓库布局和输出路径。
- [POWERSHELL.md](POWERSHELL.md)：PowerShell UTF-8 / 中文环境。
