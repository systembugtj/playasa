# TASK_TRACKING

在办事项与跟踪记录写在此处；涉及目录布局或 MSBuild 契约的变更须同步更新 **[.spec/rfc/rfc-0011-windows-repository-layout.md](.spec/rfc/rfc-0011-windows-repository-layout.md)**。第三方升级按 **[.spec/rfc/rfc-0012-thirdparty-library-upgrades.md](.spec/rfc/rfc-0012-thirdparty-library-upgrades.md)** 执行（**P1 原子步骤见该文 §9**）。

| 状态 | 项 | 备注 |
|------|-----|------|
| 完成 | RFC-0011：输出目录脚本收敛 + BUILD-FIXES 文档归位 | `fix-output-directories-rfc0011.ps1`、旧 `fix-output-directories*.ps1` 已删、`docs/root-notes/BUILD-FIXES-SUMMARY.md` |
| 完成 | 仓库根散落物清理 | 已删本地 `lang/`、`lib/`、`Release/`、`tools/`（空）、`nul`；README 链接修正；`.gitignore` 增加 `/lang/` |
| 待办 | **RFC-0012 P1**：zlib + libpng 升级到当前稳定主线 | 按 RFC-0012 **§9** 15 步检查清单；上游 tag 写进 PR；路线 A 内嵌源码 |
| 待办 | **RFC-0012 P2**：jsoncpp 现代化 | RFC-0012 **§11**；`rg Json::` 摸底后选上游 tag |
| 待办 | **RFC-0012 P3**：yaml-cpp / librhash | 单库 MSBuild → 全解；见 RFC-0012 **§5** 表 |
| 待办 | **RFC-0012 P4**：zeromq / sqlitepp | 运行时手测 + 已有 `test-*.ps1` 则接入 |
| 待办 | **RFC-0012 P5**：OpenSSL 路径审计 | RFC-0012 **§11**；无链接则删树或文档声明废弃 |
|  |  |  |
