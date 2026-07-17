# RFC-0043：CustomizeFontDlg DrawItem 状态完整性

| 字段 | 内容 |
|------|------|
| **状态** | 提案 (Proposed) |
| **类型** | Atomic（父级 [RFC-0036](./rfc-0036-mfc-ui-modernization.md)） |
| **父 RFC** | [RFC-0036](./rfc-0036-mfc-ui-modernization.md) |
| **适用范围** | `src/Source/apps/mplayerc/UserInterface/Dialogs/CustomizeFontDlg.cpp`（仅 `DrawItem`） |
| **相关 RFC** | [RFC-0036](./rfc-0036-mfc-ui-modernization.md)（父级）、[RFC-0037](./completed/rfc-0037-ui-surface-inventory.md)（问题来源） |
| **创建日期** | 2026-07-17 |
| **最后更新** | 2026-07-17 |

## 1. 摘要

字幕字体定制对话框（`CustomizeFontDlg`）的颜色色块按钮通过标准 MFC owner-draw（`DrawItem`，`LPDRAWITEMSTRUCT`）实现，但绘制逻辑完全不检查 `lpdis->itemState`，导致选中、禁用、键盘焦点三种状态在视觉上与普通状态完全一样。本 RFC 是一个单文件、单函数的最小修复：补齐 `ODS_SELECTED`/`ODS_DISABLED`/`ODS_FOCUS` 的视觉区分。

## 2. 问题（证据）

1. `CustomizeFontDlg.cpp:88-125`：`DrawItem` 的实现使用手工 `CreateCompatibleDC`/`StretchBlt`（2x 超采样后用 `HALFTONE` 缩小绘制色块/字体预览），但整个函数体内**没有任何 `lpdis->itemState` 判断**（已用 grep 在函数范围内确认零 `ODS_` 匹配）。
2. 影响：色块按钮无论是否被选中（`ODS_SELECTED`）、禁用（`ODS_DISABLED`）、获得键盘焦点（`ODS_FOCUS`），绘制结果完全一致——用户无法通过视觉判断当前选中的颜色色块是哪一个，键盘用户也得不到焦点反馈。
3. 对比同仓另一处 owner-draw 实现 `PlaylistView_Win.cc:124-160+`：该实现**检查了 `ODS_SELECTED`**（`PlaylistView_Win.cc:134`）并据此切换渐变高亮 vs. 纯色填充分支，是本仓状态感知最完整的 owner-draw 参考实现，但仍缺 `ODS_DISABLED`/`ODS_FOCUS`（本 RFC 不改动 `PlaylistView_Win.cc`，仅作为实现参考）。

## 3. 目标

1. `CustomizeFontDlg::DrawItem` 读取 `lpdis->itemState`，为 `ODS_SELECTED` 增加明显的选中态视觉（描边高亮或背景色变化，与现有 2x 超采样绘制风格兼容）。
2. 为 `ODS_DISABLED` 增加禁用态视觉（降低饱和度/灰化）。
3. 为 `ODS_FOCUS` 增加键盘焦点指示（`DrawFocusRect` 或等效描边）。
4. 保持现有超采样+`HALFTONE`缩放的绘制质量不变，新增状态视觉是在此基础上叠加，而非重写绘制管线。

## 4. 非目标

1. 不改变色块按钮的布局、尺寸、字体预览逻辑。
2. 不改动 `OptionSubtitlePage_Win.cc` 中 `m_subtitlestyle.DrawItem` 所委托的 `UserInterface/Support/SubtitleStyle.cc`（该文件同样缺少 `ODS_*` 检查，但不在 RFC-0036 §5 声明的适用范围内，需要时应另开子 RFC）。
3. 不改动 `PlaylistView_Win.cc` 现有的 `ODS_SELECTED` 处理（仅作参考，不修改）。

## 5. 提案

1. 在 `CustomizeFontDlg.cpp:88-125` 的 `DrawItem` 函数开头，读取 `lpdis->itemState`，提取 `bool bSelected = (lpdis->itemState & ODS_SELECTED) != 0;`、`bool bDisabled = (lpdis->itemState & ODS_DISABLED) != 0;`、`bool bFocused = (lpdis->itemState & ODS_FOCUS) != 0;`。
2. 在现有 `StretchBlt` 之后（不改变缩放绘制本身），根据 `bSelected` 叠加一层描边或轻微高亮框，根据 `bDisabled` 在绘制前对源位图做灰度/降饱和处理（或绘制半透明遮罩），根据 `bFocused` 调用 `::DrawFocusRect(lpdis->hDC, &lpdis->rcItem)`。
3. 确认三种状态可以叠加显示（例如同时选中且获得焦点）而不互相冲突覆盖。

## 6. 验证方式

1. 构建：`mplayerc_vs2005.vcxproj`（或包含 `CustomizeFontDlg.cpp` 的最小相关配置）。
2. 手测：打开字幕字体定制对话框，用 Tab 键在颜色色块间移动，确认焦点框可见；点击选中某色块，确认选中态视觉区别于未选中色块；若存在可禁用的色块场景，验证禁用态视觉正确。

## 7. 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| 新增状态绘制与现有 2x 超采样管线顺序不当导致锯齿/晕影 | 视觉质量下降 | 状态叠加层在最终缩放后的目标 DC 上绘制，而非污染超采样中间位图 |

## 8. 决策记录

### 8.1 已做决策

1. 范围严格限定在 `CustomizeFontDlg.cpp::DrawItem` 一个函数，不牵动 `SubtitleStyle.cc`（超出 RFC-0036 声明的适用范围，需要时另开子 RFC）。

### 8.2 待决策

1. `SubtitleStyle.cc`（`OptionSubtitlePage_Win` 委托目标）是否也需要类似修复——留待评估是否将 `UserInterface/Support/` 纳入 RFC-0036 适用范围后再决定。

## 9. 参考文献

- [RFC-0037：UI 表面现状清单](./completed/rfc-0037-ui-surface-inventory.md) 第 7 节
- `src/Source/apps/mplayerc/UserInterface/Dialogs/CustomizeFontDlg.cpp:88-125`
- `src/Source/apps/mplayerc/UserInterface/Renderer/PlaylistView_Win.cc:124-160`（参考实现）

---

**下一步行动**：实施第 5 节改动，跑第 6 节手测，通过后更新状态为完成并归档。
