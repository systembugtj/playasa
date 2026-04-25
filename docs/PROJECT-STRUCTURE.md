# 项目结构说明

本页合并旧的项目结构分析和结构建议。规范性来源仍是 RFC-0011；这里用于快速阅读和 onboarding。

## 当前布局

```text
playasa/
├── .spec/          # 工程契约类 RFC
├── docs/           # 用户文档、历史 RFC 索引和说明
├── out/            # 构建输出根目录，默认不提交
├── script/         # 从仓库根执行的安装 / bootstrap 脚本
├── src/            # 源码、解决方案、第三方库和构建脚本
├── README.md
├── ROADMAP.md
└── TASK_TRACKING.md
```

```text
src/
├── splayer.sln     # 唯一主解决方案
├── BuildScript/    # 日常构建、诊断、验证脚本
├── Source/         # 主程序、过滤器、UI 和共享源码
├── Thirdparty/     # 随仓第三方源码或头文件
├── lib/            # 随仓预编译库源料
├── Test/           # 测试工程
└── Prototype/      # 原型工程
```

## 关键约定

1. 主解决方案固定为 `src\splayer.sln`。
2. `$(SolutionDir)` 解析为 `src\`，因此工程中不要写 `$(SolutionDir)src\...`。
3. 可重复生成物落在仓库根 `out\`，不要落在根目录 `Release\`、`lang\`、`lib\`。
4. 构建脚本入口在 `src\BuildScript`；根目录只保留弱耦合 bootstrap 脚本。
5. `.spec\rfc` 记录工程契约；`docs` 只放使用说明和叙述性文档。

## 为什么不继续拆目录

旧文档曾讨论把 `Source`、`Thirdparty`、`lib`、`BuildScript` 移到仓库根。现阶段不建议这样做，因为会带来大量 `.vcxproj` 路径改写，并增加 `$(SolutionDir)` 语义分裂风险。保持 `src\` 为 Visual Studio 解决方案根，更符合当前脚本和工程文件状态。

## 允许的渐进改进

- 为 `src\BuildScript` 中的维护脚本补充运行目录说明。
- 新脚本优先使用 `$PSScriptRoot` 推导路径。
- 新增生成物必须写入 `out\` 或现有项目输出目录。
- 第三方升级先写 RFC，再改工程和验证脚本。

## 参考

- [RFC-0011: Windows-only 仓库目录与构建布局约定](../.spec/rfc/completed/rfc-0011-windows-repository-layout.md)
- [BUILD.md](BUILD.md)
- [INSTALL.md](INSTALL.md)
