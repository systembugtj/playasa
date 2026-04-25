# RFC-0013: Rust 原生模块接入与 MSBuild 消费契约

| 字段 | 内容 |
|------|------|
| **状态** | 完成 (Completed) |
| **适用范围** | 本仓库 `playasa`：仅限非 UI、非 DirectShow COM 外壳的小型原生模块 |
| **平台** | Windows；Win32 优先，x64 后续沿用同一目录与 ABI 规则 |
| **作者** | 维护团队 |
| **创建日期** | 2026-04-24 |
| **最后更新** | 2026-04-25 |
| **相关 RFC** | [RFC-0011](./rfc-0011-windows-repository-layout.md)、[RFC-0012](./rfc-0012-thirdparty-library-upgrades.md) |

## 摘要

本 RFC 定义 Playasa 在现有 Visual Studio / MSBuild / C++ 架构中引入 Rust 的边界、目录、构建、链接、C ABI 与验证规则。Rust 只作为**小型原生模块试点**接入，不替换 MFC UI、DirectShow filter COM 外壳、主播放器框架或现有成熟 C/C++ 引擎。

首个推荐试点为 `sphash` 兼容层：仓库已有 `src/Thirdparty/pkg/sphash.h` 声明和 C ABI 消费点。该边界天然适合由 Rust 实现，并通过原有 C ABI 被 C++ 消费。当前实现要求始终构建并链接 Rust `playasa_sphash.dll`，不再保留空实现占位路径。

## 1. 背景与动机

### 1.1 当前状态

Playasa 是 Windows 桌面媒体播放器，主工程由 `src/splayer.sln`、大量 `.vcxproj`、MFC、DirectShow、C/C++ 第三方库和 Win32 构建脚本组成。RFC-0011 已规定生成物必须落在仓库根 `out\` 下，RFC-0012 已规定第三方库升级应分阶段、小边界推进。

Rust 可用于提升内存安全、简化二进制解析和封装纯算法，但如果直接替换 UI、COM filter 或播放器主循环，会显著扩大构建、调试、ABI 和发布风险。因此，本 RFC 将 Rust 限定为「C++ 主工程可消费的小型 DLL 或静态库」。

### 1.2 问题陈述

直接把 Rust crate 随意放入源码树并从 `.vcxproj` 临时调用 `cargo build` 会带来几个问题：产物路径不符合 RFC-0011、Debug/Release 与 Win32/x64 配置映射不清楚、C++ 与 Rust 的内存所有权不明确、panic/exception 边界不可控、CI 无法稳定复现。

本 RFC 需要给出一套统一契约，使 Rust 模块可以被安全引入、按 MSBuild 配置构建、被 C++ 稳定链接，并且可以通过 Rust 单测和 C++ smoke test 双重验证。

## 2. 目标与非目标

### 2.1 目标

1. 规定 Rust 模块在仓库中的推荐目录、命名和产物位置。
2. 规定 Cargo 与 MSBuild 的配置映射，确保生成物仍进入 `out\`。
3. 规定 C ABI 设计准则，使 C++ 可以稳定消费 Rust 模块。
4. 规定首个试点 `sphash` 的最小实施路线。
5. 规定测试、验证和 PR 审查清单。

### 2.2 非目标

- 不重写 MFC UI、DirectShow filter COM 外壳或播放器主框架。
- 不用 Rust 替换 SQLite、zlib、libpng、librhash、FFmpeg 等成熟库本体。
- 不引入跨平台主构建系统替代 `src/splayer.sln`。
- Rust 接入模块必须由 Rust 工具链构建；没有 Rust 工具链时应构建失败并给出明确诊断，不提供空实现替代。

## 3. 候选方案

### 3.1 方案 A：Rust 静态库，C++ 通过 `.lib` 链接

**技术原理**：Rust crate 使用 `crate-type = ["staticlib"]`，导出 `extern "C"` 函数。MSBuild 在目标 C++ 项目前先执行 Cargo，随后把生成的 `.lib` 加入 `AdditionalDependencies`。

**实施步骤**：新增 Rust crate；固定 C ABI header；增加 MSBuild wrapper `.props` 或项目级 pre-build；将 Rust `.lib` 复制或输出到 `out\lib\<Platform>\<Configuration>\`；C++ 链接该 `.lib`。

**风险分析**：静态链接会增大最终二进制；CRT 与 panic 策略需要统一；不同 Rust target triple 与 MSBuild Platform 必须显式映射。

**适用场景**：模块极小、部署不希望增加 DLL，且确认不会造成最终二进制膨胀或链接诊断复杂化时使用。

### 3.2 方案 B：Rust DLL，C++ 通过导入库或运行时加载（推荐）

**技术原理**：Rust crate 使用 `crate-type = ["cdylib"]`，生成 `.dll` 和 `.lib`，C++ 链接 import lib 或通过 `LoadLibraryW` / `GetProcAddress` 调用。

**实施步骤**：Rust 生成 DLL；MSBuild 将 DLL 复制到 `out\bin\<Platform>\<Configuration>\`；C++ 链接 `.lib` 或做运行时加载；安装包带上 DLL。

**风险分析**：部署多一个 DLL；加载失败路径需要处理；导出符号和运行时依赖需要额外检查。

**推荐理由**：与本仓现有 DLL/filter 产物模型更接近，Rust 运行时边界更清晰，升级或回滚单个 Rust 模块更容易；首期通过 import lib 静态绑定，缺少 Rust 产物时直接构建失败。

### 3.3 方案 C：保持纯 C++，不接入 Rust

**技术原理**：继续用 C/C++ 实现缺失模块，例如调用现有 librhash 或新增 C++ MD5 实现。

**实施步骤**：在 C++ 工程内新增实现；复用现有 `.vcxproj`；补测试。

**风险分析**：构建最简单，但无法验证 Rust 在本仓的工具链集成；二进制解析和边界安全收益较低。

**适用场景**：没有 Rust toolchain、CI 暂时不能安装 Rust，或目标模块太小不值得引入新语言。

## 4. 推荐决策

默认采用**方案 B：Rust DLL + C ABI + C++ 链接 import `.lib`**。首个试点只实现 `sphash` 兼容层，不修改调用方业务语义，不改变 `sphash.h` 公开函数签名。Rust DLL 必须复制到对应 `out\bin\<Platform>\<Configuration>\`，import `.lib` 必须进入 `out\lib\<Platform>\<Configuration>\`。若试点证明 MSBuild、CI、测试、部署和调试体验稳定，再考虑 ZIP/archive helper 或 SQLite wrapper 周边逻辑。

## 5. 目录与命名契约

### 5.1 Rust 源码目录

Rust 源码应放在仓库根 Cargo workspace 下的 `crates/<module>/`。根目录必须保留 `Cargo.toml` 作为 workspace 入口，例如：

```text
<repo-root>/
├── Cargo.toml                           # workspace 入口
├── crates/
│   └── sphash/
│       ├── Cargo.toml
│       ├── build.rs                     # 仅在确有需要时使用
│       ├── include/
│       │   └── sphash_rust.h             # 可选；C++ 仍优先消费既有 sphash.h
│       └── src/
│           └── lib.rs
└── src/
    └── Thirdparty/
        └── pkg/
            └── sphash.h
```

`crates/` 属于本仓维护源码，不等同于 Cargo 的下载缓存。Cargo registry、target 目录、临时下载物不得提交。所有 Rust crate 必须纳入根 `Cargo.toml` 的 `[workspace].members`，避免每个模块各自形成孤立 Cargo 项目。

### 5.2 生成物目录

Rust 构建输出必须遵守 RFC-0011：

| 类型 | 规范位置 |
|------|----------|
| Cargo target dir | `out\obj\rust\` |
| DLL `.dll` | `out\bin\<Platform>\<Configuration>\` |
| DLL import `.lib` | `out\lib\<Platform>\<Configuration>\` |
| 静态库 `.lib`（仅方案 A） | `out\lib\<Platform>\<Configuration>\` |
| C/C++ 中间文件 | 继续按现有 `.vcxproj` 规则进入 `out\obj\...` |

禁止把 Rust 生成的 `.lib`、`.dll`、`.pdb`、`target\` 长期放入 `src\` 或仓库根。

## 6. Cargo 与 MSBuild 映射

### 6.1 配置映射

| MSBuild Platform | Rust target triple |
|------------------|-------------------|
| `Win32` | `i686-pc-windows-msvc` |
| `x64` | `x86_64-pc-windows-msvc` |

| MSBuild Configuration | Cargo profile |
|-----------------------|---------------|
| 包含 `Debug` | `dev` |
| 其他，如 `Release` / `Release Unicode` | `release` |

`Release Unicode` 只是本仓 C++ 配置名，Rust 不应因此建立单独 profile。Unicode 行为应由 C ABI 的宽字符参数负责，例如 `const wchar_t*`。

### 6.2 推荐 MSBuild 接入方式

第一阶段可以在消费项目中使用最小 pre-build 或 custom build target。稳定后应收敛为共享 props，例如 `src/BuildScript/rust-native.props`，由需要 Rust 的 `.vcxproj` 导入。

推荐 props 职责：

1. 检测 `cargo` 是否存在，缺失时给出明确错误。
2. 根据 `$(Platform)` 选择 Rust target triple。
3. 根据 `$(Configuration)` 选择 Cargo profile。
4. 设置 `CARGO_TARGET_DIR=$(SolutionDir)..\out\obj\rust\<module>\$(Platform)\$(Configuration)\`。
5. 执行 `cargo build --manifest-path ... --target ...`。
6. 将 Rust DLL 复制到 `$(SolutionDir)..\out\bin\$(Platform)\$(Configuration)\`，将 import `.lib` 复制到 `$(SolutionDir)..\out\lib\$(Platform)\$(Configuration)\`。

### 6.3 环境要求

进入 Accepted 前，Rust 工具链应固定为以下最低要求：

- Rust stable MSVC toolchain。
- `i686-pc-windows-msvc` target，因当前主交付平台为 Win32。
- Visual Studio C++ build tools，与现有 `.vcxproj` 使用的 MSVC 工具链一致。

建议在 `rust-toolchain.toml` 中固定 channel，避免开发机间漂移。若后续 CI 引入 Rust，应在 CI bootstrap 脚本中显式安装 target。

## 7. C ABI 设计规则

### 7.1 允许跨边界传递的类型

Rust 与 C++ 之间只允许传递以下类型：

- 整数、布尔、枚举值的固定宽度表示。
- `const uint8_t*` / `uint8_t*` 加长度。
- `const char*`，仅用于 UTF-8 或 ASCII，必须写入注释或文档。
- `const wchar_t*`，仅用于 Windows 路径。
- POD struct，字段必须固定宽度并有 `repr(C)` 对应。

### 7.2 禁止跨边界传递的类型

- `std::string`、`std::wstring`、`CString`、`std::vector`。
- Rust `String`、`Vec<T>`、slice、trait object。
- C++ exception 或 Rust panic。
- 由一侧分配、另一侧隐式释放的不透明内存。

### 7.3 错误与内存规则

1. Rust 导出函数不得 panic 穿过 FFI 边界；必须使用 `catch_unwind` 或把核心实现写成不 panic 的 `Result` 流程。
2. C ABI 返回值应使用 `int` 状态码，或沿用既有 API 的 `len == 0` 失败语义。
3. 输出 buffer 由 C++ 调用方分配，Rust 只写入不超过给定长度的字节。
4. 若必须由 Rust 分配内存，必须同时导出 `free` 函数；首个 `sphash` 试点禁止采用 Rust 分配返回。

## 8. 首个试点：`sphash` 兼容层

### 8.1 现有 ABI

`src/Thirdparty/pkg/sphash.h` 当前公开以下函数：

```cpp
void hash_file(const char* mod, int algo, const wchar_t* path, char* out, int* len);
void hash_data(const char* mod, int algo, char* buff, int* len);
```

首个 Rust 试点必须保持这两个函数的 C ABI 和调用语义。`HASH_ALGO_MD5` 初期作为唯一算法实现，未知算法必须返回失败，即将 `*len` 置为 `0`，并在 `out` 非空时写入空字符串。

### 8.2 行为契约

`hash_file`：

1. `path == nullptr`、`out == nullptr` 或 `len == nullptr` 时不得崩溃。
2. `*len` 输入值应作为输出 buffer 容量；容量不足时失败并置 `*len = 0`。
3. 成功时写入小写十六进制摘要和结尾 `\0`，并将 `*len` 设为摘要字符数。
4. 文件无法打开或读取失败时返回失败语义。

`hash_data`：

1. 沿用既有签名限制，`buff` 同时代表输入数据指针。
2. 旧 ABI 没有独立输出 buffer 和输入长度，后续通过 `hash_data_v2` 修正该限制。
3. 若要实现 `hash_data`，必须先新增不破坏旧 ABI 的 v2 函数，例如 `hash_data_v2(const char* mod, int algo, const uint8_t* input, int input_len, char* out, int* out_len)`。

### 8.3 兼容策略

Rust 接入后，消费项目必须链接 Rust DLL 的 import `.lib`，并确保 DLL 复制到运行目录。不保留空实现占位路径；缺少 Rust 工具链或 Rust 产物时构建必须失败。

## 9. 测试与验证

### 9.1 Rust 单元测试

每个 Rust 模块必须包含 Rust 单测。`sphash` 至少覆盖：

1. 空文件 MD5。
2. 小文件 MD5。
3. 不存在文件。
4. 输出 buffer 过小。
5. 空指针输入不会崩溃。

### 9.2 C++ smoke test

首个接入 PR 应增加一个最小 C++ smoke test 或测试工程步骤，验证：

1. C++ 可以包含 `sphash.h` 并链接成功。
2. `hash_file(HASH_MOD_FILE_STR, HASH_ALGO_MD5, ...)` 对固定夹具文件返回预期摘要。
3. `len == 0` 失败语义与现有调用方兼容。

### 9.3 验证命令模板

Rust 单测：

```bat
cargo test -p playasa-sphash --target i686-pc-windows-msvc
```

单模块构建：

```bat
cargo build -p playasa-sphash --target i686-pc-windows-msvc --release
```

C++ 全量构建仍以现有入口为准：

```bat
cd /d <REPO>\src\BuildScript
build-with-msbuild.cmd
```

## 10. PR 审查清单

1. Rust 源码位于根 Cargo workspace 的 `crates/<module>/`，且已登记到根 `Cargo.toml`。
2. Cargo target dir 指向 `out\obj\rust\...`，没有提交 `target\`。
3. `.lib` / `.dll` 输出进入 `out\lib` 或 `out\bin`。
4. C ABI 不传递 C++ STL、Rust `String` / `Vec` 或异常。
5. Rust panic 不穿过 FFI 边界。
6. 新增或修改的 C++ 项目在无重复符号的情况下链接。
7. Rust 单测通过。
8. C++ smoke test 或主配置构建通过。
9. README、TASK 或相关 RFC 已记录试点状态。

## 11. 阶段计划

| 阶段 | 目标 | 退出条件 |
|------|------|----------|
| **P0** | 接受本 RFC，确认 Rust 只用于小型 native island | RFC 合入，`TASK_TRACKING.md` 登记 |
| **P1** | `sphash` Rust DLL 试点 | Rust 单测 + C++ smoke test + `Release Unicode|Win32` 构建通过，DLL 位于 `out\bin`，import `.lib` 位于 `out\lib` |
| **P2** | 将 MSBuild Rust 接入收敛为共享 props | 至少两个项目可复用，路径与输出符合 RFC-0011 |
| **P3** | 评估 ZIP/archive helper 或 SQLite wrapper 周边逻辑 | 有 profiling 或维护性证据支持，不替换成熟库本体 |

## 12. 风险与缓解

| 风险 | 等级 | 缓解 |
|------|------|------|
| 开发机未安装 Rust | 中 | 构建脚本输出明确错误并失败 |
| Win32 Rust target 缺失 | 中 | bootstrap 脚本检查 `i686-pc-windows-msvc` |
| FFI 内存所有权错误 | 高 | 首期只用调用方 buffer；禁止 Rust 分配返回 |
| panic 穿过 C ABI | 高 | 核心逻辑返回 `Result`；FFI 层捕获并转换为失败码 |
| 生成物污染 `src` 或仓库根 | 中 | 强制 `CARGO_TARGET_DIR` 指向 `out\obj\rust` |
| 重复定义旧实现与 Rust 符号 | 中 | Rust 接入模块只保留 Rust import `.lib` 链接路径，PR 中检查链接日志 |

## 13. 决策记录

| 日期 | 决策 | 理由 |
|------|------|------|
| 2026-04-24 | Rust 不替换 UI、DirectShow COM 外壳、主播放器框架 | 降低迁移风险，保持现有 C++ 架构稳定 |
| 2026-04-24 | 首个试点选择 `sphash` 兼容层 | C ABI 已存在，边界最小 |
| 2026-04-24 | 默认采用 Rust `cdylib`，C++ 链接 import `.lib` 并部署 DLL | 模块边界更清晰，便于独立升级、回滚和诊断 |
| 2026-04-25 | Rust 接入模块不再保留空实现占位路径 | 避免产出可链接但运行时功能静默失败的程序 |

## 14. 下一步行动

1. 评审本 RFC 的目录、ABI 与 MSBuild 输出契约。
2. 新增 `crates/sphash/` crate，先实现 Rust 单测。
3. 增加最小 MSBuild 接入脚本或 props，使 `sphash` Rust DLL 输出到 `out\bin\Win32\Release Unicode\`，import `.lib` 输出到 `out\lib\Win32\Release Unicode\`。
4. 切换消费项目，确保只链接 Rust 实现。
5. 增加 C++ smoke test 并跑主配置构建。
