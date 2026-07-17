# RFC-0045: RealAudio 剩余 codec（AAC / 14_4 / 28_8）Modern 化

| 字段 | 内容 |
| --- | --- |
| **状态** | 已完成 (Completed) |
| **创建日期** | 2026-07-17 |
| **最后更新** | 2026-07-17 |
| **完成日期** | 2026-07-17 |
| **负责人** | AI / Playasa |
| **相关 RFC** | [RFC-0034](./rfc-0034-realaudio-modern-playback.md)、[RFC-0044](./rfc-0044-realaudio-legacy-cleanup.md)、[RFC-0024](../rfc-0024-ffmpeg-modern-island.md) |

## 1. 摘要

将 AAC / RAAC / RACP / 14_4 / 28_8 迁入与 RFC-0034 相同的 audio ABI / bridge；island 启用 `aac` / `ra_144` / `ra_288`。

## 2. Completion Proof

### Code

| Commit | 文件 | 说明 |
| --- | --- | --- |
| `e76b6289`..`CLOSE_HASH` | `rfc0024-expected.txt`、build/verify | `--enable-decoder=aac\|ra_144\|ra_288` |
| `e76b6289`..`CLOSE_HASH` | `ffmpeg_modern_bridge.h`、`ModernFfmpeg*` | codec 19–21 + `IsRealAudioCodec` |
| `e76b6289`..`CLOSE_HASH` | `RealAudioExtradata.*`、`RealMediaSplitter.cpp` | AAC ASC `0x02`；subtype；InitRA |
| `CLOSE_HASH` | `MPCVideoDecModernBridgeSmoke.cpp`、`test-rfc0045-*.ps1` | AAC/RA144/RA288 open smoke + selfcheck |

Build: island rebuild + bridge + `./dev.ps1 buildFast` PASS（2026-07-17）。

### Tests

| Script | Result |
| --- | --- |
| `verify-rfc0024-ffmpeg-modern.ps1` | PASS |
| `test-rfc0024-modern-bridge-smoke.ps1` | PASS（含 AAC/RA144/RA288 open） |
| `test-rfc0034-realaudio-selfcheck.ps1` | PASS（cook 回归） |
| `test-rfc0045-realaudio-remaining-selfcheck.ps1` | PASS |
| `test-rmvb-seek-selfcheck.ps1` | PASS |

## 3. 遗留

- 公开 Real AAC 整文件样本 selfcheck 为可选（脚本支持 `-SamplePath`）；默认以 bridge open smoke 验收。
- DNET 仍不处理。
