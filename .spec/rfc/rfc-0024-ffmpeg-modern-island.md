# RFC-0024：新版 FFmpeg 并行 island 与软件解码渐进迁移

| 字段 | 内容 |
|------|------|
| **状态** | 执行中 (In Progress) |
| **适用范围** | `src/Thirdparty/ffmpeg-modern`、`src/BuildScript`、`src/Source/filters/transform/mpcvideodec` 新版 FFmpeg adapter 与非 DXVA 软件解码路径 |
| **相关 RFC** | [RFC-0017](./completed/rfc-0017-ffmpeg-mpcvideodec-upgrade.md)、[RFC-0019](./rfc-0019-thirdparty-crt-mfc-linkage-contract.md) |
| **创建日期** | 2026-04-25 |
| **最后更新** | 2026-04-25 |

## 1. 摘要

RFC-0017 已确认当前 `mpcvideodec` 内嵌 FFmpeg/libav 是 `libavcodec 52.32.0` / `libavutil 50.2.0` 时代的旧实现，并且 `FfmpegContext.c` 与 H.264 / MPEG-2 / VC-1 DXVA 路径强依赖旧 FFmpeg 内部结构。本 RFC 不直接替换旧 `ffmpeg/` 源码树，而是在仓库内建立新版 FFmpeg 并行 island，先迁移软件解码路径。

固定版本选择为 **FFmpeg 8.1 "Hoare"**。该版本是 2026-03-16 发布的稳定版本，官方版本线索包括 `libavcodec 62.28.100`、`libavutil 60.26.100`、`libavformat 62.12.100`、`libswscale 9.5.100`。

## 2. 目标

1. 新增 `src/Thirdparty/ffmpeg-modern` 作为新版 FFmpeg island，不覆盖旧 `mpcvideodec/ffmpeg`。
2. 固定 FFmpeg 8.1 源码来源、压缩包 URL、SHA-256、许可证和最小 configure 选项。
3. 新增最小软件解码 adapter，封装 `AVCodecContext`、`AVPacket`、`AVFrame` 生命周期。
4. 第一阶段只迁移非 DXVA 软件 codec；H.264 / MPEG-2 / VC-1 DXVA 仍走旧路径。
5. 每一步都必须有脚本门闩，不能靠人工记忆维护版本和边界。

## 3. 非目标

1. 不在本 RFC 中删除旧 `mpcvideodec/ffmpeg`。
2. 不把新版 FFmpeg 私有 header 泄漏到 `MPCVideoDecFilter.cpp`。
3. 不在第一阶段迁移 DXVA。
4. 不引入不可复现的预编译二进制。

## 4. 目录与产物边界

| 路径 | 用途 |
|------|------|
| `src/Thirdparty/ffmpeg-modern/rfc0024-expected.txt` | FFmpeg 8.1 固定版本、URL、SHA-256、许可证、configure 选项和边界 |
| `src/Thirdparty/ffmpeg-modern/src/` | vendored FFmpeg 8.1 源码 |
| `src/Thirdparty/ffmpeg-modern/build/` | 本地生成目录，不应手写业务代码 |
| `src/Thirdparty/ffmpeg-modern/install/` | 本地安装目录，不应手写业务代码 |
| `src/Source/filters/transform/mpcvideodec/modern_ffmpeg/` | C++ adapter，只暴露本项目自定义边界 |
| `src/Thirdparty/pkg/ffmpeg_modern_bridge.h` | MSVC 消费新版 FFmpeg island 的唯一 C ABI 头文件 |
| `src/Source/filters/transform/mpcvideodec/modern_ffmpeg/ModernFfmpegBridgeConsumer.*` | `MPCVideoDec` 侧动态加载 bridge DLL 的 MSVC consumer |
| `src/BuildScript/verify-rfc0024-ffmpeg-modern.ps1` | 新版 island 结构和版本门闩 |
| `src/BuildScript/build-rfc0024-ffmpeg-modern.ps1` | 新版 FFmpeg 最小软件解码构建入口 |
| `src/BuildScript/build-rfc0024-ffmpeg-bridge.ps1` | 构建 C ABI bridge DLL 并生成 MSVC import `.lib` |

## 5. 固定 configure 选项

第一阶段目标是最小软件解码，不进入设备、滤镜和硬件加速路径：

```text
--disable-programs
--disable-doc
--disable-debug
--disable-avdevice
--disable-avfilter
--disable-network
--disable-hwaccels
--disable-encoders
--disable-decoders
--disable-demuxers
--disable-parsers
--disable-muxers
--enable-avcodec
--enable-avutil
--enable-avformat
--enable-swscale
--enable-decoder=mpeg4
--enable-decoder=flv
--enable-decoder=vp6
--enable-decoder=vp6a
--enable-decoder=vp6f
--enable-decoder=wmv1
--enable-decoder=wmv2
--enable-demuxer=avi
--enable-demuxer=flv
--enable-demuxer=matroska
--enable-demuxer=mov
--enable-parser=mpeg4video
--enable-parser=h263
--enable-parser=vp3
```

`libavformat` 用于样本级 smoke test 打开容器并喂给 adapter；仍禁用 network / muxers / device / filter / hwaccel，并且默认禁用所有 decoder/demuxer/parser 后只打开第一批迁移需要的最小集合。

## 6. Adapter 边界

新版 adapter 使用 public API：

1. `avcodec_find_decoder` / `avcodec_alloc_context3`
2. `av_packet_alloc` / `av_new_packet` / `av_packet_unref`
3. `av_frame_alloc` / `av_frame_unref`
4. `avcodec_send_packet` / `avcodec_receive_frame`
5. `avcodec_flush_buffers`

adapter 内部可以包含新版 FFmpeg header；`MPCVideoDecFilter.cpp` 只依赖 adapter 自己的头文件。

MSVC 侧不能直接链接 MinGW 生成的 FFmpeg 静态 `.a`。`MPCVideoDec` 后续只允许通过 `playasa_ffmpeg_modern_bridge.dll` + `playasa_ffmpeg_modern_bridge.lib` 这个 C ABI bridge 消费新版 FFmpeg，避免 C++ ABI 和 CRT 混用。

实际接入 `MPCVideoDec` 时，主工程不直接链接 `.lib`，而是通过 `ModernFfmpegBridgeConsumer` 使用 `LoadLibraryA` / `GetProcAddress` 动态解析 C ABI。这样静态库配置不会把 bridge 变成强链接依赖，同时运行目录只需要部署 `playasa_ffmpeg_modern_bridge.dll`、`libiconv-2.dll` 和 `libwinpthread-1.dll`。

首批真实替代范围限定为无 DXVA 模式的 first-wave 软件解码：MPEG-4 ASP/DivX/Xvid/MP4V、FLV1、VP6/VP6F/VP6A、WMV1、WMV2。`MPCVideoDecFilter` 只在这些 FourCC 命中时启用 `ModernFfmpegBridgeDecode`，其他 codec 仍保持 legacy FFmpeg 路径。

旧 FFmpeg 仍会在 H264/DXVA 兼容性探测阶段运行，因此 `MPCVideoDec` 必须始终安装 `LogLibAVCodec` 作为 libavcodec 日志回调，避免默认 `av_log_default_callback` 写 CRT `stderr` 并在 GUI/混合 CRT 链接环境中崩溃。

## 7. 第一批 codec 策略

第一批候选仅限非 DXVA 软件路径：

1. MPEG-4 ASP / DivX / Xvid
2. FLV / VP6
3. WMV1 / WMV2

H.264、MPEG-2、VC-1 先不迁移，因为它们当前和 DXVA / `FfmpegContext.c` 的私有结构耦合太深。

## 8. 验证

1. `verify-rfc0012-all.ps1` 必须继续通过，并会包含 RFC-0017 门闩。
2. `verify-rfc0024-ffmpeg-modern.ps1` 必须验证 FFmpeg 8.1 island 结构与 expected 文件。
3. `build-rfc0024-ffmpeg-modern.ps1` 必须能在本地生成最小软件解码库或给出明确缺失工具诊断。
4. `MPCVideoDec.vcxproj` 和 `splayer.sln` 的旧路径构建不能回归。
5. 第一批 codec 迁移后必须新增至少一个“解码一帧”的 smoke。

## 9. 风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| 新旧 FFmpeg symbol 冲突 | 链接或运行时崩溃 | adapter island 独立 include/lib 路径，不直接混进旧 target |
| 许可证/configure 面扩大 | 发布风险 | expected 文件 + verify 脚本固定 |
| DXVA 私有结构不兼容 | 硬解崩溃 | 第一阶段不迁移 DXVA |
| Win32 构建工具缺失 | 构建不可复现 | build 脚本必须给出明确诊断 |

## 10. 决策记录

| 日期 | 决策 | 理由 |
|------|------|------|
| 2026-04-25 | 选择 FFmpeg 8.1 "Hoare" | 当前稳定版本，便于长期钉扎 |
| 2026-04-25 | 采用 vendored source island | 可复现，避免预编译二进制黑盒 |
| 2026-04-25 | 软件解码先行，DXVA 后置 | 降低 `FfmpegContext.c` 私有结构迁移风险 |
