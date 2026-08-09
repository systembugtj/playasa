# RFC-0035: 旧 mpcvideodec 内嵌 FFmpeg 树退役

| 字段 | 内容 |
| --- | --- |
| **状态** | 执行中 (In Progress) |
| **创建日期** | 2026-05-17 |
| **最后更新** | 2026-07-18 |
| **负责人** | AI / Playasa |
| **相关 RFC** | [RFC-0024](./rfc-0024-ffmpeg-modern-island.md)、[RFC-0017](./completed/rfc-0017-ffmpeg-mpcvideodec-upgrade.md)、[RFC-0031](./completed/rfc-0031-mpeg2-playback-path-modernization.md)、[RFC-0032](./completed/rfc-0032-rmvb-realvideo-modern-playback.md)、[RFC-0033](./completed/rfc-0033-ffmpeg-dxva-phase2-h264-vc1.md)、[RFC-0034](./completed/rfc-0034-realaudio-modern-playback.md)、[RFC-0044](./completed/rfc-0044-realaudio-legacy-cleanup.md)、[RFC-0045](./completed/rfc-0045-realaudio-remaining-codecs.md)、[RFC-0046](./completed/rfc-0046-mpadecfilter-modern-audio.md)、[RFC-0047](./rfc-0047-ffmpegcontext-dxva-glue-retirement.md) |

## 1. 摘要

[RFC-0024](./rfc-0024-ffmpeg-modern-island.md) 非目标包含「不在本 RFC 中删除旧 `mpcvideodec/ffmpeg`」。随着各 codec 子 RFC 完成 software modern 迁移，需要统一跟踪 **何时、如何** 移除 `src/Source/filters/transform/mpcvideodec/ffmpeg` 旧树及相关链接，避免双 FFmpeg 永久共存。

本 RFC 是 **退役程序**（program RFC），不重复各 codec 的实施细节。

## 2. 退役门禁（全部满足前不得删树）

| 门禁 | 跟踪 RFC | 状态 |
| --- | --- | --- |
| H.264/FLV/WMV/MPEG-4 等 MPCVideoDec modern 稳定 | RFC-0024 | 部分（software bridge + fail-closed；DXVA/FfmpegContext 仍依赖旧树） |
| MPEG-2 真实路径 modern-only | RFC-0031 | ✓ |
| RealVideo modern + 时间戳 | RFC-0032 | ✓ |
| RealAudio modern + legacy 清理 | RFC-0034/0044/0045 | ✓ |
| DXVA 不依赖旧私有结构 | [RFC-0033](./completed/rfc-0033-ffmpeg-dxva-phase2-h264-vc1.md) + [RFC-0047](./rfc-0047-ffmpegcontext-dxva-glue-retirement.md) | 0033 ✓；0047 阶段 4 ✓ / 5a runtime smoke ✓（glue 仍链接 `libavcodec_gcc`；删树待 5b） |
| `MpaDecFilter` 不再链接旧 libavcodec | [RFC-0046](./completed/rfc-0046-mpadecfilter-modern-audio.md) | ✓ |
| `verify-rfc0017` 策略更新 | RFC-0017 | 待删树时更新 |

## 3. 目标

1. 维护「仍依赖旧 libavcodec 52」的符号/文件清单（自动化 grep + 手审）。
2. 定义分阶段删除：先禁止新 fallback，再删未引用 TU，最后删整树。
3. 更新 `rfc0017-expected.txt` / `verify-rfc0017-ffmpeg-mpcvideodec.ps1` 反映新基准。
4. 全量 `dev.ps1 build` + 代表性样本矩阵回归。

## 4. 非目标

1. 不删除 `ffmpeg-modern` island（那是新基线）。
2. 不在门禁未满足时强行删树。
3. RealAudio modern 路径已由 RFC-0034/0044/0045 收口；本 RFC 仍只负责 `mpcvideodec/ffmpeg` 树退役。
4. 不在本 RFC 内完成 H.264/VC-1 DXVA 合同（RFC-0033）。

## 5. 实施计划

1. ~~生成 `mpcvideodec-legacy-ffmpeg-refs.txt` 门闩（脚本化引用计数）~~（2026-07-17）
2. 与各子 RFC 勾选门禁（§2）。
3. 在 RFC-0033 收口后：删除仍依赖 `FfmpegContext` 的 DXVA 私有结构读路径（或缩成 shim）。
4. ~~由 RFC-0046 迁移 MpaDecFilter~~（已完成）
5. 移除 `mpcvideodec/ffmpeg/` 目录与 vcxproj 编译项；更新 `verify-rfc0017`。
6. 归档 RFC-0024 为 completed 或改为「island-only 维护」。

## 6. 验证计划

```text
src/BuildScript/audit-rfc0035-legacy-ffmpeg-refs.ps1
verify-rfc0012-all.ps1: PASS
verify-rfc0017-ffmpeg-mpcvideodec.ps1: 更新后 PASS
verify-rfc0024-ffmpeg-modern.ps1: PASS
test-rfc0024-*, test-rfc0031-*, test-rmvb-*, test-rfc0027-*, test-rfc0034-*, test-rfc0045-* : PASS
```

## 7. 下一步行动

1. ~~运行步骤 1 引用审计~~（已完成）
2. ~~推进 RFC-0033~~（已完成）
3. ~~推进 RFC-0046~~（已完成；audit MpaDec 0 hits）
4. ~~Category A 死引用清理~~（2026-07-18）：`MpcAudioRenderer` / WMVSplitter / RealMedia `.vcproj` orphan links；删除未编入工程的 `MPCAudioDecFilter.*`
5. ~~Category B fail-closed~~（2026-07-18）：bridge codec 在 `!m_bUseDXVA` 时不再 `avcodec_open` / software fallback
6. ~~解耦 `EASplitter`~~（2026-07-18）：本地 `EaFfmpegCompat.h` + 去掉 ffmpeg `/I`；门禁 `verify-rfc0035-easplitter-no-legacy-ffmpeg.ps1`
7. ~~RFC-0047 阶段 1~~（2026-07-18）：`DXVADecoderH264` 去 `avcodec.h`；`FFH264GetNalLengthSize` / `FFH264ApplyExtradata`
8. ~~RFC-0047 阶段 2~~（2026-07-23）：`DxvaH264DxvaSession` + `FFH264*Session`；decoder 帧路径不再 `GetAVCtx()`
9. ~~RFC-0047 阶段 3~~（2026-07-23）：H.264/VC-1/MPEG-2 legacy glue 全部分离；`FfmpegContext.c` 公共层 4a ✓
10. ~~RFC-0047 阶段 4~~（2026-07-23）：H.264/VC-1/MPEG-2 modern parse + skip-open + glue 链接隔离 ✓
11. RFC-0047 阶段 5b：可选 GPU DXVA 样本 handoff ✓；`audit-rfc0035` `libavcodec_gcc` 降为 0 后删树

## 8. 当前清单（审计 2026-07-18）

生成命令：

```text
powershell -NoProfile -ExecutionPolicy Bypass -File src/BuildScript/audit-rfc0035-legacy-ffmpeg-refs.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File src/BuildScript/verify-rfc0035-easplitter-no-legacy-ffmpeg.ps1
```

产物：`src/Thirdparty/ffmpeg-modern/mpcvideodec-legacy-ffmpeg-refs.txt`

| 指标 | 值 |
| --- | --- |
| Total hits | 93 |
| Distinct files | 12（全部在 `mpcvideodec`） |

### 按主题（阻塞删树）

| 主题 | 说明 |
| --- | --- |
| `MPCVideoDec` + `libavcodec_gcc` | 仍为活跃链接（DXVA + 非 bridge legacy software） |
| DXVA / `FfmpegContext` | [RFC-0047](./rfc-0047-ffmpegcontext-dxva-glue-retirement.md) 阶段 1 已去 decoder `avcodec.h`；glue 仍读私有结构 |

### 已清出

| 项 | 状态 |
| --- | --- |
| RealMediaSplitter → legacy avcodec | ✓ RFC-0034/0044 |
| `RA_FFMPEG` / Real SDK | ✓ RFC-0044 |
| `CMpeg2DecFilter` / libmpeg2 | ✓ RFC-0031 |
| RealVideo `RV_FFMPEG` | ✓ RFC-0032 |
| MpaDecFilter → modern bridge | ✓ RFC-0046 |
| H.264/VC-1 DXVA contract | ✓ RFC-0033 |
| Orphan `libavcodec_gcc`（MpcAudioRenderer / WMV includes / stale vcproj） | ✓ 2026-07-18 |
| 未构建 `MPCAudioDecFilter.*` | ✓ 已删除 |
| Bridge codec software fail-closed | ✓ 2026-07-18 Category B |
| EASplitter 旧 ffmpeg 头 / include paths | ✓ 2026-07-18 |
| H.264 DXVA decoder TU 去 `avcodec.h` | ✓ RFC-0047 阶段 1 |
| H.264 DXVA ref/surface session contract | ✓ RFC-0047 阶段 2 |

### 结论

**现在仍不能删 `mpcvideodec/ffmpeg`。** 剩余硬依赖在 `MPCVideoDec`：`FfmpegContext.c` 私有结构读者 + `libavcodec_gcc`（跟踪 [RFC-0047](./rfc-0047-ffmpegcontext-dxva-glue-retirement.md)）。
