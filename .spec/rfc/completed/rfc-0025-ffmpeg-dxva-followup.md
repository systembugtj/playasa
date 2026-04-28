# RFC-0025：FFmpeg DXVA / FfmpegContext 后续替代计划

| 字段 | 内容 |
|------|------|
| **状态** | 已完成 (Completed) |
| **适用范围** | `src/Source/filters/transform/mpcvideodec/FfmpegContext.c`、`FfmpegContext.h`、`DXVADecoder*.cpp`、H.264 / MPEG-2 / VC-1 硬解路径 |
| **相关 RFC** | [RFC-0017](./rfc-0017-ffmpeg-mpcvideodec-upgrade.md)、[RFC-0024](../rfc-0024-ffmpeg-modern-island.md)、[RFC-0026](./rfc-0026-mkv-support-modernization.md)、[RFC-0030](../rfc-0030-mpeg2-dxva-context-modernization.md) |
| **创建日期** | 2026-04-25 |
| **完成日期** | 2026-04-27 |

## 1. 摘要

RFC-0024 迁移了新版 FFmpeg 的软件解码 island，并在 modern bridge 路径上主动禁用旧 DXVA。这个决策是正确的：旧 DXVA 依赖 `FfmpegContext.c` 直接读取旧 FFmpeg 私有结构，例如 `H264Context`、`VC1Context`、`MpegEncContext`，以及本地复制的 MPEG-2 context 布局；这些都不是现代 FFmpeg 的稳定 public API。

本 RFC 已完成第一轮只读审计。结论是：不要把 DXVA 迁移混入当前软件解码稳定线。正确做法是先把 `FfmpegContext.c` 拆成“旧 FFmpeg 读取层”和“项目自有 DXVA picture contract”，再按 codec 逐步替换旧私有字段依赖。后续 MPEG-2 DXVA 第一阶段实施已移交 [RFC-0030](../rfc-0030-mpeg2-dxva-context-modernization.md)。

## 2. 当前保护边界

当前 `MPCVideoDec` 已经为 modern FFmpeg bridge 建立保护边界：

1. H.264、MPEG-2、VC-1 使用 modern bridge 时，`m_bUseDXVA` 被置为 `false`。
2. modern bridge 只走软件 decode，不调用 `FfmpegContext.c` 的 DXVA picture parameter 构造逻辑。
3. 旧 DXVA 路径仍可和旧 FFmpeg 路径并存，但不能读取 modern FFmpeg 私有 header。
4. 所有 DXVA modernization 必须保持 codec 级回退能力，不能回退整个 FFmpeg island。

## 3. 私有依赖审计

### 3.1 集中入口

`FfmpegContext.h` 暴露的函数几乎都以 `AVCodecContext*` 为输入，再在 `FfmpegContext.c` 内部强转 `pAVCtx->priv_data`：

1. `FFH264DecodeBuffer`
2. `FFH264BuildPicParams`
3. `FFH264CheckCompatibility`
4. `FFH264SetCurrentPicture`
5. `FFH264UpdateRefFramesList`
6. `FF264UpdateRefFrameSliceLong`
7. `FFVC1UpdatePictureParam`
8. `FFMpeg2DecodeFrame`
9. `FFIsInterlaced`
10. `FFGetMBNumber`
11. `FFGetCodedPicture`
12. `FFGetAlternateScan`

这些函数是 DXVA 迁移的真正边界。后续实现不能让 `DXVADecoder*.cpp` 继续直接或间接依赖 modern FFmpeg private struct。

### 3.2 MPEG-2

调用方：`DXVADecoderMpeg2.cpp`

主要入口：

1. `FFMpeg2DecodeFrame`
2. `FFGetAlternateScan`
3. `FFGetCodedPicture`

旧私有依赖：

1. 本地复制的 `Mpeg1Context`，其中嵌入 `MpegEncContext mpeg_enc_ctx`。
2. `pAVCtx->priv_data` 被强转为 `Mpeg1Context*`。
3. `MpegEncContext` 字段：`mb_width`、`mb_height`、`pict_type`、`picture_structure`、`progressive_sequence`、`progressive_frame`、`top_field_first`、`repeat_first_field`。
4. `MpegEncContext` quant matrix：`intra_matrix`、`inter_matrix`、`chroma_intra_matrix`、`chroma_inter_matrix`。
5. `MpegEncContext::alternate_scan` 和 `current_picture.coded_picture_number`。
6. 旧 `avcodec_decode_video` side effect：填充 context、slice count、frame coded picture number。

迁移难度：最低。MPEG-2 DXVA 参数相对固定，reference 管理由 `DXVADecoderMpeg2` 自己维护，适合作为第一阶段。

### 3.3 VC-1

调用方：`DXVADecoderVC1.cpp`

主要入口：

1. `FFVC1UpdatePictureParam`
2. `FFIsSkipped`
3. `FFIsInterlaced`

旧私有依赖：

1. `pAVCtx->priv_data` 被强转为 `VC1Context*`。
2. `VC1Context` 字段：`fcm`、`tff`、`profile`、`lumshift`、`lumscale`、`panscanflag`、`refdist_flag`、`fastuvmc`、`extended_mv`、`dquant`、`vstransform`、`quantizer_mode`、`multires`、`rangered`、`syncmarker`、`overlap`、`maxbframes`、`p_frame_skipped`、`interlace`。
3. 嵌套 `MpegEncContext` 字段：`s.pict_type`、`s.loop_filter`、`s.resync_marker`。
4. 旧 `av_vc1_decode_frame` side effect：更新 VC-1 picture state。

迁移难度：中。VC-1 picture parameter 字段多，但 reference 管理仍主要在 decoder 类中完成。

### 3.4 H.264

调用方：`DXVADecoderH264.cpp`

主要入口：

1. `FFH264DecodeBuffer`
2. `FFH264BuildPicParams`
3. `FFH264SetCurrentPicture`
4. `FFH264UpdateRefFramesList`
5. `FFH264IsRefFrameInUse`
6. `FF264UpdateRefFrameSliceLong`
7. `FFH264SetDxvaSliceLong`
8. `FFH264CheckCompatibility`

旧私有依赖：

1. `pAVCtx->priv_data` 被强转为 `H264Context*`。
2. SPS/PPS：`sps_buffers`、`pps_buffers`、`sps`、`pps`、`level_idc`、`ref_frame_count`、`mb_width`、`mb_height`、`frame_mbs_only_flag`、`mb_aff`、`residual_color_transform_flag`、`chroma_format_idc`、`bit_depth_luma`、`bit_depth_chroma`、`log2_max_frame_num`、`poc_type`、`log2_max_poc_lsb`、`delta_pic_order_always_zero_flag`、`direct_8x8_inference_flag`。
3. PPS fields：`constrained_intra_pred`、`weighted_pred`、`weighted_bipred_idc`、`transform_8x8_mode`、`cabac`、`pic_order_present`、`slice_group_count`、`mb_slice_group_map_type`、`deblocking_filter_parameters_present`、`redundant_pic_cnt_present`、`slice_group_change_rate_minus1`、`chroma_qp_index_offset`、`ref_count`、`init_qp`、`init_qs`、`scaling_matrix4`。
4. Picture/ref fields：`short_ref_count`、`long_ref_count`、`short_ref`、`long_ref`、`ref_list`、`ref_count`、`frame_num`、`field_poc`、`opaque`、`current_picture_ptr`。
5. Slice/POC fields：`slice_type`、`poc_lsb`、`poc_msb`、`sei_pic_struct`、`ref_pic_flag`、`sp_for_switch_flag`、`dxva_slice_long`。
6. 旧 `av_h264_decode_frame` side effect：更新 parser/decoder private state、POC、ref list、slice state。

迁移难度：最高。H.264 DXVA 需要完整 SPS/PPS、DPB/ref list、slice reference list 和 POC contract，不能直接从 modern FFmpeg private headers 复制字段。

## 4. 目标中间结构

后续代码应新增项目自有 contract，而不是让 DXVA decoder 继续读取 FFmpeg 私有结构。建议拆为三个 codec 专用结构：

1. `DxvaMpeg2PictureContext`
2. `DxvaVc1PictureContext`
3. `DxvaH264PictureContext`

每个结构都只表达 DXVA decoder 需要的稳定输入：

1. picture type / field type / slice type
2. frame dimensions in macroblocks
3. reference frame indexes
4. quantization matrices
5. codec-specific sequence/header flags
6. slice control metadata
7. coded picture number 或等价 display/reorder 标识

短期可以由旧 FFmpeg reader 填充这些结构，长期再由 modern parser / bitstream parser 填充同一结构。这样 DXVA decoder 类只依赖项目自有 contract，迁移时风险集中在 reader 层。

## 5. 已移交后续

1. MPEG-2 DXVA 子 RFC 已创建：[RFC-0030](../rfc-0030-mpeg2-dxva-context-modernization.md)。
2. `RFC-0030` 限定只做 `DxvaMpeg2PictureContext` 和旧 reader 输出重构。
3. VC-1 / H.264 DXVA 迁移等待 MPEG-2 context 模式验证后再继续。
4. DXVA selection/fallback 低容量日志和手测记录模板应随具体 codec 实施 RFC 增加。

## 6. 非目标

1. 不在本 RFC 中直接启用新版 FFmpeg 硬件加速 API。
2. 不把现代 FFmpeg 私有 header 当成兼容层。
3. 不同时重构 DirectShow filter 或 UI。
4. 不在 H.264 前置完成前强行恢复 modern bridge 的 DXVA。
5. 不牺牲当前 H.264/MPEG-2/VC-1 modern software decode 稳定性。

## 7. 完成标准

1. `FfmpegContext.c` 私有依赖已完成只读审计。
2. H.264 / MPEG-2 / VC-1 DXVA 风险和迁移顺序已明确。
3. 中间结构方案已明确。
4. MPEG-2 第一阶段实施已拆分到独立 active RFC。
