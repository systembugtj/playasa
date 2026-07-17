# RFC-0034: RealAudio Modern 播放路径

| 字段 | 内容 |
| --- | --- |
| **状态** | 执行中 (In Progress) |
| **创建日期** | 2026-05-17 |
| **最后更新** | 2026-07-16 |
| **负责人** | AI / Playasa |
| **相关 RFC** | [RFC-0032](./completed/rfc-0032-rmvb-realvideo-modern-playback.md)、[RFC-0024](./rfc-0024-ffmpeg-modern-island.md) |

## 1. 摘要

[RFC-0032](./completed/rfc-0032-rmvb-realvideo-modern-playback.md) 明确 **非目标** 包含 RealAudio：RMVB 文件常带 RealAudio 音轨，当前仍走 `CRealAudioDecoder` + `RA_FFMPEG`（旧 libavcodec）。本 RFC 将 cook / sipr / atrac3（及后续 AAC）迁入 `playasa_ffmpeg_modern_bridge`，与 RealVideo 解耦。

## 2. 背景

1. RealMedia 容器由 `RealMediaSplitter` demux，视频已 modern 化（RFC-0032）。
2. 音频解码器是独立 transform：`CRealAudioDecoder`（CLSID `{941A4793-A705-4312-8DFC-C11CA05F397E}`），不经 `CMPCVideoDecFilter`。
3. FFmpeg 8.1 island 与 C ABI bridge 当前仅覆盖 **视频** 帧（`PlayasaFfmpegModernFrameInfo`）；音频需并行 PCM 输出 ABI。

## 3. 当前验证结果（审计 2026-07-16）

### 3.1 Graph / 模块

| 组件 | 路径 | 说明 |
| --- | --- | --- |
| Splitter | `RealMediaSplitter.cpp` | 输出 `MEDIASUBTYPE_COOK` / `SIPR` / `ATRC` / `AAC` 等 |
| Decoder | `CRealAudioDecoder` | `#define RA_FFMPEG`；`InitFfmpeg` → 旧 `avcodec_find_decoder` / `avcodec_open` |
| 注册 | `FGManager.cpp` | `CFGFilterInternal<CRealAudioDecoder>` |
| Legacy fallback | `#ifndef RA_FFMPEG` | Real SDK `drv*.dll`（`RAOpenCodec` 等）仍保留在源码，但默认走 FFmpeg |

### 3.2 支持的输入 subtype（`CheckInputType`）

| subtype | codec id（旧） | 备注 |
| --- | --- | --- |
| `MEDIASUBTYPE_COOK` | `CODEC_ID_COOK` | 主路径；extradata 需跳过到 `"cook"` + 12 字节头 |
| `MEDIASUBTYPE_SIPR` | `CODEC_ID_SIPR` | 含 interleave swap 表 |
| `MEDIASUBTYPE_ATRC` | `CODEC_ID_ATRAC3` | 与 cook 共用 extradata 扫描 |
| `MEDIASUBTYPE_AAC` | （Real AAC 头） | InitRA 特殊 cbSize 处理 |

### 3.3 Modern bridge 缺口

| 项 | 现状 |
| --- | --- |
| `PLAYASA_FFMPEG_MODERN_CODEC_*` | 仅视频 0–15（至 MPEG1） |
| island configure | 无 `--enable-decoder=cook/sipr/atrac3` |
| 输出 ABI | 仅 `PlayasaFfmpegModernFrameInfo`（width/height/pixfmt） |
| Consumer | `ModernFfmpegBridgeConsumer` 面向 `MPCVideoDec` |

## 4. 目标

1. 在 island 启用 `cook`、`sipr`、`atrac3`（及验证所需的最小 parser/demuxer）。
2. 扩展 C ABI：音频 session open（sample_rate/channels/block_align/bit_rate/extradata）+ PCM frame receive。
3. `CRealAudioDecoder` modern-only：动态加载 bridge，删除对旧 `AVCodecContext` / `RA_FFMPEG` 的依赖；保留 Real SDK `#ifndef` 分支直至 modern 验证通过后再删。
4. selfcheck：RMVB 样本断言音频 modern open / 首包 PCM / seek 后音频 flush。

## 5. 非目标

1. 不替换 RealMedia 容器 splitter。
2. 不修改 RealVideo 视频时间戳（RFC-0032）。
3. 不强制本阶段删除 Real SDK DLL 加载代码（可第二阶段）。
4. 不把音频解码并入 `MPCVideoDecFilter`。

## 6. 实施计划

### 阶段 2：`CRealAudioDecoder` 接入（2026-07-16）

1. 新增 `RealAudioModernDecodeAdapter` / `RealAudioExtradata`（动态加载 `open_audio` / `decode_audio` / `receive_audio`）。
2. `CRealAudioDecoder` 在 `RA_FFMPEG` 路径下改用 modern bridge，移除旧 `InitFfmpeg` / `avcodec_decode_audio2`。
3. 保留 cook/sipr interleave 与 extradata `"cook"`/`"atrc"` 扫描；`BeginFlush` 调用 `playasa_ffmpeg_modern_flush`。
4. `buildFast` + `test-rfc0024-modern-bridge-smoke.ps1` 通过。

### 阶段 1：Island + ABI（已完成）

1. `rfc0024-expected.txt` / configure 增加 `--enable-decoder=cook|sipr|atrac3`。
2. `ffmpeg_modern_bridge.h` 增加：
   - `PLAYASA_FFMPEG_MODERN_CODEC_COOK/SIPR/ATRAC3`
   - `PlayasaFfmpegModernAudioOpenParams` / `PlayasaFfmpegModernAudioFrameInfo`
   - `playasa_ffmpeg_modern_open_audio` / `decode_audio` / `receive_audio`（或与现有 decode 共用 session，按 codec 分支）
3. 实现 MinGW bridge DLL 侧音频路径；重编 island + bridge。
4. `verify-rfc0024-ffmpeg-modern.ps1` 覆盖新 decoder 钉扎。

### 阶段 2：`CRealAudioDecoder` 接入

1. 用 `ModernFfmpegBridgeConsumer`（或轻量 audio consumer）替代 `InitFfmpeg` 旧路径。
2. 保留 cook/sipr interleave / extradata 扫描逻辑。
3. seek：`BeginFlush` → `playasa_ffmpeg_modern_flush`；`NewSegment` 行为对齐现有。

### 阶段 3：测试与收口（2026-07-16）

1. 新增 `test-rfc0034-realaudio-selfcheck.ps1`（RMVB cook 样本：modern open + 首包 PCM）。
2. 重编 FFmpeg island（cook/sipr/atrac3）+ bridge；`verify-rfc0024` / `test-rfc0024-modern-bridge-smoke` PASS。
3. 待办：删除 `RA_FFMPEG` 旧符号依赖（`avcodec.h` include）；AAC/14_4 等未 modern 化 subtype 仍返回 unsupported。

## 7. 验证计划

```text
./dev.ps1 buildFast
src/BuildScript/verify-rfc0024-ffmpeg-modern.ps1
src/Test/Scripts/setup-rmvb-samples.ps1
src/Test/Scripts/test-rmvb-seek-selfcheck.ps1
# 新增: test-rfc0034-realaudio-selfcheck.ps1（音频 modern open + PCM）
```

## 8. 风险

| 风险 | 缓解 |
| --- | --- |
| 音频 ABI 与视频混用导致消费者误用 | 独立 open_audio / AudioFrameInfo；codec enum 分区 |
| cook extradata 偏移脆弱 | 保留现有 `"cook"`/`"atrc"` 扫描，加单元/日志 |
| island 体积增大 | 仅启用必要 audio decoder |
| sipr interleave 与 FFmpeg 8.1 行为差异 | 对照旧路径样本 A/B |

## 9. 下一步行动

1. ~~完成 RFC-0032~~（已完成）
2. ~~执行 §3 审计~~（已完成）
3. ~~阶段 2 `CRealAudioDecoder` 接入~~（已完成 2026-07-16）
4. ~~阶段 3 selfcheck~~（`test-rfc0034-realaudio-selfcheck.ps1` PASS）
5. 清理：`RealMediaSplitter.cpp` 移除 legacy `avcodec.h`；可选删除 `RA_FFMPEG` 宏分支
