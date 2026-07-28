# RFC-0047: FfmpegContext DXVA glue 退役（旧树删树前置）

| 字段 | 内容 |
| --- | --- |
| **状态** | 执行中 (In Progress) |
| **创建日期** | 2026-07-18 |
| **最后更新** | 2026-07-23 |
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

### 阶段 2（2026-07-23）：表面 / 参考帧生命周期合同

1. 新增 opaque `DxvaH264DxvaSession` + `FFH264*Session` API。
2. `DXVADecoderH264` 在 `Init()` 绑定一次 session；帧路径不再调用 `GetAVCtx()`。
3. 门禁：`test-rfc0047-dxva-decoder-no-avcodec.ps1`（扩展 session 断言）。

### 阶段 3（2026-07-23）：parser 替换数据源 — 3a 已落地

**3a（本提交）**

1. 抽取 `h264_bitstream/H264BitstreamUtils`（extradata / length-prefixed NAL 纯函数，无 legacy 头）。
2. `DxvaH264Session.cpp` 承接 `FFH264*Session`；session 缓存 extradata + `nal_length_size`。
3. `ModernFfmpegDecodeAdapter` 复用同一模块，去除重复 H.264 bitstream 逻辑。
4. 门禁：`test-rfc0047-h264-bitstream-utils.ps1`；`audit-rfc0047-ffmpegcontext-h264-glue.ps1` 跟踪剩余 `H264Context` 读者。

**3c（2026-07-23，本提交）**

1. `ModernFfmpegDxvaH264BridgeConsumer` 动态加载 `playasa_dxva_h264_parse_*`。
2. `DxvaH264Session` 在 bridge DLL 可用时走 modern parse，失败则 fallback `DxvaH264LegacyGlue.c`。
3. 实现 `playasa_dxva_h264_parse_fill_picture_context` 与 `update_slice_long` modern 版。
4. 门禁：`test-rfc0047-h264-dxva-session-modern-routing.ps1`。

**3d（2026-07-23，本提交）**

1. `FFH264IsModernDxvaParseAvailable` + `FFH264CreateDxvaSession(NULL)` 当 bridge 可用时不再绑定 `AVCodecContext`。
2. `DxvaH264Session.cpp` 去除 `avcodec.h`；`FFH264ReadAvctxExtradata` 留在 legacy glue。
3. 门禁：`test-rfc0047-h264-dxva-session-no-avctx.ps1`。
4. 待续：从 `MPCVideoDec.vcxproj` 移除 `libavcodec_gcc`（VC-1/MPEG-2 仍阻塞）。

**3e（2026-07-23，本提交）**

1. `DxvaVc1LegacyGlue.c`：VC-1 私有结构读者从 `FfmpegContext.c` / `DxvaH264LegacyGlue.c` 隔离；主文件不再 `#include "vc1.h"`。
2. 门禁：`test-rfc0047-vc1-dxva-legacy-glue-compartment.ps1`。
3. 待续：MPEG-2 glue 隔离；`MPCVideoDec.vcxproj` 去 `libavcodec_gcc`。

**3f（2026-07-23，本提交）**

1. `DxvaMpeg2LegacyGlue.c`：MPEG-2 读者从 `FfmpegContext.c` 隔离；主文件不再 `#include "mpegvideo.h"` / `avcodec_decode_video`。
2. `FFGetMpegEnc*` 留在 `DxvaH264LegacyGlue.c` 供 H.264/VC-1 公共辅助分发。
3. 门禁：`test-rfc0047-mpeg2-dxva-legacy-glue-compartment.ps1`。
4. 待续：`MPCVideoDec.vcxproj` 去 `libavcodec_gcc`（legacy glue compartment 仍链接）；交接 RFC-0035。

**阶段 4（2026-07-23）**

**4a（本提交）**

1. `FfmpegContext.c` 去除 `avcodec.h`；通过 `FFAvctxIs*` 分发到各 legacy glue compartment。
2. 统一审计：`audit-rfc0047-ffmpegcontext-dxva-glue.ps1`（0 hits）。
3. 门禁：`test-rfc0047-ffmpegcontext-public-only.ps1`。

**4b（2026-07-23，本提交）**

1. `MPCVideoDecFilter`：H.264 DXVA + modern parse 时跳过 `avcodec_open` / `FFH264CheckCompatibility`（`m_bLegacyAvcodecOpened` 跟踪）。
2. 门禁：`test-rfc0047-mpcvideodec-dxva-skip-legacy-avcodec-open.ps1`。
3. 待续：VC-1/MPEG-2 DXVA 去 `avcodec_open`；`MPCVideoDec.vcxproj` 去 `libavcodec_gcc`。

**4c（进行中）**

**4c-i（本提交）**

1. 新增 `MPCVideoDecLegacyGlue.vcxproj`：`Dxva*LegacyGlue.c` + `FfmpegContext.c` 独占 `libavcodec_gcc` 链接。
2. `MPCVideoDec.vcxproj` 通过 `ProjectReference` 消费 glue 库；`audit-rfc0035` 对 filter vcxproj 的 `libavcodec_gcc` 命中为 0。
3. 门禁：`test-rfc0047-legacy-glue-link-isolation.ps1`；更新 `verify-rfc0017`。

**4c-ii（待办）**

1. 仿 H.264 `playasa_dxva_h264_parse_*`，在 modern bridge 导出 VC-1/MPEG-2 picture-context parse；门禁 `test-rfc0047-dxva-vc1-mpeg2-legacy-open-contract.ps1` 跟踪「未实现前不得 skip open」。

**4c-iii（待办）**

1. `NeedsLegacyAvcodecOpen` 扩展 VC-1/MPEG-2 skip（与 4c-ii 同批）；软件路径仍经 glue 库在最终链接解析 legacy 符号。

**阶段 5（待办）**

1. H.264/VC-1/MPEG-2 DXVA 样本回归。
2. `audit-rfc0035` 对 `libavcodec_gcc` 降为 0 后，由 RFC-0035 删树。

## 4. 验证

```text
src/Test/Scripts/test-rfc0047-dxva-decoder-no-avcodec.ps1
src/Test/Scripts/test-rfc0047-h264-bitstream-utils.ps1
src/Test/Scripts/test-rfc0047-h264-dxva-session-modern-routing.ps1
src/Test/Scripts/test-rfc0047-h264-dxva-session-no-avctx.ps1
src/Test/Scripts/test-rfc0047-vc1-dxva-legacy-glue-compartment.ps1
src/Test/Scripts/test-rfc0047-mpeg2-dxva-legacy-glue-compartment.ps1
src/Test/Scripts/test-rfc0047-ffmpegcontext-public-only.ps1
src/Test/Scripts/test-rfc0047-mpcvideodec-dxva-skip-legacy-avcodec-open.ps1
src/Test/Scripts/test-rfc0047-legacy-glue-link-isolation.ps1
src/Test/Scripts/test-rfc0047-dxva-vc1-mpeg2-legacy-open-contract.ps1
src/BuildScript/audit-rfc0047-ffmpegcontext-dxva-glue.ps1
src/Test/Scripts/test-rfc0033-h264-dxva-selfcheck.ps1
src/BuildScript/audit-rfc0035-legacy-ffmpeg-refs.ps1
```

## 5. 当前进度

| 阶段 | 状态 |
| --- | --- |
| 1 H.264 decoder 去 avcodec.h | ✓ 2026-07-18 |
| 2 ref/surface session contract | ✓ 2026-07-23 |
| 3 island/parser 替换 | 3a–3f ✓ |
| 4 FfmpegContext 公共层 | 4a ✓；4b H.264 DXVA 跳过 legacy open ✓；4c-i glue 链接隔离 ✓；4c-ii VC-1+MPEG-2 parse 待办 |
| 5 交接删树 | 待办 |
