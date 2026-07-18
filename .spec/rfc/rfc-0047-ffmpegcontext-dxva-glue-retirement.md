# RFC-0047: FfmpegContext DXVA glue 退役（旧树删树前置）

| 字段 | 内容 |
| --- | --- |
| **状态** | 执行中 (In Progress) |
| **创建日期** | 2026-07-18 |
| **最后更新** | 2026-07-18 |
| **负责人** | AI / Playasa |
| **相关 RFC** | [RFC-0035](./rfc-0035-legacy-mpcvideodec-ffmpeg-retirement.md)、[RFC-0033](./completed/rfc-0033-ffmpeg-dxva-phase2-h264-vc1.md)、[RFC-0030](./rfc-0030-mpeg2-dxva-context-modernization.md)、[RFC-0025](./completed/rfc-0025-ffmpeg-dxva-followup.md)、[RFC-0024](./rfc-0024-ffmpeg-modern-island.md) |

## 1. 摘要

[RFC-0033](./completed/rfc-0033-ffmpeg-dxva-phase2-h264-vc1.md) / [RFC-0030](./rfc-0030-mpeg2-dxva-context-modernization.md) 已让 DXVA **decoder TU** 通过 picture contract 消费参数，但 `FfmpegContext.c` 仍：

1. `#include` 旧 `mpcvideodec/ffmpeg` 私有头，读 `H264Context` / `VC1Context` / `MpegEncContext`
2. 依赖 `avcodec_decode_video` / `av_h264_decode_frame` / `av_vc1_decode_frame` 副作用填充状态
3. 迫使 `MPCVideoDec` 继续链接 `libavcodec_gcc`

本 RFC 是 [RFC-0035](./rfc-0035-legacy-mpcvideodec-ffmpeg-retirement.md) 的 **DXVA glue 子程序**：在不恢复 modern-bridge DXVA 的前提下，把旧私有结构读路径逐步收进可替换边界，最终允许删除旧 ffmpeg 树。

## 2. 非目标

1. 不接入 FFmpeg 8.1 `hwaccel` / D3D11VA 新路径（另开 RFC）。
2. 不把 DXVA 绑回 modern software bridge 稳定线。
3. 不在本 RFC 内删除 `mpcvideodec/ffmpeg`（由 RFC-0035 在门禁全绿后执行）。

## 3. 阶段计划

### 阶段 1（本提交）：H.264 decoder TU 去 `avcodec.h`

1. `FFH264GetNalLengthSize` / `FFH264ApplyExtradata` 封装 `nal_length_size` 与 extradata 解析。
2. `DXVADecoderH264.cpp` 删除 `#include "avcodec.h"` / `PODtypes.h`。
3. 门禁：`test-rfc0047-dxva-decoder-no-avcodec.ps1`。

### 阶段 2：表面 / 参考帧生命周期合同

1. 扩展 `DxvaH264PictureContext`（或并列 `DxvaH264RefState`）覆盖 `SetCurrentPicture` / `UpdateRefFramesList` / `IsRefFrameInUse` / slice-long 更新所需字段。
2. decoder 只写/读 contract；`FfmpegContext.c` 仍可从旧 `H264Context` 填充。

### 阶段 3：parser 替换数据源

1. 用 island 侧公开 bitstream 解析（或项目自有 NAL/SPS 解析）填充 contract。
2. `FfmpegContext.c` 不再编译进旧树头文件；`MPCVideoDec` 去掉 `libavcodec_gcc`（DXVA 路径）。

### 阶段 4：验证与交接 RFC-0035

1. H.264/VC-1/MPEG-2 DXVA 样本回归。
2. `audit-rfc0035` 对 `FfmpegContext` / `libavcodec_gcc` 降为 0 后，由 RFC-0035 删树。

## 4. 验证

```text
src/Test/Scripts/test-rfc0047-dxva-decoder-no-avcodec.ps1
src/Test/Scripts/test-rfc0033-h264-dxva-selfcheck.ps1
src/BuildScript/audit-rfc0035-legacy-ffmpeg-refs.ps1
```

## 5. 当前进度

| 阶段 | 状态 |
| --- | --- |
| 1 H.264 decoder 去 avcodec.h | ✓ 2026-07-18 |
| 2 ref/surface contract | 待办 |
| 3 island/parser 替换 | 待办 |
| 4 交接删树 | 待办 |
