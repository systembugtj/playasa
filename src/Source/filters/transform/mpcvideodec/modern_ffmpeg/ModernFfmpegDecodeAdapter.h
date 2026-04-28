#pragma once

#include <stddef.h>
#include <stdint.h>
#include <vector>

namespace ModernFfmpeg {

enum DecodeCodec {
    kDecodeCodecMpeg4,
    kDecodeCodecFlv1,
    kDecodeCodecVp6,
    kDecodeCodecVp6f,
    kDecodeCodecVp6a,
    kDecodeCodecWmv1,
    kDecodeCodecWmv2,
    kDecodeCodecH264,
    kDecodeCodecMpeg2,
    kDecodeCodecWmv3,
    kDecodeCodecVc1
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
    int64_t duration;
    const uint8_t* data[4];
    int linesize[4];
};

class DecodeSession {
public:
    explicit DecodeSession(DecodeCodec codec);
    ~DecodeSession();

    bool Open();
    bool OpenWithExtradata(const uint8_t* extraData, size_t extraDataSize);
    bool OpenWithH264NalLengthSize(const uint8_t* extraData, size_t extraDataSize, int h264NalLengthSize);
    DecodeStatus Decode(const uint8_t* data, size_t dataSize, DecodedFrameInfo* frameInfo);
    DecodeStatus DecodeWithPts(const uint8_t* data, size_t dataSize, int64_t pts, DecodedFrameInfo* frameInfo);
    DecodeStatus DecodeWithTiming(const uint8_t* data, size_t dataSize, int64_t pts, int64_t duration, DecodedFrameInfo* frameInfo);
    DecodeStatus ReceivePending(DecodedFrameInfo* frameInfo);
    DecodeStatus Drain(DecodedFrameInfo* frameInfo);
    void Flush();

    const char* LastError() const;

private:
    DecodeSession(const DecodeSession&);
    DecodeSession& operator=(const DecodeSession&);

    DecodeStatus ReceiveFrame(DecodedFrameInfo* frameInfo);
    DecodeStatus SendPacket(const uint8_t* data, size_t dataSize, int64_t pts, int64_t duration, DecodedFrameInfo* frameInfo);
    DecodeStatus SendParsedPacket(const uint8_t* data, size_t dataSize, int64_t pts, int64_t duration, DecodedFrameInfo* frameInfo);
    DecodeStatus SendH264Packet(const uint8_t* data, size_t dataSize, int64_t pts, int64_t duration, DecodedFrameInfo* frameInfo);
    DecodeStatus SendStoredPendingPacket(DecodedFrameInfo* frameInfo);
    void SaveParsedPendingInput(const uint8_t* data, int dataSize, int64_t pts, int64_t duration);
    void SavePendingPacket(const uint8_t* data, size_t dataSize, int64_t pts, int64_t duration);
    void SetError(const char* message);
    void SetAvError(const char* operation, int errorCode);

    DecodeCodec codec_;
    void* codecContext_;
    void* parser_;
    void* packet_;
    void* frame_;
    std::vector<uint8_t> parsedPendingInput_;
    int64_t parsedPendingPts_;
    int64_t parsedPendingDuration_;
    std::vector<uint8_t> pendingPacket_;
    int64_t pendingPacketPts_;
    int64_t pendingPacketDuration_;
    int h264NalLengthSize_;
    std::vector<uint8_t> h264AnnexBExtraData_;
    std::vector<uint8_t> h264PendingAccessUnit_;
    int64_t h264PendingPts_;
    int64_t h264PendingDuration_;
    bool h264ExtraDataPrepended_;
    bool h264UseNativeAvc_;
    bool h264HasPendingVcl_;
    bool hasDecodedFrame_;
    char lastError_[256];
};

bool DecodeCodecFromFourcc(uint32_t fourcc, DecodeCodec* codec);
bool DecodeCodecFromModernAvCodecId(int codecId, DecodeCodec* codec);
bool IsFirstWaveSoftwareCodec(DecodeCodec codec);

} // namespace ModernFfmpeg
