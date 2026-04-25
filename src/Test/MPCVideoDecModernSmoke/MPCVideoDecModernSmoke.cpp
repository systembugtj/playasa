#include "../../Source/filters/transform/mpcvideodec/modern_ffmpeg/ModernFfmpegDecodeAdapter.h"

#include <stdio.h>

extern "C" {
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
}

namespace {

const int kSuccess = 0;
const int kUsageError = 2;
const int kDecodeError = 3;
const int kUnsupportedCodec = 4;

void PrintUsage()
{
    fprintf(stderr, "Usage: MPCVideoDecModernSmoke.exe <sample-video>\n");
}

int FindFirstWaveVideoStream(AVFormatContext* formatContext, ModernFfmpeg::DecodeCodec* codec)
{
    for (unsigned int i = 0; i < formatContext->nb_streams; ++i) {
        AVStream* stream = formatContext->streams[i];
        if (!stream || !stream->codecpar || stream->codecpar->codec_type != AVMEDIA_TYPE_VIDEO) {
            continue;
        }

        if (ModernFfmpeg::DecodeCodecFromModernAvCodecId(stream->codecpar->codec_id, codec)) {
            return static_cast<int>(i);
        }
    }

    return -1;
}

} // namespace

int main(int argc, char** argv)
{
    if (argc != 2) {
        PrintUsage();
        return kUsageError;
    }

    AVFormatContext* formatContext = 0;
    if (avformat_open_input(&formatContext, argv[1], 0, 0) < 0) {
        fprintf(stderr, "Failed to open sample: %s\n", argv[1]);
        return kDecodeError;
    }

    if (avformat_find_stream_info(formatContext, 0) < 0) {
        fprintf(stderr, "Failed to read stream info\n");
        avformat_close_input(&formatContext);
        return kDecodeError;
    }

    ModernFfmpeg::DecodeCodec codec = ModernFfmpeg::kDecodeCodecMpeg4;
    const int streamIndex = FindFirstWaveVideoStream(formatContext, &codec);
    if (streamIndex < 0) {
        fprintf(stderr, "Sample does not contain an RFC-0024 first-wave video codec\n");
        avformat_close_input(&formatContext);
        return kUnsupportedCodec;
    }

    AVCodecParameters* codecParameters = formatContext->streams[streamIndex]->codecpar;
    ModernFfmpeg::DecodeSession session(codec);
    if (!session.OpenWithExtradata(codecParameters->extradata, codecParameters->extradata_size)) {
        fprintf(stderr, "Failed to open modern decoder: %s\n", session.LastError());
        avformat_close_input(&formatContext);
        return kDecodeError;
    }

    AVPacket* packet = av_packet_alloc();
    if (!packet) {
        fprintf(stderr, "Failed to allocate packet\n");
        avformat_close_input(&formatContext);
        return kDecodeError;
    }

    int result = kDecodeError;
    ModernFfmpeg::DecodedFrameInfo frameInfo = {};
    while (av_read_frame(formatContext, packet) >= 0) {
        if (packet->stream_index == streamIndex) {
            const ModernFfmpeg::DecodeStatus status = session.Decode(packet->data, packet->size, &frameInfo);
            if (status == ModernFfmpeg::kDecodeStatusFrameReady) {
                printf("Decoded first frame: %dx%d pixfmt=%d pts=%lld\n",
                    frameInfo.width,
                    frameInfo.height,
                    frameInfo.pixelFormat,
                    static_cast<long long>(frameInfo.pts));
                result = kSuccess;
                av_packet_unref(packet);
                break;
            }
            if (status == ModernFfmpeg::kDecodeStatusFailure) {
                fprintf(stderr, "Decode failed: %s\n", session.LastError());
                av_packet_unref(packet);
                break;
            }
        }

        av_packet_unref(packet);
    }

    av_packet_free(&packet);
    avformat_close_input(&formatContext);
    return result;
}
