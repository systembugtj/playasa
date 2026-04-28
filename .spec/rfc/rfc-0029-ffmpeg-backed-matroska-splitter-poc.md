# RFC-0029：FFmpeg-backed Matroska Source/Splitter PoC

| 字段 | 内容 |
|------|------|
| **状态** | 提案 (Proposed) |
| **适用范围** | FFmpeg-backed Matroska/WebM packet timeline dump、DirectShow source/splitter PoC、旧 `MatroskaSplitter` 与 `libavformat` packet contract 对比 |
| **相关 RFC** | [RFC-0026](./completed/rfc-0026-mkv-support-modernization.md)、[RFC-0024](./rfc-0024-ffmpeg-modern-island.md)、[RFC-0028](./rfc-0028-uia-video-and-seek-followups.md) |
| **创建日期** | 2026-04-27 |
| **最后更新** | 2026-04-27 |

## 1. 摘要

RFC-0026 已完成短期 MKV playback contract 修复：现有 `MatroskaSplitter -> MPCVideoDec -> modern FFmpeg bridge` 链路不再输出 100ns 假视频 duration，并具备 MKV timing selfcheck。长期如果要更完整地“按 FFmpeg 正确方式处理 MKV/WebM”，正确位置仍然是 DirectShow source/splitter 层，而不是 video decoder。

本 RFC 跟踪后续 FFmpeg-backed Matroska Source/Splitter PoC。第一步只做 packet timeline dump，对比旧 `MatroskaSplitter` 和 `libavformat` 的 packet `pts/dts/duration/keyframe/extradata`，不直接接入主 graph。

## 2. 目标

1. 建立 `libavformat` 读取 MKV/WebM 的 packet timeline dump 工具。
2. 对比旧 `MatroskaSplitter` 的 DirectShow timing 与 FFmpeg `AVPacket` timing。
3. 明确 H.264 AVCC/extradata/keyframe/duration contract 的差异。
4. 为将来 DirectShow source/splitter 实现提供数据依据。
5. 不破坏当前已能工作的旧 splitter + modern decoder 路径。

## 3. 非目标

1. 不在 `MPCVideoDec` 内 demux MKV。
2. 不在 PoC 阶段替换默认 `MatroskaSplitter`。
3. 不一次性实现完整 DirectShow stream select、chapter、subtitle、attachment、cue handling。
4. 不把 FFmpeg island 的 C ABI 边界绕回 MSVC 直接链接 FFmpeg C++ 代码。

## 4. 设计方向

### 4.1 Packet Timeline Dump

PoC 工具读取 MKV/WebM 文件，输出每个 video stream packet：

1. stream index
2. codec id / codec tag
3. `AVStream.time_base`
4. packet `pts`
5. packet `dts`
6. packet `duration`
7. keyframe flag
8. side data / extradata 摘要

所有时间需要同时输出原始 FFmpeg ticks 和 rescale 后的 DirectShow `REFERENCE_TIME`，便于与 `MKV timing` 日志对比。

### 4.2 DirectShow Splitter 评估

只有 packet dump 对比证明收益明确后，才设计真实 filter：

1. FFmpeg-backed source/splitter 仍然输出 DirectShow pins。
2. audio/video/subtitle 必须共享同一 graph 状态。
3. seek、stream select、subtitle、chapter 不能被 decoder 私有状态接管。
4. modern FFmpeg bridge 继续只作为 decoder 层边界。

## 5. 验证计划

1. 对同一个 MKV 样本运行旧 `MatroskaSplitter` selfcheck，收集 `MKV timing` 日志。
2. 对同一个 MKV 样本运行 FFmpeg packet dump。
3. 对比前 N 个 video packet 的 timestamp、duration、keyframe。
4. 对 H.264 B-frame、多 slice、无 `BlockDuration`、含 SEI/AUD 的样本重复对比。
5. 不允许引入播放器默认播放路径回归。

## 6. 待完成

1. 确定 PoC 放置目录，优先考虑 `src\Prototype` 或 `src\Test` 下的只读工具。
2. 新增 FFmpeg packet timeline dump 工具。
3. 新增对比脚本，读取 `SVPDebug.log` 的 `MKV timing` 与 FFmpeg dump 输出。
4. 根据数据决定是否进入正式 DirectShow source/splitter 设计。

## 7. 相关文件

1. `src/Source/filters/parser/MatroskaSplitter/MatroskaSplitter.cpp`
2. `src/Source/filters/parser/BaseSplitter/BaseSplitter.cpp`
3. `src/Source/filters/transform/mpcvideodec/modern_ffmpeg`
4. `src/Thirdparty/ffmpeg-modern`
5. `src\Test\Scripts\test-rfc0026-mkv-timing-selfcheck.ps1`
