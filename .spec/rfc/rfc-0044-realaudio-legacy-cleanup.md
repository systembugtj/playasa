# RFC-0044: RealAudio Legacy SDK / `RA_FFMPEG` 清理

| 字段 | 内容 |
| --- | --- |
| **状态** | 提案 (Proposed) |
| **创建日期** | 2026-07-17 |
| **最后更新** | 2026-07-17 |
| **负责人** | AI / Playasa |
| **相关 RFC** | [RFC-0034](./completed/rfc-0034-realaudio-modern-playback.md)、[RFC-0032](./completed/rfc-0032-rmvb-realvideo-modern-playback.md)、[RFC-0035](./rfc-0035-legacy-mpcvideodec-ffmpeg-retirement.md)、[RFC-0024](./rfc-0024-ffmpeg-modern-island.md) |

## 1. 摘要

[RFC-0034](./completed/rfc-0034-realaudio-modern-playback.md) 已将 cook / sipr / atrac3 接到 `playasa_ffmpeg_modern_bridge`，并移除 `RealMediaSplitter` 对旧 `avcodec.h` / `libavcodec_gcc` 的链接。源码中仍保留 `#define RA_FFMPEG` 与大段 `#ifndef RA_FFMPEG` **Real SDK**（`RAOpenCodec` / `drv*.dll`）死分支。本 RFC 对齐 RealVideo（RFC-0032 删除 `RV_FFMPEG`）做法：令 `CRealAudioDecoder` **modern-only**，删除 SDK 回退与宏门闩。

## 2. 背景 / 现状

1. `RealMediaSplitter.h`：`#define RA_FFMPEG`；`#ifndef RA_FFMPEG` 下仍声明 Real SDK 函数指针与 `m_hDrvDll`。
2. `RealMediaSplitter.cpp`：`CheckInputType` / `InitRA` / `Receive` / `FreeRA` 等处夹杂 `#ifndef RA_FFMPEG` SDK 路径；默认编译从不进入。
3. 与 [RFC-0035](./rfc-0035-legacy-mpcvideodec-ffmpeg-retirement.md) 正交：本 RFC **不**删除 `mpcvideodec/ffmpeg` 树，只清理 RealMediaSplitter 内 RealAudio SDK 死代码。

## 3. 目标

1. 删除 `RA_FFMPEG` 宏及所有 `#ifdef/#ifndef RA_FFMPEG` 分支；保留且仅保留 modern bridge 路径。
2. 删除 Real SDK typedef / `LoadLibrary` / `RAOpenCodec*` / `RADecode` 等死代码。
3. `CRealAudioDecoder` 类成员只保留 `CRealAudioModernDecodeAdapter` 及相关字段。
4. 回归：`test-rfc0034-realaudio-selfcheck.ps1`、`test-rmvb-seek-selfcheck.ps1`、`./dev.ps1 buildFast`。
5. 可选增强：为 sipr（及 atrac3，若有样本）增加/扩展 selfcheck 针脚（不阻塞主目标）。

## 4. 非目标

1. 不扩展 AAC / 14_4 / 28_8（见 [RFC-0045](./rfc-0045-realaudio-remaining-codecs.md)）。
2. 不删除 `mpcvideodec/ffmpeg`（RFC-0035）。
3. 不修改 RealVideo / splitter demux 语义。

## 5. 实施计划

1. 审计 `RealMediaSplitter.cpp/.h` 中所有 `RA_FFMPEG` / `RAOpen` / `m_hDrvDll` 引用，列出删除清单。
2. 将 `#ifdef RA_FFMPEG` 块改为无条件代码；删除 `#ifndef` SDK 块。
3. 移除头文件中 SDK 函数指针与 `InitFfmpeg` 时代残留注释。
4. `buildFast` + RFC-0034/0032 selfcheck。
5. 更新 RFC-0034「遗留」表指向本 RFC 完成证明。

## 6. 验证计划

```text
./dev.ps1 buildFast
src/Test/Scripts/test-rfc0034-realaudio-selfcheck.ps1
src/Test/Scripts/test-rmvb-seek-selfcheck.ps1
# grep: RA_FFMPEG / RAOpenCodec / m_hDrvDll → 零命中（RealMediaSplitter）
```

## 7. 风险

| 风险 | 缓解 |
| --- | --- |
| 极少数环境依赖 Real SDK DLL | modern 已为默认且 selfcheck 通过；回滚靠 git |
| 大段 `#ifdef` 合并冲突 | 单文件顺序删除；先 diff 清单再改 |

## 8. 下一步行动

1. 提案评审通过后进入执行。
2. 建议在 RFC-0045 之前完成（减小 AAC 改动时的宏噪音）。
