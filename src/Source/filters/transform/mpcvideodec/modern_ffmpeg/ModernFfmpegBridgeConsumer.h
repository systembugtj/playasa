#pragma once

#include "../../../../../Thirdparty/pkg/ffmpeg_modern_bridge.h"

#include <windows.h>

namespace ModernFfmpegBridge {

class Consumer {
public:
    Consumer();
    ~Consumer();

    bool Open(unsigned int fourcc, const unsigned char* extraData, size_t extraDataSize);
    int Decode(const unsigned char* data, size_t dataSize, int64_t pts, PlayasaFfmpegModernFrameInfo* frameInfo);
    void Flush();
    void Close();
    const char* LastError() const;
    bool IsOpen() const;

private:
    typedef int (*CodecFromFourccFn)(uint32_t, uint32_t*);
    typedef int (*CreateFn)(uint32_t, PlayasaFfmpegModernSession*);
    typedef int (*OpenFn)(PlayasaFfmpegModernSession, const uint8_t*, size_t);
    typedef int (*DecodeWithPtsFn)(PlayasaFfmpegModernSession, const uint8_t*, size_t, int64_t, PlayasaFfmpegModernFrameInfo*);
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
    OpenFn open_;
    DecodeWithPtsFn decodeWithPts_;
    FlushFn flush_;
    LastErrorFn lastError_;
    DestroyFn destroy_;
    char lastErrorText_[256];
};

} // namespace ModernFfmpegBridge
