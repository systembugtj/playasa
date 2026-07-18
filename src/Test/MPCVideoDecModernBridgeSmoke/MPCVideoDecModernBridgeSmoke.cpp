#include "../../Thirdparty/pkg/ffmpeg_modern_bridge.h"

#include <stdio.h>

namespace {

const uint32_t kFourccXvid = 'X' | ('V' << 8) | ('I' << 16) | ('D' << 24);
const uint32_t kFourccWvc1 = 'W' | ('V' << 8) | ('C' << 16) | ('1' << 24);
const uint32_t kFourccWmv3 = 'W' | ('M' << 8) | ('V' << 16) | ('3' << 24);

bool CheckCodec(uint32_t fourcc, bool openSession)
{
    uint32_t codec = 0;
    if (!playasa_ffmpeg_modern_codec_from_fourcc(fourcc, &codec)) {
        fprintf(stderr, "fourcc 0x%08x was not mapped\n", fourcc);
        return false;
    }

    PlayasaFfmpegModernSession session = 0;
    if (!playasa_ffmpeg_modern_create(codec, &session) || !session) {
        fprintf(stderr, "failed to create bridge session for 0x%08x\n", fourcc);
        return false;
    }

    if (openSession) {
        if (!playasa_ffmpeg_modern_open(session, 0, 0)) {
            fprintf(stderr, "failed to open bridge session for 0x%08x: %s\n", fourcc, playasa_ffmpeg_modern_last_error(session));
            playasa_ffmpeg_modern_destroy(session);
            return false;
        }
    }

    playasa_ffmpeg_modern_destroy(session);
    return true;
}

bool CheckAudioCodec(uint32_t codec, int sampleRate, int channels, int blockAlign)
{
    PlayasaFfmpegModernSession session = 0;
    if (!playasa_ffmpeg_modern_create(codec, &session) || !session) {
        fprintf(stderr, "failed to create audio bridge session for codec=%u\n", codec);
        return false;
    }

    PlayasaFfmpegModernAudioOpenParams params = {};
    params.sample_rate = sampleRate;
    params.channels = channels;
    params.bit_rate = 128000;
    params.bits_per_coded_sample = 16;
    params.block_align = blockAlign;
    params.extra_data = 0;
    params.extra_data_size = 0;

    if (!playasa_ffmpeg_modern_open_audio(session, &params)) {
        fprintf(stderr, "failed to open audio codec=%u: %s\n", codec, playasa_ffmpeg_modern_last_error(session));
        playasa_ffmpeg_modern_destroy(session);
        return false;
    }

    playasa_ffmpeg_modern_destroy(session);
    return true;
}

} // namespace

int main()
{
    const uint32_t version = playasa_ffmpeg_modern_avcodec_version();
    if (version == 0) {
        fprintf(stderr, "avcodec version is zero\n");
        return 1;
    }

    if (!CheckCodec(kFourccXvid, true)) {
        return 2;
    }
    if (!CheckCodec(kFourccWvc1, false)) {
        return 3;
    }
    if (!CheckCodec(kFourccWmv3, false)) {
        return 4;
    }

    // RFC-0045: remaining RealAudio codecs must open via audio ABI.
    if (!CheckAudioCodec(PLAYASA_FFMPEG_MODERN_CODEC_AAC, 44100, 2, 0)) {
        return 5;
    }
    if (!CheckAudioCodec(PLAYASA_FFMPEG_MODERN_CODEC_RA144, 8000, 1, 20)) {
        return 6;
    }
    // FFmpeg ra_288 requires block_align == 38.
    if (!CheckAudioCodec(PLAYASA_FFMPEG_MODERN_CODEC_RA288, 8000, 1, 38)) {
        return 7;
    }

    if (!CheckAudioCodec(PLAYASA_FFMPEG_MODERN_CODEC_WMAV2, 44100, 2, 1024)) {
        return 8;
    }
    if (!CheckAudioCodec(PLAYASA_FFMPEG_MODERN_CODEC_AMR_NB, 8000, 1, 32)) {
        return 9;
    }

    // COOK requires RealMedia extradata; create-only proves decoder is linked.
    {
        PlayasaFfmpegModernSession session = 0;
        if (!playasa_ffmpeg_modern_create(PLAYASA_FFMPEG_MODERN_CODEC_COOK, &session) || !session) {
            fprintf(stderr, "failed to create COOK bridge session\n");
            return 10;
        }
        playasa_ffmpeg_modern_destroy(session);
    }

    printf("bridge smoke OK: avcodec=%u\n", version);
    return 0;
}
