# RFC-0014: Rust Playlist Parser 接入计划

| 字段 | 内容 |
|------|------|
| **状态** | 草案 (Draft) |
| **适用范围** | `PlaylistParser` 中的纯文本播放列表解析逻辑 |
| **平台** | Windows；Win32 优先 |
| **作者** | 维护团队 |
| **创建日期** | 2026-04-24 |
| **最后更新** | 2026-04-24 |
| **相关 RFC** | [RFC-0011](./rfc-0011-windows-repository-layout.md)、[RFC-0013](./rfc-0013-rust-native-module-integration.md) |

## 摘要

本 RFC 定义第二个 Rust native island：playlist parser。目标是将 `PlaylistParser` 中边界清晰的纯文本解析逐步迁移到根 Cargo workspace 下的 Rust DLL，不替换 UI、播放列表容器、媒体格式过滤、RAR、LNK、BDMV 或文件搜索逻辑。

首期只接入 CUE parser。C++ `ParseCUEPlayList` 先调用 Rust，Rust 返回有效条目时使用 Rust 结果；若 Rust 返回空结果或遇到无法处理的编码/格式，则回退到旧 C++ parser，确保行为可回滚。

## 1. 目标

1. 新增 `crates/playlist_parser`，作为根 Cargo workspace 成员。
2. 生成 `playasa_playlist_parser.dll` 与 import `.lib`。
3. 通过 C ABI 暴露 CUE 文件解析结果。
4. C++ adapter 将 Rust 路径记录转换为 `CPlaylistItem`。
5. Rust 单测覆盖 CUE 文件名提取、引号、空格、相对路径与不存在文件。

## 2. 非目标

- 不替换 `CPlaylistItem` / `CPlaylist`。
- 不改变 `ContentType` 路由。
- 不迁移 `ParseBDMVPlayList`、RAR、LNK 或 wildcard 搜索。
- 不在首期处理 MPC playlist、M3U、PLS；这些作为后续阶段。

## 3. C ABI

Rust 导出：

```c
typedef struct PlayasaPlaylistPath {
  const wchar_t* ptr;
  size_t len;
} PlayasaPlaylistPath;

typedef struct PlayasaPlaylistPathList {
  PlayasaPlaylistPath* items;
  size_t len;
} PlayasaPlaylistPathList;

PlayasaPlaylistPathList playasa_playlist_parse_cue(const wchar_t* path);
void playasa_playlist_free_path_list(PlayasaPlaylistPathList list);
```

内存由 Rust 分配，也必须由 Rust 的 `playasa_playlist_free_path_list` 释放。C++ 不得跨边界释放 Rust buffer。

## 4. 阶段计划

| 阶段 | 目标 | 退出条件 |
|------|------|----------|
| **P1** | CUE parser Rust DLL | Rust tests 通过；`splayer` Release Unicode 构建通过；启动 smoke test 通过 |
| **P2** | 修复 `PlaylistParser_UnitTest` 并加入 CUE fixture | C++ unit test 能验证 Rust/Fallback 结果 |
| **P3** | MPC playlist parser | 保留 C++ fallback，覆盖 `.mpcpl` fixtures |
| **P4** | M3U / PLS parser | 先确认当前内容类型入口，再接入 |

## 5. 决策记录

| 日期 | 决策 | 理由 |
|------|------|------|
| 2026-04-24 | playlist parser 作为第二个 Rust island | 文本解析边界清晰、测试成本低、运行时风险小 |
| 2026-04-24 | 首期只迁移 CUE parser 并保留 C++ fallback | 降低编码和边缘格式回归风险 |
