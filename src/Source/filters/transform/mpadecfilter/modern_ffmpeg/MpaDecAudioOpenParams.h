#pragma once

#include <vector>

class CMediaType;
struct PlayasaFfmpegModernAudioOpenParams;

// Builds open params from WAVEFORMATEX + media type (ports InitFfmpeg extradata hacks).
bool BuildMpaDecAudioOpenParams(
	const CMediaType& mediaType,
	uint32_t modernCodec,
	int legacyCodecId,
	PlayasaFfmpegModernAudioOpenParams* params,
	std::vector<uint8_t>* ownedExtraData);
