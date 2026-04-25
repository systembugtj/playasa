# RFC-0021: Rust sphash v2 API 接入计划

| 字段 | 内容 |
|------|------|
| **状态** | 完成 (Completed) |
| **适用范围** | `crates/sphash`、`src/Thirdparty/pkg/sphash.h`、消费 `sphash` 的 C++ 调用点 |
| **平台** | Windows；Win32 优先 |
| **作者** | 维护团队 |
| **创建日期** | 2026-04-25 |
| **最后更新** | 2026-04-25 |
| **相关 RFC** | [RFC-0013](./rfc-0013-rust-native-module-integration.md) |

## 摘要

本 RFC 定义 Rust 后续路线的第一项：补齐 `sphash` 的 v2 数据哈希 API。RFC-0013 已完成 Rust `sphash` DLL 试点，但旧 `hash_data` ABI 同时复用输入 buffer 和输出 buffer，且没有独立输入长度/输出容量，语义不适合继续扩展。

本阶段不破坏旧 ABI，只新增清晰的 v2 函数，让 C++ 可以安全地对内存数据计算摘要。

## 1. 目标

1. 在 Rust `playasa_sphash.dll` 中新增 `hash_data_v2`。
2. v2 API 使用独立输入指针、输入长度、输出 buffer 和输出容量。
3. 保持旧 `hash_file` / `hash_data` ABI 不变。
4. Rust 单测覆盖 MD5 known vectors、空输入、空指针、输出 buffer 过小。
5. 增加最小 C++ smoke test 或现有测试扩展，验证 C++ 可链接并调用 v2 API。

## 2. 非目标

- 不替换 `librhash`。
- 不改变旧 `hash_data` 语义。
- 不新增 SHA 系列算法，除非后续调用点证明需要。

## 3. C ABI

```c
void hash_data_v2(
  const char* mod,
  int algo,
  const unsigned char* input,
  int input_len,
  char* out,
  int* out_len);
```

`out_len` 输入表示输出 buffer 容量；成功时写入小写十六进制摘要并设置实际字符数；失败时设置为 `0`。当前 MD5 输出需要调用方提供至少 33 字节容量，用于 32 字符摘要和末尾 `NUL`。

## 4. 完成内容

1. `crates/sphash/src/lib.rs` 已拆为薄模块入口，避免单体 `lib.rs`。
2. MD5 核心、文件读取、Windows 宽字符路径和 FFI 边界分别拆入 `md5.rs`、`file.rs`、`path.rs`、`ffi.rs`。
3. Rust 新增 `hash_data_v2`，输入 buffer 与输出 buffer 分离，保留旧 `hash_file` / `hash_data` ABI。
4. `src/Thirdparty/pkg/sphash.h` 已同步 v2 声明，消费项目始终链接 Rust `playasa_sphash.dll` 的 import lib。
5. 已移除空实现占位路径；缺少 Rust 工具链或 Rust 产物时构建失败，不产出静默失效的 hash。
6. `HashController::GetMD5Hash` 已切换到 `hash_data_v2`，不再依赖旧的输入/输出复用 buffer。
7. 新增 Rust 单测覆盖 known vectors、旧 ABI、v2 空输入、空指针和输出 buffer 过小。

## 5. 验证结果

| 阶段 | 结果 |
|------|------|
| **P1** | `cargo fmt -p playasa-sphash && cargo test -p playasa-sphash` 通过，8/8 tests passed |
| **P2** | `HashController.cc` 消费 `hash_data_v2`，全量构建验证链接通过 |
| **P3** | `splayer.sln` `Release Unicode|Win32` 全量 MSBuild 通过 |
| **P4** | `splayer.exe` 启动 smoke 通过，5 秒后正常强制关闭 |
