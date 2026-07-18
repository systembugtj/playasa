# RFC-0033: FFmpeg DXVA 阶段 2 — H.264 与 VC-1

| 字段 | 内容 |
| --- | --- |
| **状态** | 已完成 (Completed) |
| **创建日期** | 2026-05-17 |
| **最后更新** | 2026-07-18 |
| **完成日期** | 2026-07-18 |
| **负责人** | AI / Playasa |
| **相关 RFC** | [RFC-0025](./rfc-0025-ffmpeg-dxva-followup.md)、[RFC-0030](../rfc-0030-mpeg2-dxva-context-modernization.md)、[RFC-0024](../rfc-0024-ffmpeg-modern-island.md)、[RFC-0031](./rfc-0031-mpeg2-playback-path-modernization.md)、[RFC-0035](../rfc-0035-legacy-mpcvideodec-ffmpeg-retirement.md)、[RFC-0046](./rfc-0046-mpadecfilter-modern-audio.md) |

## 1. 摘要

[RFC-0025](./rfc-0025-ffmpeg-dxva-followup.md) 已完成 `FfmpegContext.c` 只读审计，并明确 **不得** 把 DXVA 迁移混入当前 H.264/MPEG-2/VC-1 **modern software bridge** 稳定线。MPEG-2 DXVA picture context 合同由 [RFC-0030](../rfc-0030-mpeg2-dxva-context-modernization.md) 落地。

本 RFC 为 **H.264** 与 **VC-1** 硬解落地项目自有 picture contract，使 DXVA decoder 类不直接读 `H264Context` / `VC1Context`。

## 2. Completion Proof

### Code

| 区域 | 文件 | 说明 |
| --- | --- | --- |
| Contract | `DxvaCodecContext.h` | `DxvaH264PictureContext` / `DxvaVc1PictureContext` |
| Reader | `FfmpegContext.h` / `.c` | `FFH264ReadPictureContext` / `FFVC1ReadPictureContext` |
| H.264 | `DXVADecoderH264.*` | DecodeFrame 经 contract 填充 pic params |
| VC-1 | `DXVADecoderVC1.*` | DecodeFrame 经 contract；跳帧走 `frameSkipped` |
| Audit | `audit-rfc0033-dxva-h264-vc1-refs.ps1` | 私有结构引用清单 |

Build: `./dev.ps1 buildFast` PASS（2026-07-18）。

### Tests

| Script / Suite | Result |
| --- | --- |
| `test-rfc0033-h264-dxva-selfcheck.ps1` | PASS |
| `audit-rfc0033-dxva-h264-vc1-refs.ps1` | PASS（清单已刷新） |

备注：表面/参考帧生命周期（`FFH264SetCurrentPicture` / `FFH264UpdateRefFramesList` 等）仍经 `FfmpegContext.c` glue；decoder TU 不再直接引用 `H264Context`/`VC1Context`。

## 3. 非目标（保持）

1. 不启用 FFmpeg 新版 hwaccel API。
2. 不在 modern bridge 上恢复 DXVA。
3. 不迁移 `CMpeg2DecFilter` DXVA。
