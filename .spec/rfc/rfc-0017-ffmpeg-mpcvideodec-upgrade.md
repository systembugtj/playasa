# RFC-0017：FFmpeg / mpcvideodec 升级与隔离策略

| 字段 | 内容 |
|------|------|
| **状态** | 提案 (Proposed) |
| **适用范围** | `src/Source/filters/transform/mpcvideodec`、FFmpeg/libav 衍生源码、相关解码器链接与运行时验证 |
| **相关 RFC** | [RFC-0011](./completed/rfc-0011-windows-repository-layout.md)、[RFC-0012](./completed/rfc-0012-thirdparty-library-upgrades.md)、[RFC-0019](./rfc-0019-thirdparty-crt-mfc-linkage-contract.md) |
| **创建日期** | 2026-04-25 |
| **最后更新** | 2026-04-25 |

## 1. 摘要

RFC-0012 已完成 zlib、libpng、jsoncpp、yaml-cpp、librhash、sqlitepp、zeromq 与 OpenSSL 处置。FFmpeg / mpcvideodec 被明确留作旁系事项，因为它不是普通小型第三方库：它牵涉解码器 ABI、许可证、符号导出、编译选项、性能、二进制体积和播放器运行时路径。

本 RFC 定义 FFmpeg / mpcvideodec 后续处理方式：不做“大目录直接替换”，先审计当前源码、工程清单和调用面，再决定是钉扎现状、局部更新，还是完整迁移到新版 FFmpeg 兼容层。

## 2. 当前问题

1. `mpcvideodec` 相关代码体量大，不能按 RFC-0012 中小库节奏替换。
2. FFmpeg/libav API 历史变更多，直接升级可能影响解码器初始化、packet/frame 生命周期、像素格式、音频格式和硬解路径。
3. 许可证和编译选项会影响发布边界，不能只看编译是否通过。
4. 当前全量 `Release Unicode|Win32` 可以构建，说明迁移必须保证主播放器可运行，而不是只做结构门闩。

## 3. 目标

1. 明确当前 FFmpeg / mpcvideodec 的版本、源码来源、工程清单和链接面。
2. 明确许可证、编译宏和导出符号约束。
3. 给出可验证的升级路径，不允许一次性无保护替换整树。
4. 建立最小 smoke test：主程序可启动，常见视频解码路径可播放或至少可创建 filter graph。
5. 与 RFC-0019 的 CRT/MFC 静态链接约束保持一致。

## 4. 非目标

1. 不在本 RFC 中同步升级所有 DirectShow filter。
2. 不把 FFmpeg 迁移和 UI / 播放器框架重构混在一起。
3. 不引入无法复现来源的预编译二进制。
4. 不在未审计许可证前合入新版 FFmpeg 二进制或源码。

## 5. 实施检查清单

1. 审计 `src/Source/filters/transform/mpcvideodec` 下源码、工程文件、预编译库和 include 路径。
2. 记录当前 FFmpeg/libav 版本线索、编译宏、导出符号和许可证文件。
3. 搜索主程序和 filters 中所有 mpcvideodec 调用面，列出运行时入口。
4. 确认当前 `MPCVideoDec.vcxproj` 与主构建的 CRT、Platform、Toolset。
5. 新增 `rfc0017-expected.txt` 或等价门闩，钉住当前版本和工程清单。
6. 若选择升级，先建立兼容层或最小 API 适配清单，再替换源码。
7. 添加构建验证：单项目 `MPCVideoDec.vcxproj` + 全量 `./dev.ps1 build`。
8. 添加运行时验证：主程序启动 smoke test，以及至少一个视频解码手测/自动化记录。

## 6. 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| FFmpeg API 大幅变化 | 编译通过但运行崩溃 | 先做 API 调用面清单和兼容层 |
| 许可证变化 | 发布风险 | 升级前记录许可证和 configure 选项 |
| CRT 不一致 | LNK4098 / 运行时堆问题 | 遵守 RFC-0019 |
| 二进制体积变化 | 发布包膨胀 | 记录产物大小并比较 |
| 性能回退 | 播放卡顿 | 使用代表样本手测 |

## 7. 成功标准

1. `verify-rfc0017-ffmpeg-mpcvideodec.ps1` 或同等门闩通过。
2. `MPCVideoDec.vcxproj` Release Unicode / Win32 构建通过。
3. `./dev.ps1 build` 通过。
4. 主程序启动 smoke test 通过。
5. 视频解码路径有明确手测记录。
6. RFC 或 PR 记录许可证、版本、体积和 CRT 结论。

## 8. 下一步

先执行审计和钉扎，不直接升级。审计完成后再决定是否进入源码升级阶段。
