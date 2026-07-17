# RFC-0033: FFmpeg DXVA 阶段 2 — H.264 与 VC-1

| 字段 | 内容 |
| --- | --- |
| **状态** | 执行中 (In Progress) |
| **创建日期** | 2026-05-17 |
| **最后更新** | 2026-07-17 |
| **负责人** | AI / Playasa |
| **相关 RFC** | [RFC-0025](./completed/rfc-0025-ffmpeg-dxva-followup.md)、[RFC-0030](./rfc-0030-mpeg2-dxva-context-modernization.md)、[RFC-0024](./rfc-0024-ffmpeg-modern-island.md)、[RFC-0031](./completed/rfc-0031-mpeg2-playback-path-modernization.md)、[RFC-0035](./rfc-0035-legacy-mpcvideodec-ffmpeg-retirement.md) |

## 1. 摘要

[RFC-0025](./completed/rfc-0025-ffmpeg-dxva-followup.md) 已完成 `FfmpegContext.c` 只读审计，并明确 **不得** 把 DXVA 迁移混入当前 H.264/MPEG-2/VC-1 **modern software bridge** 稳定线。MPEG-2 DXVA picture context 合同由 [RFC-0030](./rfc-0030-mpeg2-dxva-context-modernization.md) 落地，但普通 MPEG-2 播放走 [RFC-0031](./completed/rfc-0031-mpeg2-playback-path-modernization.md)（已完成）的 `CMpeg2DecFilter` software 路径。

本 RFC 承接 RFC-0025 §5「VC-1 / H.264 DXVA 迁移等待 MPEG-2 context 模式验证后再继续」，为 **H.264** 与 **VC-1/WMV3** 硬解定义阶段 2 实施范围、合同与验证，而不重复 software modern 工作。

## 2. 背景

当前行为（RFC-0024 已文档化）：

1. H.264、MPEG-2、RealVideo 命中 **modern bridge** 时 **禁用** 旧 DXVA 探测/解码。
2. VC-1/WMV3 命中 modern bridge 时禁用旧 VC-1 DXVA 与 `FFIsInterlaced` 旧探测。
3. 未命中 modern bridge 的样本仍可能走旧 `FfmpegContext.c` + 旧 FFmpeg 私有结构 DXVA。

风险：旧 DXVA 依赖 `H264Context`、`VC1Context` 等 **非稳定 API**；与 FFmpeg 8.1 island 并存时不可直接读取 modern 私有结构。

## 3. 目标

1. 为 H.264 DXVA 定义项目自有 picture/slice contract（类比 `DxvaMpeg2PictureContext`）。
2. 为 VC-1 DXVA 定义同等 contract，与 WMV3 software modern 路径解耦。
3. 旧 FFmpeg reader 或未来 bitstream reader 只填充 contract，DXVA decoder 类不直接读 `H264Context`/`VC1Context`。
4. 增加 DXVA selection/fallback **低容量日志** 与手测/selfcheck 模板（RFC-0025 要求）。
5. 明确与 modern software 的互斥策略：bridge 打开成功则继续禁用旧 DXVA（保持 RFC-0024 决策）。

## 4. 非目标

1. 不启用 FFmpeg 新版 hwaccel API（RFC-0025 非目标）。
2. 不替换 DirectShow filter 图或 UI。
3. 不在本 RFC 中恢复 modern bridge 上的 DXVA（software 优先）。
4. 不迁移 `CMpeg2DecFilter` 的 DXVA（真实 MPEG-2 graph 无 DXVA；见 RFC-0031）。

## 5. 依赖与前置

| 前置 | 状态 |
| --- | --- |
| RFC-0025 审计 | 已完成 |
| RFC-0030 `DxvaMpeg2PictureContext` 模式 | 已实现，可作模板 |
| RFC-0031 MPEG-2 software modern 稳定 | 已完成（见 completed/rfc-0031） |
| RFC-0032 RMVB software 稳定 | 已完成（见 completed/rfc-0032） |

## 6. 候选方案

### 方案 A：H.264 先行（推荐）

先隔离 H.264 DXVA reader → contract，验证 EVR/DXVA2 样本，再复制模式到 VC-1。

优点：用户面最大、RFC-0030 已验证合同模式。  
风险：H.264 参考帧/POC 合同复杂度高。

### 方案 B：VC-1 先行

先 WMV/VC-1 DXVA contract，样本面较窄。

优点：范围小。  
风险：与 WMV3 modern software 路径交叉测试成本高。

## 7. 推荐方案

**方案 A**：H.264 DXVA contract 先行；VC-1 紧随其后。实施前必须确认对应 codec 的 **modern software** selfcheck 与 seek 稳定（RFC-0024/0027/0028）。

## 8. 实施计划

1. **阶段 1（已完成 2026-07-17）**：审计 `FfmpegContext.c` / `DXVADecoderH264` / `DXVADecoderVC1` 对 `H264Context` / `VC1Context` 的字段使用。
   - 脚本：`src/BuildScript/audit-rfc0033-dxva-h264-vc1-refs.ps1`
   - 清单：`src/Thirdparty/ffmpeg-modern/mpcvideodec-dxva-h264-vc1-refs.txt`
2. 新增 `DxvaH264PictureContext`、`DxvaVc1PictureContext`（命名可调整）头文件与只读 reader（模板：`DxvaMpeg2PictureContext` / `FFMpeg2ReadPictureContext`）。
3. 重构 DXVA decoder 消费点为 contract-only。
4. 新增 `test-rfc0033-h264-dxva-selfcheck.ps1`（或扩展现有 0030 脚本参数化）。
5. 手测：DXVA 开/关、modern bridge 开/关 四象限矩阵。

## 9. 验证计划

```text
dev.ps1 buildFast: PASS (无 DXVA 行为变更时)
test-rfc0030-mpeg2-dxva-selfcheck.ps1: 仍 PASS / SKIP 语义不变
新增 RFC-0033 selfcheck: TBD
手测: H.264/VC-1 样本硬解首帧、seek、长时间播放
```

## 10. 下一步行动

1. ~~等待 RFC-0031/0032 收口~~（已完成）。
2. **下一步**：设计并落地 `DxvaH264PictureContext` + `FFH264ReadPictureContext`（先 H.264，后 VC-1）。
3. 状态/索引已同步 [ROADMAP](../../ROADMAP.md) 与 [TASK_TRACKING.md](../../TASK_TRACKING.md)。
