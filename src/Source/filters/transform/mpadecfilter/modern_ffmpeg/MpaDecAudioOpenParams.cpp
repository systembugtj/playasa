#include "../stdafx.h"
#include "MpaDecAudioOpenParams.h"

#include "MpaDecCodecMap.h"
#include "ffmpeg_modern_bridge.h"

#include <string.h>

namespace {

const char kCookTag[] = "cook";
const size_t kCookHeaderSkip = 12;

bool ScanCookExtradata(const uint8_t* format, size_t formatLength, const uint8_t** extraData, size_t* extraDataSize)
{
	if (!format || !extraData || !extraDataSize || formatLength <= sizeof(WAVEFORMATEX)) {
		return false;
	}

	const uint8_t* scan = format + sizeof(WAVEFORMATEX);
	size_t scanSize = formatLength - sizeof(WAVEFORMATEX);
	while (scanSize > 0) {
		if (scanSize >= sizeof(kCookTag) - 1 && memcmp(scan, kCookTag, sizeof(kCookTag) - 1) == 0) {
			if (scanSize <= kCookHeaderSkip) {
				return false;
			}
			*extraData = scan + kCookHeaderSkip;
			*extraDataSize = scanSize - kCookHeaderSkip;
			return true;
		}
		++scan;
		--scanSize;
	}

	return false;
}

} // namespace

bool BuildMpaDecAudioOpenParams(
	const CMediaType& mediaType,
	uint32_t modernCodec,
	int legacyCodecId,
	PlayasaFfmpegModernAudioOpenParams* params,
	std::vector<uint8_t>* ownedExtraData)
{
	if (!params || !modernCodec || mediaType.FormatLength() < sizeof(WAVEFORMATEX)) {
		return false;
	}

	WAVEFORMATEX* wfe = reinterpret_cast<WAVEFORMATEX*>(mediaType.Format());

	if (legacyCodecId == kMpaDecLegacyCodecAmrNb || legacyCodecId == kMpaDecLegacyCodecAmrWb) {
		if (!wfe->nSamplesPerSec) {
			wfe->nSamplesPerSec = 8000 * (1 + (legacyCodecId == kMpaDecLegacyCodecAmrWb));
		} else if (wfe->nSamplesPerSec > 2000) {
			if (wfe->nSamplesPerSec == 15750) {
				wfe->nSamplesPerSec = 2000;
			}
		} else {
			wfe->nSamplesPerSec = 8000;
		}
		wfe->nChannels = 1;
	}

	params->sample_rate = wfe->nSamplesPerSec;
	params->channels = wfe->nChannels;
	params->bit_rate = wfe->nAvgBytesPerSec > 0 ? wfe->nAvgBytesPerSec * 8 : 0;
	params->bits_per_coded_sample = wfe->wBitsPerSample > 0 ? wfe->wBitsPerSample : 16;
	params->block_align = wfe->nBlockAlign;
	params->extra_data = NULL;
	params->extra_data_size = 0;

	if (modernCodec == PLAYASA_FFMPEG_MODERN_CODEC_COOK) {
		const uint8_t* extraData = NULL;
		size_t extraDataSize = 0;
		if (!ScanCookExtradata(
			reinterpret_cast<const uint8_t*>(mediaType.Format()),
			mediaType.FormatLength(),
			&extraData,
			&extraDataSize)) {
			return false;
		}
		params->extra_data = extraData;
		params->extra_data_size = extraDataSize;
		return true;
	}

	if (modernCodec == PLAYASA_FFMPEG_MODERN_CODEC_QDM2 || modernCodec == PLAYASA_FFMPEG_MODERN_CODEC_FLAC) {
		if (mediaType.FormatLength() <= sizeof(WAVEFORMATEX)) {
			return false;
		}
		params->extra_data = reinterpret_cast<const uint8_t*>(mediaType.Format()) + sizeof(WAVEFORMATEX);
		params->extra_data_size = mediaType.FormatLength() - sizeof(WAVEFORMATEX);
		return true;
	}

	return true;
}
