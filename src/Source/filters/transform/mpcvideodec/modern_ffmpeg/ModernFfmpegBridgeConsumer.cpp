#include "../stdafx.h"
#include "ModernFfmpegBridgeConsumer.h"

#include <stdio.h>

namespace ModernFfmpegBridge {

namespace {

const char* const kBridgeDllName = "playasa_ffmpeg_modern_bridge.dll";
const size_t kLastErrorCapacity = 256;

} // namespace

Consumer::Consumer()
    : module_(NULL)
    , session_(NULL)
    , codecFromFourcc_(NULL)
    , create_(NULL)
    , openWithH264NalLengthSize_(NULL)
    , decodeWithTiming_(NULL)
    , receivePending_(NULL)
    , flush_(NULL)
    , lastError_(NULL)
    , destroy_(NULL)
{
    lastErrorText_[0] = '\0';
}

Consumer::~Consumer()
{
    Close();
    if (module_) {
        FreeLibrary(module_);
        module_ = NULL;
    }
}

bool Consumer::Open(unsigned int fourcc, const unsigned char* extraData, size_t extraDataSize, int h264NalLengthSize)
{
    Close();
    if (!LoadBridge()) {
        return false;
    }
    if (!extraData && extraDataSize > 0) {
        SetError("Invalid FFmpeg modern extradata");
        return false;
    }

    uint32_t codec = 0;
    if (!codecFromFourcc_(fourcc, &codec)) {
        SetError("Codec is not supported by FFmpeg modern bridge");
        return false;
    }
    if (!create_(codec, &session_) || !session_) {
        SetError("Failed to create FFmpeg modern bridge session");
        return false;
    }
    if (!openWithH264NalLengthSize_(session_, extraData, extraDataSize, h264NalLengthSize)) {
        SetError(lastError_(session_));
        Close();
        return false;
    }

    lastErrorText_[0] = '\0';
    return true;
}

int Consumer::Decode(const unsigned char* data, size_t dataSize, int64_t pts, int64_t duration, PlayasaFfmpegModernFrameInfo* frameInfo)
{
    if (!session_ || !decodeWithTiming_) {
        SetError("FFmpeg modern bridge session is not open");
        return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
    }

    const int status = decodeWithTiming_(session_, data, dataSize, pts, duration, frameInfo);
    if (status == PLAYASA_FFMPEG_MODERN_STATUS_FAILURE) {
        SetError(lastError_(session_));
    }
    return status;
}

int Consumer::ReceivePending(PlayasaFfmpegModernFrameInfo* frameInfo)
{
    if (!session_ || !receivePending_) {
        SetError("FFmpeg modern bridge session is not open");
        return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
    }

    const int status = receivePending_(session_, frameInfo);
    if (status == PLAYASA_FFMPEG_MODERN_STATUS_FAILURE) {
        SetError(lastError_(session_));
    }
    return status;
}

void Consumer::Flush()
{
    if (session_ && flush_) {
        flush_(session_);
    }
}

void Consumer::Close()
{
    if (session_ && destroy_) {
        destroy_(session_);
    }
    session_ = NULL;
}

const char* Consumer::LastError() const
{
    return lastErrorText_;
}

bool Consumer::IsOpen() const
{
    return session_ != NULL;
}

bool Consumer::LoadBridge()
{
    if (module_) {
        return true;
    }

    module_ = LoadLibraryA(kBridgeDllName);
    if (!module_) {
        SetError("Failed to load playasa_ffmpeg_modern_bridge.dll");
        return false;
    }

    codecFromFourcc_ = reinterpret_cast<CodecFromFourccFn>(LoadRequiredProc("playasa_ffmpeg_modern_codec_from_fourcc"));
    create_ = reinterpret_cast<CreateFn>(LoadRequiredProc("playasa_ffmpeg_modern_create"));
    openWithH264NalLengthSize_ = reinterpret_cast<OpenWithH264NalLengthSizeFn>(LoadRequiredProc("playasa_ffmpeg_modern_open_with_h264_nal_length_size"));
    decodeWithTiming_ = reinterpret_cast<DecodeWithTimingFn>(LoadRequiredProc("playasa_ffmpeg_modern_decode_with_timing"));
    receivePending_ = reinterpret_cast<ReceivePendingFn>(LoadRequiredProc("playasa_ffmpeg_modern_receive_pending"));
    flush_ = reinterpret_cast<FlushFn>(LoadRequiredProc("playasa_ffmpeg_modern_flush"));
    lastError_ = reinterpret_cast<LastErrorFn>(LoadRequiredProc("playasa_ffmpeg_modern_last_error"));
    destroy_ = reinterpret_cast<DestroyFn>(LoadRequiredProc("playasa_ffmpeg_modern_destroy"));

    if (!codecFromFourcc_ || !create_ || !openWithH264NalLengthSize_ || !decodeWithTiming_ || !receivePending_ || !flush_ || !lastError_ || !destroy_) {
        FreeLibrary(module_);
        module_ = NULL;
        return false;
    }

    return true;
}

FARPROC Consumer::LoadRequiredProc(const char* name)
{
    FARPROC proc = GetProcAddress(module_, name);
    if (!proc) {
        char message[kLastErrorCapacity] = { 0 };
        _snprintf_s(message, sizeof(message), _TRUNCATE, "Missing FFmpeg modern bridge export: %s", name);
        SetError(message);
    }
    return proc;
}

void Consumer::SetError(const char* message)
{
    if (!message) {
        message = "Unknown FFmpeg modern bridge error";
    }
    _snprintf_s(lastErrorText_, sizeof(lastErrorText_), _TRUNCATE, "%s", message);
}

} // namespace ModernFfmpegBridge
