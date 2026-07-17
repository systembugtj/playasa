# RFC-0032: RMVB / RealVideo Modern FFmpeg 播放路径

| 字段 | 内容 |
| --- | --- |
| **状态** | 已完成（阶段 1–3；`RV_FFMPEG` / 内嵌旧 RealVideo 路径已移除） |
| **创建日期** | 2026-05-17 |
| **完成日期** | 2026-07-11 |
| **负责人** | AI / Playasa |
| **相关 RFC** | [RFC-0024](../rfc-0024-ffmpeg-modern-island.md)、[RFC-0025](./rfc-0025-ffmpeg-dxva-followup.md)、[RFC-0017](./rfc-0017-ffmpeg-mpcvideodec-upgrade.md)、[RFC-0034](./rfc-0034-realaudio-modern-playback.md)（音频，已完成）、[RFC-0035](../rfc-0035-legacy-mpcvideodec-ffmpeg-retirement.md)、[RFC 索引](../../ROADMAP.md) |

## 1. 背景

RMVB / RealVideo（RV10–RV40）历史上走 `mpcvideodec` 内嵌旧 FFmpeg（`RV_FFMPEG`）或 `RealMediaSplitter` 内置 `CRealVideoDecoder`（Real SDK / 旧 libavcodec）。RFC-0024 建立了 `playasa_ffmpeg_modern_bridge.dll` 并行 island；本 RFC 把 RealVideo 软件解码迁入该 bridge，并保证 DirectShow 播放图上的 presentation timing 与 legacy 行为一致。

### 1.1 实际播放路径（已验证）

本机 RMVB 样本 graph 使用：

```text
RealMedia Splitter -> SVP RealVideo Decoder 2.0 (CMPCVideoDecFilter) -> renderer
```

CLSID：`{008BAC12-FBAF-497B-9670-BC6F6FBAE2C4}`。

内嵌 `CRealVideoDecoder`（`FGManager` 中 `#if 0`）保留为 modern-only 备用过滤器注册，不再含 `RV_FFMPEG` / Real SDK / 旧 libavcodec 路径。

## 2. 目标

1. 在 `playasa_ffmpeg_modern_bridge` 中启用 RV10/RV20/RV30/RV40 解码，并通过 `MPCVideoDec` modern path 播放 RMVB。
2. 保持 seek / flush 行为正确：`NewSegment` 不 flush decoder；`BeginFlush` 必须 flush modern session。
3. modern path 复用 legacy RealVideo 的 leap/timestamp 平滑，消除播放跳帧。
4. 提供可复跑 selfcheck 与 selfcheck 样本下载脚本。
5. 删除 `RealMediaSplitter` 内嵌 `CRealVideoDecoder` 的 `RV_FFMPEG` 与 legacy 分支。

## 3. 非目标

1. 不替换 `RealMediaSplitter` 容器 demux。
2. 不迁移 RealAudio（`RA_FFMPEG` 等）到 modern bridge（见 RFC-0034）。
3. 不启用 RealVideo DXVA。
4. 不在本 RFC 中删除 `mpcvideodec/ffmpeg` 整棵旧树（见 RFC-0035）。

## 4. 阶段 1：Bridge + 主路径（已完成）

见归档前 §4；关键日志：`Modern FFmpeg bridge open OK`、`Modern FFmpeg bridge flush on BeginFlush`。

## 5. 阶段 2：RV presentation timing（已完成）

| 变更 | 路径 |
| --- | --- |
| leap/input/output timing 纯函数 | `modern_ffmpeg/RealVideoPresentationTiming.h/.cpp` |
| modern decode 前 input timing + drop | `ModernFfmpegBridgeDecode()` |
| modern deliver 平滑 `rtStart` | `DeliverModernFfmpegFrame()` |
| legacy `SoftwareDecode` 复用 helper | `MPCVideoDecFilter.cpp` |

## 6. 阶段 3：收口（已完成 2026-07-11）

### 6.1 extradata

| 变更 | 路径 |
| --- | --- |
| `PlayasaBuildRealVideoExtradataFromVideoInfo()` | `modern_ffmpeg/RealVideoExtradata.h/.cpp` |
| `MPCVideoDecFilter` Connect | `MPCVideoDecFilter.cpp` |
| 内嵌 `CRealVideoDecoder::OpenModernRV()` | `RealMediaSplitter.cpp` |

典型 RMVB：`extradata=8`（`VIDEOINFOHEADER` + 跳过 26 字节 Real 头）。

### 6.2 删除 `RV_FFMPEG` / legacy `CRealVideoDecoder`

| 删除项 | 说明 |
| --- | --- |
| `#define RV_FFMPEG` | 头文件改为注释说明 modern-only |
| Real SDK (`drv*.dll`, `RVInit`/`RVTransform`) | `CheckInputType` / `Transform` 旧分支 |
| `TlibavcodecExt` + 内嵌 libavcodec 52 解码循环 | `CRealVideoDecoder` 仅保留 dynamic bridge |
| `Resize*` / `SetTypeSpecificFlags` / `Real_RVTransform` | legacy 专用代码 |

内嵌路径现与主路径一致：`RealVideoPresentationTiming` + `PlayasaBuildRealVideoExtradataFromVideoInfo` + `playasa_ffmpeg_modern_bridge.dll`。

`RA_FFMPEG` / `CRealAudioDecoder` **未动**（RFC-0034）。

## 7. 验证（2026-07-11）

```text
dev.ps1 buildFast: PASS
setup-rmvb-samples.ps1: PASS
test-rmvb-seek-selfcheck.ps1: PASS（首次偶发 graph 日志超时，重试 OK）
```

关键日志：

```text
Modern FFmpeg bridge open OK
Modern FFmpeg bridge flush on BeginFlush
Modern FFmpeg bridge first frame ready
RealVideo modern FFmpeg bridge open OK extradata=8   # 内嵌路径（若启用）
```

## 8. 关键文件索引

| 区域 | 文件 |
| --- | --- |
| Bridge ABI | `src/Thirdparty/pkg/ffmpeg_modern_bridge.h` |
| Adapter | `src/Source/filters/transform/mpcvideodec/modern_ffmpeg/ModernFfmpegDecodeAdapter.*` |
| 主解码路径 | `src/Source/filters/transform/mpcvideodec/MPCVideoDecFilter.cpp`、`.h` |
| RV timing / extradata | `modern_ffmpeg/RealVideoPresentationTiming.*`、`RealVideoExtradata.*` |
| 内嵌备用解码 | `src/Source/filters/parser/realmediasplitter/RealMediaSplitter.*` |
| 测试 | `src/Test/Scripts/test-rmvb-seek-selfcheck.ps1`、`setup-rmvb-samples.ps1` |

## 9. 决策记录

| 日期 | 决策 | 理由 |
| --- | --- | --- |
| 2026-05-17 | 主路径为 `CMPCVideoDecFilter` + modern bridge | graph 与 selfcheck 一致 |
| 2026-05-17 | RealVideo 禁用 DXVA | RFC-0024/0025 software 策略 |
| 2026-07-11 | 内嵌 `CRealVideoDecoder` modern-only，删 `RV_FFMPEG` | 与 RFC-0031 同策略；无 runtime fallback |
| 2026-07-11 | helper `.cpp` 仍由 `MPCVideoDec` 编译，RealMediaSplitter 链接复用 | 避免 duplicate symbol |

## 10. 后续（非本 RFC）

- **RFC-0034**：RealAudio modern 播放
- **RFC-0035**：旧 `mpcvideodec/ffmpeg` 树退役
- 可选：RMVB 连续播放 PTS selfcheck 断言
