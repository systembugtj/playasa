# RFC-0035: 旧 mpcvideodec 内嵌 FFmpeg 树退役

| 字段 | 内容 |
| --- | --- |
| **状态** | 提案 (Proposed) |
| **创建日期** | 2026-05-17 |
| **负责人** | AI / Playasa |
| **相关 RFC** | [RFC-0024](./rfc-0024-ffmpeg-modern-island.md)、[RFC-0017](./completed/rfc-0017-ffmpeg-mpcvideodec-upgrade.md)、[RFC-0031](./completed/rfc-0031-mpeg2-playback-path-modernization.md)、[RFC-0032](./completed/rfc-0032-rmvb-realvideo-modern-playback.md)、[RFC-0033](./rfc-0033-ffmpeg-dxva-phase2-h264-vc1.md) |

## 1. 摘要

[RFC-0024](./rfc-0024-ffmpeg-modern-island.md) 非目标包含「不在本 RFC 中删除旧 `mpcvideodec/ffmpeg`」。随着各 codec 子 RFC 完成 software modern 迁移，需要统一跟踪 **何时、如何** 移除 `src/Source/filters/transform/mpcvideodec/ffmpeg` 旧树及相关链接，避免双 FFmpeg 永久共存。

本 RFC 是 **退役程序**（program RFC），不重复各 codec 的实施细节。

## 2. 退役门禁（全部满足前不得删树）

| 门禁 | 跟踪 RFC | 说明 |
| --- | --- | --- |
| H.264/FLV/WMV/MPEG-4 等 MPCVideoDec modern 稳定 | RFC-0024 | 首帧 + seek selfcheck |
| MPEG-2 真实路径 modern-only | RFC-0031 | 无 `PLAYASA_MPEG2_LEGACY`，无 libmpeg2 |
| RealVideo modern + 时间戳 | RFC-0032 | 已完成 |
| DXVA 不依赖旧私有结构 | RFC-0033 | 或明确保留只读 shim 范围 |
| `verify-rfc0017` 策略更新 | RFC-0017 | 钉扎从 52.x 迁移到 modern-only 合同 |

## 3. 目标

1. 维护「仍依赖旧 libavcodec 52」的符号/文件清单（自动化 grep + 手审）。
2. 定义分阶段删除：先禁止新 fallback，再删未引用 TU，最后删整树。
3. 更新 `rfc0017-expected.txt` / `verify-rfc0017-ffmpeg-mpcvideodec.ps1` 反映新基准。
4. 全量 `dev.ps1 build` + 代表性样本矩阵回归。

## 4. 非目标

1. 不删除 `ffmpeg-modern` island（那是新基线）。
2. 不在门禁未满足时强行删树。
3. 不迁移 RealAudio（RFC-0034）到本 RFC 范围外强行合并。

## 5. 实施计划（待启动）

1. 生成 `mpcvideodec-legacy-ffmpeg-refs.txt` 门闩（脚本化引用计数）。
2. 与各子 RFC 负责人在 README 中勾选门禁。
3. 删除 `RV_FFMPEG`、旧 `avcodec_decode_video` 路径等已 modern-only 的 codec 分支。
4. 移除 `mpcvideodec/ffmpeg/` 目录与 vcxproj 编译项。
5. 归档 RFC-0024 为 completed 或将其状态改为「island-only 维护」。

## 6. 验证计划

```text
verify-rfc0012-all.ps1: PASS
verify-rfc0017-ffmpeg-mpcvideodec.ps1: 更新后 PASS
verify-rfc0024-ffmpeg-modern.ps1: PASS
test-rfc0024-*, test-rfc0031-*, test-rmvb-*, test-rfc0027-* : PASS
```

## 7. 下一步行动

1. 子 RFC 0031/0032 收口后运行步骤 1 引用审计。
2. 将审计结果写入本 RFC §8「当前清单」节（首次执行时追加）。
