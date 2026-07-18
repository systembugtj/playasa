#include "../stdafx.h"
#include "MpaDecCodecMap.h"

#include "ffmpeg_modern_bridge.h"

uint32_t ModernCodecFromLegacyCodecId(int legacyId)
{
	switch (legacyId) {
	case kMpaDecLegacyCodecWmav1:
		return PLAYASA_FFMPEG_MODERN_CODEC_WMAV1;
	case kMpaDecLegacyCodecWmav2:
		return PLAYASA_FFMPEG_MODERN_CODEC_WMAV2;
	case kMpaDecLegacyCodecAmrNb:
		return PLAYASA_FFMPEG_MODERN_CODEC_AMR_NB;
	case kMpaDecLegacyCodecAmrWb:
		return PLAYASA_FFMPEG_MODERN_CODEC_AMR_WB;
	case kMpaDecLegacyCodecNellymoser:
		return PLAYASA_FFMPEG_MODERN_CODEC_NELLYMOSER;
	case kMpaDecLegacyCodecQdm2:
		return PLAYASA_FFMPEG_MODERN_CODEC_QDM2;
	case kMpaDecLegacyCodecEac3:
		return PLAYASA_FFMPEG_MODERN_CODEC_EAC3;
	case kMpaDecLegacyCodecTruehd:
		return PLAYASA_FFMPEG_MODERN_CODEC_TRUEHD;
	case kMpaDecLegacyCodecMlp:
		return PLAYASA_FFMPEG_MODERN_CODEC_MLP;
	case kMpaDecLegacyCodecFlac:
		return PLAYASA_FFMPEG_MODERN_CODEC_FLAC;
	case kMpaDecLegacyCodecPcmMulaw:
		return PLAYASA_FFMPEG_MODERN_CODEC_PCM_MULAW;
	case kMpaDecLegacyCodecAdpcmImaQt:
		return PLAYASA_FFMPEG_MODERN_CODEC_ADPCM_IMA_QT;
	case kMpaDecLegacyCodecCook:
		return PLAYASA_FFMPEG_MODERN_CODEC_COOK;
	case kMpaDecLegacyCodecSipr:
		return PLAYASA_FFMPEG_MODERN_CODEC_SIPR;
	case kMpaDecLegacyCodecRa144:
		return PLAYASA_FFMPEG_MODERN_CODEC_RA144;
	case kMpaDecLegacyCodecRa288:
		return PLAYASA_FFMPEG_MODERN_CODEC_RA288;
	default:
		return 0;
	}
}
