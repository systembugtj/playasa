# RFC-0022: Rust Subtitle Text Probe 接入计划

| 字段 | 内容 |
|------|------|
| **状态** | 完成 (Completed) |
| **适用范围** | 字幕文本读取前的编码探测、BOM 识别、轻量 metadata scan |
| **平台** | Windows；Win32 优先 |
| **作者** | 维护团队 |
| **创建日期** | 2026-04-25 |
| **最后更新** | 2026-04-25 |
| **相关 RFC** | [RFC-0013](./rfc-0013-rust-native-module-integration.md)、[RFC-0021](./rfc-0021-rust-sphash-v2-api.md) |

## 摘要

本 RFC 定义 Rust 后续路线的第二项：为字幕加载路径增加一个小型 Rust text probe。该模块只负责纯文本边界：读取少量字节、判断 BOM/UTF-8/UTF-16、识别常见字幕格式信号，并返回稳定 C ABI 结构。

本阶段不触碰字幕渲染、时间轴同步、DirectShow filter、UI 设置页或字幕下载逻辑。

## 1. 目标

1. 新增独立 Rust crate 或复用合适的 text helper crate，命名应表达字幕 text probe 职责。
2. 支持 BOM 检测：UTF-8 BOM、UTF-16 LE、UTF-16 BE。
3. 对无 BOM 文本做保守 UTF-8 探测；无法确认时返回 unknown，由 C++ 旧路径继续处理。
4. 轻量识别常见字幕特征，例如 SRT 序号/时间轴、ASS/SSA header、WebVTT header。
5. C++ adapter 只消费探测结果，不改变实际字幕渲染行为。

## 2. 非目标

- 不重写字幕 parser。
- 不改变字幕显示、样式、时间轴或字体 fallback。
- 不替换现有 `CTextFile` 的所有调用点。

## 3. C ABI

```c
typedef struct PlayasaSubtitleTextProbe {
  int encoding;
  int format_hint;
  int confidence;
} PlayasaSubtitleTextProbe;

PlayasaSubtitleTextProbe playasa_subtitle_probe_text(const wchar_t* path);
```

`encoding` 和 `format_hint` 使用稳定整数枚举；`confidence` 用于让 C++ 决定是否采用 Rust 结果或继续旧逻辑。

## 4. 完成内容

1. 新增 `crates/subtitle_text_probe`，并登记到根 `Cargo.toml` workspace。
2. `src/lib.rs` 仅作为薄模块入口，实际逻辑拆到 `encoding.rs`、`format.rs`、`path.rs`、`probe.rs`、`ffi.rs`。
3. 新增 `src/Thirdparty/pkg/subtitle_text_probe_rust.h`，提供稳定 C ABI、encoding enum 和 format hint enum。
4. 新增 `src/Thirdparty/subtitle_text_probe_rust.props`，主程序和 C++ smoke test 始终构建并链接 Rust DLL，无 stub、无关闭开关。
5. `PlaylistParser_UnitTest` 增加 subtitle probe smoke：写入 SRT fixture 并验证 Rust 返回 UTF-8 + SRT。
6. 主程序 `mplayerc_vs2005.vcxproj` 已导入 subtitle text probe props，Release 构建会产出并部署 `playasa_subtitle_text_probe.dll`。

## 5. 验证结果

| 阶段 | 结果 |
|------|------|
| **P1** | `cargo fmt -p playasa-subtitle-text-probe && cargo test -p playasa-subtitle-text-probe` 通过，8/8 tests passed |
| **P2** | `PlaylistParser_UnitTest` Debug Unicode 构建并运行通过，覆盖 subtitle probe C ABI smoke |
| **P3** | 本阶段只读 probe 结果用于 smoke，不改变字幕渲染和 `CTextFile` 读取行为 |
| **P4** | `splayer.sln` `Release Unicode|Win32` 全量 MSBuild 通过；`splayer.exe` 启动 smoke 通过 |
