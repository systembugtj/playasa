# RFC-0003: SPlayer 现代化实施计划

**状态**: 已接受 (Accepted)  
**作者**: 开发团队  
**创建日期**: 2024-12-19  
**最后更新**: 2024-12-19  
**相关 RFC**: [RFC-0001](./rfc-0001-modernization-proposal.md), [RFC-0002](./rfc-0002-build-environment-analysis.md)

## 摘要

本文档提供 SPlayer 项目现代化的详细实施计划，包括编译验证、分阶段改进方案、具体实施步骤、风险评估和成功指标。本计划采用渐进式现代化策略，确保项目在现代化过程中保持稳定和可维护。

## 1. 背景

本实施计划基于 [RFC-0001](./rfc-0001-modernization-proposal.md) 和 [RFC-0002](./rfc-0002-build-environment-analysis.md) 的分析结果，提供具体的执行步骤和时间表。

## 2. 编译验证

### 2.1 当前编译状态检查清单

#### 必需环境
- [ ] Visual Studio 2013 或更高版本已安装
- [ ] Windows SDK 7.1+ 已安装
- [ ] DirectShow SDK 已安装
- [ ] MFC 库可用

#### 必需依赖库
- [ ] `thirdparty/pkg/trunk/sphash` - 需要先编译
- [ ] `thirdparty/sinet/trunk/sinet` - 需要先编译
- [ ] `thirdparty/pkg/trunk/unrar` - 需要提供

#### 编译步骤
```batch
1. 设置环境变量 VS120COMNTOOLS (VS2013) 或 VS160COMNTOOLS (VS2019)
2. 运行 src/BuildScript/build.cmd
3. 等待依赖库编译完成
4. 选择是否编译主项目
```

### 2.2 快速编译测试

**测试命令**:
```batch
cd src/BuildScript
build.cmd
```

**预期问题**:
1. ❌ 缺少 `thirdparty/pkg` 和 `thirdparty/sinet` 目录
2. ❌ Visual Studio 2013 可能未安装
3. ⚠️ 某些第三方库路径可能不正确

## 3. 现代化改进方案

### 3.1 方案 A: 渐进式现代化 (推荐)

**优点**: 风险低，可以逐步进行  
**缺点**: 时间较长

#### 阶段 1: 编译环境升级 (1-2周)

**目标**: 让项目在现代 Visual Studio 上编译

**步骤**:

1. **升级 Visual Studio 工具集**
   ```xml
   <!-- 修改所有 .vcxproj 文件 -->
   <!-- 从 -->
   <PlatformToolset>v120</PlatformToolset>
   <!-- 改为 -->
   <PlatformToolset>v142</PlatformToolset>  <!-- VS2019 -->
   <!-- 或 -->
   <PlatformToolset>v143</PlatformToolset>  <!-- VS2022 -->
   ```

2. **更新 Windows SDK 版本**
   ```xml
   <!-- common.props -->
   <PreprocessorDefinitions>
     WINVER=0x0A00;           <!-- Windows 10 -->
     _WIN32_WINNT=0x0A00;      <!-- Windows 10 -->
     NTDDI_VERSION=NTDDI_WIN10_RS1;
   </PreprocessorDefinitions>
   ```

3. **添加 x64 平台支持**
   - 在 Visual Studio 中为每个项目添加 x64 配置
   - 或手动复制 Win32 配置并修改平台

4. **修复编译错误**
   - 更新过时的 API
   - 修复类型转换问题
   - 处理新的编译器警告

**预期工作量**: 40-80 小时  
**优先级**: P0

#### 阶段 2: 代码现代化 (1-2个月)

**目标**: 引入现代 C++ 特性，提高代码质量

**步骤**:

1. **统一字符串类型**
   ```cpp
   // 创建迁移计划
   // 阶段 2.1: 新代码使用 std::wstring
   // 阶段 2.2: 逐步替换 CString
   // 阶段 2.3: 移除所有 CString 使用
   
   // 示例替换
   // 旧代码:
   CString GetFileName() { return m_fileName; }
   
   // 新代码:
   std::wstring GetFileName() const { return m_fileName; }
   ```

2. **引入智能指针**
   ```cpp
   // 替换原始指针
   // 旧代码:
   CGraphCore* m_pGraphCore;
   delete m_pGraphCore;
   
   // 新代码:
   std::unique_ptr<CGraphCore> m_pGraphCore;
   // 自动管理内存
   ```

3. **使用现代 C++ 特性**
   ```cpp
   // auto 类型推导
   auto iter = m_list.begin();
   
   // 范围 for 循环
   for (const auto& item : m_items) {
       ProcessItem(item);
   }
   
   // nullptr 替代 NULL
   if (ptr != nullptr) { }
   
   // override 关键字
   virtual void OnPlay() override;
   
   // final 关键字
   class CFinalClass final { };
   ```

4. **改进错误处理**
   ```cpp
   // 使用 std::optional
   std::optional<std::wstring> TryGetFileName();
   
   // 使用 std::expected (C++23) 或自定义 Result 类型
   Result<std::wstring> LoadMedia(const std::wstring& path);
   ```

**预期工作量**: 160-320 小时  
**优先级**: P2

#### 阶段 3: UI 现代化 (3-6个月)

**选项 3A: MFC 改进 (保守)**

**步骤**:
1. 使用现代控件库 (BCGSoft, Codejock)
2. 自定义绘制实现扁平化设计
3. 添加高 DPI 支持
4. 改进主题系统

**优点**: 改动小，风险低  
**缺点**: 仍然受限于 MFC

**预期工作量**: 240-480 小时  
**优先级**: P3

**选项 3B: Qt 迁移 (激进)**

**步骤**:
1. 创建新的 Qt 项目结构
2. 逐步迁移 UI 组件
3. 使用 Qt Multimedia 替代 DirectShow
4. 实现现代 Material Design 或 Fluent Design

**优点**: 
- 现代 UI 框架
- 跨平台支持
- 活跃的社区
- 内置媒体支持

**缺点**: 
- 工作量大
- 需要学习 Qt
- 可能丢失某些 DirectShow 特性

**预期工作量**: 800-1600 小时  
**优先级**: P3

**选项 3C: WinUI 3 (Windows 专用)**

**步骤**:
1. 创建 WinUI 3 项目
2. 使用 XAML 设计 UI
3. 使用 Media Foundation 或 FFmpeg
4. 实现 Fluent Design

**优点**: 
- 原生 Windows 现代 UI
- 性能好
- Microsoft 官方支持

**缺点**: 
- 仅 Windows 10/11
- 学习曲线陡峭
- 工作量大

**预期工作量**: 600-1200 小时  
**优先级**: P3

### 3.2 方案 B: 重构现代化 (激进)

**优点**: 可以完全现代化  
**缺点**: 风险高，工作量大

**建议**: 仅在新功能模块中采用，逐步替换旧代码

## 4. 具体实施建议

### 4.1 立即开始 (本周)

1. **创建现代化分支**
   ```bash
   git checkout -b modernization
   ```

2. **升级编译环境**
   - 安装 Visual Studio 2019/2022
   - 尝试编译项目
   - 记录所有编译错误

3. **设置 CI/CD**
   - 使用 GitHub Actions 或 Azure DevOps
   - 自动化构建和测试

4. **代码分析**
   - 运行静态分析工具
   - 识别技术债务

### 4.2 短期目标 (1-3个月)

1. **编译环境完全升级**
   - 所有项目能在 VS2019/2022 编译
   - 支持 x64 平台
   - 修复所有编译警告

2. **更新关键依赖**
   - OpenSSL 更新到 3.x
   - 其他安全相关的库更新

3. **代码质量改进**
   - 统一代码风格
   - 添加代码注释
   - 改进错误处理

### 4.3 中期目标 (3-6个月)

1. **代码现代化**
   - 引入现代 C++ 特性
   - 统一字符串类型
   - 使用智能指针

2. **架构改进**
   - 分离关注点
   - 模块化设计
   - 改进错误处理

### 4.4 长期目标 (6-12个月)

1. **UI 现代化**
   - 评估并选择 UI 框架
   - 逐步迁移或重写 UI
   - 实现现代设计

2. **媒体框架现代化**
   - 评估 FFmpeg/Media Foundation/Qt Multimedia
   - 逐步迁移

## 5. 风险评估与缓解

### 5.1 高风险项

1. **UI 框架迁移**
   - **风险**: 工作量大，可能引入 bug
   - **缓解**: 分阶段进行，保留旧版本作为备份

2. **DirectShow 替换**
   - **风险**: 核心功能，影响大
   - **缓解**: 先在新功能中试用新框架，逐步迁移

3. **第三方库更新**
   - **风险**: 可能不兼容
   - **缓解**: 充分测试，保留旧版本作为回退

### 5.2 中风险项

1. **编译环境升级**
   - **风险**: 可能遇到兼容性问题
   - **缓解**: 在独立分支进行，充分测试

2. **字符串类型统一**
   - **风险**: 工作量大，可能引入 bug
   - **缓解**: 逐步进行，充分测试

### 5.3 低风险项

1. **现代 C++ 特性引入**
   - **风险**: 低
   - **缓解**: 可以逐步进行

## 6. 成功指标

### 6.1 编译指标
- ✅ 能在 Visual Studio 2019/2022 成功编译
- ✅ 支持 x64 平台
- ✅ 无编译警告
- ✅ CI/CD 构建通过

### 6.2 代码质量指标
- ✅ 代码覆盖率 > 70%
- ✅ 静态分析无严重问题
- ✅ 代码审查通过率 > 90%

### 6.3 性能指标
- ✅ 启动时间 < 2 秒
- ✅ 内存使用减少 20%
- ✅ 播放性能不下降

### 6.4 UI 指标
- ✅ 支持高 DPI
- ✅ 现代 UI 设计
- ✅ 用户满意度提升

## 7. 资源需求

### 7.1 人力
- **开发人员**: 2-3 人
- **测试人员**: 1 人
- **UI/UX 设计师**: 1 人 (UI 迁移时)

### 7.2 时间
- **编译环境升级**: 1-2 周
- **代码现代化**: 1-2 个月
- **UI 现代化**: 3-6 个月
- **总计**: 6-9 个月

### 7.3 工具
- Visual Studio 2019/2022 (必需)
- Qt Creator (如果选择 Qt)
- 静态分析工具 (推荐)
- 性能分析工具 (推荐)

## 8. 时间表

| 阶段 | 时间 | 优先级 | 状态 |
|------|------|--------|------|
| 阶段 1: 编译环境升级 | 1-2 周 | P0 | 待开始 |
| 阶段 2: 代码现代化 | 1-2 个月 | P2 | 待开始 |
| 阶段 3: UI 现代化 | 3-6 个月 | P3 | 待开始 |
| 阶段 4: 架构重构 | 6-12 个月 | P3 | 待开始 |

## 9. 里程碑

1. **M1**: 编译环境升级完成，项目可在 VS2019/2022 编译
2. **M2**: 代码现代化完成，引入现代 C++ 特性
3. **M3**: UI 框架选择确定，开始迁移
4. **M4**: UI 现代化完成，新 UI 发布
5. **M5**: 架构重构完成，模块化设计实现

## 10. 总结

**推荐方案**: 渐进式现代化 (方案 A)

**理由**:
1. 风险可控
2. 可以逐步验证
3. 不影响现有功能
4. 可以随时调整方向

**优先级**:
1. **P0**: 编译环境升级，确保项目可维护
2. **P1**: 更新安全相关的第三方库
3. **P2**: 代码现代化，提高代码质量
4. **P3**: UI 现代化，提升用户体验

**下一步行动**:
1. 创建现代化分支
2. 尝试在 VS2019/2022 编译
3. 记录所有问题和解决方案
4. 制定详细的时间表

## 11. 参考文献

- [RFC-0001: SPlayer 现代化提案](./rfc-0001-modernization-proposal.md)
- [RFC-0002: 编译环境与技术栈分析](./rfc-0002-build-environment-analysis.md)
- [Visual Studio 工具集版本](https://docs.microsoft.com/en-us/cpp/build/reference/toolset-version)
- [Qt 文档](https://doc.qt.io/)
- [FFmpeg 文档](https://ffmpeg.org/documentation.html)

---

**下一步行动**:
1. 评审本 RFC
2. 开始阶段 1 实施
3. 定期更新进度和状态
