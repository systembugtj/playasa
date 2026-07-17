#pragma once

#include <stdint.h>
#include <vector>

#include <guiddef.h>

class CMediaType;
struct PlayasaFfmpegModernAudioOpenParams;

namespace RealAudioModern {

// Maps DirectShow audio subtype to PLAYASA_FFMPEG_MODERN_CODEC_* (0 when unsupported).
uint32_t CodecFromSubtype(const GUID& subtype);

// Scans cook/atrc extradata inside a WAVEFORMATEX + appended buffer.
// Returns pointer/size into caller-owned buffer (no allocation).
bool ScanCookOrAtracExtradata(const uint8_t* format, size_t formatLength, const uint8_t** extraData, size_t* extraDataSize);

// Builds open params from the current input media type and codec id.
// For AAC, ownedExtraData receives a 0x02-prefixed ASC buffer that must outlive open_audio.
bool BuildAudioOpenParams(
	const CMediaType& mediaType,
	uint32_t modernCodec,
	PlayasaFfmpegModernAudioOpenParams* params,
	std::vector<uint8_t>* ownedExtraData);

} // namespace RealAudioModern
