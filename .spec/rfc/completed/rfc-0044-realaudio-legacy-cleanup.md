# RFC-0044: RealAudio Legacy SDK / `RA_FFMPEG` 清理

| 字段 | 内容 |
| --- | --- |
| **状态** | 已完成 (Completed) |
| **创建日期** | 2026-07-17 |
| **最后更新** | 2026-07-17 |
| **完成日期** | 2026-07-17 |
| **负责人** | AI / Playasa |
| **相关 RFC** | [RFC-0034](./rfc-0034-realaudio-modern-playback.md)、[RFC-0032](./rfc-0032-rmvb-realvideo-modern-playback.md)、[RFC-0035](../rfc-0035-legacy-mpcvideodec-ffmpeg-retirement.md)、[RFC-0024](../rfc-0024-ffmpeg-modern-island.md)、[RFC-0045](./rfc-0045-realaudio-remaining-codecs.md) |

## 1. 摘要

令 `CRealAudioDecoder` **modern-bridge-only**：删除 `#define RA_FFMPEG` 与 `#ifndef RA_FFMPEG` Real SDK（`RAOpenCodec` / `drv*.dll`）死分支，对齐 RealVideo（RFC-0032）模式。

## 2. Completion Proof

### Code

| Commit | 文件 | 说明 |
| --- | --- | --- |
| `e76b6289`..`01df921f` | `RealMediaSplitter.h` / `.cpp` | 删除 `RA_FFMPEG`/Real SDK；仅保留 `CRealAudioModernDecodeAdapter`；sipr swap 保留 modern 实现；`DecideBufferSize` 用 `kRealAudioMaxPcmBufferBytes` |
| `01df921f` | `FGManager.cpp` | 去掉误留的 `RA_FFMPEG` 名称分支 |

Grep：`RA_FFMPEG` / `RAOpenCodec` / `m_hDrvDll` / `RADecode` / `PCloseCodec` → 零命中。

Build: `./dev.ps1 buildFast` PASS（2026-07-17）。

### Tests

| Script | Result |
| --- | --- |
| `test-rfc0034-realaudio-selfcheck.ps1` | PASS |
| `test-rmvb-seek-selfcheck.ps1` | PASS |
