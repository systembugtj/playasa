# RFC-0034: RealAudio Modern 播放路径

| 字段 | 内容 |
| --- | --- |
| **状态** | 已完成 (Completed) |
| **创建日期** | 2026-05-17 |
| **最后更新** | 2026-07-17 |
| **完成日期** | 2026-07-17 |
| **负责人** | AI / Playasa |
| **相关 RFC** | [RFC-0032](./rfc-0032-rmvb-realvideo-modern-playback.md)、[RFC-0024](../rfc-0024-ffmpeg-modern-island.md) |

## 1. 摘要

[RFC-0032](./rfc-0032-rmvb-realvideo-modern-playback.md) 明确 **非目标** 包含 RealAudio：RMVB 文件常带 RealAudio 音轨。本 RFC 将 cook / sipr / atrac3 迁入 `playasa_ffmpeg_modern_bridge`，与 RealVideo 解耦。

## 2. 背景

1. RealMedia 容器由 `RealMediaSplitter` demux，视频已 modern 化（RFC-0032）。
2. 音频解码器是独立 transform：`CRealAudioDecoder`（CLSID `{941A4793-A705-4312-8DFC-C11CA05F397E}`），不经 `CMPCVideoDecFilter`。
3. 实施前 FFmpeg 8.1 island / C ABI bridge 仅覆盖视频帧；音频需并行 PCM 输出 ABI。

## 3. 审计结论（2026-07-16）→ 最终路径（2026-07-17）

| 组件 | 路径 | 最终说明 |
| --- | --- | --- |
| Splitter | `RealMediaSplitter.cpp` | 输出 `MEDIASUBTYPE_COOK` / `SIPR` / `ATRC` 等 |
| Decoder | `CRealAudioDecoder` | `CRealAudioModernDecodeAdapter` → `playasa_ffmpeg_modern_*_audio` |
| Island | `ffmpeg-modern` | `--enable-decoder=cook\|sipr\|atrac3` |
| Legacy | `#ifndef RA_FFMPEG` | Real SDK `drv*.dll` 源码保留；默认不编译进路径 |
| 旧 libavcodec | — | `RealMediaSplitter` 已移除 `avcodec.h` / `libavcodec_gcc.lib` 链接 |

## 4. 目标（验收）

1. ~~在 island 启用 `cook`、`sipr`、`atrac3`~~
2. ~~扩展 C ABI：`open_audio` / `decode_audio` / `receive_audio` + PCM frame~~
3. ~~`CRealAudioDecoder` 经 dynamic bridge 解码；移除旧 `AVCodecContext` 依赖~~
4. ~~selfcheck：RMVB cook 样本 modern open + 首包 PCM~~

## 5. 非目标

1. 不替换 RealMedia 容器 splitter。
2. 不修改 RealVideo 视频时间戳（RFC-0032）。
3. 不强制删除 Real SDK DLL 加载代码（`#ifndef RA_FFMPEG` 仍保留）。
4. 不把音频解码并入 `MPCVideoDecFilter`。
5. 本阶段不 modern 化 AAC / 14_4 / 28_8（`CodecFromSubtype` 返回 0 时跳过 modern 解码）。

## 6. 实施记录

### 阶段 1：Island + ABI

- `rfc0024-expected.txt` / configure：`cook` / `sipr` / `atrac3`
- `ffmpeg_modern_bridge.h`：codec 16–18 + audio open/frame API
- MinGW bridge 实现音频 open/decode/receive（PCM 打包为 S16）

### 阶段 2：`CRealAudioDecoder` 接入

- `RealAudioModernDecodeAdapter` / `RealAudioExtradata`
- 保留 cook/sipr interleave；`BeginFlush` → `playasa_ffmpeg_modern_flush`
- `StartStreaming` 提前 open modern session

### 阶段 3：测试与收口

- `test-rfc0034-realaudio-selfcheck.ps1`
- 移除 `avcodec.h` / `PODtypes.h`；`kRealAudioMaxPcmBufferBytes` 替代 `AVCODEC_MAX_AUDIO_FRAME_SIZE`
- `RealMediaSplitter` 工程去掉 `libavcodec_gcc` / mingw 依赖与旧 ffmpeg include 路径

## 7. Completion Proof

### Code

| Commit | 文件 | 说明 |
| --- | --- | --- |
| `e76b6289` | `ffmpeg_modern_bridge.h`、`ModernFfmpeg*`、`RealAudio*`、`RealMediaSplitter.*` | cook/sipr/atrac3 + audio ABI 主实现 |
| `01df921f` | `RealMediaSplitter.*`、`completed/rfc-0034-*.md` | 收口归档与遗留交叉引用（0044/0045） |

Build: `./dev.ps1 buildFast` PASS（2026-07-17）；`build-rfc0024-ffmpeg-modern.ps1` + `build-rfc0024-ffmpeg-bridge.ps1` PASS。

### Tests

| Script / Suite | Result |
| --- | --- |
| `src/BuildScript/verify-rfc0024-ffmpeg-modern.ps1` | PASS |
| `src/Test/Scripts/test-rfc0024-modern-bridge-smoke.ps1` | PASS |
| `src/Test/Scripts/test-rfc0034-realaudio-selfcheck.ps1` | PASS（2026-07-17） |
| `src/Test/Scripts/test-rmvb-seek-selfcheck.ps1` | PASS（回归，2026-07-17） |

## 8. 风险与遗留

| 项 | 状态 |
| --- | --- |
| Real SDK `#ifndef RA_FFMPEG` 死代码 | **已由 [RFC-0044](./rfc-0044-realaudio-legacy-cleanup.md) 删除** |
| AAC / 14_4 / 28_8 | **已由 [RFC-0045](./rfc-0045-realaudio-remaining-codecs.md) modern 化** |
| sipr 样本 A/B | 本 RFC selfcheck 以 cook RMVB 为主；可选后续增强 |
