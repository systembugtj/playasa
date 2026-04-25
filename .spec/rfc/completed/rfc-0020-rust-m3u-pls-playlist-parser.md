# RFC-0020: Rust M3U / PLS Playlist Parser 接入计划

| 字段 | 内容 |
|------|------|
| **状态** | 完成 (Completed) |
| **适用范围** | `ContentType` redirection 路径中的 `.m3u` / `.m3u8` / `.pls` 纯文本解析 |
| **平台** | Windows；Win32 优先 |
| **作者** | 维护团队 |
| **创建日期** | 2026-04-25 |
| **最后更新** | 2026-04-25 |
| **相关 RFC** | [RFC-0013](./rfc-0013-rust-native-module-integration.md)、[RFC-0014](./rfc-0014-rust-playlist-parser.md)、[RFC-0016](./rfc-0016-rust-mpc-playlist-parser.md) |

## 摘要

本 RFC 定义 Rust playlist parser 的第三阶段：将本地 `.m3u` / `.m3u8` / `.pls` 播放列表解析迁移到 `crates/playlist_parser`。现有 C++ 结构中，M3U/PLS 不是独立 `PlaylistParser` 函数，而是通过 `ContentType::Get(..., redir)` 生成 redirection 列表，再递归调用 `Parse`。

因此本阶段不改变播放器路由：Rust 只负责把本地 M3U/PLS 文件解析为路径列表；C++ adapter 将路径列表交回现有递归 `Parse` 流程。Rust 失败或返回空列表时，继续回退旧 `ContentType` redirection 逻辑。

## 1. 目标

1. 在 `playasa_playlist_parser.dll` 中导出 `playasa_playlist_parse_m3u` 与 `playasa_playlist_parse_pls`。
2. 保持 C ABI 仍使用 `PlayasaPlaylistPathList`，避免新增复杂结构。
3. 支持 `.m3u` / `.m3u8` 的注释、空行、`#EXTM3U`、`#EXTINF`。
4. 支持 `.pls` 的 `[playlist]`、`FileN=...` 项。
5. 本地相对路径按 playlist 文件所在目录解析；URL 保持原样。
6. 保留旧 C++ parser fallback。

## 2. 非目标

- 不重写网络 URL playlist 下载逻辑。
- 不改变 `ContentType` 对 ASX / RealAudio / QuickTime 等格式的处理。
- 不替换 `CPlaylistItem` / `CPlaylist`。

## 3. C ABI 增量

```c
PlayasaPlaylistPathList playasa_playlist_parse_m3u(const wchar_t* path);
PlayasaPlaylistPathList playasa_playlist_parse_pls(const wchar_t* path);
```

返回值继续由 `playasa_playlist_free_path_list` 释放。

## 4. 退出条件

| 阶段 | 退出条件 |
|------|----------|
| **P1** | Rust M3U/PLS tests 通过 |
| **P2** | `PlaylistParser_UnitTest` 覆盖 M3U + PLS adapter |
| **P3** | 全量 `splayer.sln` `Release Unicode|Win32` 构建通过 |
| **P4** | `splayer.exe` 启动 smoke test 通过 |
