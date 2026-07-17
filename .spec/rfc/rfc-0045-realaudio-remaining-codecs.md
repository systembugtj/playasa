# RFC-0045: RealAudio 剩余 codec（AAC / 14_4 / 28_8）Modern 化

| 字段 | 内容 |
| --- | --- |
| **状态** | 提案 (Proposed) |
| **创建日期** | 2026-07-17 |
| **最后更新** | 2026-07-17 |
| **负责人** | AI / Playasa |
| **相关 RFC** | [RFC-0034](./completed/rfc-0034-realaudio-modern-playback.md)、[RFC-0044](./rfc-0044-realaudio-legacy-cleanup.md)、[RFC-0024](./rfc-0024-ffmpeg-modern-island.md) |

## 1. 摘要

[RFC-0034](./completed/rfc-0034-realaudio-modern-playback.md) 覆盖 cook / sipr / atrac3。`CRealAudioDecoder` 仍接受 `MEDIASUBTYPE_AAC` / `RAAC` / `RACP` / `14_4` / `28_8`，但 `RealAudioModern::CodecFromSubtype` 对这些 subtype 返回 0，modern 路径跳过解码。本 RFC 将剩余 RealMedia 音轨迁入同一 audio ABI / bridge，补齐 RMVB/RA 音频覆盖面。

## 2. 背景 / 现状

| subtype | 旧 codec 意图 | modern（0034 后） |
| --- | --- | --- |
| COOK / SIPR / ATRC | 已 modern | `PLAYASA_FFMPEG_MODERN_CODEC_COOK/SIPR/ATRAC3` |
| AAC / RAAC / RACP | `CODEC_ID_AAC`；`InitRA` 有特殊 extradata 前缀 | **未映射** → 无 PCM |
| 14_4 | `CODEC_ID_RA_144` | **未映射** |
| 28_8 | `CODEC_ID_RA_288` | **未映射** |
| DNET | 历史占位 | 本 RFC **不处理**（样本/需求未确认） |

Splitter 对 RAAC/RACP/AAC 有独立 packet framing（`Deliver` 侧按 size list 切帧）；解码侧需保留该 demux 行为，只换 decoder open/decode。

## 3. 目标

1. Island：按需启用 `--enable-decoder=aac`、`ra_144`、`ra_288`（以 FFmpeg 8.1 实际 decoder 名为准，钉入 `rfc0024-expected.txt`）。
2. C ABI：新增 `PLAYASA_FFMPEG_MODERN_CODEC_AAC` / `RA144` / `RA288`（或等价命名），复用现有 `open_audio` / `decode_audio` / `receive_audio`。
3. `CodecFromSubtype` + `BuildAudioOpenParams`：覆盖 AAC 族与 14_4 / 28_8；复用/移植原 `InitRA` AAC extradata（`0x02` 前缀）与 WAVEFORMATEX 字段。
4. selfcheck：至少一条 **Real AAC**（或 RAAC）样本 open + 首包 PCM；若公开样本可得，再加 14_4/28_8。
5. 文档：更新 RFC-0034 遗留表与 ROADMAP 测试速查。

## 4. 非目标

1. 不删除 Real SDK 死代码（RFC-0044）。
2. 不改 RealMedia demux / 时间戳。
3. 不强制 DNET / 其他冷门 RealAudio 变体。
4. 不把解码并入 `MPCVideoDecFilter`。

## 5. 实施计划

### 阶段 1：Island + ABI

1. 确认 FFmpeg 8.1 decoder 名（`aac`、`real_144`/`ra_144`、`real_288`/`ra_288`）。
2. 更新 `rfc0024-expected.txt`、`build-rfc0024-ffmpeg-modern.ps1`、`verify-rfc0024-ffmpeg-modern.ps1`。
3. 扩展 `ffmpeg_modern_bridge.h` codec enum + adapter/`ModernFfmpegBridge.cpp` 映射。
4. 重编 island + bridge；bridge smoke PASS。

### 阶段 2：Decoder 接入

1. `RealAudioExtradata`：AAC 族 extradata 构建；14_4/28_8 参数（通常无 cook 式扫描）。
2. `CRealAudioDecoder::Receive`：已有 RAAC 直通 `src/dst` 路径保持；确保 block_align / 分包与 modern decode 一致。
3. 日志针脚：`RealAudio modern FFmpeg bridge open OK codec=<id>`。

### 阶段 3：样本与测试

1. `setup-*-samples.ps1`：登记可复现样本 URL（优先 samples.ffmpeg.org / 仓内 out/selfcheck）。
2. 新增 `test-rfc0045-realaudio-aac-selfcheck.ps1`（或扩展 0034 脚本参数化 subtype）。
3. cook 回归：`test-rfc0034-realaudio-selfcheck.ps1` 仍 PASS。

## 6. 验证计划

```text
./dev.ps1 buildFast
src/BuildScript/verify-rfc0024-ffmpeg-modern.ps1
src/Test/Scripts/test-rfc0024-modern-bridge-smoke.ps1
src/Test/Scripts/test-rfc0034-realaudio-selfcheck.ps1
src/Test/Scripts/test-rfc0045-realaudio-aac-selfcheck.ps1   # 新增
```

## 7. 风险

| 风险 | 缓解 |
| --- | --- |
| Real AAC extradata 与裸 ADTS/ASC 差异 | 保留 0034 前 `InitRA` AAC 分支逻辑，对照旧路径 |
| 14_4/28_8 公开样本稀缺 | 阶段 3 允许「codec open smoke」单元级测试 + AAC 必过 |
| island 体积 | 仅 enable 必要 decoder |

## 8. 依赖

- **建议先完成 [RFC-0044](./rfc-0044-realaudio-legacy-cleanup.md)**，避免在 `#ifdef RA_FFMPEG` 迷宫中改 AAC。
- 父级 island 合同：[RFC-0024](./rfc-0024-ffmpeg-modern-island.md)。

## 9. 下一步行动

1. 确认公开 AAC/RAAC 样本并写入 setup 脚本。
2. 提案通过后按阶段 1→3 执行。
