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
    , open_(NULL)
    , decode_(NULL)
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

bool Consumer::Open(unsigned int fourcc, const unsigned char* extraData, size_t extraDataSize)
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
    if (!open_(session_, extraData, extraDataSize)) {
        SetError(lastError_(session_));
        Close();
        return false;
    }

    lastErrorText_[0] = '\0';
    return true;
}

int Consumer::Decode(const unsigned char* data, size_t dataSize, PlayasaFfmpegModernFrameInfo* frameInfo)
{
    if (!session_ || !decode_) {
        SetError("FFmpeg modern bridge session is not open");
        return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
    }

    const int status = decode_(session_, data, dataSize, frameInfo);
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
    open_ = reinterpret_cast<OpenFn>(LoadRequiredProc("playasa_ffmpeg_modern_open"));
    decode_ = reinterpret_cast<DecodeFn>(LoadRequiredProc("playasa_ffmpeg_modern_decode"));
    flush_ = reinterpret_cast<FlushFn>(LoadRequiredProc("playasa_ffmpeg_modern_flush"));
    lastError_ = reinterpret_cast<LastErrorFn>(LoadRequiredProc("playasa_ffmpeg_modern_last_error"));
    destroy_ = reinterpret_cast<DestroyFn>(LoadRequiredProc("playasa_ffmpeg_modern_destroy"));

    if (!codecFromFourcc_ || !create_ || !open_ || !decode_ || !flush_ || !lastError_ || !destroy_) {
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
