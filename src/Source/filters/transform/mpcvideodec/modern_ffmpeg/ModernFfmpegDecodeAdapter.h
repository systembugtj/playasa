#pragma once

#include <stddef.h>
#include <stdint.h>

namespace ModernFfmpeg {

enum DecodeCodec {
    kDecodeCodecMpeg4,
    kDecodeCodecFlv1,
    kDecodeCodecVp6,
    kDecodeCodecVp6f,
    kDecodeCodecVp6a,
    kDecodeCodecWmv1,
    kDecodeCodecWmv2
};

enum DecodeStatus {
    kDecodeStatusFrameReady,
    kDecodeStatusNeedMoreInput,
    kDecodeStatusEndOfStream,
    kDecodeStatusFailure
};

struct DecodedFrameInfo {
    int width;
    int height;
    int pixelFormat;
    int64_t pts;
    const uint8_t* data[4];
    int linesize[4];
};

class DecodeSession {
public:
    explicit DecodeSession(DecodeCodec codec);
    ~DecodeSession();

    bool Open();
    bool OpenWithExtradata(const uint8_t* extraData, size_t extraDataSize);
    DecodeStatus Decode(const uint8_t* data, size_t dataSize, DecodedFrameInfo* frameInfo);
    DecodeStatus Drain(DecodedFrameInfo* frameInfo);
    void Flush();

    const char* LastError() const;

private:
    DecodeSession(const DecodeSession&);
    DecodeSession& operator=(const DecodeSession&);

    DecodeStatus ReceiveFrame(DecodedFrameInfo* frameInfo);
    void SetError(const char* message);
    void SetAvError(const char* operation, int errorCode);

    DecodeCodec codec_;
    void* codecContext_;
    void* packet_;
    void* frame_;
    char lastError_[256];
};

bool DecodeCodecFromFourcc(uint32_t fourcc, DecodeCodec* codec);
bool DecodeCodecFromModernAvCodecId(int codecId, DecodeCodec* codec);
bool IsFirstWaveSoftwareCodec(DecodeCodec codec);

} // namespace ModernFfmpeg
