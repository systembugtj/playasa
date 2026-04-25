# TASK_TRACKING

在办事项与跟踪记录写在此处；涉及目录布局或 MSBuild 契约的变更须同步更新 **[.spec/rfc/rfc-0011-windows-repository-layout.md](.spec/rfc/rfc-0011-windows-repository-layout.md)**。第三方升级按 **[.spec/rfc/rfc-0012-thirdparty-library-upgrades.md](.spec/rfc/rfc-0012-thirdparty-library-upgrades.md)** 执行（**P1 §9**；**P2 §11.1**；**P3 §11.2**；**P4 §11.3**；**P5 §11.4**；一键钉扎 **`src/BuildScript/verify-rfc0012-all.ps1`**）。

| 状态 | 项 | 备注 |
|------|-----|------|
| 完成 | RFC-0011：输出目录脚本收敛 + BUILD-FIXES 文档归位 | `fix-output-directories-rfc0011.ps1`、旧 `fix-output-directories*.ps1` 已删、`docs/root-notes/BUILD-FIXES-SUMMARY.md` |
| 完成 | 仓库根散落物清理 | 已删本地 `lang/`、`lib/`、`Release/`、`tools/`（空）、`nul`；README 链接修正；`.gitignore` 增加 `/lang/` |
| 完成 | **RFC-0012 P1**：zlib **1.3.1** + libpng **1.6.47** | `zlib_vs2005`/`libpng_vs2005` 源清单与 `.filters` 已更新；`verify-rfc0012-zlib-libpng.ps1`；全量 MSBuild 需在本地 VS 上再跑 |
| 完成 | **RFC-0012 P2**：jsoncpp **1.9.5** | 上游 `include/json`、`src/lib_json` 已替换；`lib_json.vcxproj` 已更新；`rfc0012-expected.txt`=`1.9.5`；**请在本地跑** `MSBuild ...\lib_json.vcxproj` 与全量 `build-with-msbuild.cmd` + 字幕字体 JSON 路径手测 |
| 完成 | **RFC-0012 P3**：**librhash** 对齐上游 **RHash v1.4.6**；**yaml-cpp** 对齐上游 **0.9.0** | `librhash/rfc0012-expected.txt`=`rhash-upstream-1.4.6`；`yaml-cpp/rfc0012-expected.txt`=`yaml-cpp-0.9.0`；`rhash_ex.cpp` 已适配新 `rhash_final`/`rhash_print`；`rsc_format.cc` 已从 `YAML::Parser`/`YAML::Iterator` 迁移到新版 `YAML::Load`/`YAML::Node` API；`verify-rfc0012-all.ps1` 通过；`yamlcpp.vcxproj` Release|Win32 通过；`splayer.vcxproj` Release|Win32 通过并重新生成 `splayer.rsc`；全量 `./dev.ps1 build` 通过并产出 `out\bin\Win32\Release Unicode\splayer.exe`；ED2K 路径手测待确认 |
| 完成 | **RFC-0012 P4**：zeromq / sqlitepp | **sqlitepp 已完成 SQLite 3.53.0**：`sqlitepp/rfc0012-expected.txt`=`sqlite-amalgamation-3.53.0`；`sqliteppTest` Debug Unicode 无 warning 构建并运行通过（pass--1..6）；**zeromq 已钉扎 0MQ 2.1.3 ABI**：`zeromq/rfc0012-expected.txt`=`zeromq-2.1.3-abi-pinned`，`test-zeromq-smoke.ps1` 覆盖 Release|Win32 静态库与 `inproc://` PAIR 发收；`verify-rfc0012-all.ps1` 已接入 P4 sqlitepp + zeromq 门闩；全量 `./dev.ps1 build` 通过并产出 `out\bin\Win32\Release Unicode\splayer.exe`；UnRAR 官方 DLL 缺少旧 `RARExtractChunk*` 符号，已补仓内兼容层解决链接；主程序媒体库/历史记录手测仍待人工确认；zeromq 4.x 属于后续兼容层迁移 |
| 完成 | **RFC-0012 P5**：OpenSSL 路径审计 | `openssl-0.9.8x/rfc0012-expected.txt`=`openssl-0.9.8x-audit-delegated`；Release 主线（`mplayerc` Release Unicode/Release、`Updater` Release）未链接 `libeay32.lib`/`ssleay32.lib`；遗留链接仅存在于 `mplayerc` Debug Unicode 与 `Updater` Debug，按 RFC-0012 委派到后续 OpenSSL 3.x 或 Schannel/curl TLS 迁移；`verify-rfc0012-all.ps1` 已接入 P5 审计门闩 |
| 进行中 | **RFC-0013**：Rust 原生模块接入试点（`sphash`） | 根 `Cargo.toml` workspace + `crates/sphash` 已接入；Rust 单测 4/4 通过；全量 `splayer.sln` Release Unicode\|Win32 构建通过并产出 `playasa_sphash.dll` + import `.lib`；`splayer.exe` 启动 smoke test 通过 |
| 进行中 | **RFC-0014**：Rust playlist parser 试点（CUE） | `crates/playlist_parser` + Rust DLL 已接入 `ParseCUEPlayList`，保留旧 C++ parser fallback；Rust 单测 4/4 通过；`PlaylistParser_UnitTest` Debug Unicode 构建并运行通过（C++ adapter fixture）；全量 `splayer.sln` Release Unicode\|Win32 构建通过并产出 `playasa_playlist_parser.dll` + import `.lib`；`splayer.exe` 启动 smoke test 通过 |
|  |  |  |
