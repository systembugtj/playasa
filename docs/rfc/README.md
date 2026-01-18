# RFC 文档目录

本目录包含 SPlayer 项目的 Request for Comments (RFC) 文档。

## 什么是 RFC？

RFC (Request for Comments) 是一种用于记录技术提案、设计决策和标准化文档的格式。在 SPlayer 项目中，RFC 用于：

- 记录重要的技术决策
- 提出新的功能或改进
- 标准化开发流程
- 记录架构变更

## RFC 列表

### 已发布

- [RFC-0001: SPlayer 现代化提案](./rfc-0001-modernization-proposal.md) - 项目现代化总体提案
- [RFC-0002: 编译环境与技术栈分析](./rfc-0002-build-environment-analysis.md) - 编译环境和技术栈的详细分析
- [RFC-0003: 现代化实施计划](./rfc-0003-implementation-plan.md) - 具体的现代化实施计划和步骤
- [RFC-0004: 构建错误修复 - BaseClasses 路径问题](./rfc-0004-build-errors-fix.md) - 修复 BaseClasses 头文件路径问题
- [RFC-0005: mplayerc 项目路径修复](./rfc-0005-mplayerc-project-fix.md) - 修复 mplayerc 主项目路径问题
- [RFC-0006: 输出目录统一化](./rfc-0006-output-directory-consolidation.md) - 统一所有项目的输出目录路径
- [RFC-0007: 构建警告和错误修复](./rfc-0007-build-warnings-fix.md) - 修复构建警告和错误
- [RFC-0008: 编译错误修复](./rfc-0008-compilation-errors-fix.md) - 修复编译错误（第一阶段）
- [RFC-0009: 编译错误修复 - 第二阶段](./rfc-0009-compilation-errors-fix-phase2.md) - 修复 DirectX 7、入口点、PTRDIFF_MAX 等错误
- [RFC-0010: 全面修复所有编译问题](./rfc-0010-all-issues-fix.md) - 全面修复库依赖、字符类型、未解析符号等问题

### 草案中

- RFC-0006: UI 框架选择详细分析（待创建）
- RFC-0007: 媒体框架迁移方案（待创建）

## RFC 流程

### 1. 提案 (Proposed)
- RFC 被创建并提交评审
- 开放讨论和反馈

### 2. 评审中 (Under Review)
- 团队评审 RFC
- 收集反馈和建议

### 3. 已接受 (Accepted)
- RFC 被接受，开始实施
- 更新项目状态

### 4. 已实施 (Implemented)
- RFC 中的提案已完全实施
- 可以标记为已完成

### 5. 已拒绝 (Rejected)
- RFC 被拒绝，不进行实施
- 记录拒绝原因

### 6. 已废弃 (Deprecated)
- RFC 中的提案已被更好的方案替代
- 保留作为历史记录

## 如何创建 RFC

1. 复制模板文件 `rfc-template.md`（如果存在）
2. 创建新文件 `rfc-XXXX-title.md`，其中 XXXX 是下一个可用编号
3. 填写 RFC 内容
4. 提交 Pull Request
5. 等待评审和讨论

## RFC 编号规则

- RFC 编号从 0001 开始
- 按顺序递增
- 编号一旦分配，不再重用
- 即使 RFC 被拒绝，编号也保留

## 贡献指南

欢迎提交新的 RFC 提案。请确保：

1. 遵循 RFC 模板格式
2. 提供充分的背景和理由
3. 考虑替代方案
4. 评估风险和影响
5. 提供实施计划

## 相关链接

- [项目主 README](../../README.md)
- [现代化实施计划](../../现代化实施计划.md)
