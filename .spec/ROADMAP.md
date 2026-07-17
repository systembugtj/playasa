# ROADMAP

方向与工程契约以 **[.spec/rfc/completed/rfc-0011-windows-repository-layout.md](.spec/rfc/completed/rfc-0011-windows-repository-layout.md)** 为准；**第三方库升级路线**见 **[.spec/rfc/completed/rfc-0012-thirdparty-library-upgrades.md](.spec/rfc/completed/rfc-0012-thirdparty-library-upgrades.md)**；日常安装、构建、项目结构和现代化说明见 **[docs/](docs/README.md)**；历史 RFC 见 **[docs/rfc/](docs/rfc/)**。

在办与跟踪见 **[TASK_TRACKING.md](TASK_TRACKING.md)**。

---

## RFC 索引

`.spec/rfc/` 跟踪 Playasa/SPlayer 现代化工作。**金规则**：实现与 RFC 声明对齐；完成后归档到 `.spec/rfc/completed/` 并修正全仓链接。

最后更新：**2026-07-17**

### 编号与状态一览

| RFC | 标题 | 状态 | 路径 |
| --- | --- | --- | --- |
| 0001–0016 | 现代化提案、构建修复、Rust 试点等 | 已完成 | [.spec/rfc/completed/](.spec/rfc/completed/) |
| 0015 | Updater curl + Schannel | 提案 | [.spec/rfc/rfc-0015-curl-schannel-updater-download.md](.spec/rfc/rfc-0015-curl-schannel-updater-download.md) |
| 0017 | FFmpeg / mpcvideodec 升级审计 | 已完成 | [.spec/rfc/completed/rfc-0017-ffmpeg-mpcvideodec-upgrade.md](.spec/rfc/completed/rfc-0017-ffmpeg-mpcvideodec-upgrade.md) |
| 0018 | Boost 头文件树渐进消化 | 提案 | [.spec/rfc/rfc-0018-boost-header-tree-digestion.md](.spec/rfc/rfc-0018-boost-header-tree-digestion.md) |
| 0019 | 第三方 CRT/MFC 链接契约 | 提案 | [.spec/rfc/rfc-0019-thirdparty-crt-mfc-linkage-contract.md](.spec/rfc/rfc-0019-thirdparty-crt-mfc-linkage-contract.md) |
| 0020–0023 | Rust playlist / sphash / subtitle / ZIP | 已完成 | [.spec/rfc/completed/](.spec/rfc/completed/) |
| 0024 | FFmpeg 8.1 modern island（父级） | **执行中** | [.spec/rfc/rfc-0024-ffmpeg-modern-island.md](.spec/rfc/rfc-0024-ffmpeg-modern-island.md) |
| 0025 | FFmpeg DXVA / FfmpegContext 审计 | 已完成（审计） | [.spec/rfc/completed/rfc-0025-ffmpeg-dxva-followup.md](.spec/rfc/completed/rfc-0025-ffmpeg-dxva-followup.md) |
| 0026 | MKV 短期 playback contract | 已完成 | [.spec/rfc/completed/rfc-0026-mkv-support-modernization.md](.spec/rfc/completed/rfc-0026-mkv-support-modernization.md) |
| 0027 | MKV seek 稳定化 | 已完成 | [.spec/rfc/completed/rfc-0027-mkv-seek-stabilization.md](.spec/rfc/completed/rfc-0027-mkv-seek-stabilization.md) |
| 0028 | UIA 视频区 + seek 预滚后续 | 已完成 | [.spec/rfc/completed/rfc-0028-uia-video-and-seek-followups.md](.spec/rfc/completed/rfc-0028-uia-video-and-seek-followups.md) |
| 0029 | FFmpeg Matroska splitter PoC | 提案 | [.spec/rfc/rfc-0029-ffmpeg-backed-matroska-splitter-poc.md](.spec/rfc/rfc-0029-ffmpeg-backed-matroska-splitter-poc.md) |
| 0030 | MPEG-2 DXVA picture context 合同 | 已实现（`MPCVideoDec` 路径） | [.spec/rfc/rfc-0030-mpeg2-dxva-context-modernization.md](.spec/rfc/rfc-0030-mpeg2-dxva-context-modernization.md) |
| 0031 | MPEG-2 真实播放路径（`CMpeg2DecFilter`） | 已完成 | [.spec/rfc/completed/rfc-0031-mpeg2-playback-path-modernization.md](.spec/rfc/completed/rfc-0031-mpeg2-playback-path-modernization.md) |
| 0032 | RMVB / RealVideo modern 播放 | 已完成 | [.spec/rfc/completed/rfc-0032-rmvb-realvideo-modern-playback.md](.spec/rfc/completed/rfc-0032-rmvb-realvideo-modern-playback.md) |
| 0033 | DXVA 阶段 2：H.264 / VC-1 | 提案 | [.spec/rfc/rfc-0033-ffmpeg-dxva-phase2-h264-vc1.md](.spec/rfc/rfc-0033-ffmpeg-dxva-phase2-h264-vc1.md) |
| 0034 | RealAudio modern 播放 | 已完成 | [.spec/rfc/completed/rfc-0034-realaudio-modern-playback.md](.spec/rfc/completed/rfc-0034-realaudio-modern-playback.md) |
| 0035 | 旧 `mpcvideodec/ffmpeg` 树退役 | **执行中** | [.spec/rfc/rfc-0035-legacy-mpcvideodec-ffmpeg-retirement.md](.spec/rfc/rfc-0035-legacy-mpcvideodec-ffmpeg-retirement.md) |
| 0036 | MFC/Win32 UI 现代化（父级） | **执行中**（父级不产出代码） | [.spec/rfc/rfc-0036-mfc-ui-modernization.md](.spec/rfc/rfc-0036-mfc-ui-modernization.md) |
| 0037 | UI 表面现状清单 | 已完成 | [.spec/rfc/completed/rfc-0037-ui-surface-inventory.md](.spec/rfc/completed/rfc-0037-ui-surface-inventory.md) |
| 0038 | PlayerToolTopBar 悬停/leave 修复 | 提案 | [.spec/rfc/rfc-0038-playertooltopbar-hover-leave-fix.md](.spec/rfc/rfc-0038-playertooltopbar-hover-leave-fix.md) |
| 0039 | CSUIButton 悬停可靠性 | 提案 | [.spec/rfc/rfc-0039-suibutton-hover-reliability.md](.spec/rfc/rfc-0039-suibutton-hover-reliability.md) |
| 0040 | 原生滑块控件键盘焦点视觉 | 提案 | [.spec/rfc/rfc-0040-native-control-keyboard-focus-visuals.md](.spec/rfc/rfc-0040-native-control-keyboard-focus-visuals.md) |
| 0041 | 皮肤/主题一致性清理 | 提案 | [.spec/rfc/rfc-0041-skin-theme-consistency-cleanup.md](.spec/rfc/rfc-0041-skin-theme-consistency-cleanup.md) |
| 0042 | DPI 缓存统一 | 提案 | [.spec/rfc/rfc-0042-dpi-cache-consolidation.md](.spec/rfc/rfc-0042-dpi-cache-consolidation.md) |
| 0043 | CustomizeFontDlg DrawItem 状态完整性 | 提案 | [.spec/rfc/rfc-0043-customizefontdlg-drawitem-states.md](.spec/rfc/rfc-0043-customizefontdlg-drawitem-states.md) |
| 0044 | RealAudio legacy SDK / `RA_FFMPEG` 清理 | 已完成 | [.spec/rfc/completed/rfc-0044-realaudio-legacy-cleanup.md](.spec/rfc/completed/rfc-0044-realaudio-legacy-cleanup.md) |
| 0045 | RealAudio 剩余 codec（AAC / 14_4 / 28_8） | 已完成 | [.spec/rfc/completed/rfc-0045-realaudio-remaining-codecs.md](.spec/rfc/completed/rfc-0045-realaudio-remaining-codecs.md) |

### FFmpeg modern 子 RFC 关系

```text
RFC-0024 (island + bridge 父级)
├── RFC-0026/0027/0028 (MKV 短期 + UIA/seek) ✓ → RFC-0029 (长期 splitter)
├── RFC-0030 (MPEG-2 DXVA context 合同)
├── RFC-0031 (CMpeg2DecFilter modern + 删 libmpeg2) ✓
├── RFC-0032 (RMVB/RealVideo; 含阶段 2 时间戳) ✓
├── RFC-0034 (RealAudio cook/sipr/atrac3) ✓
├── RFC-0044 (RealAudio legacy SDK 清理) ✓
├── RFC-0045 (RealAudio AAC / ra_144 / ra_288) ✓
├── RFC-0033 (DXVA H.264/VC-1; 承接 RFC-0025)
└── RFC-0035 (全部 software 路径稳定后删旧 ffmpeg 树)

RFC-0025 (已完成审计) ──► RFC-0030 ──► RFC-0033
```

### UI 现代化子 RFC 关系

```text
RFC-0036 (UI 现代化父级；不产出代码)
├── RFC-0037 (UI 表面现状清单) ✓
├── RFC-0038 (PlayerToolTopBar 悬停/leave 修复)
├── RFC-0039 (CSUIButton 悬停可靠性；惠及 ChildView/PlayerToolBar/PlayerToolTopBar/SVPSliderCtrl)
├── RFC-0040 (VolumeCtrl/SVPSliderCtrl 键盘焦点视觉)
├── RFC-0041 (皮肤/主题一致性清理：SkinPreviewDlg + ThemePkg)
├── RFC-0042 (DPI 缓存统一：MainFrm/SUIButton/GetSystemFontWithScale)
└── RFC-0043 (CustomizeFontDlg DrawItem 状态完整性)

backlog（体量过大/有依赖，暂不开 RFC）：MainFrm 拆分、PlayerToolBar 主题一致性、工具栏按钮逐个 UIA 身份
```

### 推荐执行顺序

| 优先级 | RFC | 原因 |
| --- | --- | --- |
| P0 | **0033** | DXVA 解耦；阻塞 RFC-0035 删旧树 |
| P1 | **0035** | 旧树退役审计已启动；等 0033 + MpaDec |
| P1 | **0038** | UI：快速修复，定位明确 |
| P1 | **0039** | UI：惠及 4 个宿主表面 |
| P2 | **0040 / 0041 / 0043** | UI 小范围可独立改动 |
| P2 | **0042** | DPI 缓存统一 |
| P2 | **0024** | 父级 island 维护（RealAudio 子项已收口） |
| P3 | **0029** | 长期 Matroska splitter PoC |
| 基建 | **0015 / 0018 / 0019** | 更新器、Boost、三方链接契约 |

### 尚无独立 RFC 的 backlog

| 项 | 说明 | 建议 |
| --- | --- | --- |
| zeromq 4.x 迁移 | TASK_TRACKING 备注 | 体量够大时再开新编号 RFC（当前最大编号见上表） |
| ED2K 路径手测 | RFC-0012 P3 备注 | 手测清单写入 TASK_TRACKING |
| 媒体库/历史记录手测 | RFC-0012 P4 备注 | 同上 |

### RFC 测试脚本速查

| RFC | 脚本（相对 `src/Test/Scripts/`） |
| --- | --- |
| 0024 | `test-rfc0024-*-smoke.ps1`；`src/BuildScript/verify-rfc0024-ffmpeg-modern.ps1` |
| 0027/0028 | `test-rfc0027-mkv-seek-selfcheck.ps1`, `test-rfc0027-uia-tree-selfcheck.ps1`, `test-rfc0028-uia-video-selfcheck.ps1`, `test-rfc0028-mkv-seek-uia-selfcheck.ps1` |
| 0030 | `test-rfc0030-mpeg2-dxva-selfcheck.ps1` |
| 0031 | `test-rfc0031-mpeg2-*.ps1` |
| 0032 | `setup-rmvb-samples.ps1`, `test-rmvb-seek-selfcheck.ps1` |
| 0034 | `test-rfc0034-realaudio-selfcheck.ps1` |
| 0035 | `src/BuildScript/audit-rfc0035-legacy-ffmpeg-refs.ps1` |
| 0044/0045 | `test-rfc0045-realaudio-remaining-selfcheck.ps1`（含 cook 回归 + AAC/RA144/RA288 bridge open） |

### 新建 RFC 规则

1. 使用 [.spec/rfc/rfc-template.md](.spec/rfc/rfc-template.md) 或复制最近同级 RFC（如 0031/0032）的表格头。
2. 在 **本 ROADMAP** 的 RFC 表与 [TASK_TRACKING.md](TASK_TRACKING.md) 各增一行。
3. 更新父级 RFC（通常是 0024）的「相关 RFC」表。
4. 编号连续；子主题不重复已有 RFC 范围（例：RV 时间戳留在 0032，不另开 0033）。
