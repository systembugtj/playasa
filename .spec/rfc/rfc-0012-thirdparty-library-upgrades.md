# RFC-0012：第三方与本仓内嵌库升级策略（2026）

| 字段 | 内容 |
|------|------|
| **状态** | 草案 (Draft)；**P1 已合入**后可改为 **已接受 (Accepted)**（见 §8 与 §11 前言） |
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
| `src/Source/zlib` | zlib 静态库工程 | **已升级 1.3.1**（`gzio.c` 已移除） | `SVPToolBox.cpp` 仍用 `gzopen`/`gzread`（API 保持）；回归压缩路径 |
| `src/Source/libpng` | libpng | **已升级 1.6.47**；`pnglibconf.h` 来自 `scripts/pnglibconf.h.prebuilt`，`PNG_ZLIB_VERNUM` 对齐 `0x1310` | 与 zlib 同阶段；静态库不含 `pngtest.c` |
| `src/Thirdparty/openssl-0.9.8x` | OpenSSL | **0.9.8x**；协议与 API 与 3.x 不兼容 | 主工程若未直接链接 SSL，可先审计引用再决定是否移除或替换 |
| `src/Thirdparty/jsoncpp` | jsoncpp | **已升级 1.9.5**（`JSONCPP_VERSION_STRING`）；`lib_json.vcxproj` 源清单已对齐 | 应用侧仍用 `Json::Reader`/`StyledWriter`（1.9.5 仍提供，已弃用）；全量 MSBuild 须在本地再跑 |
| `src/Thirdparty/yaml-cpp` | yaml-cpp | **已升级 0.9.0** | Prototype `rsc_format.cc` 已迁移到新版 `YAML::Load` / `YAML::Node::as<T>()` API；静态库工程显式 `YAML_CPP_STATIC_DEFINE` + C++14 |
| `src/Thirdparty/librhash` | RHash / librhash | **已对齐上游 v1.4.6**（`RHASH_HASH_COUNT = 32`）；本仓 `rhash_ex.cpp` 封装 ED2K/磁力 | `plug_openssl.c` 仍参与编译；与 `src/include/stdint.h` 并存时有 C4005 告警，后续可收紧包含路径 |
| `src/Thirdparty/zeromq` | libzmq | **已钉扎 0MQ 2.1.3 ABI** | `test-zeromq-smoke.ps1` 覆盖 Win32 Release 静态库链接与 `inproc://` PAIR 发收；4.x API 迁移需单独兼容层阶段 |
| `src/Thirdparty/sqlitepp` | sqlitepp + SQLite amalgamation | **SQLite 已升级 3.53.0**；sqlitepp wrapper 保持本仓 API | `sqliteppTest` 已改为非交互、失败返回非 0；`appSQLlite.cc` 字符串写入路径已由测试覆盖 |
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
| **P1** | **zlib + libpng** 同步升级到当前稳定主线（**zlib 1.3.1** + **libpng 1.6.47**） | 源码与工程已合入；**须在本地 VS 上**全配置 `MSBuild` 通过并完成 gzip/PNG 手测（见 §10 脚本） |
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
| 2026-04-24 | 完成 P1：zlib **1.3.1** + libpng **1.6.47** 内嵌升级 | 工程与 `pnglibconf.h` 对齐；`verify-rfc0012-zlib-libpng.ps1` 供 CI 轻检 |
| 2026-04-23 | P2 门闩：`verify-rfc0012-jsoncpp.ps1` + `rfc0012-expected.txt` | 无 MSBuild 时可钉扎 legacy 或 SemVer；P2 PR 须更新期望首行 |
| 2026-04-23 | P3 门闩：`verify-rfc0012-p3-yaml-librhash.ps1` + `verify-rfc0012-all.ps1` | yaml-cpp / librhash 期望文件与脚本分支；P3 PR 须同步更新 |
| 2026-04-23 | **P2 执行**：内嵌 jsoncpp 换为上游 **1.9.5** | `include/json` + `src/lib_json` + 测试目录同步；`rfc0012-expected.txt` = `1.9.5` |
| 2026-04-24 | **P3 执行**：librhash 换为上游 **RHash v1.4.6** 树；`RHASH_HASH_COUNT`=**32**；保留 `rhash_ex.*` 并适配 API | `librhash/rfc0012-expected.txt` 钉扎 `rhash-upstream-1.4.6`；`rhash_ex.cpp` 已适配新 `rhash_final`/`rhash_print` |
| 2026-04-24 | **P3 执行**：yaml-cpp 换为上游 **0.9.0** 树；Prototype YAML 资源解析迁移到新版 API | `yaml-cpp/rfc0012-expected.txt` 钉扎 `yaml-cpp-0.9.0`；`verify-rfc0012-p3-yaml-librhash.ps1` 校验公共头、MSBuild 清单和旧 API 残留 |
| 2026-04-25 | **P5 审计**：OpenSSL 0.9.8x 不做原地版本号升级，迁移委派到后续 TLS/curl RFC | Release 主线未链接 `libeay32.lib`/`ssleay32.lib`；遗留链接仅在 `mplayerc` Debug Unicode 与 `Updater` Debug；`openssl-0.9.8x/rfc0012-expected.txt` 与 `verify-rfc0012-p5-openssl-audit.ps1` 钉住该结论 |

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

无 MSBuild 时的**最小自检**（仅校验头文件版本号）：

```powershell
.\src\BuildScript\verify-rfc0012-all.ps1
```

或分项执行：

```powershell
.\src\BuildScript\verify-rfc0012-zlib-libpng.ps1
.\src\BuildScript\verify-rfc0012-jsoncpp.ps1
.\src\BuildScript\verify-rfc0012-p3-yaml-librhash.ps1
```

**钉扎文件（首行非空即期望标记）**

| 组件 | 期望文件 | 当前首行含义 |
|------|-----------|--------------|
| jsoncpp | `src/Thirdparty/jsoncpp/rfc0012-expected.txt` | 当前 **`1.9.5`**，与 `include/json/version.h` 中 **`JSONCPP_VERSION_STRING`** 一致；以后再升上游时只改此首行 |
| yaml-cpp | `src/Thirdparty/yaml-cpp/rfc0012-expected.txt` | **`yaml-cpp-0.9.0`**；脚本校验上游 CMake 版本、`include/yaml-cpp/yaml.h`、`yamlcpp.vcxproj` 关键清单与 `rsc_format.cc` 新 API 迁移 |
| librhash | `src/Thirdparty/librhash/rfc0012-expected.txt` | **`rhash-upstream-1.4.6`**（`rhash.h` 中 `RHASH_HASH_COUNT = 32`）；回退旧树时用脚本内 `legacy-hash-count-22` 分支 |

## 11. P2–P5 可执行纲要（按阶段开分支；每阶段一份 PR）

**前言**：§9 的 P1 清单为模板；以下各阶段在开工前将对应小节**复制到 PR 描述**并打勾。分支命名建议 `upgrade/rfc0012-p{N}-{topic}`；合并前更新 **`TASK_TRACKING.md`** 与本文 **§8 决策记录**（一行：日期、决策、理由）。

### 11.1 P2：jsoncpp 现代化

**本仓锚点**：`src/Thirdparty/jsoncpp.props`（`AdditionalIncludeDirectories` → `Thirdparty\jsoncpp\include`）；工程 `src/Thirdparty/jsoncpp/makefiles/vs71/lib_json.vcxproj`；主程序引用见 `src/Source/apps/mplayerc/mplayerc_vs2005.vcxproj`（`ProjectReference` + `Import`）。

**两条正交路线**（与 §5.1 同一思路，落实到组件级）：

| 路线 | 技术原理 | 风险 |
|------|-----------|------|
| **2A：内嵌升级到上游维护 tag** | 替换 `include/json`、`src/lib_json` 与 `lib_json.vcxproj` 的 `ClCompile` 列表；保留 MSBuild 静态库 | `Json::Reader`/`FastWriter` 等弃用 API 需改调用方；`char`/`Unicode` 与 `std::string` 边界 |
| **2B：Amalgamation 单编译单元** | 减少工程文件漂移；仍须适配 API | 大 TU 编译时间上升；与 2A 二选一为主，不要混用两套树 |

**推荐**：优先 **2A**，与当前 `lib_json.vcxproj` 结构一致。

**实施检查清单**

1. 基线：`git checkout -b upgrade/rfc0012-p2-jsoncpp`；可选 tag `pre-rfc0012-p2-jsoncpp`。
2. 摸底（结果贴 PR）：`rg "json/json\.h" src --glob "*.{h,hpp,cc,cpp}"`；`rg "\bJson::" src --glob "*.{h,hpp,cc,cpp}"`；单独统计 `mplayerc` 与 `shared` 命中数。
3. 选定上游 **精确 tag**（如 1.9.x），在 PR 正文写死；阅读该 tag 的 **RELEASE_NOTES** 中 breaking changes。
4. 对照上游 `CMakeLists.txt` 或 `src/lib_json` 目录，更新内嵌 **`src/Thirdparty/jsoncpp/src/lib_json/*.cpp`** 与 **`include/json/*.h`**；**不要**在未审计的情况下删掉本仓对 `json_internal*.inl` 的引用——以新树是否存在为准。
5. 更新 **`lib_json.vcxproj`**：所有 `ClCompile`/`ClInclude` 路径与磁盘一致（注意 `vs71` 子目录下相对路径 `..\..\src\lib_json\`）；同步 **`.filters`**（若有）。
6. 在 PR 中记录 **`JSONCPP_VERSION_STRING`**（或说明仍为 legacy 树）；更新 **`src/Thirdparty/jsoncpp/rfc0012-expected.txt`** 首行为新 SemVer；**`verify-rfc0012-jsoncpp.ps1`**（§10）须在 CI 或本地通过。
7. **单项目**：`MSBuild src\Thirdparty\jsoncpp\makefiles\vs71\lib_json.vcxproj /m /p:Configuration=Release /p:Platform=Win32 /v:minimal`（及团队使用的 Unicode 配置名，以工程内 `ProjectConfiguration` 为准）。
8. **全量**：`src\BuildScript\build-with-msbuild.cmd`；至少 **`Release Unicode|Win32`**。
9. **冒烟**：启动播放器，覆盖 **读/写 JSON 配置**、网络返回 JSON 的对话框或解析路径（以步骤 2 命中文件为准列在 PR）。
10. 合并后：`TASK_TRACKING.md` 将 P2 标完成；§8 追加决策行。

### 11.2 P3：yaml-cpp 与 librhash

**yaml-cpp 锚点**：`src/Thirdparty/yaml-cpp/yamlcpp.vcxproj`；**Prototype** 侧 `src/Prototype/SPlayerNewGui/splayer/splayer.vcxproj` 含 `ProjectReference`；消费方以 `rg "yaml\.h"` / `YAML::` 摸底。

**librhash 锚点**：`src/Thirdparty/librhash/librhash/librhash.vcxproj` 与 **`src/Thirdparty/librhash.props`**（`mplayerc_vs2005.vcxproj` 已 `Import`）；消费方以 `rhash` / `librhash` 符号全仓 `rg` 为准。

**门闩（无 MSBuild）**：`verify-rfc0012-p3-yaml-librhash.ps1` + 上表 **yaml-cpp / librhash** 的 `rfc0012-expected.txt`；升级后须在脚本内增加新期望分支或改写指纹行。

**实施检查清单**（每库可拆独立 PR，仍属 P3）

1. 基线：`upgrade/rfc0012-p3-yaml` 与 `upgrade/rfc0012-p3-librhash` 分支二选一或顺序执行；各自可选 tag `pre-rfc0012-p3-yaml` / `pre-rfc0012-p3-librhash`。
2. **yaml-cpp**：`rg "\bYAML::" src --glob "*.{h,hpp,cc,cpp}"` 与 `rg "yaml-cpp|yaml\.h" src --glob "*.vcxproj"`，输出贴 PR。
3. 选定上游 tag；用上游 **`src/*.cpp`** / **`include/*.h`** 覆盖本仓对应子树；**不要**默认把上游 `test/`、`util/` 主程序并进 `yamlcpp.vcxproj`，除非确需链接。
4. 对照磁盘更新 **`yamlcpp.vcxproj`** 的 `ClCompile`/`ClInclude`；同步 `.filters`（若有）。
5. **单项目**：`MSBuild src\Thirdparty\yaml-cpp\yamlcpp.vcxproj /m /p:Configuration=Release /p:Platform=Win32 /v:minimal`（及工程内其它必测配置）。
6. **librhash**：`rg "\brhash_" src --glob "*.{h,hpp,cc,cpp}"` 贴 PR；替换 **`librhash/`** 下 C 源与头；更新 **`librhash.vcxproj`** 源清单（注意 `rhash_ex.cpp` 等本仓扩展文件是否保留）。
7. **单项目**：`MSBuild src\Thirdparty\librhash\librhash\librhash.vcxproj /m /p:Configuration=Release /p:Platform=Win32 /v:minimal`。
8. **全量**：`src\BuildScript\build-with-msbuild.cmd`；至少 **`Release Unicode|Win32`**（主程序链 librhash；Prototype 链 yaml-cpp 时另测 `splayer` 配置若适用）。
9. 手测：存在 **YAML 配置路径** 则覆盖读/写；覆盖 **校验和 / ED2K** 等依赖 rhash 的 UI 或后台任务。
10. 更新 **`rfc0012-expected.txt`**（两库）与 **`verify-rfc0012-p3-yaml-librhash.ps1`** 内分支；运行 **`verify-rfc0012-all.ps1`**；合并后 §8 与 **`TASK_TRACKING.md`** 标 P3 完成。

### 11.3 P4：zeromq 与 sqlitepp

**zeromq 锚点**：`src/Thirdparty/zeromq/libzmq.vcxproj`；与 **网络消息、进程间通信** 相关代码强耦合。

**zeromq 当前钉扎**：`src/Thirdparty/zeromq/rfc0012-expected.txt` = `zeromq-2.1.3-abi-pinned`。当前树使用 0MQ 2.1 API（`zmq_init`、`zmq_send(zmq_msg_t*)`、`zmq_recv(zmq_msg_t*)`、`ZMQ_XREQ/XREP`、`zmq_device`），调用面主要在 `Prototype/AcousticFingerprintServer` 与主程序 Release Unicode 链接项 `libzmq.lib`。Release|Win32 静态库 ABI 为 `ZMQ_STATIC`、`FD_SETSIZE=1024`、`/MT`；`test-zeromq-smoke.ps1` 负责编译临时 Win32 程序并通过 `inproc://` PAIR socket 发收一条消息。直接升级到 4.x 会改变上述 API，应作为后续兼容层迁移处理，而不是在 P4 中无适配替换源码。

**sqlitepp 锚点**：测试工程如 `src/Test/sqliteppTest/sqliteppTest.vcxproj`；应用内 SQLite 封装以 `rg sqlitepp` / `MediaSQLite` 等为线索。

**sqlitepp 当前钉扎**：`src/Thirdparty/sqlitepp/rfc0012-expected.txt` = `sqlite-amalgamation-3.53.0`；仅替换 SQLite amalgamation（`sqlite3.c` / `sqlite3.h` / `sqlite3ext.h`），sqlitepp wrapper API 保持不变。`sqlitepp.props` 已改为基于 `$(MSBuildThisFileDirectory)`，Debug Unicode 使用 `libsqliteD.lib`，release-utf16 使用 `sqlitepp-utf16.lib`。

**实施检查清单**

1. **libzmq**：升级前记录当前 **ABI 选项**（无 `ZMQ_BUILD_DRAFT_API`；Release|Win32 为静态库、`ZMQ_STATIC`、`FD_SETSIZE=1024`、`/MT`）；单项目构建 → 全解 → **运行时**发一条消息或走现有网络功能（当前由 `test-zeromq-smoke.ps1` 覆盖 `inproc://` PAIR 发收）。
2. **sqlitepp**：库与测试项目同升；跑 `sqliteppTest`（若 CI 未编测试，本地必跑）及主程序 **媒体库/历史记录** 路径。当前已完成 SQLite 3.53.0 与 `sqliteppTest` Debug Unicode 自动化运行；主程序媒体库/历史记录手测仍需人工确认。
3. 将 `src/BuildScript` 下已有 **`test-*.ps1`** 能覆盖到的条目在 PR 中引用文件名。

### 11.4 P5：OpenSSL 0.9.8x 审计与处置

**原则**：**先审计链接与包含**，再决定删树、换 3.x、或改为 **Schannel** 等；禁止「只升版本号不改调用方」。

**实施检查清单**

1. `rg -i "openssl|ssleay|libeay|SSL_CTX" src src/Thirdparty --glob "*.{h,hpp,c,cc,cpp,vcxproj,props}"`；区分 **真实链接** 与 **死代码/文档**。
2. 若主程序与各 filter **均未** `AdditionalDependencies` 指向 `libeay32`/`ssleay32`：将结论写入 §8；**可考虑**移除 `src/Thirdparty/openssl-0.9.8x` 或标为「未使用，保留仅历史对比」——须法务/安全确认。
3. 若存在链接：单独立项 **OpenSSL 3.x** 或 **平台 TLS** 迁移 RFC，本文 §8 引用该子 RFC；本 RFC P5 行标为「已委派」。

**当前审计结论**：`src/Thirdparty/openssl-0.9.8x/rfc0012-expected.txt` = `openssl-0.9.8x-audit-delegated`。Release 主线 `mplayerc`（`Release Unicode|Win32`、`Release|Win32`）和 `Updater`（`Release|Win32`）没有 `libeay32.lib` / `ssleay32.lib` / OpenSSL DLL 链接；遗留链接只保留在 `mplayerc` `Debug Unicode|Win32` 与 `Updater` `Debug|Win32`，且非 OpenSSL 源码树的主程序/Updater/Prototype/Test 源码没有直接 `#include <openssl/...>`。因此本阶段不删除 `src/Thirdparty/openssl-0.9.8x`，也不原地替换为 OpenSSL 3.x；后续若要消除 Debug 旧依赖，应单独做 **OpenSSL 3.x** 或 **Schannel/curl TLS** 迁移 RFC。

## 12. CI 与无 VS 环境的门闩

| 门闩 | 目的 | 命令 / 位置 |
|------|------|-------------|
| P1 头版本 | 防止 zlib/libpng 被误回退 | `src/BuildScript/verify-rfc0012-zlib-libpng.ps1` |
| P2 钉扎 | 防止 jsoncpp 被误替换或 include 路径漂移 | `verify-rfc0012-jsoncpp.ps1` + `Thirdparty/jsoncpp/rfc0012-expected.txt` |
| P3 钉扎 | 防止 yaml-cpp / librhash 静默漂移 | `verify-rfc0012-p3-yaml-librhash.ps1` + 两库各自 `rfc0012-expected.txt` |
| P4 sqlitepp 钉扎 | 防止 SQLite amalgamation、sqlitepp props 与测试入口静默回退 | `verify-rfc0012-p4-sqlitepp.ps1` + `Thirdparty/sqlitepp/rfc0012-expected.txt` |
| P4 zeromq 钉扎 | 防止 0MQ 2.1 ABI、Release 静态库选项与 smoke test 入口静默漂移 | `verify-rfc0012-p4-zeromq.ps1` + `Thirdparty/zeromq/rfc0012-expected.txt` + `test-zeromq-smoke.ps1` |
| P5 OpenSSL 审计 | 防止 OpenSSL 0.9.8x 链接面与迁移委派结论静默漂移 | `verify-rfc0012-p5-openssl-audit.ps1` + `Thirdparty/openssl-0.9.8x/rfc0012-expected.txt` |
| 一键门闩 | 本地 / 无 VS CI 串行跑 P1–P5 钉扎 | `verify-rfc0012-all.ps1` |
| 本地/CI 统一入口（PowerShell） | 门闩 + 预构建 + revision + MSBuild；避免 Git Bash 下裸 `/m` 与 MSYS `find` 污染 `revision.cmd` | `src/BuildScript/ci-local.ps1`（参数见脚本注释）；GitHub：`/.github/workflows/ci.yml` |
| 仓库根日常入口 | 子命令：`verify` / `build` / `buildFast` / `run` / `ship`（见 `./dev.ps1 help`） | 根目录 **`dev.ps1`** |
| 全量真相源 | 发布与回归仍以 MSBuild 为准 | `build-with-msbuild.cmd` 或 `ci-local.ps1`；CI 若托管机缺少 v145/MFC 等工作负载，**不得**将「仅头文件门闩」冒充为全量通过 |

## 13. 旁系事项（不阻塞 P2，但勿遗忘）

- **FFmpeg / mpcvideodec**：许可证、导出符号、性能与体积；**单独 RFC** 引用本文 P1–P2 的「单阶段单合并」节奏。
- **Boost 头文件树**：通常不整树替换；随 **编译器告警** 与 **标准库替代**（`std::`）渐进消化。
- **CRT / MFC 静态链接**：任何新第三方 `.lib` 须与主程序 **同一 `/MT` 或 `/MD` 家族**；升级 PR 中若出现 LNK4098 等，先查依赖再合。

---

**变更流程**：若 P1 在本文仍为 **草案** 时已合入，可将表头 **状态** 更新为 **已接受** 以反映「准则已冻结、后续阶段照 §11 执行」。每完成一个阶段，在 **`TASK_TRACKING.md`** 勾选对应行并附上合并提交哈希。
