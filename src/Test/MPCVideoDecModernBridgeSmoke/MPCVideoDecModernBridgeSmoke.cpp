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

    printf("bridge smoke OK: avcodec=%u\n", version);
    return 0;
}
