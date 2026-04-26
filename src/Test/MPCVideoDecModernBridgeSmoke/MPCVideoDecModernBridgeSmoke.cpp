#include "../../Thirdparty/pkg/ffmpeg_modern_bridge.h"

#include <stdio.h>

namespace {

const uint32_t kFourccXvid = 'X' | ('V' << 8) | ('I' << 16) | ('D' << 24);

} // namespace

int main()
{
    const uint32_t version = playasa_ffmpeg_modern_avcodec_version();
    if (version == 0) {
        fprintf(stderr, "avcodec version is zero\n");
        return 1;
    }

    uint32_t codec = 0;
    if (!playasa_ffmpeg_modern_codec_from_fourcc(kFourccXvid, &codec)) {
        fprintf(stderr, "XVID fourcc was not mapped\n");
        return 2;
    }

    PlayasaFfmpegModernSession session = 0;
    if (!playasa_ffmpeg_modern_create(codec, &session) || !session) {
        fprintf(stderr, "failed to create bridge session\n");
        return 3;
    }

    playasa_ffmpeg_modern_destroy(session);
    printf("bridge smoke OK: avcodec=%u codec=%u\n", version, codec);
    return 0;
}
