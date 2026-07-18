#pragma once

#include <stdint.h>

// Legacy CodecID numeric values used by historical MpaDec ProcessFfmpeg call sites.
enum MpaDecLegacyCodecId {
	kMpaDecLegacyCodecWmav1 = 86023,
	kMpaDecLegacyCodecWmav2 = 86024,
	kMpaDecLegacyCodecAmrNb = 69660,
	kMpaDecLegacyCodecAmrWb = 69661,
	kMpaDecLegacyCodecNellymoser = 86052,
	kMpaDecLegacyCodecQdm2 = 86037,
	kMpaDecLegacyCodecEac3 = 86059,
	kMpaDecLegacyCodecTruehd = 86063,
	kMpaDecLegacyCodecMlp = 86047,
	kMpaDecLegacyCodecFlac = 86030,
	kMpaDecLegacyCodecPcmMulaw = 65542,
	kMpaDecLegacyCodecAdpcmImaQt = 69632,
	kMpaDecLegacyCodecCook = 86038,
	kMpaDecLegacyCodecSipr = 86060,
	kMpaDecLegacyCodecRa144 = 69662,
	kMpaDecLegacyCodecRa288 = 69663
};

// Maps legacy CodecID integers used by MpaDec to PLAYASA_FFMPEG_MODERN_CODEC_* (0 if unsupported).
uint32_t ModernCodecFromLegacyCodecId(int legacyId);
