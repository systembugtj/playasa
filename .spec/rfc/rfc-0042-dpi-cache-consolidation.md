# RFC-0042：DPI 缓存统一（单一来源 + WM_DPICHANGED 基础设施）

| 字段 | 内容 |
|------|------|
| **状态** | 提案 (Proposed) |
| **类型** | Atomic（父级 [RFC-0036](./rfc-0036-mfc-ui-modernization.md)；跨多文件的一致性改动） |
| **父 RFC** | [RFC-0036](./rfc-0036-mfc-ui-modernization.md) |
| **适用范围** | `src/Source/apps/mplayerc/MainFrm.h/.cpp`（`m_nLogDPIY` 相关）、`SUIButton.h/.cpp`（静态 `nLogDPIX/nLogDPIY`）、`mplayerc.h/.cpp`（`GetSystemFontWithScale`） |
| **相关 RFC** | [RFC-0036](./rfc-0036-mfc-ui-modernization.md)（父级）、[RFC-0037](./completed/rfc-0037-ui-surface-inventory.md)（问题来源） |
| **创建日期** | 2026-07-17 |
| **最后更新** | 2026-07-17 |

## 1. 摘要

本仓当前没有任何 per-monitor DPI 感知代码（零 `GetDpiForWindow`/`AdjustWindowRectExForDpi`/`WM_DPICHANGED`），DPI 缩放全部基于进程启动时缓存一次的系统 DPI（`GetDeviceCaps(LOGPIXELSX/Y)`），且这一缓存**独立存在 3 份**：`CMainFrame::m_nLogDPIY`、`SUIButton.cpp` 文件级 static 全局、`GetSystemFontWithScale()` 内部局部变量。三者互不同步，任何一处的 DPI 假设变化都不会传播到另外两处。本 RFC 不实现真正的 per-monitor DPI 感知（范围过大，属于未来独立 RFC），而是先做一件更小、更安全的事：把三处独立的 `GetDeviceCaps` 调用统一为单一来源，为未来接入 `WM_DPICHANGED` 打基础。

## 2. 问题（证据）

1. `MainFrm.cpp:756-758`：`CMainFrame::OnCreate` 中通过 `GetDeviceCaps(LOGPIXELSY)` 计算并缓存进成员 `m_nLogDPIY`（声明于 `MainFrm.h:195`）。
2. `SUIButton.cpp:42-53`：文件级 `static` 全局变量 `nLogDPIX`/`nLogDPIY`（声明 `SUIButton.h:75`），在**首个** `CSUIButton` 构造时惰性求值，此后进程生命周期内不再刷新。
3. `mplayerc.cpp:5029-5030`：`GetSystemFontWithScale()` 内部又一次独立调用 `GetDeviceCaps`，与前两处无共享。
4. `PlayerToolBar.cpp:143`、`PlayerToolTopBar.cpp:202`、`PlayerFloatToolBar.cpp:166`：这些宿主各自从 `CMainFrame` 复制 `m_nLogDPIY` 到自己的成员变量，形成第 4、5、6 份"派生副本"（虽然值相同，但复制路径分散）。
5. 全仓 grep 确认 `UserInterface/Dialogs/*` 与 `UserInterface/Renderer/*` 完全没有 DPI 缩放代码——这些窗口依赖 Win32 对话框单位系统或硬编码像素常量，不在本 RFC 范围内（对话框单位系统本身对 DPI 变化有一定免疫力，风险等级不同，值得单独评估，非本 RFC 目标）。

## 3. 目标

1. 引入一个单一的 DPI 查询入口（例如 `CMainFrame` 暴露的静态/全局访问器，或独立的小型帮助类），供 `SUIButton`、`GetSystemFontWithScale`、`PlayerToolBar`/`PlayerToolTopBar`/`PlayerFloatToolBar` 统一调用，取代当前三处独立的 `GetDeviceCaps` 调用与后续的层层复制。
2. 保持当前"进程启动时读取一次系统 DPI"的语义不变——本 RFC **不**实现动态响应 `WM_DPICHANGED` 的重新布局，只是把读取入口统一，为未来（若开出后续 RFC）接入 `WM_DPICHANGED` 铺路。
3. 统一后，改一处即可让全部消费者感知 DPI 值的变化（即便本 RFC 阶段这个值仍然只在启动时确定一次）。

## 4. 非目标

1. **不实现 per-monitor DPI 感知**：不处理 `WM_DPICHANGED`、不响应窗口跨显示器移动后的重新布局。这是明显更大的改动（涉及所有使用 DPI 值的绘制/布局代码都要能在运行时重新计算，而不仅仅是重新读取一个数字），需要单独评估是否值得开新 RFC。
2. 不改变任何具体的缩放公式（`m_nHeight * m_nLogDPIY / 96` 等既有运算保持不变），只改变 `m_nLogDPIY`（或等价值）的**来源**。
3. 不处理 `UserInterface/Dialogs/*`、`UserInterface/Renderer/*` 的对话框单位/硬编码像素问题——不同的 DPI 处理模型，超出本 RFC 范围。

## 5. 提案

1. 在 `CMainFrame` 中保留 `OnCreate` 里对 `GetDeviceCaps(LOGPIXELSY)` 的读取（它已经是最早发生、生命周期最长的调用点），但把它包装为一个可供其他类调用的静态访问器，例如 `CMainFrame::GetCachedLogPixelsY()`，内部沿用现有 `m_nLogDPIY` 存储，不新增第二套状态。
2. `SUIButton.cpp:42-53` 的文件级 static 全局 `nLogDPIX/nLogDPIY` 改为调用第 1 步的统一访问器获取纵向 DPI；横向 DPI（`nLogDPIX`）如果当前也是独立 `GetDeviceCaps(LOGPIXELSX)`，同样评估是否可以合并为同一来源（多数 Windows 系统下 X/Y 系统 DPI 相同，但不假设——需要先确认现有代码是否已经隐含这个假设）。
3. `GetSystemFontWithScale()`（`mplayerc.cpp:5028-5030`）改为调用同一访问器，移除其内部独立的 `GetDeviceCaps` 调用。
4. `PlayerToolBar`/`PlayerToolTopBar`/`PlayerFloatToolBar` 中从 `CMainFrame` 复制 `m_nLogDPIY` 到自身成员变量的代码路径可以保留（三者是宿主自身状态的合理缓存，属于"消费统一来源"而非"独立计算来源"），只需确认它们复制的源头已经是第 1 步的统一访问器，而不是分别调用 `GetDeviceCaps`。
5. 明确写清楚：本次改动完成后，全仓只应有**一处** `GetDeviceCaps(LOGPIXELSX/Y)` 调用（在 `CMainFrame::OnCreate` 或其等价单一入口内）。实现时应在改动完成后用 grep 复核这一点，作为验收标准之一。

## 6. 验证方式

1. 构建：改动横跨 `MainFrm`/`SUIButton`/`mplayerc.cpp`/三个工具栏宿主，需跑全量 `src/splayer.sln` Release Unicode|Win32 构建。
2. 验收 grep：`grep -rn "GetDeviceCaps.*LOGPIXELS" src/Source/apps/mplayerc/` 结果应只剩 1 处调用点（统一访问器内部）。
3. 手测：在常规 DPI（100%）与高 DPI（125%/150%）显示器（或 Windows 显示设置调整缩放后重启应用，因为本 RFC 不处理运行时 `WM_DPICHANGED`）下分别启动 `splayer.exe`，确认工具栏高度、按钮大小、字体大小与改动前视觉一致（本 RFC 是纯重构，不应有可见的行为变化）。

## 7. 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| 统一访问器引入初始化顺序依赖（例如 `SUIButton` 构造早于 `CMainFrame::OnCreate`） | 访问器返回未初始化/默认值，缩放错误 | 梳理各消费者的构造/初始化时序，必要时访问器提供安全的懒加载兜底（首次调用时自行 `GetDeviceCaps`，而非假设 `CMainFrame` 一定已创建） |
| 横向/纵向 DPI 在极少数环境下不同，合并为单值会引入回归 | 极端配置下缩放比例错误 | 实现前确认现有代码是否已经在事实上假设 X=Y；若不确定，保留独立的 X/Y 两个值但仍统一到同一访问器/同一次系统调用，而非合并成一个数字 |
| 本 RFC 范围易滑向"顺手实现 WM_DPICHANGED" | 破坏"一个 RFC 一件事"，扩大回归面 | 严格执行第 4 节非目标；如实现中发现值得做，另开新 RFC，不在本 RFC 内追加 |

## 8. 决策记录

### 8.1 已做决策

1. 本 RFC 只做"来源统一"，明确排除运行时 per-monitor DPI 响应，避免范围蔓延。
2. 三个工具栏宿主复制 `m_nLogDPIY` 到自身成员变量的既有模式视为可接受，不要求它们改为直接调用统一访问器（只要求它们的复制源头唯一）。

### 8.2 待决策

1. 是否值得在本 RFC 之后开一个新 RFC 实现真正的 `WM_DPICHANGED` 响应——留待本 RFC 落地、观察是否有用户反馈跨显示器缩放问题后再评估。

## 9. 参考文献

- [RFC-0037：UI 表面现状清单](./completed/rfc-0037-ui-surface-inventory.md) 第 10 节
- `src/Source/apps/mplayerc/MainFrm.h:195`、`MainFrm.cpp:756-758`
- `src/Source/apps/mplayerc/SUIButton.h:75`、`SUIButton.cpp:42-53`
- `src/Source/apps/mplayerc/mplayerc.cpp:5028-5030`
- `src/Source/apps/mplayerc/PlayerToolBar.cpp:143`、`PlayerToolTopBar.cpp:202`、`PlayerFloatToolBar.cpp:166`

---

**下一步行动**：实施第 5 节改动，跑第 6 节 grep 验收与多 DPI 手测，通过后更新状态为完成并归档。
