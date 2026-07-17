# RFC-0040：原生滑块控件键盘焦点视觉恢复

| 字段 | 内容 |
|------|------|
| **状态** | 提案 (Proposed) |
| **类型** | Atomic（父级 [RFC-0036](./rfc-0036-mfc-ui-modernization.md)） |
| **父 RFC** | [RFC-0036](./rfc-0036-mfc-ui-modernization.md) |
| **适用范围** | `src/Source/apps/mplayerc/VolumeCtrl.cpp`（`OnNMCustomdraw`）、`SVPSliderCtrl.h/.cpp`（`OnPaint`） |
| **相关 RFC** | [RFC-0036](./rfc-0036-mfc-ui-modernization.md)（父级）、[RFC-0037](./completed/rfc-0037-ui-surface-inventory.md)（问题来源） |
| **创建日期** | 2026-07-17 |
| **最后更新** | 2026-07-17 |

## 1. 摘要

`CVolumeCtrl`（音量滑块）在其 `NM_CUSTOMDRAW` 处理中**显式抑制**了系统默认的键盘焦点框绘制；`CSVPSliderCtrl`（滑块基类，用于音量/进度等浮动弹窗）则完全没有任何焦点视觉。两者都子类化自 `CSliderCtrl`，理论上可以通过 Tab 键获得焦点并用方向键调整数值，但键盘用户在获得焦点后得不到任何视觉反馈，不知道当前操作的是哪个控件。本 RFC 恢复/补齐这两个控件的键盘焦点可见性。

## 2. 问题（证据）

1. `VolumeCtrl.cpp:202`：`pNMCD->uItemState &= ~CDIS_FOCUS;` —— 在 `OnNMCustomdraw` 中主动清除 `CDIS_FOCUS` 位，阻止公共控件默认绘制焦点矩形。
2. `VolumeCtrl.cpp:165-193`：`OnNMCustomdraw` 的绘制分支只用 `GetSysColor(COLOR_3DSHADOW/COLOR_3DHILIGHT/COLOR_3DFACE)`，且不区分 `CDIS_HOT`/`CDIS_SELECTED`，即悬停和按下也没有视觉差异（本 RFC 一并处理，因为焦点框和 hot/selected 着色都属于"自定义绘制的状态完整性"同一类问题，改动位置相同）。
3. `SVPSliderCtrl.cpp:52-127`：`OnPaint` 完整实现了滑块通道与滑钮（`CSUIButton`）的自绘，但没有任何 `GetFocus() == this` 判断或焦点矩形绘制逻辑。
4. `SVPSliderCtrl.cpp:184-235`：`OnLButtonDown/Up/OnMouseMove` 实现了完整的自定义拖拽逻辑（不依赖基类 `CSliderCtrl` 的默认交互），这也是它更需要显式补焦点视觉的原因——基类默认行为已被绕过。

## 3. 目标

1. `CVolumeCtrl` 恢复标准焦点框绘制（移除 `CDIS_FOCUS` 抑制），并让 `OnNMCustomdraw` 对 `CDIS_HOT`（悬停）与 `CDIS_SELECTED`（按下/拖拽中）分支使用有区分度的颜色，而不是对所有状态使用同一套 3D 阴影色。
2. `CSVPSliderCtrl::OnPaint` 在控件持有键盘焦点时（`GetFocus() == this`）绘制一个可见的焦点指示（矩形框或滑钮描边高亮均可，具体视觉在实现时与现有皮肤风格对齐）。
3. 两处改动都必须尊重现有双缓冲绘制路径（`CMemoryDC`），不引入闪烁。

## 4. 非目标

1. 不改变滑块的数值语义、步进逻辑或消息通知（`WM_HSCROLL`/自定义拖拽回调）。
2. 不为 `CSUIButton` 本身增加键盘焦点能力（`CSUIButton` 按钮不是独立 HWND，无法参与 Tab 顺序——这是 RFC-0039 之外的更大结构性问题，记入 RFC-0036 backlog，不在本 RFC 处理）。
3. 不修改 `CVolumeCtrl`/`CSVPSliderCtrl` 的 DPI 缩放方式（DPI 统一见 RFC-0042）。

## 5. 提案

### 5.1 CVolumeCtrl

1. 移除 `VolumeCtrl.cpp:202` 的 `pNMCD->uItemState &= ~CDIS_FOCUS;`，让 `uItemState` 保留公共控件传入的原始焦点位。
2. 在绘制通道/滑钮的分支中读取 `pNMCD->uItemState`：当包含 `CDIS_FOCUS` 时，在滑块通道外围绘制一个焦点矩形（`DrawFocusRect` 或与皮肤色一致的描边，二选一，实现时对齐 `AppSettings::GetColorFromTheme` 是否有可复用的焦点色 token；若没有，新增前先确认皮肤 `ui.ini` 是否已定义类似 key，避免引入未受皮肤系统管理的硬编码颜色）。
3. 增加 `CDIS_HOT`（悬停，若系统在该控件上报告）与 `CDIS_SELECTED`（按下）的颜色区分，复用现有 `GetSysColor` 体系（与背景系统色风格一致，不引入皮肤依赖，因为该控件目前整体是系统色风格，见 RFC-0037 §6 对本控件"无主题机制"的记录）。

### 5.2 CSVPSliderCtrl

1. 在 `OnPaint`（`SVPSliderCtrl.cpp:52-127`）中增加 `if (GetFocus() == this)` 分支，在滑块通道或滑钮周围绘制焦点指示。
2. 需要处理 `WM_SETFOCUS`/`WM_KILLFOCUS` 触发重绘（`Invalidate()`），确保焦点得失时视觉能刷新，而不是等到下一次自然重绘。
3. 焦点指示颜色/样式与 `colorBackGround`（`SVPSliderCtrl.cpp:22`，来自 `GetColorFromTheme("FloatDialogBG",...)`）风格协调，避免焦点框在深色皮肤下不可见。

## 6. 验证方式

1. 构建：包含 `VolumeCtrl.cpp`/`SVPSliderCtrl.cpp` 的最小相关工程配置；如涉及共享 UI 基础设施则跑全量 `src/splayer.sln`。
2. 手测：
   - Tab 键导航到音量滑块，确认出现可见焦点框；方向键调整音量时焦点框保持可见。
   - Tab 键导航到浮动滑块弹窗（若可 Tab 到达），确认焦点视觉出现；鼠标点击别处后确认焦点视觉消失（`WM_KILLFOCUS`）。
   - 悬停/按下音量滑块时颜色有可感知差异（非焦点状态下）。

## 7. 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| 焦点框在特定皮肤配色下对比度不足 | 可访问性目标落空 | 焦点色与背景色做对比度检查，必要时提供不依赖皮肤的高对比度描边作为保底 |
| `CDIS_FOCUS` 移除后暴露原生控件默认焦点框与自绘内容重叠/错位 | 视觉瑕疵 | 手测时对比恢复前后的实际截图，确认无重叠 |

## 8. 决策记录

### 8.1 已做决策

1. `CVolumeCtrl` 与 `CSVPSliderCtrl` 合并为一个 RFC，因为两者是同一类问题（键盘焦点视觉缺失）且改动范围小、互不依赖，符合"一个内聚问题一个 RFC"而非"一个文件一个 RFC"的粒度判断。
2. `CSUIButton` 本身的可聚焦性排除在外，留作更大的结构性 backlog。

### 8.2 待决策

1. 焦点色是否需要在 `ui.ini` 皮肤格式中新增一个标准 key（如 `FocusIndicator`）——若需要，涉及皮肤文件格式扩展，实现时再评估是否需要单独小节或征求皮肤维护约定。

## 9. 参考文献

- [RFC-0037：UI 表面现状清单](./completed/rfc-0037-ui-surface-inventory.md) 第 6 节
- `src/Source/apps/mplayerc/VolumeCtrl.cpp:163-202`
- `src/Source/apps/mplayerc/SVPSliderCtrl.cpp:22,52-127,184-235`

---

**下一步行动**：实施第 5 节改动，跑第 6 节手测，通过后更新状态为完成并归档。
