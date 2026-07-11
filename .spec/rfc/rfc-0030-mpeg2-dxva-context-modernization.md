# RFC-0030：MPEG-2 DXVA Picture Context 现代化

| 字段 | 内容 |
|------|------|
| **状态** | 阶段 1/2 已实现，真实播放路径验证受阻 (Implemented, Runtime Path Blocked) |
| **适用范围** | `FfmpegContext.c` MPEG-2 reader、`DXVADecoderMpeg2.cpp`、MPEG-2 DXVA picture parameters、旧 FFmpeg 私有字段隔离 |
| **相关 RFC** | [RFC-0025](./completed/rfc-0025-ffmpeg-dxva-followup.md)、[RFC-0024](./rfc-0024-ffmpeg-modern-island.md)、[RFC-0031](./completed/rfc-0031-mpeg2-playback-path-modernization.md) |
| **创建日期** | 2026-04-27 |
| **最后更新** | 2026-04-28 |

## 1. 摘要

RFC-0025 已确认 DXVA 现代化不能直接读取 modern FFmpeg 私有结构，也不能混入当前 H.264/MPEG-2/VC-1 modern software decode 稳定线。本 RFC 承接第一阶段实施，先从最小风险的 MPEG-2 DXVA 开始，把 `FfmpegContext.c` 的 MPEG-2 私有字段读取隔离到项目自有 `DxvaMpeg2PictureContext`。

本 RFC 不改变默认播放策略，不恢复 modern bridge 的 DXVA。目标只是让 `DXVADecoderMpeg2.cpp` 逐步从“直接消费旧 FFmpeg wrapper 输出”过渡到“消费项目自有 picture context”。

## 2. 当前问题

`DXVADecoderMpeg2.cpp` 当前调用：

1. `FFMpeg2DecodeFrame`
2. `FFGetAlternateScan`
3. `FFGetCodedPicture`

这些函数在 `FfmpegContext.c` 内部读取：

1. `pAVCtx->priv_data`
2. 本地复制的 `Mpeg1Context`
3. `MpegEncContext`
4. MPEG-2 quant matrix
5. old `avcodec_decode_video` side effect

这种设计无法直接迁移到 modern FFmpeg，因为现代 FFmpeg 不承诺这些结构和字段稳定存在。

## 3. 目标

1. 新增项目自有 `DxvaMpeg2PictureContext`。
2. 把 `FFMpeg2DecodeFrame` 拆成旧 FFmpeg reader 和 DXVA 参数填充两层。
3. 让 `DXVADecoderMpeg2.cpp` 的核心逻辑逐步依赖 `DxvaMpeg2PictureContext`。
4. 保留旧 FFmpeg reader 作为第一版数据来源，避免行为突变。
5. 为 VC-1/H.264 后续迁移建立可复用模式。

## 4. 非目标

1. 不接入 FFmpeg 8.1 hardware acceleration API。
2. 不恢复 modern bridge 的 MPEG-2 DXVA。
3. 不改 H.264/VC-1 DXVA。
4. 不修改 renderer、UI 或 seek 行为。
5. 不删除旧 `FfmpegContext.c`。

## 5. 建议结构

新增头文件建议路径：

```text
src/Source/filters/transform/mpcvideodec/DxvaCodecContext.h
```

首个结构：

```cpp
struct DxvaMpeg2PictureContext {
    DXVA_PictureParameters pictureParams;
    DXVA_QmatrixData qmatrixData;
    DXVA_SliceInfo sliceInfo[MAX_SLICES];
    int sliceCount;
    int nextCodecIndex;
    int fieldType;
    int sliceType;
    int codedPictureNumber;
    BOOL alternateScan;
};
```

结构字段只表达 `DXVADecoderMpeg2` 需要消费的稳定 contract。旧 FFmpeg reader 可以继续从 `MpegEncContext` 填充它，但 decoder 类不应知道 `MpegEncContext` 的存在。

## 6. 实施计划

### 阶段 1：无行为变化封装

1. 新增 `DxvaCodecContext.h`，定义 `DxvaMpeg2PictureContext`。
2. 在 `FfmpegContext.h` 新增 `FFMpeg2ReadPictureContext`，输出 `DxvaMpeg2PictureContext`。
3. 在 `FfmpegContext.c` 内部复用当前 `FFMpeg2DecodeFrame` 的读取逻辑填充 context。
4. 保留现有 `FFMpeg2DecodeFrame`，由它调用新 reader 再拷贝到旧输出参数。
5. 构建验证，确保行为不变。

### 阶段 2：decoder 消费 context

1. 修改 `DXVADecoderMpeg2.cpp`，调用 `FFMpeg2ReadPictureContext`。
2. 用 context 填充 `m_PictureParams`、`m_QMatrixData`、`m_SliceInfo`、`m_nSliceCount`、`m_nNextCodecIndex`。
3. 将 `FFGetAlternateScan`、`FFGetCodedPicture` 的 MPEG-2 使用点并入 context。
4. 保留旧函数给非迁移路径使用，直到 VC-1/H.264 也完成拆分。

### 阶段 3：验证和记录

1. 运行 fast build。
2. 运行 existing modern software smoke，确认 modern path 不受影响。
3. 用 MPEG-2 DXVA 样本手测一次硬解路径。
4. 记录 GPU/驱动/renderer/sample 信息。

## 7. 风险

1. MPEG-2 DXVA 依赖旧 `avcodec_decode_video` side effect，第一阶段只能隔离结构，不能彻底消除旧依赖。
2. `MAX_SLICES` 的定义位置需要保持与现有 decoder 一致，避免 ABI/栈布局问题。
3. 手测硬解依赖本机 GPU 和驱动，自动化覆盖有限。
4. 如果拷贝 context 时遗漏 field，会出现画面错乱而不是直接编译失败。

## 8. 验收标准

1. `DXVADecoderMpeg2.cpp` 可以通过 `DxvaMpeg2PictureContext` 获得所有 MPEG-2 DXVA 输入。
2. `FfmpegContext.c` 的 MPEG-2 私有字段读取集中在 reader 函数内。
3. modern FFmpeg software path 的 H.264/MPEG-2/VC-1 selfcheck 仍通过。
4. MPEG-2 DXVA 手测记录已补充到 RFC 或测试日志。
5. 若 MPEG-2 DXVA 回归，可以只回退 MPEG-2 context reader，不影响 modern FFmpeg island。

## 9. 实施记录

### 2026-04-28

已完成：

1. 新增 `src/Source/filters/transform/mpcvideodec/DxvaCodecContext.h`。
2. 定义 `DxvaMpeg2PictureContext`，集中承载 MPEG-2 DXVA picture params、qmatrix、slice info、slice count、field/slice type、coded picture number 和 alternate scan。
3. 新增 `FFMpeg2ReadPictureContext`，把 `FfmpegContext.c` 的 MPEG-2 私有字段读取集中到 reader 函数。
4. 保留 `FFMpeg2DecodeFrame` 作为兼容 wrapper，降低非迁移路径风险。
5. 修改 `DXVADecoderMpeg2.cpp`，改为消费 `DxvaMpeg2PictureContext`，不再直接调用 `FFGetAlternateScan(m_pFilter->GetAVCtx())` 和 `FFGetCodedPicture(m_pFilter->GetAVCtx())`。
6. 将 `DXVA_MPEG2_MAX_SLICES` 与既有 `MAX_SLICE` 对齐为同一上限。

验证已完成：

```text
dev.ps1 buildFast: PASS
test-rfc0024-modern-bridge-smoke.ps1: PASS
ReadLints: no new diagnostics
```

新增验证：

```text
test-rfc0030-mpeg2-dxva-selfcheck.ps1: SKIP
sample: out/selfcheck/sample-mpeg2-dxva.m2ts size=660480
GPU: Intel(R) HD Graphics 4600 driver=20.19.15.4624; NVIDIA GeForce GTX 860M driver=32.0.15.7628
graph: FGM: Connecting 'MPEG-2 Video Decoder' {39F498AF-1A09-4275-B193-673B0BA3D478}
```

结论：默认 MPEG-2 playback graph 使用的是 `CMpeg2DecFilter`，不是 `MPCVideoDec`。因此本 RFC 修改的 `MPCVideoDec` MPEG-2 DXVA context path 已能构建，但普通 MPEG-2 播放样本无法实际覆盖该路径。真实播放路径归属和后续迁移由 [RFC-0031](./completed/rfc-0031-mpeg2-playback-path-modernization.md)（已完成）跟踪。

仍待完成：

1. 通过 `RFC-0031` 决定 MPEG-2 modern FFmpeg/DXVA 工作应迁移 `CMpeg2DecFilter`，还是调整 graph routing 让相关样本进入 `MPCVideoDec`。
2. 在目标真实 playback path 确认后，再做 MPEG-2 DXVA 硬解手测记录。
