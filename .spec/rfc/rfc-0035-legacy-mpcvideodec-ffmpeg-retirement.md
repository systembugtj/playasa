# RFC-0035: 旧 mpcvideodec 内嵌 FFmpeg 树退役

| 字段 | 内容 |
| --- | --- |
| **状态** | 执行中 (In Progress) |
| **创建日期** | 2026-05-17 |
| **最后更新** | 2026-07-17 |
| **负责人** | AI / Playasa |
| **相关 RFC** | [RFC-0024](./rfc-0024-ffmpeg-modern-island.md)、[RFC-0017](./completed/rfc-0017-ffmpeg-mpcvideodec-upgrade.md)、[RFC-0031](./completed/rfc-0031-mpeg2-playback-path-modernization.md)、[RFC-0032](./completed/rfc-0032-rmvb-realvideo-modern-playback.md)、[RFC-0033](./rfc-0033-ffmpeg-dxva-phase2-h264-vc1.md)、[RFC-0034](./completed/rfc-0034-realaudio-modern-playback.md)、[RFC-0044](./completed/rfc-0044-realaudio-legacy-cleanup.md)、[RFC-0045](./completed/rfc-0045-realaudio-remaining-codecs.md) |

## 1. 摘要

[RFC-0024](./rfc-0024-ffmpeg-modern-island.md) 非目标包含「不在本 RFC 中删除旧 `mpcvideodec/ffmpeg`」。随着各 codec 子 RFC 完成 software modern 迁移，需要统一跟踪 **何时、如何** 移除 `src/Source/filters/transform/mpcvideodec/ffmpeg` 旧树及相关链接，避免双 FFmpeg 永久共存。

本 RFC 是 **退役程序**（program RFC），不重复各 codec 的实施细节。

## 2. 退役门禁（全部满足前不得删树）

| 门禁 | 跟踪 RFC | 状态 |
| --- | --- | --- |
| H.264/FLV/WMV/MPEG-4 等 MPCVideoDec modern 稳定 | RFC-0024 | 部分（software bridge 已有；旧 fallback 仍在） |
| MPEG-2 真实路径 modern-only | RFC-0031 | ✓ |
| RealVideo modern + 时间戳 | RFC-0032 | ✓ |
| RealAudio modern + legacy 清理 | RFC-0034/0044/0045 | ✓ |
| DXVA 不依赖旧私有结构 | RFC-0033 | **阻塞**（提案） |
| `MpaDecFilter` 不再链接旧 libavcodec | （本 RFC 或后续子 RFC） | **阻塞**（见 §8） |
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
4. 迁移或隔离 `MpaDecFilter` 旧 audio decode 对 `libavcodec_gcc` 的链接。
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
2. **阻塞**：推进 [RFC-0033](./rfc-0033-ffmpeg-dxva-phase2-h264-vc1.md)（H.264/VC-1 DXVA contract）
3. 评估 `MpaDecFilter`：迁 modern audio ABI，或明确「旧树为 MpaDec+DXVA 专用」并收窄 vcxproj 引用面
4. 门禁全绿后再删树

## 8. 当前清单（审计 2026-07-17）

生成命令：

```text
powershell -NoProfile -ExecutionPolicy Bypass -File src/BuildScript/audit-rfc0035-legacy-ffmpeg-refs.ps1
```

产物：`src/Thirdparty/ffmpeg-modern/mpcvideodec-legacy-ffmpeg-refs.txt`

| 指标 | 值 |
| --- | --- |
| Total hits | 135 |
| Distinct files | 26 |

### 按主题（阻塞删树）

| 主题 | 约 hits | 说明 |
| --- | --- | --- |
| `libavcodec_gcc` | 19 | `MPCVideoDec` / `MpaDecFilter` / `MpcAudioRenderer` 等链接 |
| `MpaDecFilter` | 27 | 仍调用 `avcodec_decode_audio2` / `avcodec_open` |
| `FfmpegContext` | 25 | DXVA + legacy software 辅助 |
| `MPCVideoDecFilter` | 6 | 仍有 `avcodec_decode_video` fallback |
| `DXVADecoder*` | 5 | 依赖 `FfmpegContext.h` 私有结构 |

### 已清出（相对早期）

| 项 | 状态 |
| --- | --- |
| RealMediaSplitter → legacy avcodec | ✓ RFC-0034/0044 |
| `RA_FFMPEG` 宏 / Real SDK | ✓ RFC-0044（含 `FGManager` 显示名） |
| `CMpeg2DecFilter` / libmpeg2 | ✓ RFC-0031 |
| RealVideo `RV_FFMPEG` | ✓ RFC-0032 |

### 结论

**现在不能删 `mpcvideodec/ffmpeg`。** 最短路径：RFC-0033（DXVA 解耦）+ `MpaDecFilter` 迁移/隔离 → 再执行 §5.5 删树。
