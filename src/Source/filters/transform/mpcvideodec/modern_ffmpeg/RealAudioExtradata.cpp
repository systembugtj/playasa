#include "StdAfx.h"
#include "RealAudioExtradata.h"

#include "ffmpeg_modern_bridge.h"
#include "moreuuids.h"

#include <string.h>

namespace RealAudioModern {

namespace {

const char kCookTag[] = "cook";
const char kAtracTag[] = "atrc";
const size_t kRealAudioHeaderSkip = 12;
const uint8_t kAacExtraPrefix = 0x02;

} // namespace

uint32_t CodecFromSubtype(const GUID& subtype)
{
	if (subtype == MEDIASUBTYPE_COOK) {
		return PLAYASA_FFMPEG_MODERN_CODEC_COOK;
	}
	if (subtype == MEDIASUBTYPE_SIPR) {
		return PLAYASA_FFMPEG_MODERN_CODEC_SIPR;
	}
	if (subtype == MEDIASUBTYPE_ATRC) {
		return PLAYASA_FFMPEG_MODERN_CODEC_ATRAC3;
	}
	if (subtype == MEDIASUBTYPE_AAC || subtype == MEDIASUBTYPE_RAAC || subtype == MEDIASUBTYPE_RACP) {
		return PLAYASA_FFMPEG_MODERN_CODEC_AAC;
	}
	if (subtype == MEDIASUBTYPE_14_4) {
		return PLAYASA_FFMPEG_MODERN_CODEC_RA144;
	}
	if (subtype == MEDIASUBTYPE_28_8) {
		return PLAYASA_FFMPEG_MODERN_CODEC_RA288;
	}
	return 0;
}

bool ScanCookOrAtracExtradata(const uint8_t* format, size_t formatLength, const uint8_t** extraData, size_t* extraDataSize)
{
	if (!format || !extraData || !extraDataSize || formatLength <= sizeof(WAVEFORMATEX)) {
		return false;
	}

	const uint8_t* scan = format + sizeof(WAVEFORMATEX);
	size_t scanSize = formatLength - sizeof(WAVEFORMATEX);
	while (scanSize > 0) {
		if (scanSize >= sizeof(kCookTag) - 1 &&
			(memcmp(scan, kCookTag, sizeof(kCookTag) - 1) == 0 || memcmp(scan, kAtracTag, sizeof(kAtracTag) - 1) == 0)) {
			if (scanSize <= kRealAudioHeaderSkip) {
				return false;
			}
			*extraData = scan + kRealAudioHeaderSkip;
			*extraDataSize = scanSize - kRealAudioHeaderSkip;
			return true;
		}
		++scan;
		--scanSize;
	}

	return false;
}

bool BuildAudioOpenParams(
	const CMediaType& mediaType,
	uint32_t modernCodec,
	PlayasaFfmpegModernAudioOpenParams* params,
	std::vector<uint8_t>* ownedExtraData)
{
	if (!params || !modernCodec || mediaType.FormatLength() < sizeof(WAVEFORMATEX)) {
		return false;
	}

	const WAVEFORMATEX* wfe = reinterpret_cast<const WAVEFORMATEX*>(mediaType.Format());
	params->sample_rate = wfe->nSamplesPerSec;
	params->channels = wfe->nChannels;
	params->bit_rate = wfe->nAvgBytesPerSec > 0 ? wfe->nAvgBytesPerSec * 8 : 0;
	params->bits_per_coded_sample = wfe->wBitsPerSample > 0 ? wfe->wBitsPerSample : 16;
	params->block_align = wfe->nBlockAlign;
	params->extra_data = NULL;
	params->extra_data_size = 0;

	if (modernCodec == PLAYASA_FFMPEG_MODERN_CODEC_COOK || modernCodec == PLAYASA_FFMPEG_MODERN_CODEC_ATRAC3) {
		const uint8_t* extraData = NULL;
		size_t extraDataSize = 0;
		if (!ScanCookOrAtracExtradata(
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

	if (modernCodec == PLAYASA_FFMPEG_MODERN_CODEC_AAC) {
		if (!ownedExtraData) {
			return false;
		}
		DWORD cbSize = wfe->cbSize;
		if (cbSize == sizeof(WAVEFORMATEX)) {
			cbSize = 0;
		}
		if (mediaType.FormatLength() < sizeof(WAVEFORMATEX) + cbSize) {
			return false;
		}
		ownedExtraData->assign(1 + cbSize, 0);
		(*ownedExtraData)[0] = kAacExtraPrefix;
		if (cbSize > 0) {
			memcpy(&(*ownedExtraData)[1], reinterpret_cast<const uint8_t*>(wfe + 1), cbSize);
		}
		params->extra_data = &(*ownedExtraData)[0];
		params->extra_data_size = ownedExtraData->size();
		return true;
	}

	// SIPR / RA144 / RA288: WAVEFORMATEX fields are sufficient.
	return true;
}

} // namespace RealAudioModern
