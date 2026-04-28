# RFC-0031: MPEG-2 Playback Path Modernization

| 字段 | 内容 |
| --- | --- |
| **状态** | 阶段 2/3 已实现，modern MPEG-2 software path 默认关闭 (Modern Software Path Guarded) |
| **创建日期** | 2026-04-27 |
| **负责人** | AI / Playasa |
| **相关 RFC** | [RFC-0030](./rfc-0030-mpeg2-dxva-context-modernization.md)、[RFC-0025](./completed/rfc-0025-ffmpeg-dxva-followup.md)、[RFC-0024](./rfc-0024-ffmpeg-modern-island.md) |

## 1. 背景

`RFC-0030` 已经把 `MPCVideoDec` 内部的 MPEG-2 DXVA picture context 读取收敛到项目自有结构 `DxvaMpeg2PictureContext`。但后续手测发现，普通 MPEG-2 样本默认并不会进入 `MPCVideoDec`，而是由独立的 `CMpeg2DecFilter` 处理：

```text
FGM: Connecting 'MPEG-2 Video Decoder' {39F498AF-1A09-4275-B193-673B0BA3D478}
```

这意味着继续只改 `MPCVideoDec` 无法覆盖真实 MPEG-2 playback graph。MPEG-2 向 modern FFmpeg 迁移前，需要先明确实际播放路径的所有权。

## 2. 目标

1. 明确 MPEG-2 文件在不同容器下的 decoder 选择：`.mpg`、`.mpeg`、`.m2v`、`.ts`、`.m2ts`、`.vob`、MPEG-2-in-MKV。
2. 判断 MPEG-2 modern FFmpeg 工作应该迁移 `CMpeg2DecFilter`，还是调整 graph routing 让目标样本进入 `MPCVideoDec`。
3. 保留 `RFC-0030` 的中间 context 作为可复用 DXVA 合同，避免直接读取旧 FFmpeg 私有结构扩散。
4. 建立可复跑 selfcheck，清楚区分 `MPCVideoDec`、`CMpeg2DecFilter`、系统 decoder 三类路径。

## 3. 非目标

1. 本 RFC 不直接替换 MPEG-2 解码器实现。
2. 本 RFC 不启用 modern FFmpeg DXVA。
3. 本 RFC 不改变默认用户播放行为，除非后续验证证明 routing 调整不会破坏兼容性。

## 4. 当前验证结果

已新增 `src/Test/Scripts/test-rfc0030-mpeg2-dxva-selfcheck.ps1`，用于记录 graph 路径、GPU 信息和目标 DXVA 日志。
已新增 `src/Test/Scripts/test-rfc0031-mpeg2-path-selfcheck.ps1`，用于批量分类 MPEG/MPEG-2 容器的 source/splitter/decoder/renderer 路径。

本机验证：

```text
sample: out/selfcheck/sample-mpeg2-dxva.m2ts size=660480
GPU: Intel(R) HD Graphics 4600 driver=20.19.15.4624; NVIDIA GeForce GTX 860M driver=32.0.15.7628
result: SKIP
reason: MPEG-2 sample did not reach MPCVideoDec; graph used CMpeg2DecFilter.
```

扩展真实样本验证：

```text
out/selfcheck/sample-mpeg2-dxva.m2ts -> MPEG-2 Video Decoder {39F498AF-1A09-4275-B193-673B0BA3D478}
out/selfcheck/sample-mpeg2-dxva.ts   -> MPEG-2 Video Decoder {39F498AF-1A09-4275-B193-673B0BA3D478}
out/selfcheck/sample-mpeg2-dxva.m2v  -> MPEG-2 Video Decoder {39F498AF-1A09-4275-B193-673B0BA3D478}
out/selfcheck/sample-mpeg2-dxva.vob  -> MPEG-2 Video Decoder {39F498AF-1A09-4275-B193-673B0BA3D478}
out/selfcheck/sample-mpeg2-dxva.mpg  -> MPEG-2 Video Decoder {39F498AF-1A09-4275-B193-673B0BA3D478}
out/selfcheck/sample-mpeg-small.mpeg -> MPEG Video Decoder {FEB50740-7BEF-11CE-9BD9-0000E202599C}
```

结论：这不是单个测试文件的问题。MPEG-2/MPEG playback graph 当前系统性优先选择旧 MPEG decoder path，`MPCVideoDec` 的 `DXVA selection:` 日志没有出现。

根因定位：

1. `FGManager.cpp` 主动注册 `CMpeg2DecFilter` 处理 `MEDIASUBTYPE_MPEG2_VIDEO`、`MEDIASUBTYPE_MPEG`、`MEDIATYPE_MPEG2_PACK` 和 `MEDIATYPE_MPEG2_PES`。
2. `MPC Video Decoder DXVA` 中的 MPEG-2 media types 仍处于注释状态。
3. 普通 `MPC Video Decoder` 注册块没有接管 MPEG-2 media types。
4. `CMpeg2DecFilter` 是独立旧模块，链接 `libmpeg2`，不是 `RFC-0030` 修改的 `MPCVideoDec` 模块。

## 5. `CMpeg2DecFilter` 审计结果

### 5.1 模块边界

目标模块位于 `src/Source/filters/transform/mpeg2decfilter/`。

核心文件：

1. `Mpeg2DecFilter.cpp`
2. `Mpeg2DecFilter.h`
3. `libmpeg2.cpp`
4. `libmpeg2.h`
5. `libmpeg2/vc++/libmpeg2.vcxproj`

`CMpeg2DecFilter` 是独立 DirectShow transform filter，CLSID 为 `{39F498AF-1A09-4275-B193-673B0BA3D478}`。它不是 `MPCVideoDec` 的一个模式，也不会触发 `MPCVideoDecFilter.cpp` 中的 `DXVA selection:` 日志。

### 5.2 Graph 输入类型

`CMpeg2DecFilter::CheckInputType()` 接受以下主要 MPEG/MPEG-2 输入：

1. `MEDIATYPE_DVD_ENCRYPTED_PACK` + `MEDIASUBTYPE_MPEG2_VIDEO`
2. `MEDIATYPE_MPEG2_PACK` + `MEDIASUBTYPE_MPEG2_VIDEO`
3. `MEDIATYPE_MPEG2_PES` + `MEDIASUBTYPE_MPEG2_VIDEO`
4. `MEDIATYPE_Video` + `MEDIASUBTYPE_MPEG2_VIDEO`
5. `MEDIATYPE_Video` + `MEDIASUBTYPE_MPEG`
6. MPEG-1 packet/video/payload variants

`MEDIATYPE_MPEG2_PES` 会设置 `m_allow_unbound_mpeg2_in_ts`，说明 TS/PES 路径有专门容错逻辑，不能用简单 routing 替代。

### 5.3 解码数据流

当前软件解码流：

```text
IMediaSample
  -> CDeCSSInputPin::StripPacket()
  -> CMpeg2DecFilter::Transform()
  -> CMpeg2Dec::mpeg2_buffer()
  -> CMpeg2Dec::mpeg2_parse()
  -> libmpeg2 display picture / display fbuf
  -> CMpeg2DecFilter::DeliverNormal()
  -> CMpeg2DecFilter::Deliver()
  -> CBaseVideoOutputPin::Deliver()
```

关键状态：

1. `STATE_SEQUENCE` 设置 `m_AvgTimePerFrame`。
2. `STATE_PICTURE` 把输入 sample 的 `rtStart` 绑定到 `m_dec->m_picture->rtStart`。
3. `STATE_SLICE` / `STATE_END` 从 `m_info.m_display_picture` 和 `m_info.m_display_fbuf` 取可显示帧。
4. 输出时间由 `picture->rtStart + m_AvgTimePerFrame * nb_fields` 推导。
5. `Deliver()` 只在等到 I-frame 后开始真正输出，避免从非关键帧乱播。

### 5.4 输出与 renderer

当前输出路径主要是软件 I420/IYUV/YV12 方向：

1. `DeliverFast()` 当前直接返回 `S_FALSE`，实际常用路径是 `DeliverNormal()`。
2. `DeliverNormal()` 负责 weave/blend/bob/field-shift 等 deinterlace。
3. `Deliver()` 通过 `GetDeliveryBuffer()` 获取输出 sample，调用 `CopyBuffer()` 写入并 `SetTime()`。
4. `SetTypeSpecificFlags()` 写 `AM_VIDEO_FLAG_WEAVE` 等 type-specific flags。
5. DVD source 连接 renderer 时存在额外白名单逻辑，包含 EVR。

### 5.5 DXVA 现状

`CMpeg2DecFilter` 当前审计未发现类似 `MPCVideoDec` 的 DXVA decoder object 创建路径。真实 MPEG-2 playback 是旧 `libmpeg2` 软件路径，不是 `RFC-0030` 的 MPEG-2 DXVA context path。

这意味着 `RFC-0030` 的 `DxvaMpeg2PictureContext` 仍是有价值的隔离合同，但目前没有真实 MPEG-2 graph 会自然走到它。下一步应先为 `CMpeg2DecFilter` 接入 modern FFmpeg software decode，再决定是否把 DXVA context 思路迁入此模块。

## 6. 候选方案

### 方案 A：迁移 `CMpeg2DecFilter`

技术原理：接受当前 graph 所有权，直接把真实 MPEG-2 播放路径现代化。先审计 `src/Source/filters/transform/mpeg2decfilter`，再决定是否接入 modern FFmpeg software decode 或抽出 DXVA context。

优点：命中真实用户路径，风险可观测。

风险：`CMpeg2DecFilter` 与 DVD/MPEG-PS 兼容面可能比 `MPCVideoDec` 更宽，需要更细的回归样本。

### 方案 B：调整 graph routing 到 `MPCVideoDec`

技术原理：让 MPEG-2 样本进入已经具备 FFmpeg modern bridge 和 `DxvaMpeg2PictureContext` 的 `MPCVideoDec`。

优点：复用 `RFC-0024` 和 `RFC-0030` 的基础设施。

风险：可能绕开 `CMpeg2DecFilter` 的 DVD、interlaced、MPEG-PS 特化逻辑，容易引入播放兼容性回归。

## 7. 推荐方案

推荐先执行方案 A。当前真实 graph 已经稳定选择 `CMpeg2DecFilter`，直接迁移真实路径比强行改 routing 更稳。`MPCVideoDec` 的 `DxvaMpeg2PictureContext` 保留为合同样板，后续可以复用到 `CMpeg2DecFilter` 或作为迁移目标对照。

## 8. 实施计划

已完成：

1. 审计 `src/Source/filters/transform/mpeg2decfilter` 的 decode、timestamp、renderer 交互。
2. 新增 `test-rfc0031-mpeg2-path-selfcheck.ps1`，覆盖 `.m2ts`、`.ts`、`.m2v`、`.vob`、`.mpg`、`.mpeg`。
3. 记录每类样本的 source filter、splitter、decoder 和 renderer。

新增实现：

1. 新增 `Mpeg2ModernDecodeAdapter.h/.cpp`，只负责动态加载 `playasa_ffmpeg_modern_bridge.dll` 并创建 `PLAYASA_FFMPEG_MODERN_CODEC_MPEG2` session。
2. `CMpeg2DecFilter` 新增 guarded modern MPEG-2 software decode path。
3. modern path 只在 `PLAYASA_MPEG2_MODERN=1` 时启用，默认仍走旧 `libmpeg2`。
4. modern decode 出错、bridge 不可用或输出格式不是 4:2:0 时，自动关闭 modern path 并回退旧 `libmpeg2`。
5. 输出帧拷贝仍走 `CBaseVideoFilter::CopyBuffer()`，避免新增 renderer-facing 输出格式。
6. 已加入 duration 归一化：modern bridge 返回过小 duration 时回退到输入 duration、`m_AvgTimePerFrame` 或 40ms，避免 `duration=1` 造成播放抖动。
7. `test-rfc0031-mpeg2-path-selfcheck.ps1` 新增 `-EnableModernMpeg2` 和 `-RequireModernMpeg2FirstFrame`。
8. 新增 `test-rfc0031-mpeg2-modern-selfcheck.ps1`，将 modern MPEG-2 样本分成稳定严格验证与扩展观察验证。

待执行：

1. 用更多 MPEG-2 样本验证 modern path 的 seek、interlaced、audio/video sync 和长时间播放。
2. 根据样本覆盖情况决定是否把 `PLAYASA_MPEG2_MODERN=1` 从环境开关升级为设置项。
3. 在 software path 稳定后，再评估 MPEG-2 DXVA 是否迁入 `CMpeg2DecFilter`。
4. 在新实现前保持 `MPCVideoDec` 的 `DxvaMpeg2PictureContext` 不继续扩大改动范围。

## 9. 验证计划

已完成：

```text
dev.ps1 buildFast: PASS
test-rfc0031-mpeg2-path-selfcheck.ps1 -RequireKnownPath: PASS
test-rfc0031-mpeg2-path-selfcheck.ps1 -SamplePaths out/selfcheck/sample-mpeg2-dxva.m2ts -EnableModernMpeg2 -RequireKnownPath -RequireModernMpeg2FirstFrame: PASS
test-rfc0031-mpeg2-modern-selfcheck.ps1: PASS
```

modern path 关键日志：

```text
MPEG-2 modern FFmpeg open OK
MPEG-2 modern FFmpeg first frame ready: width=640 height=360 start=0 stop=400000 duration=400000
```

多样本 modern 结果：

```text
stable strict:
out/selfcheck/sample-mpeg2-dxva.m2ts -> first frame OK, fallback False
out/selfcheck/sample-mpeg2-dxva.ts   -> first frame OK, fallback False

observation:
out/selfcheck/sample-mpeg2-dxva.m2v  -> first frame OK, fallback True
out/selfcheck/sample-mpeg2-dxva.vob  -> first frame OK, fallback True
out/selfcheck/sample-mpeg2-dxva.mpg  -> first frame OK, fallback True
```

解释：`m2v/vob/mpg` 已能出 modern 首帧，但仍会遇到 packet/container 形态导致的 fallback；因此目前只能把 `m2ts/ts` 作为严格通过样本，其它样本用于观察回归，不能据此开启默认 modern path。

仍需验证：

1. `test-rfc0030-mpeg2-dxva-selfcheck.ps1`
2. MPEG-2 样本 seek、关闭无 crash/hang
3. 更长 MPEG-2 样本的 A/V sync
4. 对照 `SVPDebug.log` 确认目标 decoder 路径和 modern path gate
