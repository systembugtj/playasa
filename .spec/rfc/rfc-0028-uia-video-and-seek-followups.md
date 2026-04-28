# RFC-0028：UIA Video Area 与 Seek 预滚后续

| 字段 | 内容 |
|------|------|
| **状态** | 提案 (Proposed) |
| **适用范围** | `ChildView` video area UIA provider、`MainFrameUiaProvider` fragment tree、FlaUI seek harness、`BaseSplitter` decode-start/presentation-target 分离、modern H.264 seek pre-roll/drop |
| **相关 RFC** | [RFC-0027](./completed/rfc-0027-mkv-seek-stabilization.md)、[RFC-0026](./completed/rfc-0026-mkv-support-modernization.md)、[RFC-0024](./rfc-0024-ffmpeg-modern-island.md) |
| **创建日期** | 2026-04-27 |
| **最后更新** | 2026-04-27 |

## 1. 摘要

RFC-0027 已完成 MKV seek 的用户目标时间修复、decoder flush 诊断、多次 seek selfcheck、测试脚本迁移，以及主窗口/seek bar 的基础 UIA provider。本 RFC 接手剩余后续项，避免已完成 RFC 继续挂未完成尾巴。

本 RFC 的目标是补齐更完整的 UI Automation tree，并继续推进 seek 的深层正确性：视频区域要能被 UIA/FlaUI 稳定识别，seek 测试要从 `WM_COMMAND` 过渡到真实 UIA `RangeValuePattern.SetValue()`，底层 splitter/decoder 要明确区分内部 decode start 与用户 presentation target。

## 2. 背景

当前已经具备：

1. 主窗口 UIA root provider：`AutomationId=MainWindow`。
2. seek bar 虚拟 UIA child：`AutomationId=SeekBar`、`ControlType.Slider`、`RangeValuePattern`。
3. `RangeValuePattern.SetValue()` 复用现有 seek bar position 更新和 `WM_HSCROLL` seek 路径。
4. `test-rfc0027-uia-tree-selfcheck.ps1 -RequireSeekBar` 已能验证 seek bar UIA contract。
5. `test-rfc0027-mkv-seek-selfcheck.ps1 -RequireUiAutomation` 已能在 seek selfcheck 中强制检查 UIA contract。

仍未完成的是视频区域 provider，以及真正用 UIA 设置 seek bar value 来替代 `WM_COMMAND` fallback。

## 3. 目标

1. 为视频区域暴露稳定 UIA element，建议 `AutomationId=VideoView`，`ControlType.Pane` 或更合适的 custom/pane 类型。
2. 让 UIA tree 中同时存在主窗口、视频区域和 `SeekBar`，供测试和辅助功能使用同一语义 contract。
3. 新增或升级测试 harness，使 seek 测试通过 UIA `RangeValuePattern.SetValue(target)` 触发真实 seek。
4. 保留 `WM_COMMAND` seek selfcheck 作为 fallback/兼容诊断，但不作为最终主要回归路径。
5. 在 splitter/decoder 层继续推进 seek pre-roll：内部 decode start 可以在目标前关键帧，presentation target 必须保持用户选择的时间。

## 4. 非目标

1. 不把 seek UX 改成松手后才 seek。
2. 不把 MKV demux 放进 video decoder。
3. 不让 keyframe 时间覆盖用户目标时间。
4. 不在本 RFC 中一次性重写全部播放器控件 UIA tree。

## 5. 设计方向

### 5.1 Video Area UIA Provider

`CChildView` 当前是视频承载窗口，DirectShow/EVR/VMR 会把 renderer 放在它下面或使用它作为 owner。应为 `CChildView` 或主窗口虚拟 child 增加 video area provider，暴露：

1. `AutomationId=VideoView`
2. 稳定 `Name`，例如 `Video view`
3. `ControlType.Pane`
4. bounding rectangle 使用 `CChildView::GetVideoRect()` 或窗口客户区转换后的屏幕坐标

实现上应优先复用 RFC-0027 新增的 provider 风格：小型 COM provider，显式 `AddRef/Release/QueryInterface`，通过 `WM_GETOBJECT` 或主窗口 root fragment 暴露。

### 5.2 UIA Seek Harness

测试脚本应增加 UIA seek 路径：

1. 启动播放器和样片。
2. 从 UIA tree 查找 `AutomationId=SeekBar`。
3. 读取 `RangeValuePattern.Minimum/Maximum/Value`。
4. 调用 `SetValue(target)`，目标取当前值之后的稳定偏移。
5. 验证 `SeekTo begin/end` 的 `pos` 与 target 接近，并验证 modern FFmpeg flush。

`WM_COMMAND` 路径保留用于兼容和快速诊断，但最终回归应优先 UIA。

### 5.3 Decode Start 与 Presentation Target

后续 seek 正确性应明确分离两个时间：

1. **Decode start time**：内部从目标前关键帧开始读取/解码，用于恢复参考帧。
2. **Presentation target time**：用户拖动或 UIA 设置的目标时间，必须保持不被 keyframe 改写。

`BaseSplitter` / output pin / `MPCVideoDec` 需要避免把这两个时间混用。modern H.264 seek 后应 drop 目标时间前的 decoded frame，只交付目标时间及之后的帧。

## 6. 验证计划

基础验证：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\dev.ps1" buildFast
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "src\Test\Scripts\test-rfc0027-uia-tree-selfcheck.ps1" -RequireSeekBar -TimeoutSeconds 60
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "src\Test\Scripts\test-rfc0027-mkv-seek-selfcheck.ps1" -RequireUiAutomation -SeekCount 3 -CheckWindowResponding -TimeoutSeconds 60
```

新增后续验证：

1. UIA tree 中存在 `AutomationId=VideoView`。
2. `VideoView` bounding rectangle 与实际视频显示区域一致。
3. UIA seek harness 使用 `RangeValuePattern.SetValue()` 触发 seek。
4. `SeekTo begin pos=...` 接近 UIA 设置目标。
5. seek 后画面不花屏、不冻结、不回退到随机 keyframe。

## 7. 待完成

1. 为视频区域实现 UIA provider，并接入主窗口 fragment tree。
2. 扩展 `test-rfc0027-uia-tree-selfcheck.ps1` 或新增 `test-rfc0028-uia-video-selfcheck.ps1`，验证 `VideoView`。
3. 新增 UIA/FlaUI seek harness，使用 `RangeValuePattern.SetValue()` 替代 `WM_COMMAND` 主路径。
4. 为 `BaseSplitter` 增加明确的 decode-start 与 presentation-target 分离。
5. 为 modern H.264 seek 增加目标时间前 frame drop。

## 8. 相关文件

1. `src/Source/apps/mplayerc/ChildView.cpp`
2. `src/Source/apps/mplayerc/ChildView.h`
3. `src/Source/apps/mplayerc/MainFrameUiaProvider.cpp`
4. `src/Source/apps/mplayerc/PlayerSeekBarUiaProvider.cpp`
5. `src/Test/Scripts/test-rfc0027-uia-tree-selfcheck.ps1`
6. `src/Test/Scripts/test-rfc0027-mkv-seek-selfcheck.ps1`
7. `src/Source/filters/parser/BaseSplitter/BaseSplitter.cpp`
8. `src/Source/filters/transform/mpcvideodec/MPCVideoDecFilter.cpp`
