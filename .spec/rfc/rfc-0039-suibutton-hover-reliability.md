# RFC-0039：CSUIButton 悬停状态可靠性（TrackMouseEvent 化）

| 字段 | 内容 |
|------|------|
| **状态** | 提案 (Proposed) |
| **类型** | Atomic（父级 [RFC-0036](./rfc-0036-mfc-ui-modernization.md)；跨 4 个宿主表面共享一个组件） |
| **父 RFC** | [RFC-0036](./rfc-0036-mfc-ui-modernization.md) |
| **适用范围** | `src/Source/apps/mplayerc/SUIButton.h`、`SUIButton.cpp`；不改动 `ChildView`/`PlayerToolBar`/`PlayerToolTopBar`/`SVPSliderCtrl` 的其他逻辑 |
| **相关 RFC** | [RFC-0036](./rfc-0036-mfc-ui-modernization.md)（父级）、[RFC-0037](./completed/rfc-0037-ui-surface-inventory.md)（问题来源）、[RFC-0038](./rfc-0038-playertooltopbar-hover-leave-fix.md)（同类问题的宿主级症状之一） |
| **创建日期** | 2026-07-17 |
| **最后更新** | 2026-07-17 |

## 1. 摘要

`CSUIButton`/`CSUIBtnList`（`SUIButton.h/.cpp`）是本仓底部工具栏、顶部工具栏、视频区悬浮按钮、滑块滑钮共用的位图按钮引擎，已有完整的 4 态模型（`m_stat`：0 正常/1 悬停/2 按下/3 禁用）。但悬停状态完全依赖**宿主窗口自身**的 `OnMouseMove` + `OnHitTest` 轮询来设置/清除，组件本身不使用 `TrackMouseEvent`。这意味着：只要任何一个宿主窗口的鼠标离开事件处理有缺陷（如 RFC-0038 描述的 `PlayerToolTopBar`），其上的所有 `CSUIButton` 实例都会表现出悬停状态残留。本 RFC 把"鼠标离开即清除悬停"这一职责下沉到 `CSUIButton`/`CSUIBtnList` 自身，一次修复惠及全部 4 个宿主表面，且不再依赖每个宿主各自正确实现 `WM_MOUSELEAVE`。

## 2. 问题（证据）

1. `SUIButton.h:88`：`m_stat` 字段定义，取值含义 0/1/2/3。
2. `SUIButton.cpp:94-130`：`OnHitTest` 由宿主在 `OnMouseMove` 中调用，负责判定当前坐标命中哪个按钮并设置对应 `m_stat`；`CSUIButton` 自身没有独立的窗口消息循环。
3. `SUIButton.cpp:220-238`：`OnPaint` 按 `m_stat` 从精灵表取对应偏移绘制——绘制逻辑本身没有问题，问题在状态**清除**的触发来源单一（仅靠宿主轮询），没有组件自身兜底。
4. 已知宿主级症状：`PlayerToolTopBar`（RFC-0038）的 `WM_MOUSELEAVE` 不可靠触发，会导致其上 `CSUIButton` 实例的悬停视觉残留；`PlayerFloatToolBar` 甚至完全没有 `WM_MOUSELEAVE` 处理（`PlayerFloatToolBar.cpp:171-192` 的 `OnMouseMove` 无 leave 逻辑，目前无悬停敏感外观所以未构成缺陷，但如果未来给它加悬停态按钮，会重现同一类问题）。
5. `SUIButton.h:88` 的 hover 态没有键盘可达性：按钮不是独立 HWND，无法接收键盘焦点/Tab 顺序，也没有 UIA/MSAA 身份（本 RFC **不**处理此项，见「非目标」）。

## 3. 目标

1. 让 `CSUIButton`/`CSUIBtnList` 在**任意宿主**窗口下，鼠标离开宿主窗口客户区时都能可靠地把悬停中的按钮状态清除为正常态，不再单方面依赖宿主自行正确实现 `WM_MOUSELEAVE`/`TrackMouseEvent`。
2. 保持现有 4 态模型（正常/悬停/按下/禁用）与精灵表绘制方式不变。
3. 一次改动同时惠及 `ChildView`、`PlayerToolBar`、`PlayerToolTopBar`、`SVPSliderCtrl` 四个宿主，不需要逐个宿主单独打补丁。
4. 与 RFC-0038 兼容：即使 RFC-0038 先落地，本 RFC 仍应作为组件级根治收尾（RFC-0038 的宿主级修复可以保留，也可以在本 RFC 落地后评估是否仍需要，由实现时决定，不在本 RFC 强制回退 RFC-0038）。

## 4. 非目标

1. 不给 `CSUIButton` 增加真实 HWND、键盘焦点或 Tab 顺序——这是结构性变更（把手绘位图区域变成真正的子窗口），超出本 RFC 范围。
2. 不给 `CSUIButton` 增加 UIA/MSAA 可访问性身份——留作 RFC-0036 未来 backlog（依赖本 RFC 的状态引擎先落地）。
3. 不改变精灵表资源、按钮布局算法（`CalcRealMargin`/`CountDPi`）或皮肤加载逻辑。
4. 不移除或替换宿主窗口现有的 `OnHitTest` 调用点——命中测试职责保留在宿主，本 RFC 只处理"离开清除"这一件事。

## 5. 提案

1. 在 `CSUIBtnList`（管理一组按钮的容器类，负责 `OnHitTest` 分发）中增加一个内部的鼠标离开处理入口，例如 `OnHostMouseLeave()`，由宿主窗口在自身的 `OnMouseLeave` 中调用一次即可，将所有按钮的 `m_stat == 1`（悬停）重置为 0（正常），并触发一次重绘。这一步是"让现有宿主 leave 事件更可靠地被组件消费"，不需要宿主自己新增状态清除逻辑。
2. 更进一步的可靠性根治：在 `CSUIBtnList` 首次收到 `OnHitTest`（即鼠标进入按钮命中区域）时，检查宿主 HWND 是否已武装 `TRACKMOUSEEVENT`；如未武装，由 `CSUIBtnList` 自己调用 `_TrackMouseEvent(hwndTrack = 宿主 HWND, dwFlags = TME_LEAVE)`，使悬停清除不再依赖宿主是否"记得"武装。宿主原有的 `WM_MOUSELEAVE` 处理器（如果有）仍会被正常调用，二者不冲突——`CSUIBtnList` 只是确保武装这一步不再遗漏。
3. 具体接入点：`CSUIBtnList` 需要知道宿主 `HWND`（构造/初始化时已经持有，用于 `OnPaint`/`OnHitTest` 的坐标转换），复用该句柄即可，无需新增参数。
4. 四个宿主（`ChildView`、`PlayerToolBar`、`PlayerToolTopBar`、`SVPSliderCtrl`）各自的 `OnMouseLeave`（如果已存在）保持调用 `CSUIBtnList` 的重置入口；若某宿主原本没有 `OnMouseLeave`/`ON_WM_MOUSELEAVE()`（需逐一确认），需要补上最小的消息映射项，仅用于转发给 `CSUIBtnList::OnHostMouseLeave()`。

## 6. 验证方式

1. 构建：涉及 `SUIButton.h/.cpp` 改动，且四个宿主头文件可能新增消息映射项，需要跑全量 `src/splayer.sln` Release Unicode|Win32 构建。
2. 手测矩阵（覆盖四个宿主）：
   - `PlayerToolBar`（底部工具栏）：悬停按钮后快速移出窗口，确认视觉复位（回归测试，此宿主此前已是正确实现）。
   - `PlayerToolTopBar`（顶部工具栏）：同上，验证与 RFC-0038 修复叠加或独立生效均正确。
   - `ChildView`（视频区悬浮按钮）：悬停打开文件/水印按钮后移出视频区，确认复位。
   - `SVPSliderCtrl`（滑块滑钮）：拖拽滑钮后移出滑块区域，确认滑钮悬停态复位。
3. 确认命中测试（`OnHitTest`）驱动的悬停**进入**逻辑不受影响——本 RFC 只改"离开清除"路径。

## 7. 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| `CSUIBtnList` 与宿主各自都调用 `TrackMouseEvent`，重复武装 | Win32 API 幂等，理论上无害，但需确认无重复 leave 回调 | 手测四个宿主，确认 `OnMouseLeave` 不会被触发两次导致重复重绘或状态错乱 |
| 四个宿主的 `OnHitTest`/`OnMouseMove` 调用时机略有差异 | 状态重置时机不一致 | 逐个宿主手测，而非只测一个后假设其余一致 |
| 改动共享组件，回归面较广 | 影响面覆盖 4 个表面 | 全量构建 + 四宿主独立手测矩阵，不做单一表面抽样 |

## 8. 决策记录

### 8.1 已做决策

1. 悬停清除职责下沉到 `CSUIButton`/`CSUIBtnList` 组件本身，不要求每个宿主各自正确实现 `WM_MOUSELEAVE`。
2. 键盘焦点与 UIA 可访问性明确排除在本 RFC 之外，留作后续按需开出的子 RFC。

### 8.2 待决策

1. RFC-0038（`PlayerToolTopBar` 宿主级修复）与本 RFC 都落地后，是否保留 RFC-0038 的改动（双重保险）还是回退为纯组件级方案——留待两者都实现后评估代码整洁度。
2. `CSUIButton` 键盘焦点/UIA 身份是否值得单独开 RFC——留待本 RFC 落地、四个宿主验证通过后再评估投入产出比。

## 9. 参考文献

- [RFC-0037：UI 表面现状清单](./completed/rfc-0037-ui-surface-inventory.md) 第 6 节
- [RFC-0038：PlayerToolTopBar 悬停/鼠标离开可靠性修复](./rfc-0038-playertooltopbar-hover-leave-fix.md)
- `src/Source/apps/mplayerc/SUIButton.h:75,88`、`SUIButton.cpp:42-53,94-130,220-238`

---

**下一步行动**：实施第 5 节改动，跑第 6 节四宿主验证矩阵，通过后更新状态为完成并归档。
