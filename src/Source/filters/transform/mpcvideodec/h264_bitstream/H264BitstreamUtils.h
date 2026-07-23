#pragma once

// RFC-0047 phase 3a: shared H.264 extradata / length-prefixed NAL utilities.
// Used by DXVA session glue and modern_ffmpeg decode adapter (no legacy ffmpeg headers).

#include <stddef.h>
#include <stdint.h>
#include <vector>

namespace PlayasaH264 {

/** Zero means unknown; callers may fall back to legacy AVCodecContext fields. */
const int kUnknownNalLengthSize = 0;

const uint8_t kAnnexBStartCode[4] = { 0, 0, 0, 1 };

bool IsAvcDecoderConfigurationRecord(const uint8_t* extraData, size_t extraDataSize);
int NalLengthSizeFromExtradata(const uint8_t* extraData, size_t extraDataSize);
bool StartsWithAnnexBStartCode(const uint8_t* data, size_t dataSize);
bool ConvertAvcLengthPrefixedToAnnexB(const uint8_t* data, size_t dataSize, int nalLengthSize, std::vector<uint8_t>* output);
uint8_t NalType(uint8_t nalHeader);
bool IsVclNalType(uint8_t nalType);
bool NalStartsNewSlice(const uint8_t* nalData, size_t nalSize);
bool ContainsAvcLengthPrefixedVclNal(const uint8_t* data, size_t dataSize, int nalLengthSize);
bool AvcLengthPrefixedStartsNewVclSlice(const uint8_t* data, size_t dataSize, int nalLengthSize);
int DetectNalLengthSize(const uint8_t* data, size_t dataSize);
bool ConvertAvcConfigurationToAnnexB(const uint8_t* extraData, size_t extraDataSize, std::vector<uint8_t>* output);
bool ConvertLengthPrefixedParameterSetsToAnnexB(const uint8_t* extraData, size_t extraDataSize, std::vector<uint8_t>* output);

} // namespace PlayasaH264
