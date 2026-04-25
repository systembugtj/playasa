# 构建与排障

本页合并旧的构建状态、修复指南、进度记录和根目录笔记。现行构建入口以 `src\BuildScript` 为准，主解决方案为 `src\splayer.sln`。

## 快速构建

```batch
cd src\BuildScript
build-with-msbuild.cmd
```

备用入口：

```batch
cd src\BuildScript
build-fixed.cmd
```

推荐先执行本地 CI 检查：

```powershell
.\dev.ps1 build
```

如果只验证 RFC-0012 第三方升级门闩：

```powershell
src\BuildScript\verify-rfc0012-all.ps1
```

## 当前基线

- 主解决方案：`src\splayer.sln`
- 平台：Win32
- 主要输出：`out\bin\Win32\Release Unicode\splayer.exe`
- 构建脚本：`src\BuildScript\build-with-msbuild.cmd`、`src\BuildScript\build-fixed.cmd`
- 布局契约：RFC-0011
- 第三方升级契约：RFC-0012

## 构建前检查

1. Visual Studio 或 Build Tools 已安装。
2. C++ 桌面开发、Windows SDK、MFC/ATL 已安装。
3. PowerShell 终端使用 UTF-8，避免中文路径或日志乱码。
4. `src\BuildScript\find-msbuild.ps1` 能找到 MSBuild。
5. 没有把生成物提交到仓库根目录；输出应在 `out\`。

## 常见失败与处理

### MSBuild 或 Visual Studio 未找到

先运行：

```powershell
cd src\BuildScript
.\find-msbuild.ps1
```

如果仍失败，补装 Visual Studio Build Tools 或完整 Visual Studio，并确认安装了 C++ 桌面开发工作负载。

### 缺少 MFC/ATL

错误类似：

```text
MSB8041: MFC libraries are required for this project.
```

按 [INSTALL.md](INSTALL.md) 补装与当前工具集匹配的 MFC/ATL 组件。

### 缺少 `revision.h` 或 key 文件

运行：

```powershell
cd src\BuildScript
.\fix-build-issues.ps1
```

该脚本负责创建常见的本地占位文件和检查输出目录。

### 输出目录异常

输出目录统一由 RFC-0011 约束，维护脚本为：

```powershell
powershell -File src\BuildScript\fix-output-directories-rfc0011.ps1 -SelfTest
```

不要恢复旧的输出目录修复脚本，也不要把 `Release\`、`lang\`、`lib\` 等生成目录放回仓库根。

### 缺少旧第三方库

旧文档曾提到 `thirdparty/pkg/trunk/*` 之类外置路径；现行仓库应优先查看 `src\Thirdparty`、`src\lib`、对应 `.vcxproj` 和 RFC-0012。若链接错误指向已经删除或不存在的旧 `.lib`，应先确认是否是 stale link，而不是把旧二进制复制回来。

## 构建问题处理顺序

1. 先修环境：MSBuild、Windows SDK、MFC/ATL。
2. 再修路径：`$(SolutionDir)` 必须按 RFC-0011 解析到 `src\`。
3. 再修依赖：确认 `.vcxproj` 链接的是现行随仓库或生成的库。
4. 最后跑全量构建和 RFC 验证脚本。

## 旧记录归档说明

旧的 `BUILD-FIXES.md`、`BUILD-ISSUES-FOUND.md`、`BUILD-PROGRESS.md`、`BUILD-STATUS.md` 和 `docs/root-notes/*` 只是历史状态快照。有效内容已经合并到本页；长期决策以 RFC 和 `TASK_TRACKING.md` 为准。
