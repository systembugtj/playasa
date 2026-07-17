# RFC-0026：MKV 支持现代化与 FFmpeg 正确集成设计

| 字段 | 内容 |
|------|------|
| **状态** | 已完成 (Completed) |
| **适用范围** | `MatroskaSplitter`、`BaseSplitter` packet contract、`MPCVideoDec` modern FFmpeg bridge、MKV/H264 播放验证 |
| **相关 RFC** | [RFC-0024](../rfc-0024-ffmpeg-modern-island.md)、[RFC-0025](./rfc-0025-ffmpeg-dxva-followup.md)、[RFC-0028](./rfc-0028-uia-video-and-seek-followups.md)、[RFC-0029](../rfc-0029-ffmpeg-backed-matroska-splitter-poc.md) |
| **创建日期** | 2026-04-27 |
| **完成日期** | 2026-04-27 |

## 1. 摘要

本 RFC 跟踪的短期 MKV support modernization 已完成。最终方向保持不变：decoder 不做容器 demux；现阶段修复 `MatroskaSplitter -> MPCVideoDec -> modern FFmpeg bridge` 的 packet/timing contract；长期 FFmpeg-backed Matroska Source/Splitter 已拆分到 [RFC-0029](../rfc-0029-ffmpeg-backed-matroska-splitter-poc.md)。

## 2. 已完成内容

### 2.1 Matroska 视频 duration fallback

`MatroskaSplitter` 不再对缺失 `BlockDuration` 的视频 block 输出 `rtStart + 1` 的 100ns 假时长。当前策略为：

1. 优先使用 track `DefaultDuration`。
2. 如果 output pin 队列里已有同 track 下一帧，则用下一帧 `rtStart` 推导当前 `rtStop`。
3. 如果仍无法推导，视频使用 conservative fallback `400000`（25fps 的 DirectShow 100ns 单位）。
4. subtitle 保持独立语义，不被视频 fallback 逻辑污染。
5. lacing 场景按 block count 扩展最小 duration，避免多帧 block 总 duration 过小。

### 2.2 MKV timing diagnostics

新增低容量 `MKV timing` 日志，记录 video packet 的 `start/stop/duration/blockDurationValid/lacingCount/keyframe`，用于自检和人工定位 jitter。

### 2.3 Modern FFmpeg bridge timebase

modern adapter 已统一 DirectShow `REFERENCE_TIME` 语义：

1. `AVCodecContext::pkt_timebase = {1, 10000000}`。
2. bridge 输入 `pts/duration` 使用 DirectShow 100ns 时间基。
3. 不再把 `dts = pts` 伪装为真实 DTS；无 DTS 时使用 `AV_NOPTS_VALUE`。
4. frame 输出使用 `best_effort_timestamp`，并携带 frame duration。

### 2.4 Receive pending frame loop

`MPCVideoDec` 在 `send_packet` 后会循环调用 `receive_pending`，交付当前立即可用的所有 decoded frames，避免一个 compressed packet 输出多帧时丢掉后续 frame。

### 2.5 自动化验证

新增 `src\Test\Scripts\test-rfc0026-mkv-timing-selfcheck.ps1`：

1. 启动 `splayer.exe` 播放 MKV 样本。
2. 等待并解析 `MKV timing` 日志。
3. 验证 video packet 数量达到阈值。
4. 验证每条记录 `rtStop > rtStart`。
5. 验证 duration 不再是 100ns/近零假 fallback。
6. 验证 duration 与 `stop - start` 一致。
7. 继续做短时 UI responsiveness 检查。

## 3. 验证结果

已运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "<PowerShell parser check>"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "src/Test/Scripts/test-rfc0026-mkv-timing-selfcheck.ps1" -TimeoutSeconds 60 -MinimumTimingPackets 20 -SteadyStateSeconds 3
```

结果：

```text
PARSE OK ...\src\Test\Scripts\test-rfc0026-mkv-timing-selfcheck.ps1
test-rfc0026-mkv-timing-selfcheck: OK
```

## 4. 决策记录

1. 不在 `MPCVideoDec` 内做 MKV demux。
2. 短期最高优先级是稳定现有 DirectShow packet/timing contract。
3. FFmpeg-backed MKV 支持如果继续推进，必须在 DirectShow source/splitter 层。
4. 旧 `MatroskaSplitter` 的长期替换 PoC 由 [RFC-0029](../rfc-0029-ffmpeg-backed-matroska-splitter-poc.md) 跟踪。
5. seek 后首帧与 decode-start/presentation-target 分离属于后续 seek 稳定性工作，由 [RFC-0028](./rfc-0028-uia-video-and-seek-followups.md) 跟踪。

## 5. 相关文件

1. `src/Source/filters/parser/MatroskaSplitter/MatroskaSplitter.cpp`
2. `src/Source/filters/transform/mpcvideodec/MPCVideoDecFilter.cpp`
3. `src/Source/filters/transform/mpcvideodec/modern_ffmpeg/ModernFfmpegDecodeAdapter.cpp`
4. `src/Source/filters/transform/mpcvideodec/modern_ffmpeg/ModernFfmpegBridge.cpp`
5. `src/Source/filters/transform/mpcvideodec/modern_ffmpeg/ModernFfmpegBridgeConsumer.cpp`
6. `src/Test/Scripts/test-rfc0026-mkv-timing-selfcheck.ps1`
