# RFC-0034: RealAudio Modern 播放路径

| 字段 | 内容 |
| --- | --- |
| **状态** | 提案 (Proposed) |
| **创建日期** | 2026-05-17 |
| **负责人** | AI / Playasa |
| **相关 RFC** | [RFC-0032](./completed/rfc-0032-rmvb-realvideo-modern-playback.md)、[RFC-0024](./rfc-0024-ffmpeg-modern-island.md) |

## 1. 摘要

[RFC-0032](./completed/rfc-0032-rmvb-realvideo-modern-playback.md) 明确 **非目标** 包含 RealAudio：RMVB 文件常带 RealAudio 音轨，当前仍可能走 `RA_FFMPEG` 或 splitter/decoder 旧路径。本 RFC 单独跟踪 RealAudio（cook、sipr、ralf 等）是否及如何迁入 `playasa_ffmpeg_modern_bridge`，与 RealVideo 视频现代化解耦。

## 2. 背景

1. RealMedia 容器由 `RealMediaSplitter` demux，视频已 modern 化（RFC-0032）。
2. 音频解码器链路与视频不同，可能不经 `CMPCVideoDecFilter`。
3. FFmpeg 8.1 island 当前 configure 以 **视频软件解码** 为主；音频 decoder 需单独评估许可证与体积。

## 3. 目标

1. 审计 RM/RMVB 样本实际 graph 中的 **音频 decoder** CLSID 与模块。
2. 列出需支持的 RealAudio FourCC / codec id 与样本覆盖。
3. 评估 modern bridge 扩展 `PLAYASA_FFMPEG_MODERN_CODEC_*` 音频枚举的可行性。
4. 若迁移，提供 seek/flush 与 A/V sync 验证计划。

## 4. 非目标

1. 不替换 RealMedia 容器 splitter（同 RFC-0032）。
2. 不在本 RFC 中修改 RealVideo 视频时间戳（归属 RFC-0032 阶段 2）。
3. 不强制删除旧 RealAudio 实现直至 modern 路径验证通过。

## 5. 依赖

| 依赖 | 说明 |
| --- | --- |
| RFC-0032 阶段 1 | 视频 modern decode 已通 |
| RFC-0024 island | 可能需 `--enable-decoder=` 增加 cook/sipr/… |

## 6. 实施计划（待启动）

1. 播放 RMVB 样本，记录 `SVPDebug.log` 中音频 filter 连接行。
2. 对照 `realmediasplitter`、`fgmanager` 注册表定位音频 transform。
3. 在 `build-rfc0024-ffmpeg-modern.ps1` 中试点启用目标 decoder 并重编 island。
4. 新增 `test-realaudio-rmvb-selfcheck.ps1`（或扩展现有 RMVB 脚本断言音频 modern 日志）。

## 7. 验证计划

```text
setup-rmvb-samples.ps1
手工: RMVB 播放有连续音频
自动化: TBD（音频 modern open 日志针）
```

## 8. 下一步行动

1. 完成 RFC-0032 阶段 2 后再启动（避免 A/V 同时大改难以归因）。
2. 执行 §6 步骤 1 审计并回填本 RFC「当前验证结果」节。
