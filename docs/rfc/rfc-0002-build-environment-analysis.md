# RFC-0002: SPlayer 编译环境与技术栈分析

**状态**: 已接受 (Accepted)  
**作者**: 开发团队  
**创建日期**: 2024-12-19  
**最后更新**: 2024-12-19  
**相关 RFC**: [RFC-0001](./rfc-0001-modernization-proposal.md), [RFC-0003](./rfc-0003-implementation-plan.md)

## 摘要

本文档对 SPlayer 项目的编译环境和技术栈进行深入分析，识别当前存在的问题，并提出现代化改进建议。分析涵盖编译环境、代码质量、技术债务和现代化路线图。

## 1. 背景

### 1.1 当前配置

SPlayer 项目当前使用以下技术栈：

- **Visual Studio 版本**: 2013 (v120 toolset)
- **构建系统**: MSBuild / Visual Studio Solution
- **字符集**: Unicode / MultiByte (混合)
- **MFC**: 静态链接 (UseOfMfc=Static)
- **平台**: Win32 (32位)
- **C++ 标准**: 未明确指定，实际使用 C++98/03 特性

### 1.2 编译要求

**必需环境变量**:
- `VS120COMNTOOLS` (Visual Studio 2013 工具路径)

**必需依赖**:
- MFC 库 (静态链接)
- DirectShow SDK
- Windows SDK 7.1+
- 第三方库: Boost, OpenSSL, JSON-CPP, SQLite++, ZeroMQ 等

### 1.3 编译步骤

1. 运行 `src/BuildScript/build.cmd`
2. 脚本会先构建依赖项 (sphash, sinet)
3. 然后构建主项目 `splayer.sln`

## 2. 问题分析

### 2.1 编译环境问题

#### 问题 1: Visual Studio 2013 已停止支持
- **状态**: ❌ 严重问题
- **影响**: Visual Studio 2013 在 2019 年停止更新，无法获得安全补丁和新特性
- **风险**: 高 - 影响项目可维护性

#### 问题 2: 缺少依赖库
- **状态**: ❌ 严重问题
- **影响**: 需要先构建 `thirdparty/pkg` 和 `thirdparty/sinet`，但这些目录可能不存在
- **风险**: 高 - 无法编译项目

#### 问题 3: 仅支持 32 位架构
- **状态**: ⚠️ 中等问题
- **影响**: 仅支持 Win32，不支持 x64，无法充分利用现代硬件
- **风险**: 中 - 限制性能和内存使用

#### 问题 4: 旧版第三方库
- **状态**: ⚠️ 安全问题
- **影响**: OpenSSL 0.9.8x 已过时，存在已知安全漏洞
- **风险**: 高 - 安全风险

### 2.2 技术栈问题

#### 问题 1: 使用过时的 MFC

**当前代码示例**:
```cpp
// 当前代码大量使用 MFC
class CMainFrame : public CFrameWnd  // MFC 框架
CString str;  // MFC 字符串类
```

**影响**:
- MFC 是 1990 年代的框架，UI 设计过时
- 难以实现现代扁平化 UI
- 不支持高 DPI 缩放
- 维护成本高

**风险**: 中 - 影响用户体验和开发效率

#### 问题 2: 混合使用字符串类型

**当前代码示例**:
```cpp
CString mfcString;           // MFC
std::wstring stlString;      // STL
LPCTSTR rawString;           // 原始指针
```

**影响**:
- 类型转换频繁，容易出错
- 内存管理复杂
- 代码可读性差

**风险**: 中 - 增加 bug 风险

#### 问题 3: 缺少现代 C++ 特性

**缺失的特性**:
- ❌ 未使用 C++11/14/17 特性
- ❌ 没有 `auto`, `nullptr`, `override`, `final`
- ❌ 没有智能指针 (`std::unique_ptr`, `std::shared_ptr`)
- ❌ 没有范围 for 循环
- ❌ 没有 lambda 表达式

**影响**:
- 代码冗长，可读性差
- 内存管理容易出错
- 无法利用现代 C++ 的性能优化

**风险**: 中 - 影响代码质量和维护性

#### 问题 4: DirectShow 架构过时

**状态**: DirectShow 已被 Microsoft 弃用

**影响**:
- 无法获得官方支持
- 推荐使用 Media Foundation 或 FFmpeg

**风险**: 中 - 长期维护问题

## 3. 现代化改进建议

### 3.1 阶段 1: 编译环境升级 (短期)

**目标**: 使项目能在现代 Visual Studio 上编译

**具体步骤**:

1. **升级到 Visual Studio 2019/2022**
   ```xml
   <!-- 修改 .vcxproj 文件 -->
   <PlatformToolset>v142</PlatformToolset>  <!-- VS2019 -->
   <!-- 或 -->
   <PlatformToolset>v143</PlatformToolset>  <!-- VS2022 -->
   ```

2. **添加 x64 支持**
   - 创建 x64 平台配置
   - 更新所有项目文件

3. **更新第三方库**
   - OpenSSL: 0.9.8x → 3.x
   - Boost: 更新到最新版本
   - 其他库: 检查并更新

4. **修复编译警告**
   - 启用 `/W4` 警告级别
   - 修复所有警告

**预期工作量**: 40-80 小时  
**优先级**: P0 (必须)

### 3.2 阶段 2: 代码现代化 (中期)

**目标**: 逐步引入现代 C++ 特性

**具体步骤**:

1. **统一字符串类型**
   ```cpp
   // 建议统一使用 std::wstring
   // 替换所有 CString 为 std::wstring
   // 使用 std::wstring_view 作为参数
   ```

2. **引入智能指针**
   ```cpp
   // 替换原始指针
   std::unique_ptr<CGraphCore> m_graphCore;
   std::shared_ptr<CPlayer> m_player;
   ```

3. **使用现代 C++ 特性**
   ```cpp
   // 使用 auto
   auto iter = vec.begin();
   
   // 使用 nullptr
   if (ptr != nullptr) { }
   
   // 使用 override
   virtual void OnPlay() override;
   
   // 使用范围 for
   for (const auto& item : container) { }
   ```

4. **改进错误处理**
   ```cpp
   // 使用 std::optional
   std::optional<std::wstring> GetFileName();
   
   // 使用异常处理替代错误码
   try {
       LoadMedia(file);
   } catch (const MediaException& e) {
       // 处理错误
   }
   ```

**预期工作量**: 160-320 小时  
**优先级**: P2 (建议)

### 3.3 阶段 3: UI 现代化 (长期)

**目标**: 实现现代 UI 设计

**选项 A: 保留 MFC，改进 UI**
- 使用现代控件库 (如 BCGSoft)
- 自定义绘制实现扁平化设计
- 添加高 DPI 支持

**选项 B: 迁移到现代框架 (推荐)**
- **Qt**: 跨平台，现代 UI，丰富的媒体支持
- **WinUI 3**: 原生 Windows 现代 UI
- **Electron + C++**: Web 技术 + 原生性能

**推荐方案: Qt 迁移**
```cpp
// Qt 示例
class MainWindow : public QMainWindow {
    Q_OBJECT
public:
    MainWindow(QWidget *parent = nullptr);
    
private:
    QMediaPlayer* m_player;
    QVideoWidget* m_videoWidget;
};
```

**优势**:
- ✅ 跨平台支持
- ✅ 现代 UI 框架
- ✅ 内置媒体播放支持
- ✅ 活跃的社区和文档
- ✅ 高 DPI 自动支持

**预期工作量**: 800-1600 小时  
**优先级**: P3 (可选)

### 3.4 阶段 4: 架构重构 (长期)

**目标**: 改进整体架构

**具体步骤**:

1. **分离关注点**
   ```
   当前: 所有逻辑在 CMainFrame
   建议: 
   - Model (数据层)
   - View (UI层)  
   - Controller (控制层)
   ```

2. **使用现代媒体框架**
   - 考虑 FFmpeg 替代 DirectShow
   - 或使用 Qt Multimedia
   - 或使用 Media Foundation

3. **模块化设计**
   - 将功能拆分为独立模块
   - 使用插件架构

**预期工作量**: 600-1200 小时  
**优先级**: P3 (可选)

## 4. 现代化路线图

### 4.1 短期 (1-3 个月)
- [ ] 升级到 Visual Studio 2019/2022
- [ ] 添加 x64 支持
- [ ] 更新关键第三方库
- [ ] 修复编译警告和错误
- [ ] 添加 CI/CD 支持

### 4.2 中期 (3-6 个月)
- [ ] 统一字符串类型 (CString → std::wstring)
- [ ] 引入智能指针
- [ ] 添加现代 C++ 特性
- [ ] 改进错误处理
- [ ] 代码重构和清理

### 4.3 长期 (6-12 个月)
- [ ] 评估 UI 框架迁移 (Qt/WinUI3)
- [ ] 架构重构
- [ ] 媒体框架现代化
- [ ] 性能优化
- [ ] 添加单元测试

## 5. 风险评估

### 5.1 高风险

- ⚠️ **UI 框架迁移**: 需要重写大量 UI 代码
- ⚠️ **DirectShow 替换**: 核心功能，影响大
- ⚠️ **第三方库更新**: 可能引入不兼容问题

### 5.2 中风险

- ⚠️ **字符串类型统一**: 工作量大，但风险可控
- ⚠️ **编译环境升级**: 可能遇到兼容性问题

### 5.3 低风险

- ✅ **现代 C++ 特性引入**: 逐步进行，风险低
- ✅ **代码重构**: 可以分模块进行

## 6. 建议

### 6.1 立即可做

1. **创建现代化分支**: 在 Git 中创建新分支进行现代化工作
2. **升级编译环境**: 先确保能在 VS2019/2022 编译
3. **添加 CI/CD**: 使用 GitHub Actions 或 Azure DevOps 自动化构建
4. **代码分析**: 使用静态分析工具 (如 PVS-Studio, Clang-Tidy)

### 6.2 谨慎考虑

1. **UI 框架迁移**: 需要评估投入产出比
2. **架构重构**: 建议分阶段进行，避免大爆炸式重构

### 6.3 优先级排序

1. **P0 (必须)**: 编译环境升级，修复编译错误
2. **P1 (重要)**: 更新安全相关的第三方库 (OpenSSL)
3. **P2 (建议)**: 代码现代化，引入现代 C++ 特性
4. **P3 (可选)**: UI 框架迁移，架构重构

## 7. 总结

**当前状态**: 
- ✅ 项目结构完整，功能丰富
- ⚠️ 使用过时的技术栈
- ❌ 编译环境需要升级

**现代化潜力**: 
- 高 - 项目有良好的模块化结构
- 可以逐步现代化，不需要一次性重写

**建议**: 
- 从编译环境升级开始
- 逐步引入现代 C++ 特性
- 评估 UI 框架迁移的可行性
- 保持向后兼容，避免破坏性更改

## 8. 参考文献

- [RFC-0001: SPlayer 现代化提案](./rfc-0001-modernization-proposal.md)
- [RFC-0003: 现代化实施计划](./rfc-0003-implementation-plan.md)
- [Visual Studio 工具集版本](https://docs.microsoft.com/en-us/cpp/build/reference/toolset-version)
- [C++ 核心指南](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines)

---

**下一步行动**:
1. 评审本 RFC
2. 开始阶段 1 实施（编译环境升级）
3. 参考 [RFC-0003](./rfc-0003-implementation-plan.md) 获取详细实施计划
