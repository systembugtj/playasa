# RFC-0037：UI 表面现状清单

| 字段 | 内容 |
|------|------|
| **状态** | 提案 (Proposed) |
| **类型** | Atomic（父级 [RFC-0036](./rfc-0036-mfc-ui-modernization.md)；本 RFC 只交付一份现状清单文档，不改动源码） |
| **父 RFC** | [RFC-0036](./rfc-0036-mfc-ui-modernization.md) |
| **适用范围** | `src/Source/apps/mplayerc/`（`MainFrm.*`、`ChildView.*`、`PlayerToolBar.*`、`PlayerToolTopBar.*`、`PlayerFloatToolBar.*`、`SVPSliderCtrl.*`、`VolumeCtrl.*`、`SUIButton.*`、`SkinPreviewDlg.*`、`UserInterface/Dialogs/`、`UserInterface/Renderer/`、`Model/ThemePkg.*`）及相关 `.rc`/`resource.h`/位图图标资源——仅盘点，不修改 |
| **相关 RFC** | [RFC-0036](./rfc-0036-mfc-ui-modernization.md)（父级）、[RFC-0028](./completed/rfc-0028-uia-video-and-seek-followups.md) |
| **创建日期** | 2026-07-17 |
| **最后更新** | 2026-07-17 |

## 1. 摘要

[RFC-0036](./rfc-0036-mfc-ui-modernization.md) 是 MFC/Win32 UI 现代化的父级 Umbrella RFC，本身不交付任何实现。本 RFC 是其第一个子 RFC：产出一份 UI 表面现状清单，覆盖现有对话框、工具栏、自定义控件与皮肤/主题资源，标注每个表面是否已 DPI 感知、是否走主题机制、是否有已知绘制/布局/可访问性问题。清单是后续子 RFC（RFC-0038 起）划分范围与排优先级的依据。

**本 RFC 不修改任何源码**，唯一交付物是清单文档。

## 2. 背景

1. 现有 UI 代码分布在多个类（工具栏、滑块、音量控件、皮肤预览、主题包）中，缺少一份现状清单，不清楚哪些表面已经支持高 DPI、哪些仍用旧的固定像素布局。
2. 皮肤/主题相关颜色、字体、图标来源不统一，部分绘制逻辑可能直接使用魔法数字而非主题查找，需要先盘点才能定位。
3. 没有清单时，后续子 RFC 容易范围重叠或遗漏表面。

## 3. 目标

1. 遍历 RFC-0036 适用范围内的 UI 相关类，逐个记录：文件、职责、是否 DPI 感知（缩放辅助函数 vs. 固定像素）、是否走 `Model/ThemePkg.*` 主题机制、已知绘制/布局/可访问性问题、代码量级（用于估算子 RFC 拆分粒度）。
2. 清单以表格形式落地为本 RFC 附录（第 6 节）。
3. 基于清单，为 RFC-0036 产出「建议的子 RFC 列表」（每条对应一个内聚表面），供后续创建 RFC-0038+ 时直接使用，不在本 RFC 中展开实现。

## 4. 非目标

1. 不修改任何源码、资源文件或工程文件。
2. 不在本 RFC 中定义具体改进方案（布局常量、DPI 缩放实现、主题统一方案等）——这些属于各自的后续子 RFC。
3. 不引入新的验证脚本或工具。

## 5. 方法

1. 搜索 `src/Source/apps/mplayerc/` 下继承 `CWnd`/`CDialog`/`CToolBar` 等 MFC 基类的类，以及 `UserInterface/Dialogs/`、`UserInterface/Renderer/` 下的文件。
2. 对每个文件/类检查：
   - 是否存在 DPI 相关代码（`GetDpiForWindow`、`MulDiv`、`AdjustForDpi` 等模式）或仍用固定像素常量。
   - 是否调用 `Model/ThemePkg.*` 提供的颜色/字体查找，还是直接硬编码 `RGB(...)`/字体名。
   - `OnPaint`/`DrawItem` 是否处理 hover/pressed/focused/disabled 状态与双缓冲。
   - 是否有关联的可访问性（UIA/MSAA）覆盖（参考 RFC-0028 已覆盖的视频区）。
3. 记录发现，不做任何修改。

## 6. 现状清单（待填充）

> 本节在 RFC 执行阶段填充，完成后本 RFC 可标记为完成。

| 文件/类 | 职责 | DPI 感知 | 主题机制 | 已知问题 | 建议子 RFC 优先级 |
|---|---|---|---|---|---|
| _待盘点_ | | | | | |

## 7. 验证方式

本 RFC 无代码改动，无需构建验证。完成标准：第 6 节清单覆盖 RFC-0036 适用范围列出的全部文件，且每行有明确的 DPI/主题/问题标注。

## 8. 决策记录

### 8.1 已做决策

1. 本 RFC 是 RFC-0036 的第一个子 RFC，编号 RFC-0037。
2. 交付物仅为清单文档，不改动源码。

### 8.2 待决策

1. 清单完成后具体拆分为几个 RFC-0038+ 子 RFC，留待清单产出后决定。

## 9. 参考文献

- [RFC-0036：MFC/Win32 UI 现代化（父级）](./rfc-0036-mfc-ui-modernization.md)
- `.cursor/skills/mfc-ui-modernization/SKILL.md`
- [ROADMAP.md](../../ROADMAP.md)

---

**下一步行动**：执行第 5 节方法，填充第 6 节清单；清单完成后据此创建 RFC-0038 起的具体改进子 RFC。
