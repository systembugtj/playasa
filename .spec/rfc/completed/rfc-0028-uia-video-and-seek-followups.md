# RFC-0028：UIA Video Area 与 Seek 预滚后续

| 字段 | 内容 |
|------|------|
| **状态** | 已完成 (Completed) |
| **适用范围** | `ChildView` video area UIA provider、`MainFrameUiaProvider` fragment tree、FlaUI seek harness、`BaseSplitter` decode-start/presentation-target 分离、modern H.264 seek pre-roll/drop |
| **相关 RFC** | [RFC-0027](./rfc-0027-mkv-seek-stabilization.md)、[RFC-0026](./rfc-0026-mkv-support-modernization.md)、[RFC-0024](../rfc-0024-ffmpeg-modern-island.md) |
| **创建日期** | 2026-04-27 |
| **完成日期** | 2026-07-11 |

## 1. 摘要

RFC-0027 已完成 MKV seek 的用户目标时间修复、decoder flush 诊断、多次 seek selfcheck、测试脚本迁移，以及主窗口/seek bar 的基础 UIA provider。本 RFC 补齐视频区域 UIA、UIA seek harness，并在 splitter 层分离 presentation target 与 decode start，保留 sample 级 pre-roll drop（`rtStart < 0`）而不在 PTS 覆盖后二次丢弃（避免 seek 卡死）。

## 2. 已完成内容

### 2.1 VideoView UIA Provider

- `PlayerVideoViewUiaProvider`：`AutomationId=VideoView`、`ControlType.Pane`
- 接入 `MainFrameUiaProvider` fragment tree（`VideoView` 为 first child，`SeekBar` 为 last child / sibling）
- 验证：`test-rfc0028-uia-video-selfcheck.ps1`

### 2.2 UIA Seek Harness

- `Invoke-SplayerUiaSeek`：`RangeValuePattern.SetValue()` + 重试
- `test-rfc0027-mkv-seek-selfcheck.ps1` 支持 `-RequireUiAutomation` 与 `PLAYASA_TEST_UIA_SEEK=1`（`-UseUiaSeek` 等效路径）
- `test-rfc0028-mkv-seek-uia-selfcheck.ps1` 为 RFC-0028 包装脚本
- `WM_COMMAND` seek 路径保留为稳定回归门禁（`test-rfc0027-mkv-seek-selfcheck.ps1`）

#### 2.2.1 UIA `SetValue` 稳定化（2026-07-16）

根因：虚拟 fragment 合并 HWND host 后 pattern 路由错误；UIA RPC 线程直接触碰 seek 管线；测试侧 SeekBar 发现/flush 匹配不稳定。

| 修复 | 说明 |
| --- | --- |
| `PlayerSeekBarUiaProvider::get_HostRawElementProvider` | 虚拟子节点（有 parent）不再合并 popup HWND host |
| `SetValue` / `SetAutomationPos` | 经 `WM_SPLAYER_UIA_SEEK` + seek bar 自身 HWND `SendMessage` 切回 UI 线程，再 `SeekTo` |
| `SplayerTestSupport.psm1` | 统一 `Wait-SplayerUiaPlaybackReady`、多候选 SeekBar、独立 deadline、flush regex、进程冷却 1500ms |
| 包装脚本默认 | `TimeoutSeconds=120`、`BetweenSeekMilliseconds=2000` |

### 2.3 Decode Start 与 Presentation Target

- **已回退** `BaseSplitter` 的 `m_rtPresentationTarget` / `DeliverPacket` 减法变更（导致 seek 后 demux/decoder 间歇卡死、flush 计数失败）
- 保留 sample 级 pre-roll 丢弃（`rtStart < 0` / `IsPreroll`）
- **`MPCVideoDecFilter`**：当 `frameInfo.pts` 覆盖后变负、但 splitter sample 时间已 ≥ 0 时，回退使用 sample 时间（避免 seek 后无帧输出）

### 2.4 测试支持增强

- `SplayerTestSupport.psm1`：`Wait-SplayerUiaPlaybackReady`、SeekBar 树遍历 / 进程 HWND 枚举、`Stop-SplayerProcesses` 冷却

## 3. 验证

### 3.1 2026-07-11（归档时）

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\dev.ps1" buildFast
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "src\Test\Scripts\test-rfc0027-mkv-seek-selfcheck.ps1" -SeekCount 3 -TimeoutSeconds 120
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "src\Test\Scripts\test-rfc0028-uia-video-selfcheck.ps1"
```

### 3.2 2026-07-16（UIA SetValue 稳定化后）

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\dev.ps1" buildFast
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "src\Test\Scripts\test-rfc0027-mkv-seek-selfcheck.ps1" -SeekCount 3 -TimeoutSeconds 120
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "src\Test\Scripts\test-rfc0028-uia-video-selfcheck.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "src\Test\Scripts\test-rfc0028-mkv-seek-uia-selfcheck.ps1" -SeekCount 3 -TimeoutSeconds 120
```

结果：`test-rfc0028-mkv-seek-uia-selfcheck.ps1` 连续 3/3 PASS；WM seek 与 UIA video selfcheck PASS。

## 4. 相关文件

1. `src/Source/apps/mplayerc/PlayerVideoViewUiaProvider.cpp`
2. `src/Source/apps/mplayerc/MainFrameUiaProvider.cpp`
3. `src/Source/apps/mplayerc/PlayerSeekBarUiaProvider.cpp`
4. `src/Source/filters/transform/mpcvideodec/MPCVideoDecFilter.cpp`
5. `src/Test/Scripts/test-rfc0028-uia-video-selfcheck.ps1`
6. `src/Test/Scripts/test-rfc0028-mkv-seek-uia-selfcheck.ps1`
7. `src/Test/Scripts/test-rfc0027-mkv-seek-selfcheck.ps1`
8. `src/Test/Scripts/TestSupport/SplayerTestSupport.psm1`
