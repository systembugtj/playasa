# 现代化路线

本页合并旧的 `docs/analysis` 分析报告和实施计划。现代化不再按零散 Markdown 推进；具体工程决策应进入 RFC，状态跟踪写入 `TASK_TRACKING.md`。

## 当前技术基线

- 平台：Windows / Win32
- UI 与应用框架：MFC
- 媒体架构：DirectShow
- 主工程入口：`src\splayer.sln`
- 构建系统：MSBuild / Visual Studio solution
- 第三方库：随仓源码、头文件和部分预编译库混合存在

## 主要问题

1. 历史工程依赖较多，路径与第三方库状态需要 RFC 和验证脚本钉住。
2. MFC 与 DirectShow 仍是主架构，短期不适合一次性替换。
3. 字符串、资源、COM、MFC 类型混用，适合渐进收敛，不适合大爆炸式重写。
4. 旧第三方库升级需要保持 ABI、CRT/MFC 链接和 Win32 行为稳定。

## 推荐策略

采用渐进式现代化：

1. 先保证当前 Windows 构建可重复。
2. 每次只升级一个有边界的第三方库或模块。
3. 为每个高风险升级建立 RFC、验证脚本和 smoke test。
4. 对稳定模块优先加测试，再做内部替换。
5. 新增 Rust 或现代 C++ 模块时，通过清晰的 C ABI / C++ adapter 与旧代码隔离。

## 阶段计划

### 阶段 1：构建与依赖基线

目标是让仓库可以在现代 Visual Studio 上稳定构建，并把第三方库状态写入 RFC 与验证脚本。

已完成的代表性工作：

- RFC-0011：仓库布局和输出目录契约。
- RFC-0012：第三方库分阶段升级。
- RFC-0013 / RFC-0014 / RFC-0016：Rust 原生模块试点。

后续仍需跟进：

- RFC-0015：curl + Schannel 恢复 Updater 下载能力。
- RFC-0017：FFmpeg / mpcvideodec 升级与隔离策略。
- RFC-0018：Boost 头文件树渐进消化。
- RFC-0019：第三方库 CRT / MFC 静态链接准入契约。

### 阶段 2：模块级现代化

优先选择边界清晰、测试容易补齐的模块。可接受的方向包括：

- 新代码使用更明确的 adapter 层，减少 UI、COM、业务逻辑直接交叉。
- 对 playlist、hash、配置解析等纯逻辑模块优先使用单元测试保护。
- 保留旧实现 fallback，直到新实现通过构建、单测和 smoke test。

### 阶段 3：架构替换评估

MFC、DirectShow、FFmpeg、Media Foundation、Qt/WinUI 等属于高风险架构决策。不能用分析文档直接决定，应单独 RFC 化，先明确：

- 调用面和替换边界。
- 许可证影响。
- 二进制体积和分发影响。
- CRT/MFC 链接策略。
- smoke test 和回滚方案。

## 非目标

- 不做一次性全仓重写。
- 不把 UI 框架迁移作为短期构建修复的一部分。
- 不引入未经验证的新依赖。
- 不用复制旧二进制的方式掩盖 stale link 或工程路径问题。

## 参考入口

- [ROADMAP.md](../ROADMAP.md)
- [TASK_TRACKING.md](../TASK_TRACKING.md)
- [RFC-0011](../.spec/rfc/completed/rfc-0011-windows-repository-layout.md)
- [RFC-0012](../.spec/rfc/completed/rfc-0012-thirdparty-library-upgrades.md)
