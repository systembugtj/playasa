# RFC-0019：第三方库 CRT / MFC 静态链接准入契约

| 字段 | 内容 |
|------|------|
| **状态** | 提案 (Proposed) |
| **适用范围** | 所有新增或升级的第三方 `.lib`、`.dll`、MSBuild `.vcxproj`、预编译二进制 |
| **相关 RFC** | [RFC-0011](./completed/rfc-0011-windows-repository-layout.md)、[RFC-0012](./completed/rfc-0012-thirdparty-library-upgrades.md)、[RFC-0015](./rfc-0015-curl-schannel-updater-download.md)、[RFC-0017](./rfc-0017-ffmpeg-mpcvideodec-upgrade.md)、[RFC-0018](./rfc-0018-boost-header-tree-digestion.md) |
| **创建日期** | 2026-04-25 |
| **最后更新** | 2026-04-25 |

## 1. 摘要

本仓大量历史项目使用 MFC、ATL、静态库和 Win32 Release/Debug 多配置。新第三方库如果 CRT 或 MFC 链接模式不一致，会引发 LNK4098、`_ITERATOR_DEBUG_LEVEL` mismatch、Debug/Release 混链、堆跨模块释放、PDB 缺失和运行时崩溃。

本 RFC 定义所有新三方库的准入标准：任何引入、升级或恢复的 `.lib` / `.dll` 都必须明确 CRT、MFC、架构、配置、工具链和依赖系统库，不允许“能链接就合入”。

## 2. 必须声明的链接属性

每个新第三方库必须记录：

1. 架构：Win32 / x64。
2. 配置：Debug / Release / Debug Unicode / Release Unicode。
3. CRT：`/MT`、`/MTd`、`/MD`、`/MDd`。
4. MFC：Static / Dynamic / Not using MFC。
5. Toolset：例如 v145。
6. Windows SDK 版本。
7. 是否启用 LTCG。
8. 依赖系统库，例如 `Crypt32.lib`、`Secur32.lib`、`Ws2_32.lib`。
9. 是否需要 delay-load DLL。
10. 许可证和二进制来源。

## 3. 准入规则

1. Release 主线不得链接 Debug 第三方库。
2. Debug 配置不得链接 Release-only 第三方库，除非 RFC 明确解释且验证通过。
3. 静态库和主程序 CRT 家族必须一致，除非边界完全不跨 CRT 分配。
4. 禁止引入来源不明的 `.lib`。
5. 禁止在仓库根目录散落库文件；路径遵守 RFC-0011。
6. 任何恢复 curl、FFmpeg、Boost 相关依赖的工作都必须引用本 RFC。
7. 发现 LNK4098、`_ITERATOR_DEBUG_LEVEL` mismatch、`RuntimeLibrary` mismatch 时，必须修根因，不靠 `/FORCE` 掩盖。

## 4. 验证要求

每个三方库 PR 至少提供：

1. 单项目 MSBuild 命令。
2. 主交付配置 `Release Unicode|Win32` 全量构建结果。
3. 如果修改 Debug 配置，必须提供 Debug 构建结果或明确标记该配置未维护。
4. `dumpbin /directives` 或等价证据，证明 CRT 选择。
5. 链接错误和 warning 说明，不能把新增 warning 当成成功。

## 5. 推荐目录

1. 源码型依赖：`src/Thirdparty/<name>/` 或现有 `src/Source/<name>/`。
2. 预编译库：`src/lib/<Platform>/<Configuration>/` 或 RFC-0011 允许的等价路径。
3. 期望文件：`src/Thirdparty/<name>/rfcXXXX-expected.txt`。
4. 验证脚本：`src/BuildScript/verify-rfcXXXX-<name>.ps1`。

## 6. 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| CRT 混用 | 链接失败或堆崩溃 | `dumpbin /directives` + MSBuild 配置检查 |
| Debug/Release 混链 | `_ITERATOR_DEBUG_LEVEL` mismatch | 分配置产物和库名 |
| MFC 模式不一致 | 链接或资源行为异常 | 明确 `UseOfMfc` |
| `/FORCE` 掩盖错误 | 产物可生成但不可运行 | 禁止新增依赖靠 `/FORCE` 过关 |

## 7. 成功标准

1. 新三方库有明确 expected 文件或 RFC 记录。
2. 活跃 `.vcxproj` 的 `RuntimeLibrary` 与第三方库匹配。
3. `./dev.ps1 build` 通过。
4. 没有新增 CRT / MFC 链接 warning。
5. PR 描述包含库来源、版本、CRT、MFC、架构和验证命令。

## 8. 下一步

RFC-0015 恢复 curl + Schannel 时必须先按本 RFC 记录 libcurl 的 CRT、架构和系统库依赖。
