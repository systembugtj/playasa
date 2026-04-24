# TASK_TRACKING

在办事项与跟踪记录写在此处；涉及目录布局或 MSBuild 契约的变更须同步更新 **[.spec/rfc/rfc-0011-windows-repository-layout.md](.spec/rfc/rfc-0011-windows-repository-layout.md)**。第三方升级按 **[.spec/rfc/rfc-0012-thirdparty-library-upgrades.md](.spec/rfc/rfc-0012-thirdparty-library-upgrades.md)** 执行（**P1 §9**；**P2 §11.1**；**P3 §11.2**；一键钉扎 **`src/BuildScript/verify-rfc0012-all.ps1`**）。

| 状态 | 项 | 备注 |
|------|-----|------|
| 完成 | RFC-0011：输出目录脚本收敛 + BUILD-FIXES 文档归位 | `fix-output-directories-rfc0011.ps1`、旧 `fix-output-directories*.ps1` 已删、`docs/root-notes/BUILD-FIXES-SUMMARY.md` |
| 完成 | 仓库根散落物清理 | 已删本地 `lang/`、`lib/`、`Release/`、`tools/`（空）、`nul`；README 链接修正；`.gitignore` 增加 `/lang/` |
| 完成 | **RFC-0012 P1**：zlib **1.3.1** + libpng **1.6.47** | `zlib_vs2005`/`libpng_vs2005` 源清单与 `.filters` 已更新；`verify-rfc0012-zlib-libpng.ps1`；全量 MSBuild 需在本地 VS 上再跑 |
| 完成 | **RFC-0012 P2**：jsoncpp **1.9.5** | 上游 `include/json`、`src/lib_json` 已替换；`lib_json.vcxproj` 已更新；`rfc0012-expected.txt`=`1.9.5`；**请在本地跑** `MSBuild ...\lib_json.vcxproj` 与全量 `build-with-msbuild.cmd` + 字幕字体 JSON 路径手测 |
| 待办 | **RFC-0012 P3**：yaml-cpp / librhash（下一个「一次一个」） | RFC-0012 **§11.2**；`verify-rfc0012-p3-yaml-librhash.ps1`；升级后再改两库 `rfc0012-expected.txt` |
| 待办 | **RFC-0012 P4**：zeromq / sqlitepp | 运行时手测 + 已有 `test-*.ps1` 则接入 |
| 待办 | **RFC-0012 P5**：OpenSSL 路径审计 | RFC-0012 **§11**；无链接则删树或文档声明废弃 |
|  |  |  |
