# RFC-0031: MPEG-2 Playback Path Modernization

| 字段 | 内容 |
| --- | --- |
| **状态** | 阶段 2/3 已实现，modern MPEG-2 software path 默认启用且 strict no-fallback；最终目标为 drop old `libmpeg2` |
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
2. `CMpeg2DecFilter` 新增 modern MPEG-2 software decode path，并作为默认 MPEG-2 software path 启用。
3. 旧 `libmpeg2` 只剩临时开发回滚开关 `PLAYASA_MPEG2_LEGACY=1`；这不是完成态，RFC 完成前应删除旧源码和项目引用。
4. modern decode 出错、bridge 不可用或输出格式不受支持时不再回退旧 `libmpeg2`；modern-only 模式下失败必须暴露为错误，避免旧路径掩盖现代实现问题。
5. modern 解码只负责把 FFmpeg 输出帧转换进 `m_fb`，最终交付继续走既有 `CMpeg2DecFilter::Deliver(false)`，复用 legacy renderer-facing 路径。
6. 已加入 duration 归一化：modern bridge 返回过小 duration 时回退到输入 duration、`m_AvgTimePerFrame` 或 40ms，避免 `duration=1` 造成播放抖动。
7. `test-rfc0031-mpeg2-path-selfcheck.ps1` 的 `-EnableModernMpeg2` 现在通过清除 `PLAYASA_MPEG2_LEGACY` 保证默认 modern path，不再设置已废弃的 `PLAYASA_MPEG2_MODERN`。
8. 新增 `test-rfc0031-mpeg2-modern-selfcheck.ps1`，当前默认把 `.m2ts/.ts/.m2v/.vob/.mpg` 全部作为 strict no-fallback 验证样本。
9. modern 输出补充 4:2:2/4:4:4 planar YUV 到 I420 的下采样，保持 renderer-facing 格式不变。
10. 首帧之后的少量 invalid packet 改为 soft failure；renderer delivery failure 仍视为 modern path 错误，但不会触发旧 `libmpeg2` fallback。
11. modern path 对帧时间戳做单调归一化，避免 raw elementary stream 中重复/回退 PTS 影响 renderer delivery。
12. `playasa_ffmpeg_modern_bridge.dll` 对 MPEG-2 启用 FFmpeg parser，并保留 parser 提前返回时尚未消费的输入，避免 DirectShow sample 边界和 picture 边界不一致导致丢包、花屏或 invalid packet。
13. 撤销 early modern path 自建 output sample 的做法，避免绕过 `Deliver()` 中的 1088 裁剪、subtitle buffer、rate change、output subtype 和 type-specific flag 处理。
14. 修复 bridge `avcodec_send_packet()` 返回 `EAGAIN` 时丢弃当前 encoded packet 的问题；现在会先输出 pending frame，再保留并重送该 packet。
15. `.m2v` raw elementary stream 的 `disc=1 start=0 stop=1` 标记块会在短样本尾部/renderer clock stop 后再次出现；modern path 识别该 bogus ES marker，不再把它升级为 decoder reset 或 modern fallback。
16. 撤销 decoder 层注入 output `SetDiscontinuity(TRUE)` 的做法，继续依赖 base filter 的 `NewSegment` 传播，避免 EVR 在已停止/尾部状态拒收样本时误判 modern decoder 失败。
17. `CMpeg2DecFilter` 的 modern path 已移除 runtime legacy fallback：`TransformModern()` 失败会直接返回错误，`StartStreaming()` 打不开 bridge 也直接失败。
18. `PLAYASA_MPEG2_MODERN` 不再是启用条件；modern path 默认启用，只有 `PLAYASA_MPEG2_LEGACY=1` 会临时回到旧路径。
19. seek/NewSegment/discontinuity 时，modern path 使用独立 reset：只 flush modern FFmpeg bridge、清理 modern 时间轴和 raw ES suppress 状态，不再通过旧 `libmpeg2` reset 作为 seek 主路径。
20. 已新增 `test-rfc0031-mpeg2-seek-selfcheck.ps1` 作为 MPEG-2 seek harness 草案；当前 WM_COMMAND/UIA seek 在本机自动化环境未能可靠触发真实 seek，不能作为通过项。
21. 重新审计后修正遗漏：默认 modern path 只接 `MEDIASUBTYPE_MPEG2_VIDEO`，MPEG-1/系统 MPEG decoder 路径不会被 MPEG-2 modern session 误接管。
22. `StartStreaming()` 在默认 modern MPEG-2 路径不再创建并 reset `CMpeg2Dec/libmpeg2`，只在 `PLAYASA_MPEG2_LEGACY=1` 或非 MPEG-2 输入时进入 legacy 初始化。
23. modern path 启动时从输入 media type 填充 `m_AvgTimePerFrame`，避免 duration fallback 继续依赖旧 `STATE_SEQUENCE`。
24. `BeginFlush/NewSegment/discontinuity` 增加 post-flush/raw ES marker 状态区分：真实 flush 后仍 reset modern decoder，但 `.m2v` 尾部 `NewSegment(0)+disc(0..1)` 以及 renderer 已停止后的 `VFW_E_TYPE_NOT_ACCEPTED` 不再升级为 modern decoder failure。
25. `framebuf::alloc()` 在重分辨率/重协商时先释放旧 buffer，modern frame copy 后检查分配结果，避免尺寸变化导致泄漏或空指针写入。

待执行：

1. 用更多 MPEG-2 样本验证 modern path 的 seek、interlaced、audio/video sync 和长时间播放。
2. 删除 `CMpeg2DecFilter` 旧 `libmpeg2` decode loop、`CMpeg2Dec` wrapper、`libmpeg2` project reference、`libmpeg2.cpp/.h` 编译项和 `libmpeg2\vc++` 子项目引用。
3. 删除 `PLAYASA_MPEG2_LEGACY=1` 临时回滚开关，完成 modern-only 收口。
4. 在 software path 稳定后，再评估 MPEG-2 DXVA 是否迁入 `CMpeg2DecFilter`。
5. 在新实现前保持 `MPCVideoDec` 的 `DxvaMpeg2PictureContext` 不继续扩大改动范围。

## 9. 验证计划

已完成：

```text
dev.ps1 buildFast: PASS
test-rfc0031-mpeg2-path-selfcheck.ps1 -RequireKnownPath: PASS
test-rfc0031-mpeg2-path-selfcheck.ps1 -SamplePaths out/selfcheck/sample-mpeg2-dxva.m2ts -EnableModernMpeg2 -RequireKnownPath -RequireModernMpeg2FirstFrame: PASS
test-rfc0031-mpeg2-path-selfcheck.ps1 -SamplePaths out/selfcheck/sample-mpeg2-dxva.m2v -EnableModernMpeg2 -RequireModernMpeg2FirstFrame -RequireNoModernMpeg2Fallback: PASS
test-rfc0031-mpeg2-modern-selfcheck.ps1 (all default samples strict no-fallback): PASS
test-rfc0031-mpeg2-path-selfcheck.ps1 -SamplePaths m2ts,ts,m2v,vob,mpg -RequireKnownPath -RequireModernMpeg2FirstFrame -RequireNoModernMpeg2Fallback: PASS (also checks modern failure log)
2026-04-28 re-audit:
dev.ps1 buildFast: PASS
test-rfc0031-mpeg2-path-selfcheck.ps1 -SamplePaths m2ts,ts,m2v,vob,mpg -RequireKnownPath -RequireModernMpeg2FirstFrame -RequireNoModernMpeg2Fallback: PASS
test-rfc0031-mpeg2-path-selfcheck.ps1 -SamplePaths out/selfcheck/sample-mpeg-small.mpeg -RequireKnownPath: PASS (isolated run; confirms MPEG-1 is not taken by MPEG-2 modern path)
```

modern path 关键日志：

```text
MPEG-2 modern FFmpeg open OK
MPEG-2 modern FFmpeg first frame ready: width=640 height=360 start=0 stop=400000 duration=400000
```

多样本 modern 结果：

```text
strict no-fallback:
out/selfcheck/sample-mpeg2-dxva.m2ts -> first frame OK, fallback False
out/selfcheck/sample-mpeg2-dxva.ts   -> first frame OK, fallback False
out/selfcheck/sample-mpeg2-dxva.m2v  -> first frame OK, fallback False
out/selfcheck/sample-mpeg2-dxva.vob  -> first frame OK, fallback False
out/selfcheck/sample-mpeg2-dxva.mpg  -> first frame OK, fallback False
```

解释：MPEG-2 parser 和 `EAGAIN` packet 保留修复后，`m2ts/ts/m2v/vob/mpg` 当前样本可走 modern path 且不 fallback；`.m2v` 的 raw ES splitter 会在短样本尾部送出 `disc=1 start=0 stop=1` 的 bogus marker，并且此时 EVR clock 已经 stop。modern path 现在会 suppress 该尾部 marker 之后的 stopped-renderer delivery failure，不再把它当作 decode failure。重新审计后，default modern path 不再初始化旧 `libmpeg2`、不再误接 MPEG-1 输入，并且 flush/segment/discontinuity 区分真实 seek/reset 与 raw ES 尾部 marker。modern path 不再直接构造 output sample，而是复用 legacy `Deliver(false)`，这是当前避免画面错乱的正确交付路径。modern path 已默认启用，`PLAYASA_MPEG2_LEGACY=1` 只是删除旧代码前的临时开发回滚开关；RFC 完成前必须删除旧 `libmpeg2`。

仍需验证：

1. `test-rfc0030-mpeg2-dxva-selfcheck.ps1`
2. MPEG-2 样本真实手动 seek、关闭无 crash/hang；当前自动 seek harness 未能可靠触发 `SeekTo begin/end`
3. 更长 MPEG-2 样本的 A/V sync
4. 对照 `SVPDebug.log` 确认目标 decoder 路径和 modern path gate
