# RFC-0012：第三方与本仓内嵌库升级策略（2026）

| 字段 | 内容 |
|------|------|
| **状态** | 草案 (Draft) |
| **适用范围** | 本仓库 `playasa`（MSBuild / Win32 为主） |
| **相关 RFC** | [RFC-0011](./rfc-0011-windows-repository-layout.md)（路径与 `out\` 契约）、[RFC-0002](./rfc-0002-build-environment-analysis.md)（历史环境分析） |

## 1. 摘要

「升级到最新库」在本仓**不是单次提交能完成**的工作：`src/Source` 与 `src/Thirdparty` 内嵌了大量**按源码编译**的 C/C++ 依赖（zlib、libpng、FFmpeg 衍生、解码器、Boost 头、旧 jsoncpp、ZeroMQ、OpenSSL 0.9.8x 等），彼此通过 **ABI、宏、工程文件清单** 耦合。本文给出 **2026 年可执行的优先级与阶段**，要求：**每阶段合并后全量构建（至少 `Release Unicode|Win32`）与关键路径手测**，禁止无验证的大爆炸替换。

## 2. 动机

- 文档与 `README` 曾描述已不存在的 `thirdparty/pkg/trunk/...` 路径；真实依赖在 **`src/Thirdparty`** 与 **`src/Source/*`**。
- 部分内嵌版本极旧（例：`src/Source/zlib` 为 **1.2.3 (2005)**），存在已知缺陷与安全债；但升级会牵动 **API/源文件列表/预处理器**。
- 工具链已普遍使用 **Platform Toolset v145**（以 `.vcxproj` 为准）；库升级须与 **VS / Windows SDK** 组合在 CI 或可复现脚本下验证。

## 3. 现状盘点（维护时以此表为检查基线）

| 区域 | 代表内容 | 大致年代 / 风险 | 备注 |
|------|-----------|-----------------|------|
| `src/Source/zlib` | zlib 静态库工程 | **1.2.3**；含已弃用 `gzio.c` | `SVPToolBox.cpp` 使用 `gzopen`/`gzread`；升级需换为现代 zlib 中 `gz*.c` 组合并回归压缩相关功能 |
| `src/Source/libpng` | libpng | 与 zlib 强绑定 | 建议与 zlib **同一阶段**升级并跑图像相关用例 |
| `src/Thirdparty/openssl-0.9.8x` | OpenSSL | **0.9.8x**；协议与 API 与 3.x 不兼容 | 主工程若未直接链接 SSL，可先审计引用再决定是否移除或替换 |
| `src/Thirdparty/jsoncpp` | jsoncpp 老目录布局 | 无 `JSONCPP_VERSION` 宏的早期形态 | 与上游 1.9.x 差异大；需 API 与 `lib_json.vcxproj` 双迁移 |
| `src/Thirdparty/yaml-cpp` | yaml-cpp | 中等 | 工程体量小于 OpenSSL；适合 jsoncpp 之后单独阶段 |
| `src/Thirdparty/zeromq` | libzmq | 依赖网络栈与编译选项 | 与业务消息路径相关，需运行时验证 |
| `src/Source/filters/transform/mpcvideodec/ffmpeg` | FFmpeg/libav 衍生 | 体量大、许可证与符号导出敏感 | **单独 RFC 或子阶段**；不在 RFC-0012 首波范围 |
| `src/Thirdparty/boost` | 头文件树 | 体量大 | 通常随编译器升级渐进替换用法，而非整树替换 |
| `src/Thirdparty/pkg`、`src/Thirdparty/sinet` | 头文件 / stub | 非旧文档中的 `trunk` 大目录 | README 已改为指向本路径 |

## 4. 升级原则（必须遵守）

1. **一阶段一合并**：每 PR 只动一个「阶段边界」内的组件；附带 **构建与自检说明**。
2. **先 ABI 边界清晰的静态库**：zlib / libpng 优先于 OpenSSL / FFmpeg。
3. **不删除尚在使用中的符号**：升级前 `grep`/链接图确认调用方。
4. **保留回滚点**：大目录替换前用 Git 分支或 tag；必要时保留 `*_vs2005.vcxproj` 的 `ClCompile` 清单对比。
5. **与 RFC-0011 一致**：新预编译料放 **`src/lib\`**；生成物只进 **`out\`**。

## 5. 建议阶段（顺序可随审计微调）

| 阶段 | 目标 | 退出条件 |
|------|------|----------|
| **P0** | 修正文档与工程中对依赖路径、版本的描述；建立本表为单一事实来源 | README / TASK / 关键 `docs` 与现状一致 |
| **P1** | **zlib + libpng** 同步升级到当前稳定主线（如 zlib 1.3.x + 匹配 libpng） | `zlib`/`libpng` 工程全配置链接通过；压缩/解 PNG 路径手测 |
| **P2** | **jsoncpp** 迁移至维护分支（或 `Json::Value` 用法适配后的上游 tag） | 依赖 JSON 的配置/网络模块编译 + 最小解析测试 |
| **P3** | **yaml-cpp**、**librhash** 等中小库 | 单元测试或启动路径覆盖 |
| **P4** | **zeromq**、**sqlitepp** 等与运行时强相关组件 | 与网络/数据库相关功能手测 |
| **P5** | **OpenSSL**（若确需）：评估 3.x 或平台 TLS 替代 | 安全审计通过；无未使用的大体积依赖 |

**FFmpeg / libavcodec 与全套解码器**：默认 **不纳入 P1–P2**；单独立项（性能、许可证、二进制体积）。

### 5.1 两条正交路线（择一为主，可长期迁移）

| 维度 | **路线 A：继续内嵌源码（推荐先做）** | **路线 B：引入 vcpkg / 外部二进制** |
|------|--------------------------------------|-------------------------------------|
| **技术原理** | 仍由 `*.vcxproj` 编译 `src/Source/zlib` 等；升级 = 替换上游 `.c/.h` 并改工程文件清单 | 依赖由 vcpkg 解析版本与 triplet，链接时从 `installed/` 取 `.lib` |
| **实施步骤** | 按下文 **§9 P1 检查清单** 逐条执行；每步可提交小 commit | 根目录增加 `vcpkg.json`、统一 `VcpkgTriplet`、批量改 `AdditionalIncludeDirectories` / `AdditionalDependencies`、处理 MFC 静态与 CRT 一致性 |
| **风险** | 单库边界清晰；风险在 **源文件列表遗漏**、**大小写**、**旧文件未删** | 首期改动面大；与现有 **多配置 Unicode/Release Lib** 矩阵对齐成本高；CI 需装 vcpkg |
| **推荐** | **默认采用路线 A** 完成 P1–P2，证明团队能稳定发版 | 在 P1–P2 稳定后，若仍希望统一供应链，再单开「vcpkg 迁移」RFC |

## 6. 与工具链的关系

- 当前各 `.vcxproj` 以 **`<PlatformToolset>v145</PlatformToolset>`** 为主流；升级第三方源码时**不要**在未讨论的情况下全局改工具集。
- `src/Source/common.props` 中 **WINVER / `_WIN32_WINNT`** 已锚定 Win10+；第三方若自带旧 Windows 目标宏，需在合并时统一或隔离。

## 7. 成功指标

- 至少完成 **P1** 后，主配置 **`Release Unicode|Win32`** 可从零构建通过。
- 无新增「根目录散落 DLL」或错误 `$(SolutionDir)src\` 路径（与 RFC-0011 一致）。

## 8. 决策记录

| 日期 | 决策 | 理由 |
|------|------|------|
| 2026-04-19 | 采用分阶段升级，拒绝单 PR「全库最新」 | 降低链接/运行时回归风险；与内嵌源码现实一致 |
| 2026-04-19 | 默认路线 A（内嵌升级），vcpkg 为后续可选 | 与当前 MSBuild 仓结构一致，可交付增量 PR |

## 9. 可执行计划：P1（zlib + libpng）检查清单

以下顺序**建议严格照做**；任一步失败则停止并回滚到上一 tag。

**上游获取（优先 GitHub，避免镜像失效）**

- zlib：`https://github.com/madler/zlib/archive/refs/tags/v1.3.1.zip`（或当前 **v1.3.x** 最新 tag）。
- libpng：从 `https://github.com/pnggroup/libpng` 取与 zlib 1.3.x **兼容**的 **libpng16** 发布 tag（具体小版本以该 tag 的 `INSTALL` / `CHANGES` 为准；升级 PR 正文写死版本号）。

**实施检查清单**

1. 从 `main`（或默认分支）创建分支 `upgrade/rfc0012-p1-zlib-libpng`；在替换源码前打轻量 tag `pre-rfc0012-p1` 便于 `git diff` / 回滚。
2. 在仓库根执行：`rg "gz(open|read|write|close|printf)" src/Source --glob "*.cpp" --glob "*.h"`，将输出保存到 PR 描述（当前已知 **`SVPToolBox.cpp`**）。
3. 解压 zlib 上游包到**临时目录**，对照 **v1.3.1** 根目录的 `.c` 列表；**不要**再把已移除的 `gzio.c` 加入工程（现代 zlib 拆分为 `gzlib.c`、`gzread.c`、`gzwrite.c`、`gzclose.c` 等，以 tag 内实际文件为准）。
4. 备份：复制当前 `src/Source/zlib` 下除 `*.vcxproj`、`*.vcproj`、`*.sln`、`*.filters`、`.rc`、`.def` 外的纯上游文件列表（可用 `git status` 管控）。
5. 用上游 **`.c` / `.h`** 覆盖 `src/Source/zlib` 中对应文件；**保留**本仓工程文件（`zlib_vs2005.vcxproj` 等）与 `ZLIB.RC` / `ZLIB.DEF`（若仍适用；`DEF` 需对照上游是否变更导出符号）。
6. 编辑 **`zlib_vs2005.vcxproj`**：`<ClCompile>` 与上游 **v1.3.1** 对齐（移除 `Gzio.c`；按大小写与磁盘一致添加新 `gz*.c`）；`<ClInclude>` 同步 `zlib.h`、`zconf.h`、`zutil.h`、`deflate.h` 等。
7. 若存在 **`zlib_vs2005.vcxproj.filters`**，同步过滤器节点，避免 IDE 与磁盘脱节。
8. **单项目构建**：在装有 VS 的机器上（路径按本机调整）  
   `MSBuild src\Source\zlib\zlib_vs2005.vcxproj /m /p:Configuration=Release /p:Platform=Win32 /v:minimal`  
   再对 **`Debug`**、**`Debug Unicode`**（若工程含该配置）各执行一次，确认无 C4996 等需策略处理的告警洪泛。
9. 解压 libpng 上游至临时目录；阅读 **`scripts`** / **`CMakeLists.txt`** 仅作参考，本仓仍以 **`libpng_vs2005.vcxproj`** 为准。
10. 对照上游 `*.c` 列表更新 **`libpng_vs2005.vcxproj`**：删除树中已不存在的文件（旧树常见 **`pnggccrd.c` / `pngvcrd.c`** 在新 libpng 中可能已移除）；**不要**把 `contrib/`、`tests/` 下测试主程序默认并进主静态库，除非确有需要。
11. 确认 **`libpng_vs2005.vcxproj`** 中 `AdditionalIncludeDirectories` 仍包含 **`..\zlib`**（与现结构一致）。
12. **单项目构建**：`MSBuild src\Source\libpng\libpng_vs2005.vcxproj /m /p:Configuration=Release /p:Platform=Win32 /v:minimal` 及所需其它配置。
13. **全量解决方案**：`cd src\BuildScript` 后执行 **`build-with-msbuild.cmd`**（或团队等价脚本）；**必须通过**至少 **`Release Unicode|Win32`**（主交付配置）。
14. **运行时手测**：覆盖 **`gzopen`/`gzread`** 路径（与步骤 2 清单一致）；打开/保存含 **PNG** 的界面或资源（若有自动化测试则一并跑）。
15. PR 正文必须包含：**zlib 精确 tag**、**libpng 精确 tag**、`ClCompile` 变更摘要、**全量配置矩阵**中已通过的配置列表；合并后更新 **`TASK_TRACKING.md`** 将 P1 标为完成。

## 10. 验证命令模板（复制后按需改路径）

```bat
cd /d <REPO>\src\BuildScript
build-with-msbuild.cmd
```

单项目快速失败探测（无全量时）：

```bat
MSBuild ..\Source\zlib\zlib_vs2005.vcxproj /m /p:Configuration="Release Unicode" /p:Platform=Win32 /v:minimal
MSBuild ..\Source\libpng\libpng_vs2005.vcxproj /m /p:Configuration="Release Unicode" /p:Platform=Win32 /v:minimal
```

（若某配置在单项目中不存在，以 `zlib_vs2005.vcxproj` 内 `<ProjectConfiguration>` 为准。）

## 11. P2 及之后（纲要，执行前展开为检查清单）

- **P2 jsoncpp**：先 `rg "json/json.h"` / `Json::` 统计模块；选定上游 tag；优先静态链进现有 `lib_json.vcxproj` 或改为 amalgamation；全解 + 配置读写冒烟测试。
- **P3 yaml-cpp / librhash**：单库 MSBuild → 全解；覆盖读 yaml / 校验路径。
- **P4 zeromq / sqlitepp**：全解 + 与网络/持久化相关的手测脚本（若有 `test-*.ps1` 则接入）。
- **P5 OpenSSL**：`rg -i openssl` 全仓；若仅头文件残留则删树；若链接则走 3.x 迁移或替换为 **Schannel / BCrypt** 等 Windows 原生方案，另附安全评审结论。

---

**变更流程**：执行 **P1** 前将本文 **状态** 升为 **已接受 (Accepted)**；每完成一个阶段，在 **`TASK_TRACKING.md`** 勾选对应行并附上合并提交哈希。
