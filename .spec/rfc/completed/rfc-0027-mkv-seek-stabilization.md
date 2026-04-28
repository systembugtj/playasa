# RFC-0027：MKV Seek 精确性与 H.264 预滚稳定化

| 字段 | 内容 |
|------|------|
| **状态** | 已完成 (Completed) |
| **适用范围** | `MainFrm::SeekTo`、modern FFmpeg seek flush diagnostics、MKV seek selfcheck、测试脚本迁移、主窗口/seek bar UIA provider |
| **相关 RFC** | [RFC-0024](../rfc-0024-ffmpeg-modern-island.md)、[RFC-0026](./rfc-0026-mkv-support-modernization.md)、[RFC-0028](../rfc-0028-uia-video-and-seek-followups.md) |
| **创建日期** | 2026-04-27 |
| **完成日期** | 2026-04-27 |

## 1. 摘要

本 RFC 修复 MKV seek 的用户目标时间问题，并建立 seek 回归测试基础。核心原则是：用户拖动或设置的 seek 目标必须被尊重，不能被附近 keyframe 随机覆盖；底层可以为了 H.264 正确解码使用内部预滚，但预滚不能改变用户可见目标时间。

本 RFC 也完成了测试基础设施迁移：`test*.ps1` 已从 `src\BuildScript` 迁移到 `src\Test\Scripts`，共享测试 helper 已集中到 `src\Test\Scripts\TestSupport\SplayerTestSupport.psm1`。

## 2. 已完成内容

### 2.1 保留用户目标时间

`MainFrm::SeekTo` 已调整：

1. 如果调用方要求 keyframe seek，仅保留 `AM_SEEKING_SeekToKeyFrame` 作为 DirectShow hint。
2. 不再用 `m_kfs[i]` 覆盖用户传入的 `rtPos`。
3. 增加 `SeekTo begin/end` 日志，用于确认实际目标时间。

这保证 UI 和 DirectShow seek request 的目标时间仍然是用户拖动到的位置。

### 2.2 Decoder Flush 诊断

`MPCVideoDec` 在 `NewSegment` 中 flush modern FFmpeg bridge，并记录：

```text
Modern FFmpeg bridge flush on segment: start=... stop=...
```

这用于确认 seek 后 decoder 旧参考状态和 pending frame 已被清理。

### 2.3 自动化测试

新增/迁移测试脚本：

```powershell
src\Test\Scripts\test-rfc0027-mkv-seek-selfcheck.ps1
src\Test\Scripts\test-rfc0027-uia-tree-selfcheck.ps1
src\Test\Scripts\TestSupport\SplayerTestSupport.psm1
```

`test-rfc0027-mkv-seek-selfcheck.ps1` 默认连续执行 3 次小步 seek，并检查：

1. 每次 seek 都产生新的 `SeekTo begin`。
2. 每次 seek 都产生新的 `SeekTo end`。
3. 每次 seek 都触发 `Modern FFmpeg bridge flush on segment`。
4. `SeekTo begin/end` 的 `pos` 对齐。
5. 连续小步前进时目标时间单调不回退。
6. seek 后进程存活和可选窗口响应。

### 2.4 UIA Seek Bar Contract

已为播放器增加基础 UIA provider：

1. 主窗口通过 `WM_GETOBJECT` 暴露 root provider，`AutomationId=MainWindow`。
2. `SeekBar` 作为虚拟 UIA child 暴露。
3. `SeekBar` 使用 `AutomationId=SeekBar`。
4. `SeekBar` 使用 `ControlType.Slider`。
5. `SeekBar` 支持 `RangeValuePattern`。
6. `RangeValuePattern.SetValue()` 复用现有 seek bar position 更新和 `WM_HSCROLL` seek 路径。

这让测试可以通过语义化 UIA contract 找到 seek bar，并确认后续 FlaUI 测试的基础路径可用。

## 3. 验证结果

已通过：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\dev.ps1" buildFast
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "src\Test\Scripts\test-rfc0027-uia-tree-selfcheck.ps1" -TimeoutSeconds 60 -RequireSeekBar
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "src\Test\Scripts\test-rfc0027-mkv-seek-selfcheck.ps1" -TimeoutSeconds 60 -SeekCount 3 -PostSeekSeconds 5 -CheckWindowResponding -RequireUiAutomation
```

PowerShell parser 检查也已通过。

## 4. 决策记录

1. 拖动 seek 必须实时反映视频变化。
2. 不允许为了稳定性把 UX 改成松手后才 seek。
3. 用户目标时间不能被 keyframe 时间覆盖。
4. Keyframe 只能作为内部预滚起点。
5. Seek/drag 回归测试应优先使用 UIA/FlaUI。
6. 已完成 RFC 不继续挂未完成尾巴；视频区域 provider、FlaUI 主路径和更深层 seek pre-roll 由 RFC-0028 跟踪。

## 5. 后续 RFC

剩余工作已转入：

```text
.spec/rfc/rfc-0028-uia-video-and-seek-followups.md
```

包括：

1. 视频区域 UIA provider。
2. UIA/FlaUI seek harness 主路径。
3. `BaseSplitter` decode-start 与 presentation-target 分离。
4. modern H.264 seek 目标时间前 frame drop。

## 6. 相关文件

1. `src/Source/apps/mplayerc/MainFrm.cpp`
2. `src/Source/apps/mplayerc/MainFrm.h`
3. `src/Source/apps/mplayerc/PlayerSeekBar.cpp`
4. `src/Source/apps/mplayerc/PlayerSeekBar.h`
5. `src/Source/apps/mplayerc/PlayerSeekBarUiaProvider.cpp`
6. `src/Source/apps/mplayerc/PlayerSeekBarUiaProvider.h`
7. `src/Source/apps/mplayerc/MainFrameUiaProvider.cpp`
8. `src/Source/apps/mplayerc/MainFrameUiaProvider.h`
9. `src/Source/filters/transform/mpcvideodec/MPCVideoDecFilter.cpp`
10. `src\Test\Scripts\test-rfc0027-mkv-seek-selfcheck.ps1`
11. `src\Test\Scripts\test-rfc0027-uia-tree-selfcheck.ps1`
12. `src\Test\Scripts\TestSupport\SplayerTestSupport.psm1`
