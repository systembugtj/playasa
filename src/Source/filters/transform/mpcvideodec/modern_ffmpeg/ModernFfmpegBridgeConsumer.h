#pragma once

#include "../../../../../Thirdparty/pkg/ffmpeg_modern_bridge.h"

#include <windows.h>

namespace ModernFfmpegBridge {

class Consumer {
public:
    Consumer();
    ~Consumer();

    bool Open(unsigned int fourcc, const unsigned char* extraData, size_t extraDataSize, int h264NalLengthSize);
    int Decode(const unsigned char* data, size_t dataSize, int64_t pts, int64_t duration, PlayasaFfmpegModernFrameInfo* frameInfo);
    int ReceivePending(PlayasaFfmpegModernFrameInfo* frameInfo);
    void Flush();
    void Close();
    const char* LastError() const;
    bool IsOpen() const;

private:
    typedef int (*CodecFromFourccFn)(uint32_t, uint32_t*);
    typedef int (*CreateFn)(uint32_t, PlayasaFfmpegModernSession*);
    typedef int (*OpenWithH264NalLengthSizeFn)(PlayasaFfmpegModernSession, const uint8_t*, size_t, int32_t);
    typedef int (*DecodeWithTimingFn)(PlayasaFfmpegModernSession, const uint8_t*, size_t, int64_t, int64_t, PlayasaFfmpegModernFrameInfo*);
    typedef int (*ReceivePendingFn)(PlayasaFfmpegModernSession, PlayasaFfmpegModernFrameInfo*);
    typedef void (*FlushFn)(PlayasaFfmpegModernSession);
    typedef const char* (*LastErrorFn)(PlayasaFfmpegModernSession);
    typedef void (*DestroyFn)(PlayasaFfmpegModernSession);

    Consumer(const Consumer&);
    Consumer& operator=(const Consumer&);

    bool LoadBridge();
    FARPROC LoadRequiredProc(const char* name);
    void SetError(const char* message);

    HMODULE module_;
    PlayasaFfmpegModernSession session_;
    CodecFromFourccFn codecFromFourcc_;
    CreateFn create_;
    OpenWithH264NalLengthSizeFn openWithH264NalLengthSize_;
    DecodeWithTimingFn decodeWithTiming_;
    ReceivePendingFn receivePending_;
    FlushFn flush_;
    LastErrorFn lastError_;
    DestroyFn destroy_;
    char lastErrorText_[256];
};

} // namespace ModernFfmpegBridge
