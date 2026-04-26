#include "ModernFfmpegDecodeAdapter.h"

#include <string.h>
#include <stdio.h>
#include <limits.h>

extern "C" {
#include "libavcodec/avcodec.h"
#include "libavutil/error.h"
#include "libavutil/frame.h"
#include "libavutil/mem.h"
}

namespace ModernFfmpeg {

namespace {

const size_t kLastErrorCapacity = 256;

const uint32_t kFourccDIVX = 'D' | ('I' << 8) | ('V' << 16) | ('X' << 24);
const uint32_t kFourccdivx = 'd' | ('i' << 8) | ('v' << 16) | ('x' << 24);
const uint32_t kFourccXVID = 'X' | ('V' << 8) | ('I' << 16) | ('D' << 24);
const uint32_t kFourccxvid = 'x' | ('v' << 8) | ('i' << 16) | ('d' << 24);
const uint32_t kFourccFLV1 = 'F' | ('L' << 8) | ('V' << 16) | ('1' << 24);
const uint32_t kFourccflv1 = 'f' | ('l' << 8) | ('v' << 16) | ('1' << 24);
const uint32_t kFourccVP60 = 'V' | ('P' << 8) | ('6' << 16) | ('0' << 24);
const uint32_t kFourccvp60 = 'v' | ('p' << 8) | ('6' << 16) | ('0' << 24);
const uint32_t kFourccWMV1 = 'W' | ('M' << 8) | ('V' << 16) | ('1' << 24);
const uint32_t kFourccwmv1 = 'w' | ('m' << 8) | ('v' << 16) | ('1' << 24);
const uint32_t kFourccWMV2 = 'W' | ('M' << 8) | ('V' << 16) | ('2' << 24);
const uint32_t kFourccwmv2 = 'w' | ('m' << 8) | ('v' << 16) | ('2' << 24);

enum AVCodecID ToAvCodecId(DecodeCodec codec)
{
    switch (codec) {
    case kDecodeCodecMpeg4:
        return AV_CODEC_ID_MPEG4;
    case kDecodeCodecFlv1:
        return AV_CODEC_ID_FLV1;
    case kDecodeCodecVp6:
        return AV_CODEC_ID_VP6;
    case kDecodeCodecWmv1:
        return AV_CODEC_ID_WMV1;
    case kDecodeCodecWmv2:
        return AV_CODEC_ID_WMV2;
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

void CopyFrameInfo(const AVFrame* frame, DecodedFrameInfo* frameInfo)
{
    if (!frameInfo) {
        return;
    }

    frameInfo->width = frame->width;
    frameInfo->height = frame->height;
    frameInfo->pixelFormat = frame->format;
    frameInfo->pts = frame->pts;
}

} // namespace

DecodeSession::DecodeSession(DecodeCodec codec)
    : codec_(codec)
    , codecContext_(0)
    , packet_(0)
    , frame_(0)
{
    lastError_[0] = '\0';
}

DecodeSession::~DecodeSession()
{
    AVCodecContext* context = AsContext(codecContext_);
    AVPacket* packet = AsPacket(packet_);
    AVFrame* frame = AsFrame(frame_);

    avcodec_free_context(&context);
    av_packet_free(&packet);
    av_frame_free(&frame);

    codecContext_ = 0;
    packet_ = 0;
    frame_ = 0;
}

bool DecodeSession::Open()
{
    return OpenWithExtradata(0, 0);
}

bool DecodeSession::OpenWithExtradata(const uint8_t* extraData, size_t extraDataSize)
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

    if (extraData && extraDataSize > 0) {
        if (extraDataSize > static_cast<size_t>(INT_MAX)) {
            avcodec_free_context(&context);
            SetError("Codec extradata is too large");
            return false;
        }
        context->extradata = static_cast<uint8_t*>(av_mallocz(extraDataSize + AV_INPUT_BUFFER_PADDING_SIZE));
        if (!context->extradata) {
            avcodec_free_context(&context);
            SetError("Failed to allocate codec extradata");
            return false;
        }
        memcpy(context->extradata, extraData, extraDataSize);
        context->extradata_size = static_cast<int>(extraDataSize);
    }

    const int openResult = avcodec_open2(context, codec, 0);
    if (openResult < 0) {
        avcodec_free_context(&context);
        SetAvError("avcodec_open2", openResult);
        return false;
    }

    AVPacket* packet = av_packet_alloc();
    if (!packet) {
        avcodec_free_context(&context);
        SetError("Failed to allocate AVPacket");
        return false;
    }

    AVFrame* frame = av_frame_alloc();
    if (!frame) {
        av_packet_free(&packet);
        avcodec_free_context(&context);
        SetError("Failed to allocate AVFrame");
        return false;
    }

    codecContext_ = context;
    packet_ = packet;
    frame_ = frame;
    lastError_[0] = '\0';
    return true;
}

DecodeStatus DecodeSession::Decode(const uint8_t* data, size_t dataSize, DecodedFrameInfo* frameInfo)
{
    AVCodecContext* context = AsContext(codecContext_);
    AVPacket* packet = AsPacket(packet_);
    if (!context || !packet) {
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

    av_packet_unref(packet);
    const int packetResult = av_new_packet(packet, static_cast<int>(dataSize));
    if (packetResult < 0) {
        SetAvError("av_new_packet", packetResult);
        return kDecodeStatusFailure;
    }

    memcpy(packet->data, data, dataSize);
    const int sendResult = avcodec_send_packet(context, packet);
    av_packet_unref(packet);
    if (sendResult == AVERROR(EAGAIN)) {
        return ReceiveFrame(frameInfo);
    }
    if (sendResult < 0) {
        SetAvError("avcodec_send_packet", sendResult);
        return kDecodeStatusFailure;
    }

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
        *codec = kDecodeCodecMpeg4;
        return true;
    case kFourccFLV1:
    case kFourccflv1:
        *codec = kDecodeCodecFlv1;
        return true;
    case kFourccVP60:
    case kFourccvp60:
        *codec = kDecodeCodecVp6;
        return true;
    case kFourccWMV1:
    case kFourccwmv1:
        *codec = kDecodeCodecWmv1;
        return true;
    case kFourccWMV2:
    case kFourccwmv2:
        *codec = kDecodeCodecWmv2;
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
    case AV_CODEC_ID_VP6F:
    case AV_CODEC_ID_VP6A:
        *codec = kDecodeCodecVp6;
        return true;
    case AV_CODEC_ID_WMV1:
        *codec = kDecodeCodecWmv1;
        return true;
    case AV_CODEC_ID_WMV2:
        *codec = kDecodeCodecWmv2;
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
    case kDecodeCodecWmv1:
    case kDecodeCodecWmv2:
        return true;
    default:
        return false;
    }
}

} // namespace ModernFfmpeg
