# RFC-0026：MKV 支持现代化与 FFmpeg 正确集成设计

| 字段 | 内容 |
|------|------|
| **状态** | 提案 (Proposed) |
| **适用范围** | `MatroskaSplitter`、`BaseSplitter` packet contract、`MPCVideoDec` modern FFmpeg bridge、MKV/H264 播放验证 |
| **相关 RFC** | [RFC-0024](./rfc-0024-ffmpeg-modern-island.md)、[RFC-0025](./rfc-0025-ffmpeg-dxva-followup.md) |
| **创建日期** | 2026-04-27 |
| **最后更新** | 2026-04-27 |

## 1. 摘要

当前 MKV 播放虽然已经可以通过 modern FFmpeg bridge 输出首帧，但实际播放仍然表现为抖动、跳变、时序异常和不稳定。根因不是单个 decoder crash，而是 MKV splitter、H264 packet 格式、DirectShow sample timing 和 modern FFmpeg decoder 之间的 contract 不完整。

本 RFC 跟踪 MKV 支持现代化。设计原则是：**decoder 不做容器 demux**；如果使用 `libavformat` 处理 MKV，必须作为 DirectShow source/splitter 层实现，而不能塞进 `MPCVideoDec`。短期先修 `MatroskaSplitter -> MPCVideoDec` 的 packet/timing contract；长期再评估 FFmpeg-backed Matroska Source/Splitter。

## 2. 背景

### 2.1 当前链路

当前 MKV 播放链路是：

```text
Async Reader / Matroska Source
  -> CMatroskaSplitterFilter
  -> compressed video IMediaSample
  -> CMPCVideoDecFilter
  -> playasa_ffmpeg_modern_bridge.dll
  -> EVR / renderer
```

`CMatroskaSplitterFilter` 是自研 EBML/Matroska parser，不是 `libavformat`。它负责解析 Track、Cluster、Block、BlockDuration、CodecPrivate，并通过 DirectShow output pin 交付压缩视频、音频和字幕样本。

`MPCVideoDec` 是 transform decoder，只应该消费 splitter 输出的 compressed packet。它不能重新打开 MKV 文件再 demux，否则会破坏 DirectShow graph 的音频、字幕、seek、stream select 和 graph clock 状态。

### 2.2 FFmpeg 官方管线对照

FFmpeg 官方 demux/decode 模型是：

```text
avformat_open_input
  -> avformat_find_stream_info
  -> av_read_frame
  -> AVPacket{stream_index, pts, dts, duration, time_base}
  -> avcodec_send_packet
  -> loop avcodec_receive_frame
  -> AVFrame{best_effort_timestamp, duration, flags, pict_type}
```

关键差异：

1. FFmpeg demuxer 输出的 packet 带 `pts/dts/duration`，且这些值属于 `AVStream.time_base`。
2. 对 H264，AVCC / Annex B / extradata / side data 由 demuxer、parser 和 bitstream filter 共同处理。
3. decoder 每个 input packet 可能输出 `0..N` frames，必须循环 `avcodec_receive_frame`。
4. presentation 层需要统一时间基，不能混用 container tick、DirectShow `REFERENCE_TIME` 和 decoder-internal timestamp。

## 3. 问题陈述

### 3.1 BlockDuration 缺失时的错误 frame duration

当前 `MatroskaSplitter` 对缺失 `BlockDuration` 的 block 使用 `rtStop = rtStart + 1`。这里的 `1` 是 DirectShow `REFERENCE_TIME` 的 100ns，不是 Matroska tick，也不是视频帧时长。结果是 splitter 可能输出近乎 0 duration 的 video sample，后续 decoder 和 EVR 会被迫猜测帧间隔。

这是 MKV 播放抖动的最高优先级根因之一。

### 3.2 H264 packet contract 不明确

MKV 中 `V_MPEG4/ISO/AVC` 通常使用 length-prefixed NAL。当前 splitter 会把 `CodecPrivate` 转成 DirectShow `MPEG2VIDEOINFO` 的 sequence header，decoder adapter 再尝试把 length-prefixed packet 转 Annex B 并聚合 access unit。

这造成重复职责：

1. splitter 负责一部分 AVCC 解包。
2. decoder 负责一部分 AVCC/AnnexB 转换。
3. decoder 还必须猜 packet 是否完整 access unit。

更好的 contract 是：splitter 明确声明输出格式、NAL length size、extradata 语义、packet 边界和 keyframe 标记；decoder 只按 contract 解码。

### 3.3 PTS/DTS 与 B-frame 重排序信息不足

DirectShow sample 当前只提供 `rtStart/rtStop`，没有独立 DTS。modern bridge 曾把 `dts = pts` 传给 FFmpeg，这对 H264 B-frame 不可靠。虽然 decoder 可以用 `best_effort_timestamp`，但前提是输入 packet timing 和 parser 状态合理。

### 3.4 Decoder 层引入 libavformat 是错误设计

把 MKV demux 放进 `MPCVideoDec` 会导致：

1. video decoder 绕过 DirectShow splitter 重新读取文件。
2. audio/subtitle 仍由旧 splitter 输出，video 由 decoder 内部 demux，时钟和 seek 状态分裂。
3. stream select、chapter、subtitle、multi-audio、playlist resume 等播放器功能不再共享同一 graph 状态。
4. 文件读取和缓存路径重复，风险高且难调试。

因此本 RFC 明确禁止在 `MPCVideoDec` 内实现 MKV demux。

## 4. 目标

1. 建立 MKV support 的可跟踪修复计划。
2. 修复 `MatroskaSplitter` 对视频 sample duration 的 contract，禁止输出 100ns 假帧时长。
3. 明确 H264 AVC packet/extradata contract，减少 decoder 侧猜测。
4. 统一 modern FFmpeg bridge 的 timestamp 语义，明确 `REFERENCE_TIME` 与 FFmpeg `pkt_timebase` 的关系。
5. 为长期 FFmpeg-backed DirectShow Matroska Source/Splitter 预留架构边界。
6. 建立 MKV playback regression 自检，包括首帧、持续响应、seek/resume、时间戳稳定性。

## 5. 非目标

1. 不在 `MPCVideoDec` 内重新打开 MKV 文件或使用 `libavformat` demux 容器。
2. 不在本 RFC 中删除旧 `MatroskaSplitter`。
3. 不一次性替换所有容器 splitter。
4. 不在本 RFC 中实现 DXVA。
5. 不牺牲现有 DirectShow graph 的 audio/subtitle/stream select 行为。

## 6. 设计方案

### 6.1 推荐方案：contract-first 分阶段修复

这是本 RFC 的推荐方案。

第一阶段修复现有 DirectShow contract：

1. `MatroskaSplitter` 对视频 block 缺少 `BlockDuration` 时，优先使用 Track `DefaultDuration`。
2. 若没有 `DefaultDuration`，使用同 track 下一帧 `rtStart` 推导当前 `rtStop`。
3. 若仍无法推导，使用 `AvgTimePerFrame` 或 conservative fallback，不允许输出 `rtStart + 1`。
4. `MPCVideoDec` modern bridge 明确 `pkt_timebase = {1, 10000000}`，传入 FFmpeg 的 `pts/dts/duration` 均为 DirectShow 100ns 时间基。
5. H264 path 保留 length-prefixed packet 输入，但必须把 NAL length size、extradata 形态、packet 边界记录为明确 contract。
6. `avcodec_send_packet` 后循环 `avcodec_receive_frame`，bridge 需要能缓存多帧或支持 repeated receive。

优点：

1. 改动范围小，符合当前 DirectShow 架构。
2. 同时改善 legacy decoder 和 modern decoder。
3. 不破坏 audio/subtitle/seek/stream select。
4. 可以用现有 selfcheck 快速回归。

风险：

1. 旧 `MatroskaSplitter` 逻辑复杂，`m_rob` / `m_tos` / lacing 行为需要小心验证。
2. 没有 DTS 的情况下，B-frame 仍可能需要 decoder/parser 估算。
3. H264 AU 聚合仍然不是最理想架构，但可作为过渡。

### 6.2 长期方案：FFmpeg-backed DirectShow Matroska Source/Splitter

如果要完整“learn from web / use FFmpeg properly”，最正确的位置是 splitter/source 层，而不是 decoder。

设计：

1. 新增 `ModernFfmpegMatroskaSource` 或 `ModernFfmpegSplitter`。
2. 内部使用 `libavformat` 打开 MKV/WebM。
3. 每个 `AVStream` 映射为 DirectShow output pin。
4. `AVPacket` 的 `pts/dts/duration` 按 `AVStream.time_base` rescale 到 DirectShow `REFERENCE_TIME`。
5. H264 extradata 和 packet side data 由 FFmpeg demuxer/parser/bitstream filter 处理后输出稳定 contract。
6. 输出仍然通过 DirectShow pins 交给现有 audio/video/subtitle decoders。

优点：

1. 最接近 FFmpeg 官方 demux/decode 模型。
2. MKV/WebM corner case 覆盖最好。
3. 可逐步替代旧 EBML parser。

风险：

1. 工程量大。
2. 需要重新实现 DirectShow source/splitter 的 seek、stream select、chapter、subtitle、attachment、cue handling。
3. 需要处理 FFmpeg island 与 MSVC/DirectShow 的 ABI 边界。
4. 需要非常完整的回归样本库。

### 6.3 不推荐方案：在 decoder bridge 内 demux MKV

该方案明确禁止。

原因：

1. 违反 DirectShow filter 职责边界。
2. 破坏 A/V 同步。
3. 破坏 seek/resume/stream select。
4. 让 subtitle/audio 仍走旧 splitter，video 走 decoder 内部 demux，状态不可维护。

## 7. 实施计划

### 阶段 1：稳定现有 MKV packet timing

1. 审计 `MatroskaSplitter.cpp` 中所有 `rtStart/rtStop` 生成点。
2. 修复无 `BlockDuration` 视频 block 的 fallback duration。
3. 保证 video sample `rtStop > rtStart` 且接近真实帧间隔。
4. 为 MKV selfcheck 增加时间戳稳定性检查。

### 阶段 2：统一 modern bridge 时间基

1. 在 modern adapter 中设置 `AVCodecContext::pkt_timebase = {1, 10000000}`。
2. 保证 bridge 输入输出时间均为 DirectShow `REFERENCE_TIME`。
3. 避免 `dts = pts` 被误认为真实 DTS；无 DTS 时使用 `AV_NOPTS_VALUE` 或明确策略。
4. `send_packet` 后循环 `receive_frame`，支持一个 packet 输出多帧。

### 阶段 3：H264 AVC contract 清理

1. 明确 splitter 输出的是 AVCC length-prefixed NAL 还是 Annex B。
2. 若保持 AVCC，adapter 使用 FFmpeg parser/bitstream filter 或等价完整实现。
3. 不丢弃 SEI/AUD/SPS/PPS，除非有明确可验证理由。
4. 建立多 slice、B-frame、无 BlockDuration、seek 后首帧样本。

### 阶段 4：评估 FFmpeg-backed splitter

1. 编写 PoC，不接入主 graph，只输出 packet timeline dump。
2. 对比旧 `MatroskaSplitter` 与 `libavformat` 的 packet `pts/dts/duration/keyframe/extradata`。
3. 若收益明确，再设计 DirectShow source/splitter 接入。

## 8. 验证策略

### 8.1 自动化

1. `test-rfc0024-splayer-selfcheck.ps1` 继续验证首帧、进程存活、窗口响应。
2. 新增 MKV timing selfcheck，记录前 N 个 video sample 的 `rtStart/rtStop/duration`。
3. 新增 modern bridge decode trace，验证输出 frame timestamp 单调且间隔合理。
4. 对比 FFmpeg/libavformat packet dump 与 DirectShow splitter packet dump。

### 8.2 样本矩阵

1. H264 MKV，无 `BlockDuration`。
2. H264 MKV，有 B-frame。
3. H264 MKV，多 slice。
4. H264 MKV，含 SEI/AUD。
5. MPEG-2 MKV。
6. VC-1/WMV3 MKV。
7. WebM VP6/VPx 兼容性样本，如适用。

### 8.3 成功指标

1. 打开 MKV 后首帧可见。
2. 30 秒 playback selfcheck 无 crash、无 AppHang、窗口响应稳定。
3. 前 300 个 video output frame timestamp 单调。
4. frame duration 不出现 100ns 假间隔。
5. seek/resume 后首帧不乱跳、不长时间卡住。
6. audio/video 不出现明显漂移。

## 9. 决策记录

### 已确认

1. 不在 video decoder 内做 MKV demux。
2. `MatroskaSplitter` 的 packet timing contract 是短期最高优先级。
3. FFmpeg-backed MKV 支持如果要做，必须在 DirectShow source/splitter 层。
4. modern FFmpeg bridge 仍是 decoder 层边界，不拥有容器状态。

### 待确认

1. 是否新增 `rfc0026` 专属 packet timing dump 工具。
2. 是否把 FFmpeg-backed splitter PoC 放在 `src/Prototype` 还是正式 filter 目录。
3. 是否优先支持 H264 MKV，还是同时覆盖 VC-1/MPEG-2。
4. 是否临时禁用 auto-resume 以隔离 playback jump 与 decoder jitter。

## 10. 参考

1. FFmpeg 官方 demux/decode 示例：`doc/examples/demux_decode.c`
2. FFmpeg `av_read_frame` 文档：packet 包含 `pts/dts/duration`，时间属于 `AVStream.time_base`
3. FFmpeg H264 parser：处理 frame boundary、picture timing、field order、framerate
4. FFmpeg bitstream filter 文档：`h264_mp4toannexb`
5. [RFC-0024](./rfc-0024-ffmpeg-modern-island.md)
6. [RFC-0025](./rfc-0025-ffmpeg-dxva-followup.md)

## 11. 下一步行动

1. 修复 `MatroskaSplitter` 视频 block 缺失 `BlockDuration` 的 fallback duration。
2. 给 modern adapter 设置明确 `pkt_timebase`。
3. 把 `send_packet -> receive_frame` 改成可完整 drain 当前可用 frames。
4. 增加 MKV packet timing dump/selfcheck。
5. 对比旧 splitter 与 FFmpeg demux 的 packet timeline，为长期 FFmpeg-backed splitter 做数据依据。
