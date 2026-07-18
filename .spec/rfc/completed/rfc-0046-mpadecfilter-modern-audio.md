# RFC-0046: MpaDecFilter Modern FFmpeg 音频迁移

| 字段 | 内容 |
| --- | --- |
| **状态** | 已完成 (Completed) |
| **创建日期** | 2026-07-17 |
| **最后更新** | 2026-07-18 |
| **完成日期** | 2026-07-18 |
| **负责人** | AI / Playasa |
| **相关 RFC** | [RFC-0024](../rfc-0024-ffmpeg-modern-island.md)、[RFC-0035](../rfc-0035-legacy-mpcvideodec-ffmpeg-retirement.md)、[RFC-0034](./rfc-0034-realaudio-modern-playback.md)、[RFC-0044](./rfc-0044-realaudio-legacy-cleanup.md)、[RFC-0045](./rfc-0045-realaudio-remaining-codecs.md)、[RFC-0033](./rfc-0033-ffmpeg-dxva-phase2-h264-vc1.md) |

## 1. 摘要

将 `MpaDecFilter` 的 FFmpeg 后端从旧 `mpcvideodec/ffmpeg`（`avcodec_decode_audio2` / `libavcodec_gcc`）迁到 `playasa_ffmpeg_modern_bridge` audio ABI，解除 [RFC-0035](../rfc-0035-legacy-mpcvideodec-ffmpeg-retirement.md) 删树门禁之一。

## 2. Completion Proof

### Code

| 区域 | 文件 | 说明 |
| --- | --- | --- |
| ABI | `ffmpeg_modern_bridge.h` | codec 22–33（WMAV1…ADPCM_IMA_QT） |
| Island | `rfc0024-expected.txt` / build+verify scripts | `wmav*`、`amrnb`/`amrwb`、`eac3`、`flac` 等 |
| Bridge | `ModernFfmpegDecodeAdapter.*` / `ModernFfmpegBridge.cpp` | `IsBridgeAudioCodec` + ToAvCodecId |
| Adapter | `mpadecfilter/modern_ffmpeg/*` | LoadLibrary 适配器 + codec map + open params |
| Filter | `MpaDecFilter.*` / vcxproj | 去掉 `avcodec.h` 与 `libavcodec_gcc` |
| Stale | `MpaDecFilter*.vcproj` | 同步清除旧工程里的 ffmpeg/libavcodec 引用 |

Build: island rebuild + bridge + `./dev.ps1 buildFast` PASS（2026-07-18）。

### Tests

| Script / Suite | Result |
| --- | --- |
| `verify-rfc0024-ffmpeg-modern.ps1` | PASS |
| `test-rfc0024-modern-bridge-smoke.ps1` | PASS（含 WMAV2/AMR_NB open） |
| `test-rfc0046-mpadec-modern-selfcheck.ps1` | PASS |
| `audit-rfc0035-legacy-ffmpeg-refs.ps1` | MpaDec 主题 **0 hits** |

## 3. 非目标（保持）

libmad / a52 / dts / faad2 / libFLAC / vorbis 原生路径未迁移；RealAudio splitter 路径未改。
