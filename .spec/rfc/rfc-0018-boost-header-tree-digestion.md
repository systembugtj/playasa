# RFC-0018：Boost 头文件树渐进消化策略

| 字段 | 内容 |
|------|------|
| **状态** | 提案 (Proposed) |
| **适用范围** | `src/Thirdparty/boost`、使用 Boost 头文件的 C++ 调用点、标准库替代路径 |
| **相关 RFC** | [RFC-0011](./completed/rfc-0011-windows-repository-layout.md)、[RFC-0012](./completed/rfc-0012-thirdparty-library-upgrades.md)、[RFC-0019](./rfc-0019-thirdparty-crt-mfc-linkage-contract.md) |
| **创建日期** | 2026-04-25 |
| **最后更新** | 2026-04-25 |

## 1. 摘要

Boost 是大体量头文件树，升级方式不能等同于 zlib、jsoncpp 这类边界清晰的小库。直接整树替换会引入大量模板编译差异、警告变化、标准库冲突和编译时间波动。

本 RFC 定义 Boost 的处理策略：不做一次性整树替换，先定位实际使用的 Boost 组件，再按调用点逐步迁移到 `std::` 或局部升级，必要时为仍需保留的组件钉住版本和 include 边界。

## 2. 当前问题

1. `src/Thirdparty/boost` 体量大，可能包含大量未使用头文件。
2. 头文件库升级会在使用点展开，风险分散在全仓。
3. 现代 C++ 标准库已覆盖部分旧 Boost 用法，例如 `shared_ptr`、`optional`、`filesystem`、`regex`、`bind` 等。
4. 在没有调用面清单前整树替换，不容易定位回归。

## 3. 目标

1. 统计仓库实际使用的 Boost 头文件和命名空间。
2. 将可替换用法迁移到标准库或本仓已有 helper。
3. 对不能替换的 Boost 组件建立保留清单。
4. 降低 include 面和编译警告。
5. 为未来升级或删除 Boost 子树提供依据。

## 4. 非目标

1. 不一次性删除 `src/Thirdparty/boost`。
2. 不一次性整树升级 Boost。
3. 不为未使用组件引入新依赖。
4. 不改变公开 ABI，除非调用点已有测试覆盖。

## 5. 实施检查清单

1. 搜索 `#include <boost/`、`#include "boost/` 和 `boost::`。
2. 生成 Boost 使用清单，按组件分类：smart_ptr、filesystem、regex、bind、thread、asio 等。
3. 标记可替换项：优先 `std::shared_ptr`、`std::unique_ptr`、`std::optional`、`std::filesystem`、lambda、`std::function`。
4. 标记不可替换项：需要保留原因、调用面、测试方式。
5. 每次只迁移一个组件或一个模块，避免大范围模板错误。
6. 对迁移点添加或扩展测试。
7. 每阶段运行相关单项目构建和 `./dev.ps1 build`。
8. 更新 `TASK_TRACKING.md` 记录已消化组件。

## 6. 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| 模板错误扩散 | 定位困难 | 每次只动一个组件 |
| ABI 改变 | 链接或运行时不兼容 | 不跨 DLL/库边界改公开类型 |
| C++ 标准版本不足 | 替代不可用 | 先确认工具链和 `/std` 设置 |
| 编译时间波动 | 开发体验下降 | 记录构建时间和 include 面 |

## 7. 成功标准

1. 有 Boost 使用清单。
2. 每个保留组件都有原因。
3. 至少一个 Boost 调用面成功迁移到标准库或本仓 helper。
4. `./dev.ps1 build` 通过。
5. 没有新增全局 include 路径污染。

## 8. 下一步

先建立 Boost 使用清单，不直接升级或删除 Boost 树。
