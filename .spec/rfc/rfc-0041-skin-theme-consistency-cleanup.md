# RFC-0041：皮肤/主题一致性清理

| 字段 | 内容 |
|------|------|
| **状态** | 提案 (Proposed) |
| **类型** | Atomic（父级 [RFC-0036](./rfc-0036-mfc-ui-modernization.md)） |
| **父 RFC** | [RFC-0036](./rfc-0036-mfc-ui-modernization.md) |
| **适用范围** | `src/Source/apps/mplayerc/SkinPreviewDlg.h/.cc`、`Model/ThemePkg.h/.cc`、`Controller/ThemePkgController.h/.cc` |
| **相关 RFC** | [RFC-0036](./rfc-0036-mfc-ui-modernization.md)（父级）、[RFC-0037](./completed/rfc-0037-ui-surface-inventory.md)（问题来源） |
| **创建日期** | 2026-07-17 |
| **最后更新** | 2026-07-17 |

## 1. 摘要

RFC-0037 盘点发现两个独立但都属于"皮肤/主题命名混淆或不一致"的问题：(1) `SkinPreviewDlg`——皮肤选择/预览对话框本身——完全不使用运行时主题色查找机制 `AppSettings::GetColorFromTheme`，纯系统色渲染；(2) `Model/ThemePkg` 是一个与 `AppSettings::GetColorFromTheme` 同名相关但完全不同职责（皮肤包打包/解包）的类，其全部方法都是未实现的空桩，容易被误认为是主题颜色 API。本 RFC 分两个独立子任务处理，均为小范围、低风险改动。

## 2. 问题（证据）

### 2.1 SkinPreviewDlg 未使用主题色

1. `SkinPreviewDlg.h:78`、`SkinPreviewDlg.cc`（326 行）：WTL `CDialogImpl`，使用 `CListBox`/`CStatic`/`CLinkCtrl` 等纯系统控件。
2. 已用 grep 确认该文件零 `GetColorFromTheme` 调用、零 `RGB()` 调用——布局完全来自 `.rc` 对话框模板（`IDD_SKIN_PREVIEW`），颜色完全是系统默认。
3. 讽刺之处：这是"皮肤预览"对话框，但它自己的界面不受用户选择的皮肤影响。

### 2.2 Model/ThemePkg 是未实现死桩，命名易混淆

1. `Model/ThemePkg.h:8-11`：声明 `ReadThemeFromDir`、`ReadThemeFromPkg`、`WriteThemeToDir`、`WriteThemeToPkg` 四个方法。
2. `Model/ThemePkg.cc:4-33`：四个方法的实现体全部只设置一个标志位后 `return false`，没有任何实际打包/解包逻辑。
3. 已用 grep 确认全仓只有 `Controller/ThemePkgController.h/.cc` 引用 `CThemePkg`，没有任何 UI 代码通过它读取颜色——真正的运行时颜色查找是 `AppSettings::GetColorFromTheme`（`mplayerc.h:688`、`mplayerc.cpp:4739`），两者命名相似（`ThemePkg` vs. `GetColorFromTheme`）但完全不是一回事，容易让后来者误用或误判"主题机制已实现"。

## 3. 目标

1. `SkinPreviewDlg` 的可自定义颜色元素（列表背景/选中项高亮/文字色等，视对话框模板实际控件而定）改为通过 `AppSettings::GetColorFromTheme` 查询，与其余已接入主题的表面（`ChildView`/`PlayerToolBar`/`PlayerToolTopBar`/`SVPSliderCtrl`）保持一致的接入方式。
2. 对 `Model/ThemePkg` 做出明确处置决定并执行：要么补齐其打包/解包实现使其名副其实，要么将其重命名/移除以消除与 `GetColorFromTheme` 的命名混淆——具体选哪个由第 5 节的调查步骤决定，不预设结论。
3. 两项改动互相独立，可分别提交、分别验证。

## 4. 非目标

1. 不新增皮肤文件格式或 `ui.ini` key（如需要，属于更大的皮肤格式扩展，超出本 RFC）。
2. 不改变 `SkinPreviewDlg` 的功能行为（浏览/选择/删除皮肤、跳转"获取更多皮肤"网页对话框）——仅改颜色来源。
3. 不影响 `Controller/ThemePkgController` 现有调用方为 `CThemePkg` 传入的调用契约，除非第 5 节调查确认该调用方也是死代码（若是，一并在本 RFC 范围内说明但改动仍需保持行为等价或明确记录为清理死代码）。

## 5. 提案

### 5.1 SkinPreviewDlg 接入主题色

1. 审查 `IDD_SKIN_PREVIEW` 对话框模板与 `SkinPreviewDlg.cc` 中的控件初始化代码，确定哪些视觉元素（列表背景、选中高亮、分隔线等）适合读取主题色。
2. 为每个适用元素调用 `AppSettings::GetColorFromTheme("<新 key 名>", <当前系统色默认值>)`，默认值取当前系统色以保证未配置该 key 的皮肤下行为不变（向后兼容）。
3. 如果需要自绘（当前是纯系统控件），优先用 `WM_CTLCOLORLISTBOX`/`WM_CTLCOLORSTATIC` 之类的颜色钩子而非引入新的 owner-draw，保持改动最小。

### 5.2 Model/ThemePkg 死代码处置

1. 先确认 `Controller/ThemePkgController` 当前如何调用 `CThemePkg` 的四个方法、调用结果（恒为 `false`）在调用方是否被检查/影响任何用户可见行为。
2. 根据调查结果二选一：
   - **选项 A（补齐实现）**：如果皮肤导出/导入打包功能是产品需要的能力，补齐 `ReadThemeFromDir`/`ReadThemeFromPkg`/`WriteThemeToDir`/`WriteThemeToPkg` 的真实实现（读写皮肤目录/皮肤包文件）。
   - **选项 B（移除/重命名清理）**：如果该功能从未被需要或已被前端其他方式取代，删除 `Model/ThemePkg.h/.cc` 及 `Controller/ThemePkgController` 中的死调用点，避免继续误导。
3. 本 RFC 不预设选 A 还是 B——由实现者在动手前先完成 2.1 的调查并在本 RFC 的「决策记录」中补充结论，再执行对应分支。

## 6. 验证方式

1. 构建：`mplayerc_vs2005.vcxproj`（`SkinPreviewDlg` 改动）；若涉及 `Controller/ThemePkgController` 的删除/改动，需确认其调用点（若有其他 UI 入口）一并更新，必要时跑全量 `src/splayer.sln`。
2. 手测：切换不同皮肤，打开皮肤预览对话框，确认其颜色随皮肤变化（若 5.1 选择自绘颜色元素）。
3. 若选择 5.2 的选项 A：验证打包/解包出的皮肤包文件可被重新导入并生效。若选择选项 B：确认删除后无编译警告/悬挂引用，全量构建通过。

## 7. 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| `SkinPreviewDlg` 新增主题色 key 后旧皮肤包缺少该 key | 回退到默认值，视觉可能与其他表面不完全一致但不崩溃 | `GetColorFromTheme` 调用点提供合理系统色默认值 |
| `ThemePkg` 选项 B（删除）遗漏隐藏调用点 | 编译失败或运行时行为变化 | 删除前全仓 grep 确认调用面，删除后跑全量构建 |

## 8. 决策记录

### 8.1 已做决策

1. `SkinPreviewDlg` 主题接入与 `Model/ThemePkg` 死代码处置合并为一个 RFC，因为两者都源于同一份清单发现的"主题相关命名/覆盖不一致"问题，且都是小范围、可独立提交的改动。

### 8.2 待决策

1. `Model/ThemePkg` 选 A（补实现）还是选 B（删除/重命名）——留待实现者完成 5.2 步骤 1 的调用面调查后在本 RFC 中补充决策并记录理由。

## 9. 参考文献

- [RFC-0037：UI 表面现状清单](./completed/rfc-0037-ui-surface-inventory.md) 第 6 节
- `src/Source/apps/mplayerc/SkinPreviewDlg.h:78`、`SkinPreviewDlg.cc`
- `src/Source/apps/mplayerc/Model/ThemePkg.h:8-11`、`Model/ThemePkg.cc:4-33`
- `src/Source/apps/mplayerc/mplayerc.h:688`、`mplayerc.cpp:4739`（`AppSettings::GetColorFromTheme`，真正的运行时主题色 API）

---

**下一步行动**：先完成 5.2 步骤 1 的 `ThemePkg` 调用面调查并在本 RFC 决策记录中补充选 A/B 结论，再并行实施 5.1 与已决策的 5.2 分支。
