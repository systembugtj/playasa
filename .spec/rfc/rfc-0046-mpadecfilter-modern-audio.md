# RFC-0046: MpaDecFilter Modern FFmpeg 音频迁移

| 字段 | 内容 |
| --- | --- |
| **状态** | 提案 (Proposed) |
| **创建日期** | 2026-07-17 |
| **最后更新** | 2026-07-17 |
| **负责人** | AI / Playasa |
| **相关 RFC** | [RFC-0024](./rfc-0024-ffmpeg-modern-island.md)、[RFC-0035](./rfc-0035-legacy-mpcvideodec-ffmpeg-retirement.md)、[RFC-0034](./completed/rfc-0034-realaudio-modern-playback.md)、[RFC-0044](./completed/rfc-0044-realaudio-legacy-cleanup.md)、[RFC-0045](./completed/rfc-0045-realaudio-remaining-codecs.md)、[RFC-0033](./rfc-0033-ffmpeg-dxva-phase2-h264-vc1.md) |

## 1. 摘要

`MpaDecFilter` 仍通过旧 `mpcvideodec/ffmpeg`（libavcodec 52）调用 `avcodec_open` / `avcodec_decode_audio2`，并在 Unicode 静态库配置链接 `libavcodec_gcc`。这是 [RFC-0035](./rfc-0035-legacy-mpcvideodec-ffmpeg-retirement.md) 删旧树的硬门禁之一（与 [RFC-0033](./rfc-0033-ffmpeg-dxva-phase2-h264-vc1.md) DXVA 解耦并列）。

本 RFC 将 MpaDec 的 **FFmpeg 后端** 迁到已有 `playasa_ffmpeg_modern_bridge` audio ABI（与 RealAudio [RFC-0034](./completed/rfc-0034-realaudio-modern-playback.md) / [RFC-0045](./completed/rfc-0045-realaudio-remaining-codecs.md) 同模式），最终去掉对旧 libavcodec 的 include 与链接。

## 2. 背景

### 2.1 当前状态

- 入口：`InitFfmpeg` / `DeliverFfmpeg` / `ProcessFfmpeg`（`MpaDecFilter.cpp`）。
- 生命周期：`avcodec_init` → `avcodec_find_decoder` → `avcodec_alloc_context` → `avcodec_open` → `avcodec_decode_audio2` → `avcodec_close`。
- 辅助：`FFGetChannelMap` / `FF_aligned_malloc`（旧树 `mpc_helper.c`）。
- 工程：`MpaDecFilter_vs2005.vcxproj` 在 Release Unicode lib 等配置链接 `libavcodec_gcc` + MinGW CRT。

### 2.2 走 FFmpeg 的 MEDIASUBTYPE（约 17 个 CodecID）

| 族 | MEDIASUBTYPE / CodecID | 备注 |
| --- | --- | --- |
| RealAudio 重叠 | COOK / SIPR / 14_4 / 28_8 | RealMedia 路径已 modern；MpaDec 仍有遗留分支 |
| 压缩音频 | WMA1/2、AMR_NB/WB、NELLYMOSER、QDM2、IMA4、PCM_MULAW | 需扩展 island + bridge enum |
| AC3 混合 | E-AC3 / TrueHD / MLP | AC3 本体仍走 a52；仅 BSID>12 / sync 分支走 FFmpeg |
| FLAC 双路径 | `F1AC_FLAC` | 另有 libFLAC 原生路径；需择一或收敛 |

**不经 FFmpeg（本 RFC 非目标）**：libmad（MP3）、liba52（AC3）、libdts、faad2（AAC）、libFLAC（`FLAC_FRAMED`）、libvorbisidec、原生 PCM。

## 3. 目标

1. `MpaDecFilter` **不再** `#include` 旧 `mpcvideodec/ffmpeg`，**不再**链接 `libavcodec_gcc` / `libgcc.a` / `libmingwex.a`。
2. 用 `playasa_ffmpeg_modern_*` audio ABI 替代 `InitFfmpeg` / `DeliverFfmpeg`（LoadLibrary 适配器，对齐 `CRealAudioModernDecodeAdapter`）。
3. 保留现有 73 个输入 subtype 注册面与输出 `Deliver` / SPDIF 行为（非 FFmpeg 后端不变）。
4. 为 channel map 提供不依赖 `H264/AC3` 私有结构的替代（替换 `FFGetChannelMap`）。
5. 增加 `verify` / selfcheck：至少覆盖 bridge open smoke + 代表性样本（WMA/AMR/E-AC3 等按可用样本）。

## 4. 非目标

1. 不迁移 libmad / a52 / dts / faad2 / libFLAC / vorbis 原生路径。
2. 不改动 RealMedia `CRealAudioDecoder`（已 modern）。
3. 不做 RFC-0033 DXVA；不做 MPCVideoDec 视频 legacy 删除（仍归 RFC-0035）。
4. 不重排 FGManager merit，除非为去掉死注册（如 COOK `#if 0`）所必需。
5. 不引入 stub bridge；缺 DLL 必须失败（与现有 modern 契约一致）。

## 5. 方案

### 方案 A：按 codec 族扩展 island + 统一 MpaDec 适配器（推荐）

**原理**：复用 RealAudio audio ABI；按需 `--enable-decoder=` 与 `PLAYASA_FFMPEG_MODERN_CODEC_*`；MpaDec 侧单一 `MpaDecModernDecodeAdapter`。

**步骤**：见 §6。

**风险**：E-AC3/TrueHD channel map 与 WMA/AMR extradata 需仔细移植；island 体积增大。

### 方案 B：仅隔离「旧树为 MpaDec+DXVA 专用」

**原理**：收窄 vcxproj，不迁 decode，仍保留旧树。

**风险**：无法满足 RFC-0035 删树门禁；双 FFmpeg 永久共存。**否决**。

## 6. 实施计划

| 阶段 | 内容 | 验收 |
| --- | --- | --- |
| 0 Scaffold | `MpaDecModernDecodeAdapter`（clone RealAudio）；subtype→codec 表；共享/抽出 extradata helper | 编译挂接、未改行为 |
| 1 Overlap | COOK/SIPR/RA144/RA288：文档化 RealAudio 为优先路径；清理 MpaDec 死分支 / FGManager `#if 0` | grep 无死 `CODEC_ID_COOK` 活动路径（或明确废弃） |
| 2 Bridge 扩展 | enum + island：`wma*`、`amr*`、`nellymoser`、`qdm2`、`eac3`、`truehd`、`mlp`、`flac`、`pcm_mulaw`、`adpcm_ima_qt`；更新 `rfc0024-expected.txt` | `verify-rfc0024` + bridge smoke open |
| 3 集成 | `ProcessFfmpeg` → `decode_audio` + `receive_audio`；映射 `PlayasaFfmpegModernAudioFrameInfo` → 现有 float/`Deliver`；处理 `NEED_MORE_INPUT` | `buildFast` + 样本矩阵 |
| 4 去链接 | 删旧 include；vcxproj 去 `libavcodec_gcc`；更新 `audit-rfc0035` 期望；RFC-0035 门禁勾选 | audit 无 MpaDec→旧树命中 |

## 7. 验证计划

```text
./dev.ps1 buildFast
src/BuildScript/verify-rfc0024-ffmpeg-modern.ps1
src/Test/Scripts/test-rfc0024-modern-bridge-smoke.ps1  (扩展新 codec open)
src/BuildScript/audit-rfc0035-legacy-ffmpeg-refs.ps1   (MpaDec 主题 → 0)
新增: test-rfc0046-mpadec-modern-selfcheck.ps1
回归: test-rfc0034 / test-rfc0045 / test-rmvb-seek（RealAudio 不回归）
```

## 8. 风险

| 项 | 缓解 |
| --- | --- |
| E-AC3/TrueHD 无 `FFGetChannelMap` | 用 public AVFrame channel layout / WAVEFORMATEXTENSIBLE mask |
| FLAC 双路径 | 阶段 3 收敛：优先原生 libFLAC 或统一 modern；删重复 TODO |
| AMR/WMA extradata 黑客 | 原样迁入 `PlayasaFfmpegModernAudioOpenParams` 构建器并单测 |
| vcxproj Debug/Release 链接不对称 | 阶段 4 两配置一并去掉 MinGW 依赖 |

## 9. 下一步行动

1. 评审本 RFC；确认方案 A。
2. 启动阶段 0：适配器脚手架 + subtype 映射表（常量，无魔法字符串散落）。
3. 与 RFC-0033 并行推进（二者均为 RFC-0035 门禁）。

## 10. 决策记录

| 决策 | 内容 |
| --- | --- |
| 推荐方案 | A（modern bridge 迁移，非隔离旧树） |
| 模板 | RealAudio `CRealAudioModernDecodeAdapter` + audio ABI |
| 编号 | RFC-0046（接 0045；不占用 0033/0035） |
