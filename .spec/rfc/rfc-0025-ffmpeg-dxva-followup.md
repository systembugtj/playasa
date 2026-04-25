# RFC-0025：FFmpeg DXVA / FfmpegContext 后续替代计划

| 字段 | 内容 |
|------|------|
| **状态** | 提案 (Proposed) |
| **适用范围** | `src/Source/filters/transform/mpcvideodec/FfmpegContext.c`、`DXVADecoder*.cpp`、H.264 / MPEG-2 / VC-1 硬解路径 |
| **相关 RFC** | [RFC-0017](./completed/rfc-0017-ffmpeg-mpcvideodec-upgrade.md)、[RFC-0024](./rfc-0024-ffmpeg-modern-island.md) |
| **创建日期** | 2026-04-25 |
| **最后更新** | 2026-04-25 |

## 1. 摘要

RFC-0024 只迁移新版 FFmpeg 的软件解码 island，不直接处理 DXVA。当前 `FfmpegContext.c` 读取旧 FFmpeg 内部结构，例如 `H264Context`、`MpegEncContext` 和本地复制的 MPEG-2 context 布局，这些都不是现代 FFmpeg 的稳定 public API。

本 RFC 记录后续硬解替代策略：必须等 RFC-0024 的软件解码路径和首帧 smoke 稳定后，再单独设计 DXVA 路径。禁止在软件路径尚未稳定前改写 `FfmpegContext.c`。

## 2. 启动条件

1. RFC-0024 的 FFmpeg 8.1 island 可构建。
2. `test-rfc0024-modern-smoke.ps1` 至少对一个 first-wave 软件 codec 样本解出首帧。
3. `MPCVideoDec.vcxproj` 和 `splayer.sln` 仍能通过旧路径构建。
4. RFC-0024 明确哪些 codec 已经迁移，哪些仍留在旧路径。

## 3. DXVA 分解顺序

1. 只读审计 `FfmpegContext.c` 中 H.264、MPEG-2、VC-1 各自依赖的 FFmpeg 私有字段。
2. 为 `DXVADecoderH264.cpp`、`DXVADecoderMpeg2.cpp`、`DXVADecoderVC1.cpp` 建立输入/输出数据契约文档。
3. 先保留旧 FFmpeg 私有路径，新增中间结构体承载 DXVA picture parameters、slice info、reference frame list。
4. 按 codec 迁移：MPEG-2 优先，VC-1 第二，H.264 最后。
5. 每个 codec 至少需要一个硬解样本手测记录；如果无法自动化，必须记录 GPU/驱动/系统版本。

## 4. 非目标

1. 不在 RFC-0025 中直接启用新版 FFmpeg 硬件加速 API。
2. 不把现代 FFmpeg 私有 header 当成兼容层。
3. 不同时重构 DirectShow filter 或 UI。

## 5. 成功标准

1. `FfmpegContext.c` 的私有结构读取被逐步替换为项目自有中间结构。
2. 旧 DXVA 路径和新版软件路径可以在迁移期间并存。
3. 任一 DXVA codec 迁移前后都有样本验证记录。
4. 出现硬解回归时可以按 codec 回退，而不是回退整个 FFmpeg island。
