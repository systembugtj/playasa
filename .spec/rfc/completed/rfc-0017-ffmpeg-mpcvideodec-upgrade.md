# RFC-0017：FFmpeg / mpcvideodec 升级与隔离策略

| 字段 | 内容 |
|------|------|
| **状态** | 完成 (Completed) |
| **适用范围** | `src/Source/filters/transform/mpcvideodec`、FFmpeg/libav 衍生源码、相关解码器链接与运行时验证 |
| **相关 RFC** | [RFC-0011](./rfc-0011-windows-repository-layout.md)、[RFC-0012](./rfc-0012-thirdparty-library-upgrades.md)、[RFC-0019](../rfc-0019-thirdparty-crt-mfc-linkage-contract.md) |
| **创建日期** | 2026-04-25 |
| **最后更新** | 2026-04-25 |

## 1. 摘要

RFC-0012 已完成 zlib、libpng、jsoncpp、yaml-cpp、librhash、sqlitepp、zeromq 与 OpenSSL 处置。FFmpeg / mpcvideodec 被明确留作旁系事项，因为它不是普通小型第三方库：它牵涉解码器 ABI、许可证、符号导出、编译选项、性能、二进制体积和播放器运行时路径。

本 RFC 的执行结论是：当前阶段不替换 FFmpeg 源码树，先完成审计和钉扎。后续如要升级，必须在兼容层、许可证和运行时验证准备好之后单独进入升级阶段。

## 2. 审计结论

1. 当前 vendored FFmpeg/libav 线索为 `libavcodec 52.32.0`、`libavutil 50.2.0`。
2. `ffmpeg/config.h` 当前钉住 `CONFIG_GPL=1`、`CONFIG_LIBAMR_NB=1`、`ENABLE_LIBAMR_NB=1`、`CONFIG_DECODERS=1`、`CONFIG_ENCODERS=0`、`CONFIG_ZLIB=1`。
3. `avcodec.h` / `avutil.h` 源头 header 带 LGPL 2.1-or-later 文本；`MPCVideoDec` 本地源码带 GPL 3-or-later 文本。
4. `MPCVideoDec.def` 只导出 DirectShow COM DLL 必需入口：`DllCanUnloadNow`、`DllGetClassObject`、`DllRegisterServer`、`DllUnregisterServer`。
5. `MPCVideoDec.vcxproj` 在 `Release Unicode|Win32` 下是 `StaticLibrary`，使用 `v145`、静态 MFC、Unicode 字符集。
6. `Release Unicode|Win32` 链接面依赖 `libavcodec_gcc.lib`、`libgcc.a`、`libmingwex.a`，include 面包含 `ffmpeg`、`ffmpeg/libavcodec`、`ffmpeg/libavutil`。
7. 原项目内 stale `libflac.vcxproj` ProjectReference 会阻塞单项目 `Release Unicode|Win32` 构建，已移除；全量 solution 仍独立构建 `libflac`。

## 3. 完成内容

1. 新增 `src/Source/filters/transform/mpcvideodec/rfc0017-expected.txt`，记录当前版本、许可证、宏、工程和导出符号钉扎。
2. 新增 `src/BuildScript/verify-rfc0017-ffmpeg-mpcvideodec.ps1`，自动验证 RFC-0017 钉扎事实。
3. 修复 `MPCVideoDec.vcxproj` 单项目构建阻塞：移除 stale `libflac` ProjectReference。
4. 未替换 FFmpeg 源码树，未引入新 FFmpeg 二进制，未改变解码器运行时行为。

## 4. 后续升级准入

后续若进入真正 FFmpeg 升级阶段，必须先提交兼容层计划，至少覆盖：

1. `AVCodecContext`、`AVFrame`、`CodecID` 到新版 API 的映射。
2. packet/frame 生命周期和错误码语义变化。
3. DXVA H.264 / MPEG-2 / VC-1 路径。
4. `CONFIG_GPL`、AMR、zlib、汇编优化和编译器/CRT 约束。
5. 发布许可证、二进制体积和性能回归验证。

## 5. 验证结果

| 阶段 | 结果 |
|------|------|
| **P1** | `verify-rfc0017-ffmpeg-mpcvideodec.ps1` 通过 |
| **P2** | `MPCVideoDec.vcxproj` `Release Unicode|Win32` 单项目构建通过 |
| **P3** | `splayer.sln` `Release Unicode|Win32` 全量 MSBuild 通过 |
| **P4** | `splayer.exe` 启动 smoke 通过，5 秒后正常强制关闭 |
| **P5** | 视频解码深度手测未自动化；本 RFC 仅完成审计钉扎和启动级 smoke |

## 6. 风险记录

1. 当前 `CONFIG_GPL=1` 和 AMR 相关宏需要发布前继续由许可证流程确认。
2. 构建仍存在既有 warning，例如 `/Qopenmp-link:static` 被 MSVC 忽略、旧 GCC 静态库重复符号 warning、MPCVideoDec 与旧第三方库调试段 warning；本 RFC 未扩大处理范围。
3. 真正升级 FFmpeg 仍是高风险任务，不能直接替换整树。
