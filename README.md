# SPlayer (Playasa)

这是一个基于 Media Player Classic 的 Windows 媒体播放器项目。

## 项目状态

- **当前版本**: 基于 Visual Studio 2013 (v120)
- **平台**: Windows (Win32)
- **架构**: DirectShow + MFC
- **许可证**: GNU General Public License v2

## 快速开始

### 使用 Visual Studio 2026（推荐）

项目已升级支持 Visual Studio 2026！

1. **升级项目**（已完成）:
   - ✅ 95 个项目文件已升级到 v144 工具集
   - ✅ 解决方案文件已移动到根目录
   - ✅ Windows SDK 已更新

2. **安装 Visual Studio 2026**:
   ```powershell
   .\install-visual-studio.ps1
   ```
   或查看 [VS2026 快速开始.md](VS2026-快速开始.md)

3. **验证安装**:
   ```powershell
   cd src\BuildScript
   .\detect-vs2026.ps1
   ```

4. **构建项目**:
   ```batch
   build-with-msbuild.cmd    # 推荐：使用 MSBuild
   # 或
   build-fixed.cmd           # 使用 Visual Studio
   ```

**项目已准备好构建！** 查看 [BUILD-READY.md](BUILD-READY.md) 了解当前状态。

### 使用其他 Visual Studio 版本

项目也支持 VS2013-2025，但推荐使用 VS2026。

**详细指南**: 
- [VS2026 快速开始](VS2026-快速开始.md) ⭐ 推荐
- [快速开始.md](快速开始.md)
- [安装指南](docs/INSTALL-GUIDE.md)

### 编译要求

- Visual Studio 2013 或更高版本（推荐 2019/2022）
- Windows SDK 7.1+
- DirectShow SDK
- MFC 库（包含在 Visual Studio 中）

**遇到构建问题？** 查看 [快速修复构建问题.md](快速修复构建问题.md) 或 [详细构建修复指南](docs/BUILD-FIXES.md)

### 依赖项

项目需要以下依赖库（需要先编译）:
- `thirdparty/pkg/trunk/sphash`
- `thirdparty/sinet/trunk/sinet`
- `thirdparty/pkg/trunk/unrar`

## 项目结构

```
src/
├── Source/          # 主要源代码
│   ├── apps/       # 应用程序
│   ├── filters/    # DirectShow 过滤器
│   ├── ui/         # UI 组件
│   └── ...
├── Thirdparty/     # 第三方库
├── lib/            # 预编译库
└── BuildScript/    # 构建脚本
```

## 现代化计划

项目正在进行现代化改进，详见:
- [编译与现代化分析.md](docs/analysis/编译与现代化分析.md) - 详细的技术分析
- [现代化实施计划.md](docs/analysis/现代化实施计划.md) - 具体的实施计划
- [RFC-0001: 现代化提案](docs/rfc/rfc-0001-modernization-proposal.md) - 正式的技术提案

### 主要改进方向

1. **编译环境升级**: Visual Studio 2013 → 2019/2022
2. **代码现代化**: 引入现代 C++ 特性 (C++11/14/17)
3. **UI 现代化**: 考虑迁移到 Qt 或 WinUI 3
4. **架构改进**: 模块化设计，分离关注点

## 相关链接

- 原始项目: http://hg.splayer.org/splayer

## 工具和脚本

- **检查编译环境**: 运行 `检查编译环境.bat` 检查编译环境
- **修复构建问题**: 运行 `src\BuildScript\fix-build-issues.ps1` 自动修复常见问题
- **改进的构建脚本**: 使用 `src\BuildScript\build-fixed.cmd` 支持多个 Visual Studio 版本
- **PowerShell 中文支持**: 运行 `安装PowerShell中文支持-全局.bat` 配置全局中文支持