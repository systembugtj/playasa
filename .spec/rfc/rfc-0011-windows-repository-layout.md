# RFC-0011: Windows-only 仓库目录与构建布局约定

| 字段 | 内容 |
|------|------|
| **状态** | 已接受 (Accepted) |
| **适用范围** | 本仓库 `playasa`（SPlayer / Media Player Classic 衍生） |
| **平台** | 仅 Windows；Win32 为主，x64 未另开布局 RFC 前沿用同一套相对关系 |
| **作者** | 维护团队 |
| **创建日期** | 2026-04-18 |
| **最后更新** | 2026-04-19（§3.5 一句话摘要、§3.7 仅保留 rfc0011 输出脚本并删除历史脚本） |
| **相关文档** | [RFC-0002](./rfc-0002-build-environment-analysis.md)、[RFC-0001](./rfc-0001-modernization-proposal.md)、[RFC-0012](./rfc-0012-thirdparty-library-upgrades.md) |

## 摘要

本 RFC 是 **仓库物理布局与 MSBuild 路径契约** 的单一事实来源（与「为何这样设计」的分析类文档区分）。Playasa 定位为 **Windows 桌面应用单体仓**：主入口、源码树、生成物、规格（spec）的职责边界写死在此，便于 onboarding、代码审查与 CI 对齐。跨平台目录或第二套解决方案路径不在范围内。

## 1. 背景与动机

### 1.1 为何需要成文约定

- **入口唯一**：避免出现根目录与 `src` 下并存的多个 `splayer.sln`，导致脚本、文档与 `$(SolutionDir)` 语义分裂。
- **路径可推理**：`SolutionDir` 落在 `src\` 后，历史上曾用 `$(SolutionDir)src\...` 表达「仓库里的 src」，会退化成 `src\src\`；必须在规范层禁止并给出替换式。
- **规格可发现**：`.spec` 作为「契约」锚点，与叙述性 `docs` 分离，减少「该读哪份」的歧义。

### 1.2 非动机（刻意不做）

- 不为 Linux/macOS 预留平行源码树或 CMake 主路径（若做，应新开 RFC 并废止/迁移本节相关句）。
- 不在本文内规定编码风格或第三方版本策略（见其他 RFC / 团队约定）。

## 2. 目标与非目标

### 2.1 目标

1. **可读**：新贡献者在 5 分钟内能从本 RFC 画出「打开什么、产物在哪、脚本在哪」。
2. **可验证**：通过简单 grep / 检查表即可在 PR 中发现破坏契约的 MSBuild 片段。
3. **可演进**：目录若调整，先改本 RFC 表格与不变量，再改工程与脚本。

### 2.2 非目标

- 不规定 Visual Studio 具体版本号（由 `docs/root-notes` 与工具链 RFC 跟进）。
- 不替代 `docs/rfc` 中已有历史 RFC 的正文；冲突时以 **§7** 优先级为准。

## 3. 规范：目录布局

### 3.1 逻辑视图（仓库根为顶点）

```text
<repo-root>/
├── .spec/rfc/          ← 架构 / 布局 / 工程契约 RFC（本文件所在）
├── docs/               ← 用户文档、历史 RFC、构建笔记、RFC 索引
├── script/             ← 从仓库根调用的辅助脚本（如 VS 安装引导）
├── src/
│   ├── splayer.sln     ← 唯一主解决方案（路径相对本目录为「src 下」）
│   ├── BuildScript/    ← 构建与诊断 cmd / ps1（假定 cwd 或路径可解析到本仓）
│   ├── Source/         ← 主工程与筛选器、应用源码
│   ├── Thirdparty/     ← 随仓第三方
│   ├── lib/            ← 预编译库等
│   ├── Test/           ← 测试工程
│   ├── Prototype/      ← 实验性工程
│   └── …
├── out/                ← 生成物根（默认不提交；见 §3.4）
└── LICENSE, README.md, …
```

### 3.2 路径职责表（规范性）

| 路径 | 必须 / 应当 | 职责 |
|------|----------------|------|
| `src\splayer.sln` | **必须** | 唯一主解决方案；CI、文档、交互式开发均以此为入口。 |
| `src\BuildScript\` | **应当** | 可重复执行的构建与检查脚本；避免在根目录堆积 `.cmd` 副本。 |
| `out\` | **应当** | 统一 `OutDir`/`IntDir` 根目录；与 `src` 同级，便于清理与 CI 缓存键。 |
| `docs\` | **应当** | 对外说明与历史 RFC；**不**承担「工程契约唯一源」角色。 |
| `.spec\rfc\` | **应当** | 布局与契约类 RFC；编号与 `docs/rfc` **共用**（见 §7）。 |
| `script\` | **可选** | 与编译弱耦合、但希望从根执行的脚本（路径须在 README 写清）。 |

### 3.3 典型工作流（规范性描述）

1. **打开工程**：在 Visual Studio 中打开 `src\splayer.sln`（或从 `src\BuildScript` 调用 MSBuild 并传入该 sln 的绝对/相对路径）。
2. **命令行构建**：在 `src\BuildScript` 下执行 `build-with-msbuild.cmd` 等；脚本内部应解析到 `..\splayer.sln`（相对 BuildScript 即 `src\splayer.sln`）。
3. **安装/环境**：优先使用 `script\` 下已有脚本；README 中的示例路径须与本表一致。

### 3.4 生成物与版本控制

- **`out\`**：默认视为**生成树**；是否纳入 `.gitignore` 由仓库策略决定，但**不得**要求贡献者手工把二进制当源码提交。
- **备份型 `*.vcxproj.backup*`**：不替代主工程文件；不应成为构建依赖。

### 3.5 生成物统一在 `out\` 下（约定表）

> **关于 `out` / release / lang / lib 的一句话**：可重复生成的只进 **`out\`**（`bin` / `obj` / `lib` 子树按现有 MSBuild 约定）。随仓二进制料在 **`src\lib\`**（与 `out` 分开）。多语言资源工程输出与其它项目一样进 **`out\bin\...`**；根下不要再搞一套 `lang\` 之类的散落目录（历史 `lang/` 用 `.gitignore` 兜住）。

所有 MSBuild 可重复生成物必须落在 **`$(SolutionDir)..\out\`** 为根的子树中，与「语言资源工程」「主程序」「筛选器」共用同一套 `OutDir`/`IntDir` 规则，避免在仓库根或 `src\` 下另起炉灶。

| `out\` 子路径 | 内容 |
|----------------|------|
| **`out\bin\<Platform>\<Configuration>\`** | 主/从 `.exe`、`.dll`、与配置同级的 `* lib\` 子目录（若工程已如此输出）等。 |
| **`out\obj\...`** | 各项目的中间文件（按项目名与配置分目录）。 |
| **`out\lib\<Platform>\`**（及工程引用的同级路径） | 静态库 `.lib` 等由 `common.props` / 各 `.vcxproj` 约定的输出。 |

**`src\lib\`**：预编译或第三方二进制**源料**（随仓但不等于本次编译输出），与 **`out\`** 分离；勿把「本次链接产生的 `.lib`」长期放在 `src\lib` 冒充源码。

**语言资源工程**（`res_*` 等）：输出仍遵循各项目 `OutDir`，即落在 **`out\bin\...`** 下，不在仓库根创建 `lang\` 等旁路目录（根目录 `lang/` 已在 `.gitignore` 中忽略历史遗留）。

### 3.6 仓库根禁止散落生成物

- **禁止**使用 `$(SolutionDir)..\foo.bin`（`foo` 不为 `out`）等形式向**仓库根**写入构建结果。典型反例：曾将 `splayer.rsc` 复制到根目录；已改为仅写入对应配置的 **`$(OutDir)splayer.rsc`**，与 `splayer_prototype.exe` 同目录，便于调试。
- 仓库根仅保留 **元数据与入口文档**（如 `LICENSE`、`README.md`、`ROADMAP.md`、`.gitignore`、`.spec\` 等），不作为「临时输出盘」。若本地曾误生成 **`lang\`**、**`lib\`**、**`Release\`** 等根级散落目录，可整目录删除；**`.gitignore`** 含 **`/lang/`** 等规则以降低误提交概率。

### 3.7 构建脚本：`script\` 与 `src\BuildScript\`（扫描结论与推荐）

**扫描范围**（2026-04）：本仓「自有」脚本主要为 **`script\`**（1 个）与 **`src\BuildScript\`**（约 30 个 `.ps1` + 若干 `.cmd` + `.patch` + 杂项）；`src\Thirdparty\` 与测试数据下的 `.bat/.sh` 属上游或夹具，**不参与**本节的目录约定。

#### 分层（推荐保持，不必强行物理子目录）

| 位置 | 角色 | 内容示例 |
|------|------|-----------|
| **`script\`** | **机台/bootstrap** | 安装或检测 Visual Studio 等；从仓库根执行；**不**假设已打开解决方案。 |
| **`src\BuildScript\`** | **解决方案周边** | 日常构建 `build-with-msbuild.cmd`、`build-fixed.cmd`；`pre-build.cmd` / `post-build.cmd` / `revision.cmd`（被工程引用，路径已写死为 `$(SolutionDir)BuildScript\...`，**勿随意改名或挪动目录**）。 |
| 同上 | **诊断 / CI 辅助** | `check-project-files.ps1`、`test-build.ps1`、`test-mplayerc-load.ps1`、`find-msbuild.ps1`、`detect-vs2025.ps1`、`detect-vs2026.ps1`。 |
| 同上 | **一次性维护 / 迁移** | `fix-output-directories-rfc0011.ps1`（输出路径对齐 RFC-0011）、`fix-*-paths.ps1`、`fix-all-issues.ps1`、`fix-solution-paths.ps1`、`upgrade-to-vs2025.ps1`、`restructure-project.ps1`、`build-and-fix.ps1` 等。 |

#### 最佳实践（结论）

1. **不要再在仓库根增加** `build*.cmd` / `*.ps1`（你已反感根污染）；入口统一 **`src\BuildScript`** + 文档链到 **`script\`**。
2. **物理子目录**（如 `BuildScript\run\`、`BuildScript\maint\`）能减轻认知负担，但会**破坏**现有 **`$(SolutionDir)BuildScript\pre-build.cmd`** 等硬编码；若要做，须同步改 `.vcxproj` 并开独立迁移任务。
3. **维护类脚本的工作目录**：部分脚本使用 `Get-ChildItem -Path "src"` 等写法，隐含 **当前目录为仓库根**；应在各脚本文件头用注释写清「从何处执行」，或统一改为基于 **`$PSScriptRoot`** 推导 `srcPath`，避免在 `cd src\BuildScript` 下误跑。
4. **输出目录维护脚本**：唯一入口为 **`src\BuildScript\fix-output-directories-rfc0011.ps1`**（与 **`src\Source\common.props`** 及本节 §4.3 逐字对齐）；自检：**`powershell -File src\BuildScript\fix-output-directories-rfc0011.ps1 -SelfTest`**（从仓库根执行）。历史上曾存在的 `fix-output-directories.ps1` / `fix-output-directories-root.ps1` / `fix-output-directories-vs-best-practice.ps1` 已**删除**（勿从旧文档或笔记中恢复运行）。
5. **`BUILD-FIXES-SUMMARY.md`**：已迁至 **`docs/root-notes/BUILD-FIXES-SUMMARY.md`**（与 BuildScript 解耦）。

## 4. 规范：MSBuild 路径契约

以下不变量在主解决方案保持于 `src\splayer.sln` 期间 **必须** 成立。

### 4.1 `$(SolutionDir)` 语义

- 解析为 **包含 `splayer.sln` 的目录**，带尾部反斜杠，即 `…\<repo>\src\`。

### 4.2 源码与包含路径

- 引用本仓库源码树时，使用 **`$(SolutionDir)Source\`**、**`$(SolutionDir)Thirdparty\`**、**`$(SolutionDir)lib\`**、**`$(SolutionDir)Test\`** 等前缀。
- **禁止**在 `.vcxproj` / `.props` 中使用 **`$(SolutionDir)src\`**（已废止模式：在 sln 已位于 `src` 时必然错误）。

### 4.3 输出与中间目录

- 写入仓库根 `out\` 时，使用 **`$(SolutionDir)..\out\`**（或等价规范化路径），以保证产物落在 **`out\`** 而非 `src\out\`（除非未来 RFC 明确迁移输出根并同步 CI）。

### 4.4 审查清单（PR 可选执行）

```bash
# 在仓库根执行；命中应视为回归，须修复或附 RFC 修订说明
rg '\$\(SolutionDir\)src\\' --glob '*.vcxproj' --glob '*.props'
```

例外：仅存在于**不参与当前 sln 的备份文件**中的命中，应在合并前删除或修正备份，避免误导检索。

### 4.5 根目录污染（补充审查）

```bash
# 禁止向仓库根直接丢生成物（路径中 ..\ 后紧跟文件名而非 out\）
rg '\$\(SolutionDir\)\.\.\\\\splayer\.rsc' --glob '*.vcxproj' --glob '*.vcproj'
```

命中即应删除或改为 **`$(OutDir)`** / **`$(SolutionDir)..\out\...`**。

## 5. `.spec/rfc` 与 `docs/rfc` 的关系

| 维度 | `docs/rfc` | `.spec/rfc` |
|------|------------|--------------|
| **主要用途** | 历史 RFC、长篇分析、迁移记录、与 `docs` 站内链接一致 | **契约**：目录、编号、MSBuild 不变量、决策摘要 |
| **读者** | 贡献者、发布说明读者 | 审阅者、架构变更、工具链维护者 |
| **编号** | RFC-0001 … 已占用 | **接续同一编号空间**（本文为 0011） |

**优先级**：若对「当前仓库该怎么放」的描述冲突，**以 `.spec/rfc` 最新已接受文本为准**；`docs/rfc` 中过时句应加「见 RFC-0011」或修订原文。

**下一编号**：**[RFC-0012：第三方与本仓内嵌库升级策略](./rfc-0012-thirdparty-library-upgrades.md)**（依赖版本与分阶段路线）。

## 6. 遗留与边界

- **`.vcproj`**：若仍存在于树中，不作为主构建契约的一部分；迁移或删除另开任务跟踪。
- **`src\out\`**：若存在历史生成目录，与 §4.3 的规范输出根不同；清理策略由维护者决定，但文档不应将二者混称「官方 out」。

## 7. 风险评估

| 风险 | 级别 | 缓解 |
|------|------|------|
| 双轨 RFC 造成重复维护 | 中 | 契约只写 `.spec`；`docs` 仅保留链接与历史分析 |
| 脚本仍假设根目录 `splayer.sln` | 中 | PR 审查执行 `rg` / 脚本路径检查；更新 `src\BuildScript` |
| 第三方 props 手写错误前缀 | 低 | §4.4 grep；关键 props 走 code review 模板 |

## 8. 成功指标

- README 或等效 onboarding 文档在显著位置链接 **本文**。
- 主分支上，参与构建的 `*.vcxproj` / 主路径 `*.props` 中 **`$(SolutionDir)src\`** 命中为 **零**（备份文件除外且已声明）。

## 9. 决策记录

| 日期 | 决策 | 理由 |
|------|------|------|
| 2026-04-18 | 主 `splayer.sln` 固定在 `src\` | 与源码树同锚点，减少根目录噪音；脚本已对齐 |
| 2026-04-18 | 产物根保持在仓库根 `out\` | 兼容既有 CI/习惯路径；通过 `$(SolutionDir)..\out\` 实现 |
| 2026-04-18 | 契约类 RFC 落在 `.spec/rfc` | 与叙述性文档分离，便于「点 spec」审阅 |
| 2026-04-19 | `splayer.rsc` 不再复制到仓库根 | 仅 `out\bin\...`（`$(OutDir)`），符合 §3.6 |
| 2026-04-19 | 删除历史 `fix-output-directories*.ps1`（非 rfc0011） | 仅保留与 `common.props` 一致的单一迁移脚本，避免误跑旧语义 |

## 10. 参考文献与索引

- [RFC-0002：编译环境与技术栈分析](./rfc-0002-build-environment-analysis.md)
- [RFC 模板](./rfc-template.md)（撰写新 RFC 时的章节结构参考）

## 11. 附录：术语

| 术语 | 含义 |
|------|------|
| **仓库根** | Git 工作区根目录（含 `src`、`docs`、`.spec` 等）。 |
| **契约** | 对工具与路径的规范性约束；违反即视为 bug 或须 RFC 修订。 |

---

**变更流程**：修改 §3、§4 任一表格或不变量前，先更新本 RFC 并获维护者认可，再提交工程与脚本变更。
