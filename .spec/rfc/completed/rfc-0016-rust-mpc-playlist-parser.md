# RFC-0016: Rust MPC Playlist Parser 接入计划

| 字段 | 内容 |
|------|------|
| **状态** | 完成 (Completed) |
| **适用范围** | `PlaylistParser::ParseMPCPlayList` 的 `.mpcpl` 纯文本解析 |
| **平台** | Windows；Win32 优先 |
| **作者** | 维护团队 |
| **创建日期** | 2026-04-25 |
| **最后更新** | 2026-04-25 |
| **相关 RFC** | [RFC-0013](./rfc-0013-rust-native-module-integration.md)、[RFC-0014](./rfc-0014-rust-playlist-parser.md) |

## 摘要

本 RFC 定义 Rust playlist parser 的第二阶段：将 `.mpcpl` 文本解析迁移到 `crates/playlist_parser`。C++ 仍负责 `CPlaylistItem`、路径容器和播放器状态；Rust 只解析 `MPCPLAYLIST` 文件中的 `index,key,value` 行，并通过 C ABI 返回扁平字段列表。

首期仍保留 C++ fallback：`ParseMPCPlayList` 先尝试 Rust，Rust 无结果时回退旧 C++ parser。

## 1. 目标

1. 在 `playasa_playlist_parser.dll` 中导出 `playasa_playlist_parse_mpc`。
2. 用扁平字段列表表达 `.mpcpl` 条目，避免跨 FFI 传递 C++ STL/MFC 类型。
3. C++ adapter 按 index 重建 `CPlaylistItem`。
4. 覆盖 filename、subtitle、label、type、video/audio 与设备字段。
5. Rust tests、C++ adapter fixture、全量 `splayer.sln` 与启动 smoke test 通过。

## 2. 非目标

- 不改变 `.mpcpl` 文件格式。
- 不替换 `CPlaylistItem`。
- 不迁移 M3U/PLS；它们仍留到后续阶段，因为当前主要走 `ContentType` redirection 逻辑。

## 3. C ABI 增量

```c
typedef struct PlayasaMpcPlaylistField {
  int index;
  int key;
  const wchar_t* ptr;
  size_t len;
  long long number;
} PlayasaMpcPlaylistField;

typedef struct PlayasaMpcPlaylistFieldList {
  PlayasaMpcPlaylistField* items;
  size_t len;
} PlayasaMpcPlaylistFieldList;

PlayasaMpcPlaylistFieldList playasa_playlist_parse_mpc(const wchar_t* path);
void playasa_playlist_free_mpc_field_list(PlayasaMpcPlaylistFieldList list);
```

`key` 使用稳定整数枚举，由 C++ adapter 转换为 `CPlaylistItem` 字段。字符串内存由 Rust 分配并由 Rust free 函数释放。

## 4. 退出条件

| 阶段 | 退出条件 |
|------|----------|
| **P1** | Rust MPC tests 通过 |
| **P2** | `PlaylistParser_UnitTest` 覆盖 CUE + MPC adapter |
| **P3** | 全量 `splayer.sln` `Release Unicode|Win32` 构建通过 |
| **P4** | `splayer.exe` 启动 smoke test 通过 |
