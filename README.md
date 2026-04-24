# SPlayer (Playasa)

这是一个基于 Media Player Classic 的 Windows 媒体播放器项目。

**仓库布局与 MSBuild 路径契约**（目录、`src\splayer.sln`、`out\` 等）以 [.spec/rfc/rfc-0011-windows-repository-layout.md](.spec/rfc/rfc-0011-windows-repository-layout.md) 为准。

**原根目录下的安装/构建类 Markdown 与构建日志** 已迁入 [`docs/root-notes/`](docs/root-notes/README.md)，便于与 RFC、安装指南等统一查阅。

**仓库根**仅保留元数据、文档与入口脚本（如 `script\`）；**勿**在根目录堆积 `lang\`、`lib\`、`Release\` 等生成物或随机构建目录（应落在 **`out\`** 或 **`src\lib\`**，见 RFC-0011 §3.5–3.6）。若本地曾误生成，可直接删除；对应路径已在 `.gitignore` 中忽略。

## 项目状态

- **当前工具链**: Visual Studio 2022 / 2026 系；工程以 **Platform Toolset v145** 为主（以 `src\**\*.vcxproj` 为准）
- **平台**: Windows (Win32)
- **架构**: DirectShow + MFC
- **许可证**: GNU General Public License v2
- **依赖升级**: 见 [.spec/rfc/rfc-0012-thirdparty-library-upgrades.md](.spec/rfc/rfc-0012-thirdparty-library-upgrades.md)（分阶段；非单次「全库换最新」）

## 快速开始

### 使用 Visual Studio 2026（推荐）

项目已升级支持 Visual Studio 2026！

1. **升级项目**（已完成）:
   - ✅ 95 个项目文件已升级到 v144 工具集
   - ✅ 解决方案文件位于 `src\splayer.sln`
   - ✅ Windows SDK 已更新

2. **安装 Visual Studio 2026**:
   ```powershell
   .\script\install-visual-studio.ps1
   ```
   或查看 [VS2026 升级说明](docs/root-notes/VS2026-UPDATE.md)

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

**项目已准备好构建！** 查看 [BUILD-READY.md](docs/root-notes/BUILD-READY.md) 了解当前状态。

### 使用其他 Visual Studio 版本

项目也支持 VS2013-2025，但推荐使用 VS2026。

**详细指南**:
- [VS2026 升级与构建](docs/root-notes/VS2026-UPDATE.md)（推荐）
- [VS2025 快速开始](docs/root-notes/VS2025-快速开始.md)
- [快速开始](docs/root-notes/快速开始.md)
- [安装指南](docs/INSTALL-GUIDE.md)

### 编译要求

- Visual Studio 2013 或更高版本（推荐 2019/2022）
- Windows SDK 7.1+
- DirectShow SDK
- MFC 库（包含在 Visual Studio 中）

**遇到构建问题？** 查看 [快速修复构建问题](docs/root-notes/快速修复构建问题.md) 或 [详细构建修复指南](docs/BUILD-FIXES.md)

### 依赖项

主要依赖以 **源码或头文件** 形式位于本仓（由 `src\splayer.sln` 统一构建），包括但不限于：

- **`src/Thirdparty/pkg`**：与 `sphash` / `unrar` 等相关的头文件与 stub（非旧文档中的 `trunk` 外置树）
- **`src/Thirdparty/sinet`**：网络相关头文件
- **`src/Thirdparty/unrar`**、**`sqlitepp`**、**`jsoncpp`**、**`zeromq`**、**`yaml-cpp`** 等：见各子目录与对应 `.vcxproj`
- **`src/Source/zlib`**、**`src/Source/libpng`**：随主解决方案编译的静态库（当前 zlib 版本见该目录下 `zlib.h`）

具体升级顺序与风险见 **[RFC-0012](.spec/rfc/rfc-0012-thirdparty-library-upgrades.md)**。

## 项目结构

```
（仓库根）
├── out/            # MSBuild 生成树（默认 gitignore；契约见 RFC-0011）
├── docs/           # 叙述性文档与历史 RFC
├── script/         # 机台安装 / bootstrap（如 install-visual-studio.ps1）
├── src/            # 源码、解决方案与 BuildScript
└── .spec/          # 契约类 RFC

src/
├── Source/          # 主要源代码
│   ├── apps/       # 应用程序
│   ├── filters/    # DirectShow 过滤器
│   ├── ui/         # UI 组件
│   └── ...
├── Thirdparty/     # 第三方库
├── lib/            # 随仓预编译库（与根目录误放的 lib\ 不同）
└── BuildScript/    # 构建与诊断脚本
```

## 现代化计划

项目正在进行现代化改进，详见:
- [编译与现代化分析.md](docs/analysis/编译与现代化分析.md) - 详细的技术分析
- [现代化实施计划.md](docs/analysis/现代化实施计划.md) - 具体的实施计划
- [RFC-0001: 现代化提案](.spec/rfc/rfc-0001-modernization-proposal.md) - 正式的技术提案

### 主要改进方向

1. **编译环境升级**: Visual Studio 2013 → 2019/2022
2. **代码现代化**: 引入现代 C++ 特性 (C++11/14/17)
3. **UI 现代化**: 考虑迁移到 Qt 或 WinUI 3
4. **架构改进**: 模块化设计，分离关注点

## 相关链接

- 原始项目: http://hg.splayer.org/splayer

## 工具和脚本

- **检测 VS / MSBuild**: 在 `src\BuildScript` 下运行 `detect-vs2026.ps1` 或 `find-msbuild.ps1`
- **修复构建问题**: `src\BuildScript\fix-build-issues.ps1`
- **输出目录对齐契约**: `src\BuildScript\fix-output-directories-rfc0011.ps1`（可加 `-SelfTest`）
- **改进的构建脚本**: `src\BuildScript\build-fixed.cmd`、`build-with-msbuild.cmd`
- **PowerShell 中文环境**: 见 [docs/root-notes/POWERSHELL-CHINESE-SETUP-COMPLETE.md](docs/root-notes/POWERSHELL-CHINESE-SETUP-COMPLETE.md)