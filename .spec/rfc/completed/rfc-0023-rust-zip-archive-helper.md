# RFC-0023: Rust ZIP / Archive Helper 接入计划

| 字段 | 内容 |
|------|------|
| **状态** | 完成 (Completed) |
| **适用范围** | 压缩包内媒体候选文件列举、路径过滤、后续 archive 辅助能力 |
| **平台** | Windows；Win32 优先 |
| **作者** | 维护团队 |
| **创建日期** | 2026-04-25 |
| **最后更新** | 2026-04-25 |
| **相关 RFC** | [RFC-0013](./rfc-0013-rust-native-module-integration.md)、[RFC-0021](./rfc-0021-rust-sphash-v2-api.md)、[RFC-0022](./rfc-0022-rust-subtitle-text-probe.md) |

## 摘要

本 RFC 定义 Rust 后续路线的第三项：增加 ZIP / archive helper。首期只做压缩包目录读取和媒体候选文件列举，输出路径列表给 C++；不做解压播放、不替换 RAR 逻辑、不改变播放器现有 archive URL 语义。

这样可以先验证 Rust 对二进制容器目录结构的处理价值，同时把运行时风险控制在“只读列举”范围内。

## 1. 目标

1. 新增 Rust archive helper crate，或在明确边界下新增 `crates/archive_helper`。
2. 首期支持 ZIP central directory 读取，返回 archive 内文件名列表。
3. C++ 侧只使用该列表筛选可播放媒体/字幕候选项。
4. 输出内存仍由 Rust 分配并提供 Rust free 函数。
5. 单测覆盖空 ZIP、普通文件名、嵌套路径、非 UTF-8/损坏 ZIP 的失败语义。

## 2. 非目标

- 不替换 `SVPRarLib`。
- 不直接解压媒体流。
- 不改变 `rar://` 或其它现有 archive URL。
- 不引入大范围 archive 抽象层，直到首期只读列举验证稳定。

## 3. C ABI

```c
typedef struct PlayasaArchiveEntry {
  const wchar_t* ptr;
  size_t len;
} PlayasaArchiveEntry;

typedef struct PlayasaArchiveEntryList {
  PlayasaArchiveEntry* items;
  size_t len;
} PlayasaArchiveEntryList;

PlayasaArchiveEntryList playasa_archive_list_zip(const wchar_t* path);
void playasa_archive_free_entry_list(PlayasaArchiveEntryList list);
```

## 4. 完成内容

1. 新增 `crates/archive_helper`，并登记到根 `Cargo.toml` workspace。
2. `src/lib.rs` 仅作为薄模块入口，实际逻辑拆到 `ffi.rs`、`path.rs`、`wide.rs`、`zip.rs`。
3. 使用 Rust `zip` crate 读取 ZIP 目录；配置为 `default-features = false`，首期只列目录，不启用解压算法栈。
4. 新增 `src/Thirdparty/pkg/archive_helper_rust.h`，提供稳定 C ABI 和 Rust 分配/Rust 释放的 entry list。
5. 新增 `src/Thirdparty/archive_helper_rust.props`，主程序和 C++ smoke test 始终构建并链接 Rust DLL，无 stub、无关闭开关。
6. `PlaylistParser_UnitTest` 增加 archive helper smoke：生成最小 stored ZIP fixture，并验证 Rust 返回 `movie.mp4` 和 `subs/movie.srt`。
7. 主程序 `mplayerc_vs2005.vcxproj` 已导入 archive helper props，Release 构建会产出并部署 `playasa_archive_helper.dll`。

## 5. RAR 决策

Rust 生态中存在 `unrar` / `unrar.rs`，但其底层依赖 native UnRAR library。当前项目已经有 `unrar.dll`、`unrar.hpp` 和仓内兼容层，因此本阶段不引入 Rust RAR wrapper，也不替换现有 RAR 播放路径。

## 6. 验证结果

| 阶段 | 结果 |
|------|------|
| **P1** | `cargo fmt -p playasa-archive-helper && cargo test -p playasa-archive-helper` 通过，5/5 tests passed |
| **P2** | `PlaylistParser_UnitTest` Debug Unicode 构建并运行通过，覆盖 ZIP listing C ABI smoke |
| **P3** | 本阶段只读列举 ZIP entry；不改变 RAR、解压播放或 archive URL 行为 |
| **P4** | `splayer.sln` `Release Unicode|Win32` 全量 MSBuild 通过；`splayer.exe` 启动 smoke 通过 |

## 7. 依赖说明

`cargo tree -p playasa-archive-helper --depth 1` 显示首层依赖只有 `zip v8.5.1`。由于禁用默认特性，首期未引入 bzip2、zstd、xz、lzma 等解压功能依赖。
