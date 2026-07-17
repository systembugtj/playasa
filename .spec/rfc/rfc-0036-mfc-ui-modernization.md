# RFC-0036：MFC/Win32 UI 现代化（父级/Umbrella）

| 字段 | 内容 |
|------|------|
| **状态** | 执行中 (In Progress) — 父级本身不产出代码，状态跟随子 RFC 进度 |
| **类型** | Umbrella（父级；本 RFC 不直接交付任何代码，只交付子 RFC 列表与排序原则） |
| **子 RFC** | [RFC-0037](./completed/rfc-0037-ui-surface-inventory.md)（现状清单，已完成）、[RFC-0038](./rfc-0038-playertooltopbar-hover-leave-fix.md)（提案）、[RFC-0039](./rfc-0039-suibutton-hover-reliability.md)（提案）、[RFC-0040](./rfc-0040-native-control-keyboard-focus-visuals.md)（提案）、[RFC-0041](./rfc-0041-skin-theme-consistency-cleanup.md)（提案）、[RFC-0042](./rfc-0042-dpi-cache-consolidation.md)（提案）、[RFC-0043](./rfc-0043-customizefontdlg-drawitem-states.md)（提案） |
| **适用范围** | `src/Source/apps/mplayerc/` 下全部 UI 相关表面（对话框、工具栏、自定义控件、皮肤/主题资源）；具体文件边界由各子 RFC 各自声明 |
| **相关 RFC** | [RFC-0011](./completed/rfc-0011-windows-repository-layout.md)、[RFC-0028](./completed/rfc-0028-uia-video-and-seek-followups.md) |
| **创建日期** | 2026-07-17 |
| **最后更新** | 2026-07-17 |

## 1. 摘要

Playasa/SPlayer 的桌面 UI 基于 MFC/Win32，长期以来 UI 相关改进（皮肤、对话框、工具栏、高 DPI、可访问性）散落在各处，没有统一 RFC 覆盖，只以 `.cursor/skills/mfc-ui-modernization` 技能文档形式存在指导原则。按照本仓「金规则」（每项改动必须先有 RFC）与「一个 RFC 一件事」原则，UI 现代化涉及多个互相独立、可分别实施/回滚的表面，不适合塞进单一 monolith RFC。

本 RFC 是**纯父级 Umbrella RFC**：只声明整体目标、非目标、子 RFC 排序原则，**不描述、不交付任何具体实现步骤**。所有会改动代码或产出实质交付物（含仅文档但需要独立验收的清单）的工作，一律拆分为子 RFC（RFC-0037 起）。本 RFC 的状态仅当全部子 RFC 都进入终态（完成/拒绝/废弃）时才可标记为完成。

## 2. 背景

1. UI 现代化已有工作方式指导：`.cursor/skills/mfc-ui-modernization/SKILL.md`，定义了工作范围、检查清单、偏好模式和禁止事项，但该技能文档不是 RFC，不受「金规则」的完成/归档流程约束。
2. RFC-0028 已完成视频区 UIA（可访问性）与 seek 预滚相关改进，证明 UI 表面的改动可以在不破坏播放/DirectShow 生命周期的前提下推进。
3. ROADMAP.md 此前将「MFC UI 现代化」列为**尚无独立 RFC 的 backlog** 项，注明「可未来 RFC-003x」。本 RFC 认领该编号，作为后续所有 UI 子 RFC 的父级。

## 3. 目标

1. 作为 MFC/Win32 UI 改进工作的唯一入口：任何 UI 侧代码或清单类交付物必须归属某个子 RFC，不得以本父级 RFC 名义直接改动仓库。
2. 定义子 RFC 的排序与范围原则（见第 5 节），保证每个子 RFC 是内聚、可独立验证、可独立回滚的单元。
3. 在 ROADMAP.md 维护本 RFC 与子 RFC 的树形关系，随子 RFC 增减更新。

## 4. 非目标

1. 不引入 Qt、WinUI、WPF、WebView 或 React 等新 UI 框架替换 MFC——任何子 RFC 都不得以此为目标。
2. 本父级 RFC 不定义任何具体实施步骤、验证脚本或交付物；这些只存在于子 RFC 中。
3. 不修改播放、更新器、网络或解析器行为。

## 5. 子 RFC 排序与范围原则

1. **现状先行**：第一个子 RFC（RFC-0037）产出 UI 表面现状清单（对话框/工具栏/控件/皮肤资源，是否 DPI 感知、是否走主题机制、已知问题），作为后续子 RFC 排期依据。
2. **一个子 RFC 一个内聚表面**：例如「某自定义控件的 owner-draw 状态补全」「某类对话框的 DPI 缩放」「主题颜色/字体来源统一」应各自独立成子 RFC，不合并。
3. **编号连续**：子 RFC 从 RFC-0037 起顺序编号，创建时在本表「子 RFC」字段登记，并同步更新 ROADMAP.md 子 RFC 关系图。
4. **验证方式由子 RFC 自行定义**：窄范围改动构建对应工程；涉及共享 UI 基础设施或工程文件改动的子 RFC 需跑全量 `src/splayer.sln` 构建；涉及运行时行为的需在子 RFC 中记录手测或 selfcheck 脚本。
5. **禁止事项对所有子 RFC 生效**：不引入新 UI 框架、不手写资源文件而不检查现有 ID 规则、不引入新依赖完成简单绘制/布局改动、不用大范围强制重绘/定时器掩盖渲染 bug。

## 6. 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| 子 RFC 数量膨胀，跟踪成本上升 | ROADMAP/TASK_TRACKING 维护负担 | 统一在本 RFC 子 RFC 字段与 ROADMAP 关系图登记，不额外开跟踪文档 |
| 子 RFC 范围划分不清，出现重叠 | 改动冲突、回滚困难 | 新建子 RFC 前检查已有子 RFC 范围，重叠优先并入既有子 RFC |
| 父级长期挂起，子 RFC 停滞 | 看起来"在做"实际无进展 | ROADMAP 推荐执行顺序表跟踪当前活跃子 RFC 优先级 |

## 7. 决策记录

### 7.1 已做决策

1. 本 RFC 认领 ROADMAP.md 中「MFC UI 现代化」backlog 项，编号 RFC-0036，类型为纯 Umbrella。
2. RFC-0037（现状清单）已完成并归档，覆盖 `MainFrm`/`ChildView`/`PlayerToolBar`/`PlayerToolTopBar`/`PlayerFloatToolBar`/`SVPSliderCtrl`/`VolumeCtrl`/`SUIButton`/`SkinPreviewDlg`/`Model/ThemePkg`/`UserInterface/Dialogs`（12 文件）/`UserInterface/Renderer`（10 文件），共 33 项表面。
3. 据清单已创建 6 个具体子 RFC，均为提案状态，各自内聚、可独立实施与验证：
   - **RFC-0038**：`PlayerToolTopBar` 悬停/mouse-leave 修复（缺失 `TrackMouseEvent` 调用）。
   - **RFC-0039**：`CSUIButton` 悬停状态可靠性（改用 `TrackMouseEvent`，惠及 ChildView/PlayerToolBar/PlayerToolTopBar/SVPSliderCtrl 四个复用表面）。
   - **RFC-0040**：`VolumeCtrl`/`SVPSliderCtrl` 键盘焦点视觉（含 `VolumeCtrl` 显式抑制 `CDIS_FOCUS` 的回归）。
   - **RFC-0041**：皮肤/主题一致性清理（`SkinPreviewDlg` 接入 `GetColorFromTheme` + `Model/ThemePkg` 死代码桩处置）。
   - **RFC-0042**：DPI 缓存统一（`MainFrm`/`SUIButton`/`GetSystemFontWithScale` 三处独立 `GetDeviceCaps` 副本）。
   - **RFC-0043**：`CustomizeFontDlg::DrawItem` owner-draw 状态完整性（补齐 `ODS_SELECTED`/`ODS_DISABLED`/`ODS_FOCUS`）。
4. 以下项识别为体量过大或有依赖，暂不开子 RFC，留在本父级 backlog：`MainFrm` god-object 拆分（16,051 行，含死代码 `OnPaint`/空壳 `OnDrawItem`）、`PlayerToolBar` 全面主题一致性、工具栏按钮逐个 UIA 可访问性身份（依赖 RFC-0039 先落地）。
5. 本父级 RFC 本身仍不产出任何代码；上述 6 项交付物归属各自子 RFC。

### 7.2 待决策

1. RFC-0038～0043 完成后，是否为 `MainFrm` 拆分、`PlayerToolBar` 主题一致性、工具栏按钮 UIA 身份分别开出新一批子 RFC（RFC-0044 起）——留待前 6 项收口后评估。
2. 是否需要新增 UI 相关 selfcheck 脚本目录（类比 `src/Test/Scripts/` 下其他 RFC 的 `test-rfc00NN-*.ps1`）——留给对应子 RFC 决定，RFC-0038/0039/0040 均涉及运行时行为，建议至少手测。

## 8. 参考文献

- `.cursor/skills/mfc-ui-modernization/SKILL.md`
- [RFC-0028：UIA 视频区与 seek 预滚后续](./completed/rfc-0028-uia-video-and-seek-followups.md)
- [ROADMAP.md](../ROADMAP.md)

---

**下一步行动**：推进 RFC-0037（现状清单）；清单产出后按表面数量创建后续子 RFC（RFC-0038 起）。
