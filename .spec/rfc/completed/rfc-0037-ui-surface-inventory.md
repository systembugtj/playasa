# RFC-0037：UI 表面现状清单

| 字段 | 内容 |
|------|------|
| **状态** | 完成 (Completed) |
| **类型** | Atomic（父级 [RFC-0036](../rfc-0036-mfc-ui-modernization.md)；本 RFC 只交付一份现状清单文档，不改动源码） |
| **父 RFC** | [RFC-0036](../rfc-0036-mfc-ui-modernization.md) |
| **适用范围** | `src/Source/apps/mplayerc/`（`MainFrm.*`、`ChildView.*`、`PlayerToolBar.*`、`PlayerToolTopBar.*`、`PlayerFloatToolBar.*`、`SVPSliderCtrl.*`、`VolumeCtrl.*`、`SUIButton.*`、`SkinPreviewDlg.*`、`UserInterface/Dialogs/`、`UserInterface/Renderer/`、`Model/ThemePkg.*`）——仅盘点，不修改 |
| **相关 RFC** | [RFC-0036](../rfc-0036-mfc-ui-modernization.md)（父级）、[RFC-0028](./rfc-0028-uia-video-and-seek-followups.md) |
| **创建日期** | 2026-07-17 |
| **最后更新** | 2026-07-17 |
| **同级子 RFC（据本清单在 RFC-0036 下开出）** | [RFC-0038](../rfc-0038-playertooltopbar-hover-leave-fix.md)、[RFC-0039](../rfc-0039-suibutton-hover-reliability.md)、[RFC-0040](../rfc-0040-native-control-keyboard-focus-visuals.md)、[RFC-0041](../rfc-0041-skin-theme-consistency-cleanup.md)、[RFC-0042](../rfc-0042-dpi-cache-consolidation.md)、[RFC-0043](../rfc-0043-customizefontdlg-drawitem-states.md) |

## 1. 摘要

[RFC-0036](../rfc-0036-mfc-ui-modernization.md) 是 MFC/Win32 UI 现代化的父级 Umbrella RFC，本身不交付任何实现。本 RFC 是其第一个子 RFC，交付物是一份 UI 表面现状清单，覆盖现有对话框、工具栏、自定义控件与皮肤/主题资源，标注每个表面是否 DPI 感知、是否走主题机制、已知绘制/布局/可访问性问题。清单已完成（第 6-9 节），并据此在 RFC-0036 下开出 6 个具体、可独立实施的子 RFC（RFC-0038～0043，见上表）。

**本 RFC 未修改任何源码**，唯一交付物是本清单文档；具体修复由各子 RFC 承担。

## 2. 背景

1. 现有 UI 代码分布在多个类（工具栏、滑块、音量控件、皮肤预览、主题包）中，此前缺少一份现状清单。
2. 皮肤/主题相关颜色、字体、图标来源不统一。
3. 没有清单时，后续子 RFC 容易范围重叠或遗漏表面。

## 3. 目标（已达成）

1. 遍历 RFC-0036 适用范围内的 UI 相关类，逐个记录：文件、职责、DPI 感知情况、主题机制使用情况、已知问题、代码量级。✅ 见第 6-9 节。
2. 基于清单产出「建议的子 RFC 列表」。✅ 见第 10 节，并已据此创建 RFC-0038～0043。

## 4. 非目标

1. 不修改任何源码、资源文件或工程文件——严格遵守，本 RFC 期间零源码改动。
2. 不在本 RFC 中定义具体改进方案——具体方案已移入对应子 RFC。

## 5. 方法

1. 搜索 `src/Source/apps/mplayerc/` 下继承 `CWnd`/`CDialog`/`CToolBar` 等 MFC 基类的类，以及 `UserInterface/Dialogs/`、`UserInterface/Renderer/` 下的文件。
2. 对每个文件/类检查 DPI 相关代码模式（`GetDpiForWindow`、`MulDiv`、`GetDeviceCaps(LOGPIXELSX/Y)`、`WM_DPICHANGED`）、主题查找调用（`GetColorFromTheme` vs. 硬编码 `RGB()`）、`OnPaint`/`DrawItem` 状态完整性（`ODS_SELECTED/DISABLED/FOCUS`、`TrackMouseEvent`/`WM_MOUSELEAVE`、双缓冲）、UIA/MSAA 覆盖范围。
3. 记录发现，不做任何修改。

## 6. 现状清单：核心自定义控件/窗口

> 「主题机制」= 调用 `AppSettings::GetColorFromTheme(...)`（`mplayerc.h:688`、`mplayerc.cpp:4739`，运行时解析 `skins\<skinname>\ui.ini`）。`Model/ThemePkg.{h,cc}` **不是**颜色查找 API——其 4 个方法（`ReadThemeFromDir`/`ReadThemeFromPkg`/`WriteThemeToDir`/`WriteThemeToPkg`，`ThemePkg.h:8-11`）全部是未实现的桩（`ThemePkg.cc:4-33`，只置标志位后 `return false`），仓内除 `Controller/ThemePkgController` 外无人调用。字体没有对应的主题查找 API；`GetSystemFontWithScale()`（`mplayerc.cpp:5028`）或直接 `CreateFontIndirect`/`LOGFONT` 字面量（如 `PlayerToolBar.cpp:123-135` 硬编码 `"Comic Sans MS"`）。

| 文件/类 | 职责 | DPI 感知 | 主题机制 | 已知问题 | 规模 |
|---|---|---|---|---|---|
| `MainFrm.h/.cpp`（`CMainFrame`） | 顶层框架：菜单/工具栏/状态栏、窗口边框自绘、全屏、UIA 挂载 | 部分：`OnCreate` 中 `GetDeviceCaps(LOGPIXELSY)` 缓存进 `m_nLogDPIY`（`MainFrm.cpp:756-758`），无 `WM_DPICHANGED`；非客户区大量原始 `GetSystemMetrics` 像素计算（`MainFrm.cpp:13624,13686,13735-13777` 等） | 混合：`GetColorFromTheme` 用 9 处，同时有 5 处裸 `RGB()` 和 1 处裸 `CreateFont` | `OnPaint`（`MainFrm.cpp:13434`）因 `if (!s.bAeroGlass \|\| 1) return;`（line 13445）而**死代码**，其后约 120 行 Aero-glass 自绘路径永远不可达；`OnDrawItem`（`MainFrm.cpp:631-636`）是仅调用 `__super` 的空壳，唯一自定义菜单绘制调用被注释掉（line 634）；持有本仓唯一 UIA 根（`OnGetObject`，`MainFrm.cpp:595`） | 大（16,051 行）——god-object，任何改动须窄范围拆分 |
| `ChildView.h/.cpp`（`CChildView`） | 视频区子窗口：logo/idle 背景、纯音频封面+歌词、悬浮 `CSUIButton` 覆盖层 | 部分：本文件无 DPI API；缩放依赖 `CSUIButton::CountDPI()` 与 `GetSystemFontWithScale()`（`ChildView.cpp:589-590`） | 是（背景/文字）：`GetColorFromTheme("MainBackgroundColor",0)`（line 326）、`GetColorFromTheme("AudioOnlyInfoText",0xffffff)`（line 424），非主题路径回退硬编码 `0x363636`/歌词 RGB（line 416,419） | `OnPaint`（line 297-441）已双缓冲（`CMemoryDC`，line 317）；自身**无** hover/pressed/disabled/focus 状态区分（全权委托 `CSUIButton::m_stat`）；`OnSetFocus`（line 455-457）空壳，无焦点视觉反馈；RFC-0028 的 UIA provider 是外部包装（`PlayerVideoViewUiaProvider`），本文件零 UIA 代码 | 中（826 行） |
| `PlayerToolBar.h/.cpp`（`CPlayerToolBar`） | 底部播放工具栏：传输按钮、音量、时间文本、广告条 | 部分：`CalcFixedLayout` 用 `m_nHeight * m_nLogDPIY / 96`（line 301），legacy 系统 DPI | 混合：`GetColorFromTheme("ToolBarBG"/"ToolBarTimeText")`（line 350,368）仅在 `ID_SKIN_FIRST` 分支；`else` 分支直接贴皮肤位图（line 354-362），完全绕过主题色 | `OnPaint`（line 320-423）双缓冲正确；`OnMouseMove` 正确调用 `_TrackMouseEvent`（line 754-758）且 `ON_WM_MOUSELEAVE()` 已注册（line 279）——本类悬停跟踪正确；`OnNcPaint`（line 453-461）空壳 | 中大（1,531 行） |
| `PlayerToolTopBar.h/.cpp`（`CPlayerToolTopBar`） | 顶部覆盖条：窗口控制按钮、圆角区域 | 部分：`m_nLogDPIY` 从 `CMainFrame` 复制（line 202） | 混合：`GetColorFromTheme("TopToolBarBG"/"TopToolBarBorder")`（line 416-417,439）仅 `ID_SKIN_FIRST` 分支；默认 `RGB(61,65,69)`/`RGB(89,89,89)` 是唯一路径（自定义皮肤位图激活时） | `OnPaint`（line 394-452）双缓冲正确；**Bug**：`ON_WM_MOUSELEAVE()` 已注册（line 60）且 `OnMouseLeave`已实现（line 749-756），但 `OnMouseMove`（line 603-650）**从未调用 `TrackMouseEvent`**（grep 确认零匹配）——leave 事件不可靠触发 → **RFC-0038** | 中（985 行） |
| `PlayerFloatToolBar.h/.cpp`（`CPlayerFloatToolBar`） | 浮动/无边框工具栏宿主（Aero 分离模式） | 部分：`GetUIHeight()` 用 `m_nLogDPIY`（line 137） | 无：零 `GetColorFromTheme`/`RGB()`，无自定义 `OnPaint` | 无自绘，无状态完整性问题；`OnMouseMove`（line 171-192）无 `ON_WM_MOUSELEAVE()`/`TrackMouseEvent`（当前无悬停敏感外观，暂不构成缺陷） | 小（300 行） |
| `SVPSliderCtrl.h/.cpp`（`CSVPSliderCtrl`） | 自绘滑块基类（子类化 `CSliderCtrl`），`CSUIButton` 滑块 | 无：本文件无 DPI API | 是：`colorBackGround = GetColorFromTheme("FloatDialogBG",0x00)`（line 22） | `OnPaint`（line 52-127）双缓冲正确；无 hover/disabled/focus 状态区分，无键盘焦点视觉 → **RFC-0040** | 小（317 行） |
| `VolumeCtrl.h/.cpp`（`CVolumeCtrl`） | 音量滑块，`NM_CUSTOMDRAW` 自绘 | 无：`DeflateRect(8,4,10,11)`（line 163）等硬编码像素 | 无：仅用 `GetSysColor(COLOR_3DSHADOW/3DHILIGHT/3DFACE)`（line 165-193），非皮肤机制 | `OnNMCustomdraw` 不区分 hover/pressed；**显式抑制**焦点框：`pNMCD->uItemState &= ~CDIS_FOCUS;`（line 202）→ 键盘用户零焦点反馈 → **RFC-0040** | 小（299 行） |
| `SUIButton.h/.cpp`（`CSUIButton`/`CSUIBtnList`） | 共享位图按钮引擎（被 ChildView/PlayerToolBar/PlayerToolTopBar/SVPSliderCtrl 复用），4 态精灵表渲染，含 `CMemoryDC` 双缓冲基类 | 部分：`CountDPi()` 用文件级 static 全局 `nLogDPIX/nLogDPIY`（`SUIButton.h:75`），首次构造时取 `GetDeviceCaps`（`SUIButton.cpp:42-53`），进程生命周期内不刷新 | 无：零 `GetColorFromTheme`，色彩全部 `NEWUI_COLOR_*` `RGB()` 宏（`SUIButton.h:11-16`） | 正向：4 态模型完整（`m_stat`，`SUIButton.h:88`；`OnHitTest`，`SUIButton.cpp:94-130`）；**缺口**：hover（`m_stat==1`）由宿主窗口 `OnMouseMove`+`OnHitTest` 轮询设置，不用 `TrackMouseEvent`，宿主自身 mouse-leave 若失效（如 PlayerToolTopBar）则按钮悬停状态不可靠 → **RFC-0039**；按钮非独立 HWND，无键盘焦点、无 UIA/MSAA 身份（屏幕阅读器看不到"播放"/"音量"等独立元素） | 中（795 行）——最高杠杆的复用组件 |
| `SkinPreviewDlg.h/.cc` | 皮肤浏览/选择/删除对话框 | N/A（依赖对话框模板，无显式 DPI 处理） | 无：零 `GetColorFromTheme`/`RGB()`，纯系统色控件 | 无自绘；具讽刺意味——皮肤预览界面本身不使用皮肤色彩机制 → **RFC-0041** | 小（404 行） |
| `Model/ThemePkg.h/.cc` | 皮肤打包/解包（非颜色查找） | N/A | N/A | 4 个方法全部未实现桩，仅置标志位 `return false`（`ThemePkg.cc:4-33`），易与 `AppSettings::GetColorFromTheme` 混淆 → **RFC-0041** | 小（53 行） |

## 7. `UserInterface/Dialogs/` 清单（20 文件）

| 文件 | 职责 | OnPaint/DrawItem |
|---|---|---|
| `CustomizeFontDlg.h/.cpp` | 字幕字体定制（字体/大小/描边/阴影/颜色 + 实时预览） | **DrawItem** 有（line 88-125），但**不检查 `lpdis->itemState`**——色块按钮无 selected/disabled/focus 视觉区分 → **RFC-0043** |
| `DhtmlDlgBase.h/.cc` | DHTML 宿主对话框共享基类 | 无（内容由内嵌 HTML 引擎绘制） |
| `MovieComment_Win.h/.cc` | 影片分享/评论 DHTML 覆盖窗口 | 无 |
| `OAuthDlg.h/.cc` | OAuth 登录 DHTML 对话框 + `CircleBtn` 圆形关闭按钮 | `CircleBtn::OnPaint`（line 94-105）正确切换 hover 位图且正确调用 `TrackMouseEvent`（line 88）——本仓表现最佳的悬停控件 |
| `OptionAdvancedPage_Win.h/.cc` | 选项-高级页 | 无 |
| `OptionAssociationPage_Win.h/.cc` | 选项-文件关联页 | 无 |
| `OptionBasicPage_Win.h/.cc` | 选项-基本页 | 无 |
| `OptionDlg_Win.h/.cc` | 选项属性表容器 | 无 |
| `OptionSubtitlePage_Win.h/.cc` | 选项-字幕样式页 | DrawItem 委托给 `m_subtitlestyle.DrawItem`（超出本清单范围的 `SubtitleStyle.cc`，同样无 `ODS_*` 检查） |
| `Snapshot_FloatTip.h/.cpp` | 空占位类（无成员），`.cpp` 仅 1 行 | N/A——疑似废弃脚手架 |
| `Snapshot_Viewfinder.h/.cc` | 截图裁剪取景器状态机（纯逻辑，无自绘） | 无（委托 `Snapshot_Win`） |
| `Snapshot_Win.h/.cc` | 截图/裁剪对话框 | `OnPaint`（line 122）经 GDI+ |

## 8. `UserInterface/Renderer/` 清单（18 文件，媒体库/播放列表相关）

| 文件 | 职责 | OnPaint/DrawItem |
|---|---|---|
| `LayeredWindowUtils_Win.h` | 分层窗口合成 CRTP mixin | 提供绘制基础设施，本身无 `OnPaint` |
| `ListBlocks.h/.cc` | 媒体中心 tile 布局管理 | `DoPaint(...)`（委托 `UILayerBlock`） |
| `MediaCenterView.h/.cc` | 媒体中心网格视图窗口 | `OnPaint`（line 54） |
| `MediaListView.h/.cc` | 媒体 tile 网格：布局/选中框 | `OnPaint`（line 189）+ `DrawItem`（line 104，自定义签名，非标准 owner-draw），无 `ODS_*` 检查 |
| `MediaScrollbar.h/.cc` | 媒体网格自定义滚动条 | `OnPaint`（line 116） |
| `OSDView_Win.h/.cc` | OSD 覆盖窗口（分层窗口） | 无 `WM_PAINT`，经 `DoLayeredPaint` |
| `PlaylistView_MfcProxy.h/.cc` | MFC 停靠栏宿主代理 | 无（纯布局代理） |
| `PlaylistView_Win.h/.cc` | 播放列表面板 | `OnPaint`（line 61，`WTL::CMemoryDC` 双缓冲）+ `DrawItem`（line 124-160+，**检查 `ODS_SELECTED`**，line 134——本仓 owner-draw 状态感知最完整实现，仍缺 `ODS_DISABLED`/`ODS_FOCUS`） |
| `UILayer.h/.cc` | 单一纹理/位图层 | `DoPaint(...)`（虚方法，宿主调用） |
| `UILayerBlock.h/.cc` | 媒体中心 tile 的 `UILayer` 集合 | `DoPaint(...)`（委托子层） |

## 9. UIA/MSAA 覆盖范围（跨文件汇总）

RFC-0028 的 UIA 覆盖**不限于** `ChildView`：
- `CMainFrameUiaProvider`（UIA 根，`MainFrm.cpp:595-606` 的 `OnGetObject` 返回）
- `CPlayerVideoViewUiaProvider`（包装 `CChildView`）
- `CPlayerSeekBarUiaProvider`（包装 `CPlayerSeekBar`，可独立响应自身 `WM_GETOBJECT`，`PlayerSeekBar.cpp:274`）

**未覆盖**：`PlayerToolBar`、`PlayerToolTopBar`、`VolumeCtrl`、`SVPSliderCtrl`、`SkinPreviewDlg`、以及全部 `CSUIButton` 实例——底部/顶部工具栏按钮对屏幕阅读器结构性不可见（不只是缺少标签，而是根本不存在对应 UIA/MSAA 元素）。此项体量较大且依赖 RFC-0039 的状态引擎调整先行，暂不在本轮子 RFC 中处理，记录为 RFC-0036 未来 backlog。

## 10. DPI 现状汇总与建议子 RFC

仓库范围内零处使用 `GetDpiForWindow`/`AdjustWindowRectExForDpi`/`WM_DPICHANGED`。DPI 缓存存在 **3 处独立副本**，各自调用 `GetDeviceCaps`：`CMainFrame::m_nLogDPIY`（`MainFrm.cpp:756-758`）、`SUIButton.cpp` 文件级 static `nLogDPIX/nLogDPIY`（line 42-53）、`GetSystemFontWithScale()` 内部（`mplayerc.cpp:5029-5030`）。三者互不同步，未来若引入 per-monitor DPI 感知，需要同时改三处 → **RFC-0042**。

**已开出的子 RFC**（本清单直接产出，均为具体、可独立实施/回滚的修复）：

| 子 RFC | 范围 | 体量 |
|---|---|---|
| RFC-0038 | `PlayerToolTopBar` 悬停/mouse-leave 修复 | 小，定位明确 |
| RFC-0039 | `CSUIButton` 悬停可靠性（`TrackMouseEvent` 化） | 中，惠及 4 个表面 |
| RFC-0040 | `VolumeCtrl`/`SVPSliderCtrl` 键盘焦点视觉 | 小 |
| RFC-0041 | 皮肤/主题一致性清理（`SkinPreviewDlg` 接入主题 + `ThemePkg` 死代码处置） | 小 |
| RFC-0042 | DPI 缓存统一（3 处独立副本 → 单一来源 + `WM_DPICHANGED` 基础设施） | 中，跨 5 个文件 |
| RFC-0043 | `CustomizeFontDlg` `DrawItem` 状态完整性 | 小 |

**暂不开 RFC，记录为 RFC-0036 未来 backlog**（体量过大或依赖上述子 RFC 先行）：
- `MainFrm` god-object 拆分（16,051 行；`OnPaint` 死代码、`OnDrawItem` 空壳、DPI/主题混用需先各自独立拆分）。
- `PlayerToolBar` 主题一致性（`else` 皮肤位图分支绕过主题色）与可访问性——体量大，需单独 RFC，暂不与本轮合并。
- 工具栏按钮 UIA 可访问性（`CSUIButton` 逐按钮 UIA 身份）——依赖 RFC-0039 落地后再评估范围。

## 11. 决策记录

### 11.1 已做决策

1. 本 RFC 是 RFC-0036 的第一个子 RFC，编号 RFC-0037，交付物仅为清单文档，未改动源码。
2. 清单已完成并归档；据此创建 RFC-0038～0043 六个具体子 RFC。
3. MainFrm 拆分、PlayerToolBar 全面主题化、工具栏按钮 UIA 可访问性识别为体量过大/有依赖，暂记入 RFC-0036 backlog，不在本轮创建 RFC。

## 12. 参考文献

- [RFC-0036：MFC/Win32 UI 现代化（父级）](../rfc-0036-mfc-ui-modernization.md)
- `.cursor/skills/mfc-ui-modernization/SKILL.md`
- [ROADMAP.md](../../ROADMAP.md)

---

**完成证据**：第 6-9 节清单覆盖 RFC-0036 适用范围列出的全部文件（核心控件 11 项 + Dialogs 12 项 + Renderer 10 项），每行含 DPI/主题/问题标注与具体文件行号证据。第 10 节据此产出 6 个子 RFC，已创建（RFC-0038～0043）。
