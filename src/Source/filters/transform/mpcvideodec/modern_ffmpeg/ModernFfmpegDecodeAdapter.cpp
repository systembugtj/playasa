#include "ModernFfmpegDecodeAdapter.h"

#include <string.h>
#include <stdio.h>
#include <limits.h>
#include <vector>

extern "C" {
#include "libavcodec/avcodec.h"
#include "libavutil/channel_layout.h"
#include "libavutil/error.h"
#include "libavutil/frame.h"
#include "libavutil/mem.h"
#include "libavutil/samplefmt.h"
}

namespace ModernFfmpeg {

namespace {

const size_t kLastErrorCapacity = 256;
const uint8_t kAnnexBStartCode[] = { 0, 0, 0, 1 };
const int kUnknownH264NalLengthSize = 0;
const int64_t kNoPts = INT64_MIN;
const AVRational kDirectShowTimeBase = { 1, 10000000 };

const uint32_t kFourccDIVX = 'D' | ('I' << 8) | ('V' << 16) | ('X' << 24);
const uint32_t kFourccdivx = 'd' | ('i' << 8) | ('v' << 16) | ('x' << 24);
const uint32_t kFourccXVID = 'X' | ('V' << 8) | ('I' << 16) | ('D' << 24);
const uint32_t kFourccxvid = 'x' | ('v' << 8) | ('i' << 16) | ('d' << 24);
const uint32_t kFourccXVIX = 'X' | ('V' << 8) | ('I' << 16) | ('X' << 24);
const uint32_t kFourccxvix = 'x' | ('v' << 8) | ('i' << 16) | ('x' << 24);
const uint32_t kFourccDX50 = 'D' | ('X' << 8) | ('5' << 16) | ('0' << 24);
const uint32_t kFourccdx50 = 'd' | ('x' << 8) | ('5' << 16) | ('0' << 24);
const uint32_t kFourccMP4V = 'M' | ('P' << 8) | ('4' << 16) | ('V' << 24);
const uint32_t kFourccmp4v = 'm' | ('p' << 8) | ('4' << 16) | ('v' << 24);
const uint32_t kFourccFLV1 = 'F' | ('L' << 8) | ('V' << 16) | ('1' << 24);
const uint32_t kFourccflv1 = 'f' | ('l' << 8) | ('v' << 16) | ('1' << 24);
const uint32_t kFourccVP60 = 'V' | ('P' << 8) | ('6' << 16) | ('0' << 24);
const uint32_t kFourccvp60 = 'v' | ('p' << 8) | ('6' << 16) | ('0' << 24);
const uint32_t kFourccVP61 = 'V' | ('P' << 8) | ('6' << 16) | ('1' << 24);
const uint32_t kFourccvp61 = 'v' | ('p' << 8) | ('6' << 16) | ('1' << 24);
const uint32_t kFourccVP62 = 'V' | ('P' << 8) | ('6' << 16) | ('2' << 24);
const uint32_t kFourccvp62 = 'v' | ('p' << 8) | ('6' << 16) | ('2' << 24);
const uint32_t kFourccVP6F = 'V' | ('P' << 8) | ('6' << 16) | ('F' << 24);
const uint32_t kFourccvp6f = 'v' | ('p' << 8) | ('6' << 16) | ('f' << 24);
const uint32_t kFourccFLV4 = 'F' | ('L' << 8) | ('V' << 16) | ('4' << 24);
const uint32_t kFourccflv4 = 'f' | ('l' << 8) | ('v' << 16) | ('4' << 24);
const uint32_t kFourccVP6A = 'V' | ('P' << 8) | ('6' << 16) | ('A' << 24);
const uint32_t kFourccvp6a = 'v' | ('p' << 8) | ('6' << 16) | ('a' << 24);
const uint32_t kFourccWMV1 = 'W' | ('M' << 8) | ('V' << 16) | ('1' << 24);
const uint32_t kFourccwmv1 = 'w' | ('m' << 8) | ('v' << 16) | ('1' << 24);
const uint32_t kFourccWMV2 = 'W' | ('M' << 8) | ('V' << 16) | ('2' << 24);
const uint32_t kFourccwmv2 = 'w' | ('m' << 8) | ('v' << 16) | ('2' << 24);
const uint32_t kFourccH264 = 'H' | ('2' << 8) | ('6' << 16) | ('4' << 24);
const uint32_t kFourcch264 = 'h' | ('2' << 8) | ('6' << 16) | ('4' << 24);
const uint32_t kFourccX264 = 'X' | ('2' << 8) | ('6' << 16) | ('4' << 24);
const uint32_t kFourccx264 = 'x' | ('2' << 8) | ('6' << 16) | ('4' << 24);
const uint32_t kFourccAVC1 = 'A' | ('V' << 8) | ('C' << 16) | ('1' << 24);
const uint32_t kFourccavc1 = 'a' | ('v' << 8) | ('c' << 16) | ('1' << 24);
const uint32_t kFourccDAVC = 'D' | ('A' << 8) | ('V' << 16) | ('C' << 24);
const uint32_t kFourccdavc = 'd' | ('a' << 8) | ('v' << 16) | ('c' << 24);
const uint32_t kFourccPAVC = 'P' | ('A' << 8) | ('V' << 16) | ('C' << 24);
const uint32_t kFourccpavc = 'p' | ('a' << 8) | ('v' << 16) | ('c' << 24);
const uint32_t kFourccMPG2 = 'M' | ('P' << 8) | ('G' << 16) | ('2' << 24);
const uint32_t kFourccmpg2 = 'm' | ('p' << 8) | ('g' << 16) | ('2' << 24);
const uint32_t kFourccMMES = 'M' | ('M' << 8) | ('E' << 16) | ('S' << 24);
const uint32_t kFourccmmes = 'm' | ('m' << 8) | ('e' << 16) | ('s' << 24);
const uint32_t kFourccWMV3 = 'W' | ('M' << 8) | ('V' << 16) | ('3' << 24);
const uint32_t kFourccwmv3 = 'w' | ('m' << 8) | ('v' << 16) | ('3' << 24);
const uint32_t kFourccWVC1 = 'W' | ('V' << 8) | ('C' << 16) | ('1' << 24);
const uint32_t kFourccwvc1 = 'w' | ('v' << 8) | ('c' << 16) | ('1' << 24);
const uint32_t kFourccRV10 = 'R' | ('V' << 8) | ('1' << 16) | ('0' << 24);
const uint32_t kFourccrv10 = 'r' | ('v' << 8) | ('1' << 16) | ('0' << 24);
const uint32_t kFourccRV20 = 'R' | ('V' << 8) | ('2' << 16) | ('0' << 24);
const uint32_t kFourccrv20 = 'r' | ('v' << 8) | ('2' << 16) | ('0' << 24);
const uint32_t kFourccRV30 = 'R' | ('V' << 8) | ('3' << 16) | ('0' << 24);
const uint32_t kFourccrv30 = 'r' | ('v' << 8) | ('3' << 16) | ('0' << 24);
const uint32_t kFourccRV40 = 'R' | ('V' << 8) | ('4' << 16) | ('0' << 24);
const uint32_t kFourccrv40 = 'r' | ('v' << 8) | ('4' << 16) | ('0' << 24);
const uint32_t kFourccMPG1 = 'M' | ('P' << 8) | ('G' << 16) | ('1' << 24);
const uint32_t kFourccmpg1 = 'm' | ('p' << 8) | ('g' << 16) | ('1' << 24);
const uint32_t kFourccMPEG = 'M' | ('P' << 8) | ('G' << 16) | ('E' << 24);
const uint32_t kFourccmpeg = 'm' | ('p' << 8) | ('g' << 16) | ('e' << 24);

enum AVCodecID ToAvCodecId(DecodeCodec codec)
{
    switch (codec) {
    case kDecodeCodecMpeg4:
        return AV_CODEC_ID_MPEG4;
    case kDecodeCodecFlv1:
        return AV_CODEC_ID_FLV1;
    case kDecodeCodecVp6:
        return AV_CODEC_ID_VP6;
    case kDecodeCodecVp6f:
        return AV_CODEC_ID_VP6F;
    case kDecodeCodecVp6a:
        return AV_CODEC_ID_VP6A;
    case kDecodeCodecWmv1:
        return AV_CODEC_ID_WMV1;
    case kDecodeCodecWmv2:
        return AV_CODEC_ID_WMV2;
    case kDecodeCodecH264:
        return AV_CODEC_ID_H264;
    case kDecodeCodecMpeg2:
        return AV_CODEC_ID_MPEG2VIDEO;
    case kDecodeCodecWmv3:
        return AV_CODEC_ID_WMV3;
    case kDecodeCodecVc1:
        return AV_CODEC_ID_VC1;
    case kDecodeCodecRv10:
        return AV_CODEC_ID_RV10;
    case kDecodeCodecRv20:
        return AV_CODEC_ID_RV20;
    case kDecodeCodecRv30:
        return AV_CODEC_ID_RV30;
    case kDecodeCodecRv40:
        return AV_CODEC_ID_RV40;
    case kDecodeCodecMpeg1:
        return AV_CODEC_ID_MPEG1VIDEO;
    case kDecodeCodecCook:
        return AV_CODEC_ID_COOK;
    case kDecodeCodecSipr:
        return AV_CODEC_ID_SIPR;
    case kDecodeCodecAtrac3:
        return AV_CODEC_ID_ATRAC3;
    case kDecodeCodecAac:
        return AV_CODEC_ID_AAC;
    case kDecodeCodecRa144:
        return AV_CODEC_ID_RA_144;
    case kDecodeCodecRa288:
        return AV_CODEC_ID_RA_288;
    case kDecodeCodecWmav1:
        return AV_CODEC_ID_WMAV1;
    case kDecodeCodecWmav2:
        return AV_CODEC_ID_WMAV2;
    case kDecodeCodecAmrNb:
        return AV_CODEC_ID_AMR_NB;
    case kDecodeCodecAmrWb:
        return AV_CODEC_ID_AMR_WB;
    case kDecodeCodecNellymoser:
        return AV_CODEC_ID_NELLYMOSER;
    case kDecodeCodecQdm2:
        return AV_CODEC_ID_QDM2;
    case kDecodeCodecEac3:
        return AV_CODEC_ID_EAC3;
    case kDecodeCodecTruehd:
        return AV_CODEC_ID_TRUEHD;
    case kDecodeCodecMlp:
        return AV_CODEC_ID_MLP;
    case kDecodeCodecFlac:
        return AV_CODEC_ID_FLAC;
    case kDecodeCodecPcmMulaw:
        return AV_CODEC_ID_PCM_MULAW;
    case kDecodeCodecAdpcmImaQt:
        return AV_CODEC_ID_ADPCM_IMA_QT;
    default:
        return AV_CODEC_ID_NONE;
    }
}

AVCodecContext* AsContext(void* value)
{
    return static_cast<AVCodecContext*>(value);
}

AVPacket* AsPacket(void* value)
{
    return static_cast<AVPacket*>(value);
}

AVFrame* AsFrame(void* value)
{
    return static_cast<AVFrame*>(value);
}

bool IsAvcDecoderConfigurationRecord(const uint8_t* extraData, size_t extraDataSize)
{
    return extraData && extraDataSize >= 5 && extraData[0] == 1;
}

int H264NalLengthSizeFromExtradata(const uint8_t* extraData, size_t extraDataSize)
{
    if (!IsAvcDecoderConfigurationRecord(extraData, extraDataSize)) {
        return kUnknownH264NalLengthSize;
    }

    return (extraData[4] & 0x03) + 1;
}

bool StartsWithAnnexBStartCode(const uint8_t* data, size_t dataSize)
{
    if (!data || dataSize < 4) {
        return false;
    }

    return (data[0] == 0 && data[1] == 0 && data[2] == 1) ||
        (data[0] == 0 && data[1] == 0 && data[2] == 0 && data[3] == 1);
}

bool ConvertAvcLengthPrefixedToAnnexB(const uint8_t* data, size_t dataSize, int nalLengthSize, std::vector<uint8_t>* output)
{
    if (!data || !output || nalLengthSize < 1 || nalLengthSize > 4) {
        return false;
    }

    output->clear();
    size_t offset = 0;
    while (offset < dataSize) {
        if (dataSize - offset < static_cast<size_t>(nalLengthSize)) {
            return false;
        }

        uint32_t nalSize = 0;
        for (int i = 0; i < nalLengthSize; ++i) {
            nalSize = (nalSize << 8) | data[offset + i];
        }
        offset += nalLengthSize;

        if (nalSize == 0 || dataSize - offset < nalSize) {
            return false;
        }

        output->insert(output->end(), kAnnexBStartCode, kAnnexBStartCode + sizeof(kAnnexBStartCode));
        output->insert(output->end(), data + offset, data + offset + nalSize);
        offset += nalSize;
    }

    return !output->empty();
}

uint8_t H264NalType(uint8_t nalHeader)
{
    return nalHeader & 0x1f;
}

bool IsH264VclNalType(uint8_t nalType)
{
    return nalType >= 1 && nalType <= 5;
}

bool H264NalStartsNewSlice(const uint8_t* nalData, size_t nalSize)
{
    if (!nalData || nalSize < 2 || !IsH264VclNalType(H264NalType(nalData[0]))) {
        return false;
    }

    // The first Exp-Golomb value after the NAL header is first_mb_in_slice.
    // For the common new-frame case it is zero, encoded as a single '1' bit.
    return (nalData[1] & 0x80) != 0;
}

bool ContainsAvcLengthPrefixedVclNal(const uint8_t* data, size_t dataSize, int nalLengthSize)
{
    if (!data || nalLengthSize < 1 || nalLengthSize > 4) {
        return true;
    }

    size_t offset = 0;
    while (offset < dataSize) {
        if (dataSize - offset < static_cast<size_t>(nalLengthSize)) {
            return true;
        }

        uint32_t nalSize = 0;
        for (int i = 0; i < nalLengthSize; ++i) {
            nalSize = (nalSize << 8) | data[offset + i];
        }
        offset += nalLengthSize;
        if (nalSize == 0 || dataSize - offset < nalSize) {
            return true;
        }

        if (IsH264VclNalType(H264NalType(data[offset]))) {
            return true;
        }
        offset += nalSize;
    }

    return false;
}

bool AvcLengthPrefixedStartsNewVclSlice(const uint8_t* data, size_t dataSize, int nalLengthSize)
{
    if (!data || nalLengthSize < 1 || nalLengthSize > 4) {
        return false;
    }

    size_t offset = 0;
    while (offset < dataSize) {
        if (dataSize - offset < static_cast<size_t>(nalLengthSize)) {
            return false;
        }

        uint32_t nalSize = 0;
        for (int i = 0; i < nalLengthSize; ++i) {
            nalSize = (nalSize << 8) | data[offset + i];
        }
        offset += nalLengthSize;
        if (nalSize == 0 || dataSize - offset < nalSize) {
            return false;
        }

        if (H264NalStartsNewSlice(data + offset, nalSize)) {
            return true;
        }
        offset += nalSize;
    }

    return false;
}

int DetectH264NalLengthSize(const uint8_t* data, size_t dataSize)
{
    if (!data || dataSize < 2 || StartsWithAnnexBStartCode(data, dataSize)) {
        return kUnknownH264NalLengthSize;
    }

    const int candidates[] = { 4, 2, 1 };
    for (size_t candidateIndex = 0; candidateIndex < sizeof(candidates) / sizeof(candidates[0]); ++candidateIndex) {
        const int nalLengthSize = candidates[candidateIndex];
        size_t offset = 0;
        bool foundNal = false;
        while (offset < dataSize) {
            if (dataSize - offset < static_cast<size_t>(nalLengthSize)) {
                foundNal = false;
                break;
            }

            uint32_t nalSize = 0;
            for (int i = 0; i < nalLengthSize; ++i) {
                nalSize = (nalSize << 8) | data[offset + i];
            }
            offset += nalLengthSize;
            if (nalSize == 0 || dataSize - offset < nalSize) {
                foundNal = false;
                break;
            }

            foundNal = true;
            offset += nalSize;
        }

        if (foundNal && offset == dataSize) {
            return nalLengthSize;
        }
    }

    return kUnknownH264NalLengthSize;
}

bool AppendAvcParameterSet(const uint8_t* extraData, size_t extraDataSize, size_t* offset, std::vector<uint8_t>* output)
{
    if (!extraData || !offset || !output || extraDataSize - *offset < 2) {
        return false;
    }

    const uint16_t nalSize = (static_cast<uint16_t>(extraData[*offset]) << 8) | extraData[*offset + 1];
    *offset += 2;
    if (nalSize == 0 || extraDataSize - *offset < nalSize) {
        return false;
    }

    output->insert(output->end(), kAnnexBStartCode, kAnnexBStartCode + sizeof(kAnnexBStartCode));
    output->insert(output->end(), extraData + *offset, extraData + *offset + nalSize);
    *offset += nalSize;
    return true;
}

bool ConvertAvcConfigurationToAnnexB(const uint8_t* extraData, size_t extraDataSize, std::vector<uint8_t>* output)
{
    if (!IsAvcDecoderConfigurationRecord(extraData, extraDataSize) || !output) {
        return false;
    }

    output->clear();
    size_t offset = 5;
    if (extraDataSize - offset < 1) {
        return false;
    }

    const uint8_t spsCount = extraData[offset++] & 0x1f;
    for (uint8_t i = 0; i < spsCount; ++i) {
        if (!AppendAvcParameterSet(extraData, extraDataSize, &offset, output)) {
            return false;
        }
    }

    if (extraDataSize - offset < 1) {
        return false;
    }

    const uint8_t ppsCount = extraData[offset++];
    for (uint8_t i = 0; i < ppsCount; ++i) {
        if (!AppendAvcParameterSet(extraData, extraDataSize, &offset, output)) {
            return false;
        }
    }

    return !output->empty();
}

bool ConvertLengthPrefixedParameterSetsToAnnexB(const uint8_t* extraData, size_t extraDataSize, std::vector<uint8_t>* output)
{
    if (!extraData || !output || extraDataSize < 3 || StartsWithAnnexBStartCode(extraData, extraDataSize)) {
        return false;
    }

    output->clear();
    size_t offset = 0;
    while (offset < extraDataSize) {
        if (extraDataSize - offset < 2) {
            return false;
        }

        const uint16_t nalSize = (static_cast<uint16_t>(extraData[offset]) << 8) | extraData[offset + 1];
        offset += 2;
        if (nalSize == 0 || extraDataSize - offset < nalSize) {
            return false;
        }

        const uint8_t nalType = H264NalType(extraData[offset]);
        if (nalType != 7 && nalType != 8) {
            return false;
        }

        output->insert(output->end(), kAnnexBStartCode, kAnnexBStartCode + sizeof(kAnnexBStartCode));
        output->insert(output->end(), extraData + offset, extraData + offset + nalSize);
        offset += nalSize;
    }

    return !output->empty();
}

void CopyFrameInfo(const AVFrame* frame, DecodedFrameInfo* frameInfo)
{
    if (!frameInfo) {
        return;
    }

    frameInfo->width = frame->width;
    frameInfo->height = frame->height;
    frameInfo->pixelFormat = frame->format;
    frameInfo->pts = frame->best_effort_timestamp != AV_NOPTS_VALUE ? frame->best_effort_timestamp : frame->pts;
    frameInfo->duration = frame->duration > 0 ? frame->duration : kNoPts;
    for (int i = 0; i < 4; ++i) {
        frameInfo->data[i] = frame->data[i];
        frameInfo->linesize[i] = frame->linesize[i];
    }
}

} // namespace

DecodeSession::DecodeSession(DecodeCodec codec)
    : codec_(codec)
    , codecContext_(0)
    , parser_(0)
    , packet_(0)
    , frame_(0)
    , parsedPendingPts_(kNoPts)
    , parsedPendingDuration_(kNoPts)
    , pendingPacketPts_(kNoPts)
    , pendingPacketDuration_(kNoPts)
    , h264NalLengthSize_(kUnknownH264NalLengthSize)
    , h264PendingPts_(0)
    , h264ExtraDataPrepended_(false)
    , h264UseNativeAvc_(false)
    , h264HasPendingVcl_(false)
    , hasDecodedFrame_(false)
{
    lastError_[0] = '\0';
    h264PendingDuration_ = kNoPts;
}

DecodeSession::~DecodeSession()
{
    AVCodecContext* context = AsContext(codecContext_);
    AVCodecParserContext* parser = static_cast<AVCodecParserContext*>(parser_);
    AVPacket* packet = AsPacket(packet_);
    AVFrame* frame = AsFrame(frame_);

    av_parser_close(parser);
    avcodec_free_context(&context);
    av_packet_free(&packet);
    av_frame_free(&frame);

    codecContext_ = 0;
    parser_ = 0;
    packet_ = 0;
    frame_ = 0;
    parsedPendingInput_.clear();
    parsedPendingPts_ = kNoPts;
    parsedPendingDuration_ = kNoPts;
    pendingPacket_.clear();
    pendingPacketPts_ = kNoPts;
    pendingPacketDuration_ = kNoPts;
    h264NalLengthSize_ = kUnknownH264NalLengthSize;
    h264AnnexBExtraData_.clear();
    h264PendingAccessUnit_.clear();
    h264PendingPts_ = 0;
    h264PendingDuration_ = kNoPts;
    h264ExtraDataPrepended_ = false;
    h264UseNativeAvc_ = false;
    h264HasPendingVcl_ = false;
    hasDecodedFrame_ = false;
}

bool DecodeSession::Open()
{
    return OpenWithExtradata(0, 0);
}

bool DecodeSession::OpenWithExtradata(const uint8_t* extraData, size_t extraDataSize)
{
    return OpenWithH264NalLengthSize(extraData, extraDataSize, kUnknownH264NalLengthSize);
}

bool DecodeSession::IsAudioCodec() const
{
    return IsBridgeAudioCodec(codec_);
}

bool DecodeSession::OpenWithAudioParams(const AudioOpenParams& params)
{
    if (!IsAudioCodec()) {
        SetError("OpenWithAudioParams requires an audio codec");
        return false;
    }

    const AVCodec* codec = avcodec_find_decoder(ToAvCodecId(codec_));
    if (!codec) {
        SetError("FFmpeg audio decoder is not available");
        return false;
    }

    AVCodecContext* context = avcodec_alloc_context3(codec);
    if (!context) {
        SetError("Failed to allocate AVCodecContext for audio");
        return false;
    }

    if (params.extraData && params.extraDataSize > 0) {
        if (params.extraDataSize > static_cast<size_t>(INT_MAX)) {
            avcodec_free_context(&context);
            SetError("Audio codec extradata is too large");
            return false;
        }
        context->extradata = static_cast<uint8_t*>(av_mallocz(params.extraDataSize + AV_INPUT_BUFFER_PADDING_SIZE));
        if (!context->extradata) {
            avcodec_free_context(&context);
            SetError("Failed to allocate audio codec extradata");
            return false;
        }
        memcpy(context->extradata, params.extraData, params.extraDataSize);
        context->extradata_size = static_cast<int>(params.extraDataSize);
    }

    context->sample_rate = params.sampleRate > 0 ? params.sampleRate : 0;
    context->ch_layout.nb_channels = params.channels > 0 ? params.channels : 0;
    if (params.channels > 0) {
        av_channel_layout_default(&context->ch_layout, params.channels);
    }
    context->bit_rate = params.bitRate > 0 ? params.bitRate : 0;
    context->bits_per_coded_sample = params.bitsPerCodedSample > 0 ? params.bitsPerCodedSample : 0;
    context->block_align = params.blockAlign > 0 ? params.blockAlign : 0;
    context->pkt_timebase = kDirectShowTimeBase;

    const int openResult = avcodec_open2(context, codec, 0);
    if (openResult < 0) {
        avcodec_free_context(&context);
        SetAvError("avcodec_open2(audio)", openResult);
        return false;
    }

    AVPacket* packet = av_packet_alloc();
    if (!packet) {
        avcodec_free_context(&context);
        SetError("Failed to allocate AVPacket for audio");
        return false;
    }

    AVFrame* frame = av_frame_alloc();
    if (!frame) {
        av_packet_free(&packet);
        avcodec_free_context(&context);
        SetError("Failed to allocate AVFrame for audio");
        return false;
    }

    codecContext_ = context;
    packet_ = packet;
    frame_ = frame;
    parser_ = 0;
    lastError_[0] = '\0';
    return true;
}

bool DecodeSession::OpenWithH264NalLengthSize(const uint8_t* extraData, size_t extraDataSize, int h264NalLengthSize)
{
    const AVCodec* codec = avcodec_find_decoder(ToAvCodecId(codec_));
    if (!codec) {
        SetError("FFmpeg decoder is not available");
        return false;
    }

    AVCodecContext* context = avcodec_alloc_context3(codec);
    if (!context) {
        SetError("Failed to allocate AVCodecContext");
        return false;
    }

    std::vector<uint8_t> annexBExtraData;
    const uint8_t* contextExtraData = extraData;
    size_t contextExtraDataSize = extraDataSize;
    const int parsedH264NalLengthSize = codec_ == kDecodeCodecH264 ? H264NalLengthSizeFromExtradata(extraData, extraDataSize) : kUnknownH264NalLengthSize;
    const bool h264UseNativeAvc = false;
    if (codec_ == kDecodeCodecH264 && !h264UseNativeAvc) {
        if (ConvertAvcConfigurationToAnnexB(extraData, extraDataSize, &annexBExtraData) ||
            ConvertLengthPrefixedParameterSetsToAnnexB(extraData, extraDataSize, &annexBExtraData)) {
            contextExtraData = &annexBExtraData[0];
            contextExtraDataSize = annexBExtraData.size();
        }
    }

    if (contextExtraData && contextExtraDataSize > 0) {
        if (contextExtraDataSize > static_cast<size_t>(INT_MAX)) {
            avcodec_free_context(&context);
            SetError("Codec extradata is too large");
            return false;
        }
        context->extradata = static_cast<uint8_t*>(av_mallocz(contextExtraDataSize + AV_INPUT_BUFFER_PADDING_SIZE));
        if (!context->extradata) {
            avcodec_free_context(&context);
            SetError("Failed to allocate codec extradata");
            return false;
        }
        memcpy(context->extradata, contextExtraData, contextExtraDataSize);
        context->extradata_size = static_cast<int>(contextExtraDataSize);
    }
    if (codec_ == kDecodeCodecH264) {
        context->flags2 |= AV_CODEC_FLAG2_CHUNKS;
    }
    context->pkt_timebase = kDirectShowTimeBase;

    const int openResult = avcodec_open2(context, codec, 0);
    if (openResult < 0) {
        avcodec_free_context(&context);
        SetAvError("avcodec_open2", openResult);
        return false;
    }

    AVCodecParserContext* parser = 0;
    if (codec_ == kDecodeCodecH264 || codec_ == kDecodeCodecMpeg2 || codec_ == kDecodeCodecVc1 || codec_ == kDecodeCodecWmv3) {
        parser = av_parser_init(codec->id);
    }

    AVPacket* packet = av_packet_alloc();
    if (!packet) {
        av_parser_close(parser);
        avcodec_free_context(&context);
        SetError("Failed to allocate AVPacket");
        return false;
    }

    AVFrame* frame = av_frame_alloc();
    if (!frame) {
        av_parser_close(parser);
        av_packet_free(&packet);
        avcodec_free_context(&context);
        SetError("Failed to allocate AVFrame");
        return false;
    }

    codecContext_ = context;
    parser_ = parser;
    packet_ = packet;
    frame_ = frame;
    parsedPendingInput_.clear();
    parsedPendingPts_ = kNoPts;
    parsedPendingDuration_ = kNoPts;
    pendingPacket_.clear();
    pendingPacketPts_ = kNoPts;
    pendingPacketDuration_ = kNoPts;
    h264NalLengthSize_ = kUnknownH264NalLengthSize;
    h264AnnexBExtraData_.clear();
    h264PendingAccessUnit_.clear();
    h264PendingPts_ = 0;
    h264PendingDuration_ = kNoPts;
    h264ExtraDataPrepended_ = false;
    h264UseNativeAvc_ = false;
    h264HasPendingVcl_ = false;
    hasDecodedFrame_ = false;
    if (codec_ == kDecodeCodecH264) {
        h264UseNativeAvc_ = h264UseNativeAvc;
        if (h264NalLengthSize >= 1 && h264NalLengthSize <= 4) {
            h264NalLengthSize_ = h264NalLengthSize;
        } else {
            h264NalLengthSize_ = parsedH264NalLengthSize;
        }
        if (!annexBExtraData.empty()) {
            h264AnnexBExtraData_ = annexBExtraData;
        } else if (StartsWithAnnexBStartCode(extraData, extraDataSize)) {
            h264AnnexBExtraData_.assign(extraData, extraData + extraDataSize);
        }
    }
    lastError_[0] = '\0';
    return true;
}

DecodeStatus DecodeSession::Decode(const uint8_t* data, size_t dataSize, DecodedFrameInfo* frameInfo)
{
    return DecodeWithPts(data, dataSize, kNoPts, frameInfo);
}

DecodeStatus DecodeSession::DecodeWithPts(const uint8_t* data, size_t dataSize, int64_t pts, DecodedFrameInfo* frameInfo)
{
    return DecodeWithTiming(data, dataSize, pts, kNoPts, frameInfo);
}

DecodeStatus DecodeSession::DecodeWithTiming(const uint8_t* data, size_t dataSize, int64_t pts, int64_t duration, DecodedFrameInfo* frameInfo)
{
    AVCodecContext* context = AsContext(codecContext_);
    AVCodecParserContext* parser = static_cast<AVCodecParserContext*>(parser_);
    if (!context) {
        SetError("DecodeSession is not open");
        return kDecodeStatusFailure;
    }
    if (!data || dataSize == 0) {
        SetError("Decode input is empty");
        return kDecodeStatusFailure;
    }
    if (dataSize > static_cast<size_t>(INT_MAX)) {
        SetError("Decode input is too large");
        return kDecodeStatusFailure;
    }
	if (!pendingPacket_.empty()) {
		SaveParsedPendingInput(data, static_cast<int>(dataSize), pts, duration);
		return SendStoredPendingPacket(frameInfo);
	}

    if (codec_ == kDecodeCodecH264) {
        return SendH264Packet(data, dataSize, pts, duration, frameInfo);
    }

    if (!parser) {
        return SendPacket(data, dataSize, pts, duration, frameInfo);
    }

    return SendParsedPacket(data, dataSize, pts, duration, frameInfo);
}

DecodeStatus DecodeSession::SendPacket(const uint8_t* data, size_t dataSize, int64_t pts, int64_t duration, DecodedFrameInfo* frameInfo)
{
    AVCodecContext* context = AsContext(codecContext_);
    AVPacket* packet = AsPacket(packet_);
    if (!context || !packet) {
        SetError("DecodeSession is not open");
        return kDecodeStatusFailure;
    }

    av_packet_unref(packet);
    const int packetResult = av_new_packet(packet, static_cast<int>(dataSize));
    if (packetResult < 0) {
        SetAvError("av_new_packet", packetResult);
        return kDecodeStatusFailure;
    }

    memcpy(packet->data, data, dataSize);
    packet->pts = pts;
    packet->dts = AV_NOPTS_VALUE;
    packet->duration = duration > 0 ? duration : 0;
    const int sendResult = avcodec_send_packet(context, packet);
    if (sendResult == AVERROR(EAGAIN)) {
		SavePendingPacket(data, dataSize, pts, duration);
		av_packet_unref(packet);
        return ReceiveFrame(frameInfo);
    }
	av_packet_unref(packet);
    if (sendResult < 0) {
        if (codec_ == kDecodeCodecH264 && !hasDecodedFrame_ && sendResult == AVERROR_INVALIDDATA) {
            SetAvError("avcodec_send_packet", sendResult);
            return kDecodeStatusNeedMoreInput;
        }
        SetAvError("avcodec_send_packet", sendResult);
        return kDecodeStatusFailure;
    }

    return ReceiveFrame(frameInfo);
}

DecodeStatus DecodeSession::SendStoredPendingPacket(DecodedFrameInfo* frameInfo)
{
	if (pendingPacket_.empty()) {
		return kDecodeStatusNeedMoreInput;
	}

	std::vector<uint8_t> packet;
	packet.swap(pendingPacket_);
	const int64_t pts = pendingPacketPts_;
	const int64_t duration = pendingPacketDuration_;
	pendingPacketPts_ = kNoPts;
	pendingPacketDuration_ = kNoPts;
	return SendPacket(&packet[0], packet.size(), pts, duration, frameInfo);
}

DecodeStatus DecodeSession::SendParsedPacket(const uint8_t* data, size_t dataSize, int64_t pts, int64_t duration, DecodedFrameInfo* frameInfo)
{
    AVCodecContext* context = AsContext(codecContext_);
    AVCodecParserContext* parser = static_cast<AVCodecParserContext*>(parser_);
    if (!context || !parser) {
        return SendPacket(data, dataSize, pts, duration, frameInfo);
    }
    if (dataSize > static_cast<size_t>(INT_MAX)) {
        SetError("Decode input is too large");
        return kDecodeStatusFailure;
    }

    std::vector<uint8_t> combinedInput;
    const uint8_t* input = data;
    int inputSize = static_cast<int>(dataSize);
    if (!parsedPendingInput_.empty()) {
        combinedInput = parsedPendingInput_;
        combinedInput.insert(combinedInput.end(), data, data + dataSize);
        input = &combinedInput[0];
        inputSize = static_cast<int>(combinedInput.size());
        pts = parsedPendingPts_;
        duration = parsedPendingDuration_;
        parsedPendingInput_.clear();
        parsedPendingPts_ = kNoPts;
        parsedPendingDuration_ = kNoPts;
    }

    bool sentPacket = false;
    while (inputSize > 0) {
        uint8_t* parsedData = 0;
        int parsedSize = 0;
        const int used = av_parser_parse2(parser, context, &parsedData, &parsedSize, input, inputSize, pts, AV_NOPTS_VALUE, AV_NOPTS_VALUE);
        if (used < 0) {
            SetAvError("av_parser_parse2", used);
            return kDecodeStatusFailure;
        }

        input += used;
        inputSize -= used;
        if (parsedSize > 0) {
            sentPacket = true;
            const DecodeStatus status = SendPacket(parsedData, static_cast<size_t>(parsedSize), pts, duration, frameInfo);
            if (status == kDecodeStatusFrameReady || status == kDecodeStatusFailure) {
                SaveParsedPendingInput(input, inputSize, pts, duration);
                return status;
            }
        }
        if (used == 0 && parsedSize == 0) {
            break;
        }
    }

    if (!sentPacket && codec_ == kDecodeCodecH264) {
        uint8_t* parsedData = 0;
        int parsedSize = 0;
        const int used = av_parser_parse2(parser, context, &parsedData, &parsedSize, 0, 0, pts, AV_NOPTS_VALUE, AV_NOPTS_VALUE);
        if (used < 0) {
            SetAvError("av_parser_parse2", used);
            return kDecodeStatusFailure;
        }
        if (parsedSize > 0) {
            sentPacket = true;
            const DecodeStatus status = SendPacket(parsedData, static_cast<size_t>(parsedSize), pts, duration, frameInfo);
            if (status == kDecodeStatusFrameReady || status == kDecodeStatusFailure) {
                return status;
            }
        }
    }

    return sentPacket ? ReceiveFrame(frameInfo) : kDecodeStatusNeedMoreInput;
}

void DecodeSession::SaveParsedPendingInput(const uint8_t* data, int dataSize, int64_t pts, int64_t duration)
{
    if (!data || dataSize <= 0) {
        return;
    }

    parsedPendingInput_.assign(data, data + dataSize);
    parsedPendingPts_ = pts;
    parsedPendingDuration_ = duration;
}

void DecodeSession::SavePendingPacket(const uint8_t* data, size_t dataSize, int64_t pts, int64_t duration)
{
	if (!data || dataSize == 0) {
		return;
	}

	pendingPacket_.assign(data, data + dataSize);
	pendingPacketPts_ = pts;
	pendingPacketDuration_ = duration;
}

DecodeStatus DecodeSession::SendH264Packet(const uint8_t* data, size_t dataSize, int64_t pts, int64_t duration, DecodedFrameInfo* frameInfo)
{
    if (h264UseNativeAvc_) {
        return SendPacket(data, dataSize, pts, duration, frameInfo);
    }

    if (StartsWithAnnexBStartCode(data, dataSize)) {
        if (!h264ExtraDataPrepended_ && !h264AnnexBExtraData_.empty()) {
            std::vector<uint8_t> packetWithExtraData = h264AnnexBExtraData_;
            packetWithExtraData.insert(packetWithExtraData.end(), data, data + dataSize);
            h264ExtraDataPrepended_ = true;
            return SendParsedPacket(&packetWithExtraData[0], packetWithExtraData.size(), pts, duration, frameInfo);
        }
        return SendParsedPacket(data, dataSize, pts, duration, frameInfo);
    }

    const int nalLengthSize = h264NalLengthSize_ != kUnknownH264NalLengthSize ?
        h264NalLengthSize_ :
        DetectH264NalLengthSize(data, dataSize);
    if (nalLengthSize == kUnknownH264NalLengthSize) {
        return SendPacket(data, dataSize, pts, duration, frameInfo);
    }
    if (!ContainsAvcLengthPrefixedVclNal(data, dataSize, nalLengthSize)) {
        return kDecodeStatusNeedMoreInput;
    }
    const bool startsNewSlice = AvcLengthPrefixedStartsNewVclSlice(data, dataSize, nalLengthSize);

    std::vector<uint8_t> annexBPacket;
    if (!ConvertAvcLengthPrefixedToAnnexB(data, dataSize, nalLengthSize, &annexBPacket)) {
        return SendPacket(data, dataSize, pts, duration, frameInfo);
    }
    if (!h264ExtraDataPrepended_ && !h264AnnexBExtraData_.empty()) {
        annexBPacket.insert(annexBPacket.begin(), h264AnnexBExtraData_.begin(), h264AnnexBExtraData_.end());
        h264ExtraDataPrepended_ = true;
    }
    if (pts != kNoPts) {
        return SendPacket(&annexBPacket[0], annexBPacket.size(), pts, duration, frameInfo);
    }

    if (h264HasPendingVcl_ && startsNewSlice) {
        std::vector<uint8_t> readyAccessUnit;
        readyAccessUnit.swap(h264PendingAccessUnit_);
        h264PendingAccessUnit_.insert(h264PendingAccessUnit_.end(), annexBPacket.begin(), annexBPacket.end());
        const int64_t readyPts = h264PendingPts_;
        const int64_t readyDuration = h264PendingDuration_;
        h264PendingPts_ = pts;
        h264PendingDuration_ = duration;
        h264HasPendingVcl_ = true;
        return SendParsedPacket(&readyAccessUnit[0], readyAccessUnit.size(), readyPts, readyDuration, frameInfo);
    }

    if (h264PendingAccessUnit_.empty()) {
        h264PendingPts_ = pts;
        h264PendingDuration_ = duration;
    }
    h264PendingAccessUnit_.insert(h264PendingAccessUnit_.end(), annexBPacket.begin(), annexBPacket.end());
    h264HasPendingVcl_ = true;
    return kDecodeStatusNeedMoreInput;
}

DecodeStatus DecodeSession::ReceivePending(DecodedFrameInfo* frameInfo)
{
    return ReceiveFrame(frameInfo);
}

DecodeStatus DecodeSession::Drain(DecodedFrameInfo* frameInfo)
{
    AVCodecContext* context = AsContext(codecContext_);
    if (!context) {
        SetError("DecodeSession is not open");
        return kDecodeStatusFailure;
    }

    const int sendResult = avcodec_send_packet(context, 0);
    if (sendResult < 0 && sendResult != AVERROR_EOF) {
        SetAvError("avcodec_send_packet(NULL)", sendResult);
        return kDecodeStatusFailure;
    }

    return ReceiveFrame(frameInfo);
}

void DecodeSession::Flush()
{
    AVCodecContext* context = AsContext(codecContext_);
    if (context) {
        avcodec_flush_buffers(context);
    }
    parsedPendingInput_.clear();
    parsedPendingPts_ = kNoPts;
    parsedPendingDuration_ = kNoPts;
	pendingPacket_.clear();
	pendingPacketPts_ = kNoPts;
	pendingPacketDuration_ = kNoPts;
    h264PendingAccessUnit_.clear();
    h264PendingPts_ = 0;
    h264PendingDuration_ = kNoPts;
    h264ExtraDataPrepended_ = false;
    h264HasPendingVcl_ = false;
    hasDecodedFrame_ = false;
}

const char* DecodeSession::LastError() const
{
    return lastError_;
}

DecodeStatus DecodeSession::ReceiveFrame(DecodedFrameInfo* frameInfo)
{
    AVCodecContext* context = AsContext(codecContext_);
    AVFrame* frame = AsFrame(frame_);
    if (!context || !frame) {
        SetError("DecodeSession is not open");
        return kDecodeStatusFailure;
    }

    av_frame_unref(frame);
    const int receiveResult = avcodec_receive_frame(context, frame);
    if (receiveResult == 0) {
        hasDecodedFrame_ = true;
        CopyFrameInfo(frame, frameInfo);
        return kDecodeStatusFrameReady;
    }
    if (receiveResult == AVERROR(EAGAIN)) {
        return kDecodeStatusNeedMoreInput;
    }
    if (receiveResult == AVERROR_EOF) {
        return kDecodeStatusEndOfStream;
    }

    SetAvError("avcodec_receive_frame", receiveResult);
    return kDecodeStatusFailure;
}

namespace {

int16_t ClampFloatToS16(float sample)
{
    if (sample > 1.0f) {
        sample = 1.0f;
    } else if (sample < -1.0f) {
        sample = -1.0f;
    }
    return static_cast<int16_t>(sample * 32767.0f);
}

} // namespace

bool DecodeSession::PackAudioFrameToS16(const void* rawFrame, DecodedAudioFrameInfo* frameInfo)
{
    const AVFrame* frame = static_cast<const AVFrame*>(rawFrame);
    if (!frame || !frameInfo) {
        SetError("Invalid audio frame");
        return false;
    }

    const int channels = frame->ch_layout.nb_channels;
    if (channels <= 0 || frame->nb_samples <= 0) {
        SetError("Audio frame has no samples");
        return false;
    }

    const size_t sampleCount = static_cast<size_t>(frame->nb_samples) * static_cast<size_t>(channels);
    audioPcmBuffer_.resize(sampleCount * sizeof(int16_t));
    int16_t* output = reinterpret_cast<int16_t*>(&audioPcmBuffer_[0]);

    if (frame->format == AV_SAMPLE_FMT_S16) {
        memcpy(output, frame->data[0], sampleCount * sizeof(int16_t));
    } else if (frame->format == AV_SAMPLE_FMT_FLT) {
        const float* input = reinterpret_cast<const float*>(frame->data[0]);
        for (size_t i = 0; i < sampleCount; ++i) {
            output[i] = ClampFloatToS16(input[i]);
        }
    } else if (frame->format == AV_SAMPLE_FMT_FLTP) {
        for (int sampleIndex = 0; sampleIndex < frame->nb_samples; ++sampleIndex) {
            for (int channel = 0; channel < channels; ++channel) {
                const float* plane = reinterpret_cast<const float*>(frame->extended_data[channel]);
                output[static_cast<size_t>(sampleIndex) * static_cast<size_t>(channels) + static_cast<size_t>(channel)] =
                    ClampFloatToS16(plane[sampleIndex]);
            }
        }
    } else if (frame->format == AV_SAMPLE_FMT_S16P) {
        for (int sampleIndex = 0; sampleIndex < frame->nb_samples; ++sampleIndex) {
            for (int channel = 0; channel < channels; ++channel) {
                const int16_t* plane = reinterpret_cast<const int16_t*>(frame->extended_data[channel]);
                output[static_cast<size_t>(sampleIndex) * static_cast<size_t>(channels) + static_cast<size_t>(channel)] =
                    plane[sampleIndex];
            }
        }
    } else {
        SetError("Unsupported audio sample format");
        return false;
    }

    frameInfo->sampleRate = frame->sample_rate;
    frameInfo->channels = channels;
    frameInfo->sampleFormat = kSampleFormatS16;
    frameInfo->nbSamples = frame->nb_samples;
    frameInfo->pts = frame->pts;
    frameInfo->data = &audioPcmBuffer_[0];
    frameInfo->dataSize = static_cast<int>(audioPcmBuffer_.size());
    return true;
}

DecodeStatus DecodeSession::ReceiveAudioFrame(DecodedAudioFrameInfo* frameInfo)
{
    AVCodecContext* context = AsContext(codecContext_);
    AVFrame* frame = AsFrame(frame_);
    if (!context || !frame) {
        SetError("DecodeSession is not open");
        return kDecodeStatusFailure;
    }

    av_frame_unref(frame);
    const int receiveResult = avcodec_receive_frame(context, frame);
    if (receiveResult == 0) {
        hasDecodedFrame_ = true;
        if (!PackAudioFrameToS16(frame, frameInfo)) {
            return kDecodeStatusFailure;
        }
        return kDecodeStatusFrameReady;
    }
    if (receiveResult == AVERROR(EAGAIN)) {
        return kDecodeStatusNeedMoreInput;
    }
    if (receiveResult == AVERROR_EOF) {
        return kDecodeStatusEndOfStream;
    }

    SetAvError("avcodec_receive_frame(audio)", receiveResult);
    return kDecodeStatusFailure;
}

DecodeStatus DecodeSession::DecodeAudio(const uint8_t* data, size_t dataSize, int64_t pts, DecodedAudioFrameInfo* frameInfo)
{
    AVCodecContext* context = AsContext(codecContext_);
    AVPacket* packet = AsPacket(packet_);
    if (!context || !packet || !IsAudioCodec()) {
        SetError("DecodeAudio requires an open audio session");
        return kDecodeStatusFailure;
    }

    av_packet_unref(packet);
    if (data && dataSize > 0) {
        if (av_new_packet(packet, static_cast<int>(dataSize)) < 0) {
            SetError("Failed to allocate audio packet");
            return kDecodeStatusFailure;
        }
        memcpy(packet->data, data, dataSize);
        packet->pts = pts;
        packet->dts = pts;
    }

    const int sendResult = avcodec_send_packet(context, (data && dataSize > 0) ? packet : 0);
    av_packet_unref(packet);
    if (sendResult < 0 && sendResult != AVERROR(EAGAIN)) {
        SetAvError("avcodec_send_packet(audio)", sendResult);
        return kDecodeStatusFailure;
    }

    return ReceiveAudioFrame(frameInfo);
}

DecodeStatus DecodeSession::ReceiveAudio(DecodedAudioFrameInfo* frameInfo)
{
    return ReceiveAudioFrame(frameInfo);
}

void DecodeSession::SetError(const char* message)
{
    if (!message) {
        message = "Unknown FFmpeg adapter error";
    }
    snprintf(lastError_, kLastErrorCapacity, "%s", message);
}

void DecodeSession::SetAvError(const char* operation, int errorCode)
{
    char errorText[AV_ERROR_MAX_STRING_SIZE] = { 0 };
    av_strerror(errorCode, errorText, sizeof(errorText));
    snprintf(lastError_, kLastErrorCapacity, "%s failed: %s", operation, errorText);
}

bool DecodeCodecFromFourcc(uint32_t fourcc, DecodeCodec* codec)
{
    if (!codec) {
        return false;
    }

    switch (fourcc) {
    case kFourccDIVX:
    case kFourccdivx:
    case kFourccXVID:
    case kFourccxvid:
    case kFourccXVIX:
    case kFourccxvix:
    case kFourccDX50:
    case kFourccdx50:
    case kFourccMP4V:
    case kFourccmp4v:
        *codec = kDecodeCodecMpeg4;
        return true;
    case kFourccFLV1:
    case kFourccflv1:
        *codec = kDecodeCodecFlv1;
        return true;
    case kFourccVP60:
    case kFourccvp60:
    case kFourccVP61:
    case kFourccvp61:
    case kFourccVP62:
    case kFourccvp62:
        *codec = kDecodeCodecVp6;
        return true;
    case kFourccVP6F:
    case kFourccvp6f:
    case kFourccFLV4:
    case kFourccflv4:
        *codec = kDecodeCodecVp6f;
        return true;
    case kFourccVP6A:
    case kFourccvp6a:
        *codec = kDecodeCodecVp6a;
        return true;
    case kFourccWMV1:
    case kFourccwmv1:
        *codec = kDecodeCodecWmv1;
        return true;
    case kFourccWMV2:
    case kFourccwmv2:
        *codec = kDecodeCodecWmv2;
        return true;
    case kFourccH264:
    case kFourcch264:
    case kFourccX264:
    case kFourccx264:
    case kFourccAVC1:
    case kFourccavc1:
    case kFourccDAVC:
    case kFourccdavc:
    case kFourccPAVC:
    case kFourccpavc:
        *codec = kDecodeCodecH264;
        return true;
    case kFourccMPG2:
    case kFourccmpg2:
    case kFourccMMES:
    case kFourccmmes:
        *codec = kDecodeCodecMpeg2;
        return true;
    case kFourccWMV3:
    case kFourccwmv3:
        *codec = kDecodeCodecWmv3;
        return true;
    case kFourccWVC1:
    case kFourccwvc1:
        *codec = kDecodeCodecVc1;
        return true;
    case kFourccRV10:
    case kFourccrv10:
        *codec = kDecodeCodecRv10;
        return true;
    case kFourccRV20:
    case kFourccrv20:
        *codec = kDecodeCodecRv20;
        return true;
    case kFourccRV30:
    case kFourccrv30:
        *codec = kDecodeCodecRv30;
        return true;
    case kFourccRV40:
    case kFourccrv40:
        *codec = kDecodeCodecRv40;
        return true;
    case kFourccMPG1:
    case kFourccmpg1:
    case kFourccMPEG:
    case kFourccmpeg:
        *codec = kDecodeCodecMpeg1;
        return true;
    default:
        return false;
    }
}

bool DecodeCodecFromModernAvCodecId(int codecId, DecodeCodec* codec)
{
    if (!codec) {
        return false;
    }

    switch (codecId) {
    case AV_CODEC_ID_MPEG4:
        *codec = kDecodeCodecMpeg4;
        return true;
    case AV_CODEC_ID_FLV1:
        *codec = kDecodeCodecFlv1;
        return true;
    case AV_CODEC_ID_VP6:
        *codec = kDecodeCodecVp6;
        return true;
    case AV_CODEC_ID_VP6F:
        *codec = kDecodeCodecVp6f;
        return true;
    case AV_CODEC_ID_VP6A:
        *codec = kDecodeCodecVp6a;
        return true;
    case AV_CODEC_ID_WMV1:
        *codec = kDecodeCodecWmv1;
        return true;
    case AV_CODEC_ID_WMV2:
        *codec = kDecodeCodecWmv2;
        return true;
    case AV_CODEC_ID_H264:
        *codec = kDecodeCodecH264;
        return true;
    case AV_CODEC_ID_MPEG2VIDEO:
        *codec = kDecodeCodecMpeg2;
        return true;
    case AV_CODEC_ID_WMV3:
        *codec = kDecodeCodecWmv3;
        return true;
    case AV_CODEC_ID_VC1:
        *codec = kDecodeCodecVc1;
        return true;
    case AV_CODEC_ID_RV10:
        *codec = kDecodeCodecRv10;
        return true;
    case AV_CODEC_ID_RV20:
        *codec = kDecodeCodecRv20;
        return true;
    case AV_CODEC_ID_RV30:
        *codec = kDecodeCodecRv30;
        return true;
    case AV_CODEC_ID_RV40:
        *codec = kDecodeCodecRv40;
        return true;
    case AV_CODEC_ID_MPEG1VIDEO:
        *codec = kDecodeCodecMpeg1;
        return true;
    case AV_CODEC_ID_COOK:
        *codec = kDecodeCodecCook;
        return true;
    case AV_CODEC_ID_SIPR:
        *codec = kDecodeCodecSipr;
        return true;
    case AV_CODEC_ID_ATRAC3:
        *codec = kDecodeCodecAtrac3;
        return true;
    case AV_CODEC_ID_AAC:
        *codec = kDecodeCodecAac;
        return true;
    case AV_CODEC_ID_RA_144:
        *codec = kDecodeCodecRa144;
        return true;
    case AV_CODEC_ID_RA_288:
        *codec = kDecodeCodecRa288;
        return true;
    case AV_CODEC_ID_WMAV1:
        *codec = kDecodeCodecWmav1;
        return true;
    case AV_CODEC_ID_WMAV2:
        *codec = kDecodeCodecWmav2;
        return true;
    case AV_CODEC_ID_AMR_NB:
        *codec = kDecodeCodecAmrNb;
        return true;
    case AV_CODEC_ID_AMR_WB:
        *codec = kDecodeCodecAmrWb;
        return true;
    case AV_CODEC_ID_NELLYMOSER:
        *codec = kDecodeCodecNellymoser;
        return true;
    case AV_CODEC_ID_QDM2:
        *codec = kDecodeCodecQdm2;
        return true;
    case AV_CODEC_ID_EAC3:
        *codec = kDecodeCodecEac3;
        return true;
    case AV_CODEC_ID_TRUEHD:
        *codec = kDecodeCodecTruehd;
        return true;
    case AV_CODEC_ID_MLP:
        *codec = kDecodeCodecMlp;
        return true;
    case AV_CODEC_ID_FLAC:
        *codec = kDecodeCodecFlac;
        return true;
    case AV_CODEC_ID_PCM_MULAW:
        *codec = kDecodeCodecPcmMulaw;
        return true;
    case AV_CODEC_ID_ADPCM_IMA_QT:
        *codec = kDecodeCodecAdpcmImaQt;
        return true;
    default:
        return false;
    }
}

bool IsFirstWaveSoftwareCodec(DecodeCodec codec)
{
    switch (codec) {
    case kDecodeCodecMpeg4:
    case kDecodeCodecFlv1:
    case kDecodeCodecVp6:
    case kDecodeCodecVp6f:
    case kDecodeCodecVp6a:
    case kDecodeCodecWmv1:
    case kDecodeCodecWmv2:
    case kDecodeCodecH264:
    case kDecodeCodecMpeg2:
    case kDecodeCodecWmv3:
    case kDecodeCodecVc1:
    case kDecodeCodecRv10:
    case kDecodeCodecRv20:
    case kDecodeCodecRv30:
    case kDecodeCodecRv40:
    case kDecodeCodecMpeg1:
        return true;
    default:
        return false;
    }
}

bool IsBridgeAudioCodec(DecodeCodec codec)
{
    switch (codec) {
    case kDecodeCodecCook:
    case kDecodeCodecSipr:
    case kDecodeCodecAtrac3:
    case kDecodeCodecAac:
    case kDecodeCodecRa144:
    case kDecodeCodecRa288:
    case kDecodeCodecWmav1:
    case kDecodeCodecWmav2:
    case kDecodeCodecAmrNb:
    case kDecodeCodecAmrWb:
    case kDecodeCodecNellymoser:
    case kDecodeCodecQdm2:
    case kDecodeCodecEac3:
    case kDecodeCodecTruehd:
    case kDecodeCodecMlp:
    case kDecodeCodecFlac:
    case kDecodeCodecPcmMulaw:
    case kDecodeCodecAdpcmImaQt:
        return true;
    default:
        return false;
    }
}

} // namespace ModernFfmpeg
