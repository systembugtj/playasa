# RFC-0015：恢复 Updater curl 下载实现并迁移到 Schannel

| 字段 | 内容 |
|------|------|
| **状态** | 提案 (Proposed) |
| **适用范围** | `src/Updater`、curl/libcurl 依赖、RFC-0012 P5 后续网络下载恢复 |
| **相关 RFC** | [RFC-0012](./completed/rfc-0012-thirdparty-library-upgrades.md)、[RFC-0011](./completed/rfc-0011-windows-repository-layout.md) |
| **创建日期** | 2026-04-25 |
| **最后更新** | 2026-04-25 |

## 1. 摘要

RFC-0012 P5 已删除 `src/Thirdparty/openssl-0.9.8x`，并从活跃 `.vcxproj` 移除 `libeay32.lib` / `ssleay32.lib`。同时审计发现 `Updater` 仍保留旧 `CURL_STATICLIB` 宏和缺失的 `curllibd.lib` 链接痕迹，但当前源码没有活跃 `curl_easy_*` / `CURLOPT_*` 调用，`cupdatenetlib.cpp` 中的下载实现已基本空置或注释。

本 RFC 定义恢复 `Updater` 下载能力的正确路径：保留 curl 作为 HTTP(S) 客户端，但必须引入 **Schannel 后端**的 libcurl，禁止回退到 OpenSSL 0.9.8x 或任何 `libeay32` / `ssleay32` 链接。

## 2. 背景

### 2.1 当前状态

`Updater` 的更新流程入口仍存在：`cupdatenetlib::procUpdate()` 调用 `downloadList()` 与 `downloadFiles()`，并继续维护更新目录、文件数组、进度字段和补丁应用路径。但 `downloadList()` 当前不会实际发起网络请求，`cupdatenetlib.h` 中的 curl 回调与 `PostUsingCurl()` 声明也已注释。

RFC-0012 P5 的结论是：

1. `src/Thirdparty/openssl-0.9.8x` 已删除。
2. 活跃 `.vcxproj` 不允许再链接 `libeay32.lib` / `ssleay32.lib`。
3. 旧 `curllibd.lib` 在仓库中缺失，且当前源码没有活跃 curl 调用，因此不能继续作为假依赖保留。
4. `Updater` Debug 保留了 Schannel 方向系统库：`Crypt32.lib`、`Secur32.lib`、`Wldap32.lib`、`Normaliz.lib`、`Ws2_32.lib`。

### 2.2 问题陈述

现在的风险不是“curl 是否该保留”，而是“如何恢复真实可验证的下载能力”。直接把旧 `curllibd.lib` 链接加回来不可接受，因为该库不存在，也无法证明 TLS 后端不是 OpenSSL。直接引入 OpenSSL 3.x 也不是首选，因为本项目是 Windows 桌面/Updater 场景，系统 TLS 已能覆盖下载需求，并能减少证书、DLL 分发和 ABI 维护成本。

## 3. 目标

### 3.1 主要目标

1. 恢复 `Updater` 的 HTTP(S) 下载能力，包括更新清单下载和更新文件下载。
2. libcurl 必须使用 Windows Schannel TLS 后端。
3. 构建产物不得依赖 OpenSSL DLL，不得链接 `libeay32.lib` / `ssleay32.lib`。
4. `Updater` 的 Debug、Debug Unicode、Release 配置必须使用可追踪的 libcurl 依赖路径。
5. 下载实现必须有超时、错误码、文件长度/进度、临时文件写入和 MD5 校验路径。
6. RFC-0012 P5 门闩必须扩展为能防止 OpenSSL 或旧缺失 curl 库回归。

### 3.2 非目标

1. 不恢复 OpenSSL 0.9.8x。
2. 不引入 OpenSSL 3.x，除非后续单独 RFC 推翻本决策。
3. 不把 updater 网络层迁到 WinHTTP / WinINet，除非 libcurl Schannel 路线被验证不可行。
4. 不在本 RFC 中重写整个更新协议或补丁格式。
5. 不把 curl 依赖放到仓库根散落目录；必须遵守 RFC-0011 的路径契约。

## 4. 方案

### 4.1 推荐方案：libcurl + Schannel

技术原理：libcurl 的 TLS 后端可选择 Schannel。Schannel 使用 Windows 系统证书库和系统 TLS 实现，适合 Windows updater 场景。项目继续使用 curl 的 URL、HTTP、重定向、代理、进度和错误处理能力，但不再维护 OpenSSL。

实施步骤：

1. 获取或构建 Win32 静态 libcurl，TLS backend 为 Schannel。
2. 将依赖放入明确位置，例如 `src/Thirdparty/curl/`（源码/头/构建说明）和/或 `src/lib/Win32/<config>/`（预编译库）。
3. 新增 `src/Thirdparty/curl/rfc0015-expected.txt`，记录 curl 版本、TLS backend、CRT、架构和库名。
4. 更新 `Updater.vcxproj` 的 include/lib 路径和 `AdditionalDependencies`，使用 Schannel 后端 libcurl 与系统库。
5. 恢复 `cupdatenetlib` 中清单下载与文件下载实现。
6. 增加 `verify-rfc0015-curl-schannel.ps1`，校验版本、路径、工程链接和 OpenSSL 禁用项。
7. 接入 `verify-rfc0012-all.ps1` 或新建 RFC-0015 专用总门闩后再接入 `dev.ps1 build`。

风险分析：需要确认 libcurl 构建产物与本仓 CRT、Win32、Unicode 配置一致；静态 libcurl 可能还需要 `Bcrypt.lib`、`Advapi32.lib` 等依赖，必须以实际 `curl -V` / `curl_version_info` 或构建配置为准。

### 4.2 替代方案：WinHTTP / WinINet 重写

技术原理：直接使用 Windows 原生 HTTP API，不依赖 curl。

优点是依赖更少，TLS 必然走系统；缺点是需要重写下载、回调、代理、重定向、错误处理和测试。除非 libcurl Schannel 难以稳定接入，否则不推荐作为首选。

## 5. 实施检查清单

1. 审计 `cupdatenetlib.cpp` 中 `downloadList()`、`downloadFiles()`、`downloadFileByID()` 的现有流程和数据结构，记录需要恢复的输入输出契约。
2. 决定 libcurl 来源：源码内嵌构建或预编译静态库；记录版本和构建参数。
3. 确认 libcurl 为 Win32、静态 CRT 配置，并使用 Schannel 后端。
4. 将 curl 头文件和库放入 RFC-0011 允许的位置。
5. 新增 `src/Thirdparty/curl/rfc0015-expected.txt`，至少包含 `CURL_VERSION`、`TLS_BACKEND=Schannel`、`ARCH=Win32`、`LINKAGE=static`。
6. 更新 `Updater.vcxproj`，移除旧 `CURL_STATICLIB` 的无效配置，只保留与真实 libcurl 匹配的宏、include、lib 和系统库。
7. 恢复 `downloadList()`：POST 当前版本和 branch，下载更新清单到临时文件，解析为 `m_UpdateFileArray`。
8. 恢复 `downloadFileByID()`：下载单个文件到临时路径，支持进度、超时、失败重试和 MD5 校验。
9. 恢复 `downloadFiles()`：按更新清单批量下载，并维护 `bReadyToCopy`、总字节数和已下载字节数。
10. 新增最小自动化验证：至少覆盖无网络情况下的错误返回、临时文件路径、MD5 不匹配处理；如可行，增加本地 HTTP server 下载 fixture。
11. 新增 `src/BuildScript/verify-rfc0015-curl-schannel.ps1`，禁止 `libeay32` / `ssleay32` / `openssl-0.9.8x` 回归，验证 curl 版本与 Schannel 后端记录。
12. 运行 `verify-rfc0015-curl-schannel.ps1`、`verify-rfc0012-all.ps1`、`MSBuild src/Updater/Updater.vcxproj` 相关配置和 `./dev.ps1 build`。

## 6. 验证标准

必须满足：

1. `rg -i "libeay32|ssleay32|openssl-0.9.8x" src --glob "*.vcxproj"` 无命中。
2. `verify-rfc0015-curl-schannel.ps1` 通过。
3. `verify-rfc0012-all.ps1` 通过。
4. `Updater.vcxproj` 至少 `Release|Win32` 构建通过；若恢复 Debug 配置，Debug 也必须不依赖缺失库。
5. `./dev.ps1 build` 通过并产出 `out\bin\Win32\Release Unicode\splayer.exe`。
6. 手测或自动化覆盖 updater 下载失败路径和成功下载路径。

## 7. 风险与缓解

### 7.1 高风险

libcurl 二进制与本仓 CRT/工具链不一致会导致链接错误或运行时崩溃。缓解方式是优先源码构建或记录完整预编译来源，并用 `dumpbin` / MSBuild 实测验证。

### 7.2 中风险

更新服务端协议可能已经失效，导致下载实现恢复后仍无法完成真实更新。缓解方式是先用本地 HTTP fixture 验证客户端行为，再做真实服务端手测。

### 7.3 低风险

Schannel 证书策略与旧 OpenSSL 行为不同。Updater 下载应优先使用系统证书验证，不应默认关闭证书校验。

## 8. 决策记录

| 日期 | 决策 | 理由 |
|------|------|------|
| 2026-04-25 | 恢复下载时使用 libcurl + Schannel | 保留 curl 能力，去掉 OpenSSL 维护和分发成本 |
| 2026-04-25 | 禁止恢复 `curllibd.lib` 假依赖 | 仓库缺失该库，且无法证明 TLS 后端安全 |
| 2026-04-25 | 不恢复 OpenSSL 0.9.8x | RFC-0012 P5 已删除该树，安全风险过高 |

## 9. 参考

- RFC-0012：第三方与本仓内嵌库升级策略。
- RFC-0011：Windows 仓库布局与输出目录契约。
- libcurl TLS backend 文档：Schannel 是 Windows 原生 TLS 后端。

## 10. 下一步行动

1. 选择 libcurl 来源和版本。
2. 生成或引入 Win32 Schannel 静态 libcurl。
3. 实现 `verify-rfc0015-curl-schannel.ps1`。
4. 恢复 `cupdatenetlib` 下载实现并添加验证。
