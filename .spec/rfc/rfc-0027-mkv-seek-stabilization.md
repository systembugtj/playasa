# RFC-0027：MKV Seek 精确性与 H.264 预滚稳定化

| 字段 | 内容 |
|------|------|
| **状态** | 提案 (Proposed) |
| **适用范围** | `MainFrm::SeekTo`、`MatroskaSplitter::DemuxSeek`、`BaseSplitter` seek/flush contract、`MPCVideoDec` modern FFmpeg bridge |
| **相关 RFC** | [RFC-0024](./rfc-0024-ffmpeg-modern-island.md)、[RFC-0026](./rfc-0026-mkv-support-modernization.md) |
| **创建日期** | 2026-04-27 |
| **最后更新** | 2026-04-27 |

## 1. 摘要

本 RFC 跟踪 MKV 播放中的 seek 修复。目标是保证用户拖动进度条时，播放器尊重用户选择的目标时间/目标帧，而不是把 UI 目标随机改写为附近 keyframe。同时，为了 H.264 解码正确，底层 splitter/decoder 可以从目标时间之前的关键帧开始预滚，但预滚属于内部解码策略，不能改变用户可见的 seek 目标。

这份 RFC 也记录一个重要 UX 约束：拖动进度条必须实时反映视频变化，不能改成松手后才 seek。任何减少 seek 频率的实现都必须保持实时反馈，且需要单独验证和确认。

## 2. 背景

RFC-0026 修复了 MKV packet duration、modern FFmpeg timebase、H.264 AVCC 到 Annex B 的边界，以及 decoder receive loop。随后暴露出新的 seek 问题：

1. 拖动进度条后，播放器可能卡住或长时间无响应。
2. seek 后 H.264 画面可能花屏，说明 decoder 可能从非参考点恢复，缺少必要参考帧。
3. 旧 `SeekTo` 逻辑会在启用 keyframe seek 时把 `rtPos` 改写成 `m_kfs[i]`，这会让用户拖动的目标时间变成附近关键帧时间，破坏“拖到哪里就看哪里”的 UX。

## 3. 目标

1. 保留实时拖动 seek 的 UX。
2. `MainFrm::SeekTo` 不改写用户目标 `rtPos`。
3. splitter 可以使用 keyframe 作为内部 seek 起点，但 DirectShow segment 和 UI 目标仍应保持用户目标时间。
4. seek 后 modern FFmpeg bridge 必须 flush，清空旧参考状态和 pending frame。
5. H.264 seek 后需要预滚到目标时间，再显示目标时间及之后的帧，避免花屏。
6. 新增自动化 seek selfcheck，至少覆盖首帧、seek begin/end、decoder flush 和 seek 后窗口响应。
7. 建立良好的 Win32 UI Automation tree，让后续测试通过语义化控件操作 seek bar，而不是依赖内部 `WM_COMMAND` 或坐标猜测。

## 4. 非目标

1. 不把拖动 seek 改成“松手才 seek”。
2. 不在 video decoder 内做 MKV demux。
3. 不用随机 keyframe 替代用户选择的目标时间。
4. 不在本 RFC 中一次性重写 `BaseSplitter` 线程模型。

## 5. 当前修复

### 5.1 保留用户目标时间

`MainFrm::SeekTo` 的 keyframe seek 逻辑已调整为：

1. 如果调用方要求 keyframe seek，保留 `AM_SEEKING_SeekToKeyFrame` 标志。
2. 不再用 `m_kfs[i]` 覆盖用户传入的 `rtPos`。
3. 记录 `SeekTo begin/end` 日志，用于测试和现场诊断。

这保证 UI 和 DirectShow seek request 的目标时间仍然是用户拖动到的时间。

### 5.2 Decoder flush 诊断

`MPCVideoDec` 在 `NewSegment` 中 flush modern FFmpeg bridge，并记录：

```text
Modern FFmpeg bridge flush on segment: start=... stop=...
```

这可以确认 seek 后 decoder 旧状态被清空。

### 5.3 自动化测试

新增：

```powershell
src\BuildScript\test-rfc0027-mkv-seek-selfcheck.ps1
src\BuildScript\test-rfc0027-uia-tree-selfcheck.ps1
```

该脚本启动 MKV 样本，等待 modern FFmpeg 首帧，通过 `WM_COMMAND` 触发真实播放器 seek，然后检查：

1. `SeekTo begin`
2. `SeekTo end`
3. `Modern FFmpeg bridge flush on segment`
4. seek 后进程存活和可选窗口响应

当前 seek 脚本是过渡测试，默认使用 `WM_COMMAND` 触发 seek，并已支持 `-RequireUiAutomation` 来强制检查 `SeekBar` 的 UIA contract。`test-rfc0027-uia-tree-selfcheck.ps1` 用于单独检查播放器窗口 UIA root，并可通过 `-RequireSeekBar` 强制验收 `AutomationId=SeekBar` / `ControlType.Slider` / `RangeValuePattern`。长期自动化测试必须改为 UIA/FlaUI 路径，直接操作播放器暴露的 seek bar automation element，确保测试覆盖真实用户交互。

现有 `src\BuildScript\test*.ps1` 已迁移到共享测试模块：

```powershell
src\BuildScript\TestSupport\SplayerTestSupport.psm1
```

该模块集中管理 MSBuild/MSYS2 查找、文件断言、splayer 启停、日志等待、窗口响应检查、Win32 command fallback 和 UIA 查询，避免每个 smoke test 维护各自的重复实现。

### 5.4 UI Automation 测试 contract

播放器需要为 Win32/MFC 自绘控件提供稳定 UIA tree，至少包含：

1. 主窗口：稳定 `AutomationId`，Name 可本地化但不作为测试唯一选择器。
2. 视频区域：暴露为可识别的 pane/custom element，用于确认窗口结构和截图范围。
3. Seek bar：暴露为 `ControlType.Slider`，稳定 `AutomationId=SeekBar`。
4. Seek bar 支持 `RangeValuePattern`：`Minimum=0`、`Maximum=duration`、`Value=current position`。
5. 播放/暂停、停止、音量等核心控件：暴露稳定 `AutomationId`，避免测试依赖皮肤图片或菜单文本。

RFC-0027 的 seek 回归测试在 UIA tree 可用后应迁移到 FlaUI：

1. 启动 `splayer.exe`。
2. 通过 UIA 找到主窗口和 `SeekBar`。
3. 使用 `RangeValuePattern.SetValue(target)` 或 UIA 支持的真实 slider 操作触发 seek。
4. 断言日志中出现 `SeekTo begin/end` 和 `Modern FFmpeg bridge flush on segment`。
5. 断言窗口持续响应，且拖动/设置进度时视频实时更新。

## 6. 后续设计：预滚但不改写目标

正确的 H.264 seek 应分成两个时间：

1. **Decode start time**：目标时间之前的关键帧，用来恢复参考帧。
2. **Presentation target time**：用户拖动选择的目标时间。

短期实现方向：

1. `MatroskaSplitter::DemuxSeek(target)` 从不晚于 `target` 的 cue/keyframe 开始读取。
2. `BaseSplitter` / output pin 的 new segment 仍表达用户目标 `target`，不能被 keyframe 起点替代。
3. `MPCVideoDec` flush 后解码预滚帧，但目标时间之前的 decoded frame 不交给 renderer。
4. 第一帧显示应是 `pts >= target` 的帧，或最接近目标的可显示帧。

## 7. 风险

1. `BaseSplitter` 当前把 `m_rtStart` 同时用于 demux seek、new segment 和 packet timestamp normalization，预滚需要避免破坏这些隐含关系。
2. H.264 B-frame 没有真实 DTS，预滚和显示时间必须依赖 PTS/best effort timestamp。
3. 连续拖动会触发多次 seek/flush，后续如果做合并或取消旧 seek，必须保持实时画面反馈，不能等松手。
4. 旧 EVR/DirectShow renderer 对 flush/new segment 顺序敏感，改动需要小步验证。

## 8. 验证

基础验证：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "src\BuildScript\build-rfc0024-ffmpeg-bridge.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\dev.ps1" buildFast
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "src\BuildScript\test-rfc0024-splayer-selfcheck.ps1" -SteadyStateSeconds 30 -AllowedUnresponsiveSeconds 5 -CheckWindowResponding -TimeoutSeconds 60
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "src\BuildScript\test-rfc0027-mkv-seek-selfcheck.ps1" -CheckWindowResponding
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "src\BuildScript\test-rfc0027-uia-tree-selfcheck.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "src\BuildScript\verify-rfc0024-ffmpeg-modern.ps1"
```

UIA/FlaUI 验证目标：

1. UIA tree 中存在主窗口、视频区域和 `SeekBar`。
2. `SeekBar` 的 `RangeValuePattern.Value` 与播放器当前播放位置一致。
3. 设置 `SeekBar` 的 value 会触发真实 `SeekTo`，日志中的目标 `pos` 与设置值一致。
4. 测试不使用内部 command id 作为最终回归路径。
5. 坐标拖动只作为 fallback，不作为主要验证方式。

手动验证：

1. 打开真实问题 MKV。
2. 拖动进度条时画面应实时变化。
3. 松手后不应卡死。
4. seek 后画面不应持续花屏。
5. 日志中 `SeekTo begin pos=...` 的 `pos` 应接近用户拖动目标，而不是被替换为附近 keyframe。

## 9. 决策记录

### 已确认

1. 拖动 seek 必须实时反映视频变化。
2. 不允许为了稳定性把 UX 改成松手后才 seek。
3. 用户目标时间不能被 keyframe 时间覆盖。
4. Keyframe 只能作为内部预滚起点。
5. Seek/drag 回归测试应优先使用 UIA/FlaUI。
6. 需要为自绘 Win32 控件提供良好的 UIA tree，以便测试和辅助功能共享同一语义 contract。

### 待完成

1. 为 `BaseSplitter` 增加明确的 decode-start 与 presentation-target 分离。
2. 为 modern H.264 seek 增加目标时间前 frame drop。
3. 扩展 `test-rfc0027-mkv-seek-selfcheck.ps1`，加入多次连续 seek 和日志时间单调检查。
4. 为主窗口、视频区域和 seek bar 实现 UIA provider / `WM_GETOBJECT` 支持。
5. 新增 FlaUI 测试 harness，替代当前 `WM_COMMAND` seek selfcheck。当前 PowerShell 测试支持层已提供 UIA contract selfcheck 和 `WM_COMMAND` fallback。

## 10. 相关文件

1. `src/Source/apps/mplayerc/MainFrm.cpp`
2. `src/Source/filters/parser/MatroskaSplitter/MatroskaSplitter.cpp`
3. `src/Source/filters/parser/BaseSplitter/BaseSplitter.cpp`
4. `src/Source/filters/transform/mpcvideodec/MPCVideoDecFilter.cpp`
5. `src/BuildScript/test-rfc0027-mkv-seek-selfcheck.ps1`
6. `src/BuildScript/test-rfc0027-uia-tree-selfcheck.ps1`
7. `src/BuildScript/TestSupport/SplayerTestSupport.psm1`
8. `src/Source/apps/mplayerc/PlayerSeekBar.cpp`
9. `src/Source/apps/mplayerc/ChildView.cpp`
