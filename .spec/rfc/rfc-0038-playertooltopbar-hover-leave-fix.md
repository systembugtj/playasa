# RFC-0038：PlayerToolTopBar 悬停/鼠标离开可靠性修复

| 字段 | 内容 |
|------|------|
| **状态** | 提案 (Proposed) |
| **类型** | Atomic（父级 [RFC-0036](./rfc-0036-mfc-ui-modernization.md)） |
| **父 RFC** | [RFC-0036](./rfc-0036-mfc-ui-modernization.md) |
| **适用范围** | `src/Source/apps/mplayerc/PlayerToolTopBar.cpp`（仅 `OnMouseMove`），不改动其他文件 |
| **相关 RFC** | [RFC-0036](./rfc-0036-mfc-ui-modernization.md)（父级）、[RFC-0037](./completed/rfc-0037-ui-surface-inventory.md)（问题来源）、[RFC-0039](./rfc-0039-suibutton-hover-reliability.md)（同类问题的组件级根治） |
| **创建日期** | 2026-07-17 |
| **最后更新** | 2026-07-17 |

## 1. 摘要

`CPlayerToolTopBar`（顶部窗口控制条：关闭/还原/置顶/全屏/旋转/循环模式/缩放等按钮）已注册 `WM_MOUSELEAVE` 消息映射并实现了 `OnMouseLeave`，但其 `OnMouseMove` 从未调用 `TrackMouseEvent`/`_TrackMouseEvent` 武装该消息，导致 Windows 不保证投递 `WM_MOUSELEAVE`。本 RFC 是一个单函数、单文件的最小修复：在 `OnMouseMove` 中补上 `_TrackMouseEvent` 调用，对齐 `CPlayerToolBar`（底部工具栏）已经正确的实现。

## 2. 问题（证据）

1. `PlayerToolTopBar.cpp:60`：`ON_WM_MOUSELEAVE()` 已在消息映射中注册。
2. `PlayerToolTopBar.cpp:749-756`：`OnMouseLeave()` 已实现，负责把悬停中的按钮状态重置。
3. `PlayerToolTopBar.cpp:603-650`：`OnMouseMove()` 的完整实现中**没有任何 `TrackMouseEvent`/`_TrackMouseEvent` 调用**（已用 grep 在文件全文确认零匹配）。
4. 对比同一模块下已知正确的实现：`PlayerToolBar.cpp:754-758` 在 `OnMouseMove` 内构造 `TRACKMOUSEEVENT`（`dwFlags = TME_LEAVE`，`hwndTrack = m_hWnd`）并调用 `_TrackMouseEvent(&tmet)`，且该类的 `ON_WM_MOUSELEAVE()`（`PlayerToolBar.cpp:279`）能可靠触发。
5. **推断影响**（基于代码事实，需实测确认视觉表现）：没有武装 `TRACKMOUSEEVENT` 时，鼠标离开窗口客户区（尤其是快速划出边缘，或从顶部条离开进入非客户区/其他窗口）不保证收到 `WM_MOUSELEAVE`，`OnMouseLeave` 中的悬停按钮状态重置可能不执行，按钮的 `CSUIButton::m_stat` hover 视觉可能残留，直到下次 `OnMouseMove` 命中测试才刷新。

## 3. 目标

1. `OnMouseMove` 在每次收到鼠标移动消息时（或按 `PlayerToolBar` 的既有节流方式）武装 `TRACKMOUSEEVENT`，确保 `WM_MOUSELEAVE` 可靠投递。
2. 修复后鼠标离开顶部条窗口客户区时，`OnMouseLeave` 必定被调用一次。
3. 不改变按钮命中测试、布局、皮肤位图逻辑。

## 4. 非目标

1. 不改动 `CSUIButton` 内部悬停状态机（该组件级根治见 RFC-0039）。
2. 不改动 `PlayerToolBar`/`PlayerFloatToolBar`/`ChildView` 等其他文件。
3. 不新增可访问性（UIA）覆盖。

## 5. 提案

在 `PlayerToolTopBar.cpp` 的 `OnMouseMove(UINT nFlags, CPoint point)` 开头（命中测试逻辑之前）插入与 `PlayerToolBar.cpp:754-758` 一致的武装逻辑：

```cpp
TRACKMOUSEEVENT tmet;
tmet.cbSize = sizeof(TRACKMOUSEEVENT);
tmet.dwFlags = TME_LEAVE;
tmet.hwndTrack = m_hWnd;
_TrackMouseEvent(&tmet);
```

实现时需先读取 `PlayerToolBar.cpp:750-760` 附近的完整上下文（是否有节流/去重标志位，例如仅在未追踪时才调用一次），以保持两个兄弟类的实现风格一致，避免不必要的重复调用开销。不引入新的成员变量，除非 `PlayerToolBar` 的既有实现本身依赖某个标志位——若依赖，则镜像该标志位命名与生命周期管理。

## 6. 验证方式

1. 构建：`mplayerc_vs2005.vcxproj`（或包含 `PlayerToolTopBar.cpp` 的最小相关配置）。
2. 手测：启动 `splayer.exe`，将鼠标悬停在顶部工具条的按钮上（进入 hover 视觉），然后快速把鼠标移出窗口客户区（含移出到非客户区、移出到屏幕边缘两种路径）；确认按钮 hover 视觉在离开后立即复位，不再需要重新进入窗口才刷新。
3. 回归确认：全屏/非全屏切换、顶部条自动隐藏/显示逻辑不受影响（`SetCurrentHideState` 相关行为不变）。

## 7. 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| 重复调用 `TrackMouseEvent` 带来轻微开销 | 可忽略（Win32 API 设计为幂等武装） | 若需要可加去重标志位，参照 `PlayerToolBar` 实现 |
| 修复暴露了此前被掩盖的其他 hover 状态 bug | 需要在手测中多路径验证 | 手测覆盖全屏/浮动/停靠等多种顶部条状态 |

## 8. 决策记录

### 8.1 已做决策

1. 范围限定为 `PlayerToolTopBar.cpp::OnMouseMove` 单函数修复，不牵动 `CSUIButton` 状态机本身（留给 RFC-0039）。

### 8.2 待决策

1. 是否需要为此类悬停/leave 行为新增 selfcheck 脚本，或维持手测——待 RFC-0039（跨表面根治）确定统一验证方式后再决定是否合并测试。

## 9. 参考文献

- [RFC-0037：UI 表面现状清单](./completed/rfc-0037-ui-surface-inventory.md) 第 6 节
- `src/Source/apps/mplayerc/PlayerToolBar.cpp:754-758`（参照实现）
- `src/Source/apps/mplayerc/PlayerToolTopBar.cpp:60,603-650,749-756`

---

**下一步行动**：实施第 5 节改动，跑第 6 节验证，通过后更新状态为完成并归档。
