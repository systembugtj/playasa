#pragma once

// RFC-0035: local stand-ins for the tiny subset of legacy FFmpeg types that
// EASplitter still uses as demux discriminators. Values are local-only; they
// must stay unique within this filter and must not be compared to island
// FFmpeg CodecID / AVPacket layouts.

#include <stdint.h>
#include <errno.h>

#ifndef AVERROR
#define AVERROR(e) (-(e))
#endif

#ifndef AV_LOG_ERROR
#define AV_LOG_ERROR 16
#endif

#ifndef AV_LOG_DEBUG
#define AV_LOG_DEBUG 48
#endif

#ifndef av_uninit
#define av_uninit(x) x
#endif

#ifndef PKT_FLAG_KEY
#define PKT_FLAG_KEY 0x0001
#endif

enum CodecID {
	CODEC_ID_NONE = 0,
	CODEC_ID_MPEG2VIDEO,
	CODEC_ID_VP6,
	CODEC_ID_MDEC,
	CODEC_ID_CMV,
	CODEC_ID_TGV,
	CODEC_ID_TGQ,
	CODEC_ID_TQI,
	CODEC_ID_MAD,
	CODEC_ID_MP3,
	CODEC_ID_PCM_S8,
	CODEC_ID_PCM_S16LE,
	CODEC_ID_PCM_S16LE_PLANAR,
	CODEC_ID_PCM_MULAW,
	CODEC_ID_ADPCM_EA,
	CODEC_ID_ADPCM_EA_R1,
	CODEC_ID_ADPCM_EA_R2,
	CODEC_ID_ADPCM_EA_R3,
	CODEC_ID_ADPCM_IMA_EA_EACS,
	CODEC_ID_ADPCM_IMA_EA_SEAD
};

typedef struct AVRational {
	int num;
	int den;
} AVRational;

// Fields actually touched by EASpliter.cpp only.
typedef struct AVPacket {
	int64_t pts;
	int64_t duration;
	int64_t pos;
	int stream_index;
	int flags;
	int size;
} AVPacket;
