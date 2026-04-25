# Playasa 文档入口

本目录只保留长期可维护的主题文档。旧的构建记录、安装笔记、现代化分析和根目录迁移笔记已经合并，避免同一件事散落在多个 Markdown 中。

## 主要文档

- [INSTALL.md](INSTALL.md)：Visual Studio、MFC/ATL、Windows SDK 与首次构建准备。
- [BUILD.md](BUILD.md)：日常构建命令、当前构建状态、常见失败原因与修复顺序。
- [POWERSHELL.md](POWERSHELL.md)：PowerShell UTF-8 / 中文输出配置。
- [PROJECT-STRUCTURE.md](PROJECT-STRUCTURE.md)：仓库目录、`src\splayer.sln`、`out\` 与脚本位置说明。
- [MODERNIZATION.md](MODERNIZATION.md)：现代化方向、分阶段策略和风险边界。
- [VS2025-SUPPORT.md](VS2025-SUPPORT.md)：VS2025 兼容说明。

## 规范来源

- 工程布局与 MSBuild 路径契约以 [RFC-0011](../.spec/rfc/completed/rfc-0011-windows-repository-layout.md) 为准。
- 第三方库升级路线以 [RFC-0012](../.spec/rfc/completed/rfc-0012-thirdparty-library-upgrades.md) 为准。
- 后续 RFC 和历史 RFC 见 [RFC 索引](rfc/README.md) 与 [`.spec/rfc/`](../.spec/rfc/)。

## 已合并的旧文档

以下碎片文档不再保留独立入口，内容已经并入上面的主题文档：

- `docs/analysis/*`
- `docs/root-notes/*`
- `docs/BUILD-FIXES.md`
- `docs/BUILD-ISSUES-FOUND.md`
- `docs/BUILD-PROGRESS.md`
- `docs/BUILD-STATUS.md`
- `docs/INSTALL-GUIDE.md`
- `docs/INSTALL-MFC.md`
- `docs/POWERSHELL-CHINESE-GLOBAL.md`
- `docs/PowerShell-UTF8-Setup.md`
- `docs/PROJECT-STRUCTURE-ANALYSIS.md`
- `docs/STRUCTURE-RECOMMENDATION.md`
