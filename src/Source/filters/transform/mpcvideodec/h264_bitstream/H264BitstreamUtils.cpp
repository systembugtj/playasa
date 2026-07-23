#include "stdafx.h"
#include "H264BitstreamUtils.h"

namespace PlayasaH264 {

bool IsAvcDecoderConfigurationRecord(const uint8_t* extraData, size_t extraDataSize)
{
	return extraData && extraDataSize >= 5 && extraData[0] == 1;
}

int NalLengthSizeFromExtradata(const uint8_t* extraData, size_t extraDataSize)
{
	if (!IsAvcDecoderConfigurationRecord(extraData, extraDataSize)) {
		return kUnknownNalLengthSize;
	}

	return (extraData[4] & 0x03) + 1;
}

bool StartsWithAnnexBStartCode(const uint8_t* data, size_t dataSize)
{
	if (!data || dataSize < 4) {
		return false;
	}

	return (data[0] == 0 && data[1] == 0 && data[2] == 1) ||
		(data[0] == 0 && data[1] == 0 && data[2] == 0 && data[3] == 1);
}

bool ConvertAvcLengthPrefixedToAnnexB(const uint8_t* data, size_t dataSize, int nalLengthSize, std::vector<uint8_t>* output)
{
	if (!data || !output || nalLengthSize < 1 || nalLengthSize > 4) {
		return false;
	}

	output->clear();
	size_t offset = 0;
	while (offset < dataSize) {
		if (dataSize - offset < static_cast<size_t>(nalLengthSize)) {
			return false;
		}

		uint32_t nalSize = 0;
		for (int i = 0; i < nalLengthSize; ++i) {
			nalSize = (nalSize << 8) | data[offset + i];
		}
		offset += nalLengthSize;

		if (nalSize == 0 || dataSize - offset < nalSize) {
			return false;
		}

		output->insert(output->end(), kAnnexBStartCode, kAnnexBStartCode + sizeof(kAnnexBStartCode));
		output->insert(output->end(), data + offset, data + offset + nalSize);
		offset += nalSize;
	}

	return !output->empty();
}

uint8_t NalType(uint8_t nalHeader)
{
	return nalHeader & 0x1f;
}

bool IsVclNalType(uint8_t nalType)
{
	return nalType >= 1 && nalType <= 5;
}

bool NalStartsNewSlice(const uint8_t* nalData, size_t nalSize)
{
	if (!nalData || nalSize < 2 || !IsVclNalType(NalType(nalData[0]))) {
		return false;
	}

	// first_mb_in_slice == 0 encodes as a single '1' bit after the NAL header
	return (nalData[1] & 0x80) != 0;
}

bool ContainsAvcLengthPrefixedVclNal(const uint8_t* data, size_t dataSize, int nalLengthSize)
{
	if (!data || nalLengthSize < 1 || nalLengthSize > 4) {
		return true;
	}

	size_t offset = 0;
	while (offset < dataSize) {
		if (dataSize - offset < static_cast<size_t>(nalLengthSize)) {
			return true;
		}

		uint32_t nalSize = 0;
		for (int i = 0; i < nalLengthSize; ++i) {
			nalSize = (nalSize << 8) | data[offset + i];
		}
		offset += nalLengthSize;
		if (nalSize == 0 || dataSize - offset < nalSize) {
			return true;
		}

		if (IsVclNalType(NalType(data[offset]))) {
			return true;
		}
		offset += nalSize;
	}

	return false;
}

bool AvcLengthPrefixedStartsNewVclSlice(const uint8_t* data, size_t dataSize, int nalLengthSize)
{
	if (!data || nalLengthSize < 1 || nalLengthSize > 4) {
		return false;
	}

	size_t offset = 0;
	while (offset < dataSize) {
		if (dataSize - offset < static_cast<size_t>(nalLengthSize)) {
			return false;
		}

		uint32_t nalSize = 0;
		for (int i = 0; i < nalLengthSize; ++i) {
			nalSize = (nalSize << 8) | data[offset + i];
		}
		offset += nalLengthSize;
		if (nalSize == 0 || dataSize - offset < nalSize) {
			return false;
		}

		if (NalStartsNewSlice(data + offset, nalSize)) {
			return true;
		}
		offset += nalSize;
	}

	return false;
}

int DetectNalLengthSize(const uint8_t* data, size_t dataSize)
{
	if (!data || dataSize < 2 || StartsWithAnnexBStartCode(data, dataSize)) {
		return kUnknownNalLengthSize;
	}

	const int candidates[] = { 4, 2, 1 };
	for (size_t candidateIndex = 0; candidateIndex < sizeof(candidates) / sizeof(candidates[0]); ++candidateIndex) {
		const int nalLengthSize = candidates[candidateIndex];
		size_t offset = 0;
		bool foundNal = false;
		while (offset < dataSize) {
			if (dataSize - offset < static_cast<size_t>(nalLengthSize)) {
				foundNal = false;
				break;
			}

			uint32_t nalSize = 0;
			for (int i = 0; i < nalLengthSize; ++i) {
				nalSize = (nalSize << 8) | data[offset + i];
			}
			offset += nalLengthSize;
			if (nalSize == 0 || dataSize - offset < nalSize) {
				foundNal = false;
				break;
			}

			foundNal = true;
			offset += nalSize;
		}

		if (foundNal && offset == dataSize) {
			return nalLengthSize;
		}
	}

	return kUnknownNalLengthSize;
}

static bool AppendAvcParameterSet(const uint8_t* extraData, size_t extraDataSize, size_t* offset, std::vector<uint8_t>* output)
{
	if (!extraData || !offset || !output || extraDataSize - *offset < 2) {
		return false;
	}

	const uint16_t nalSize = (static_cast<uint16_t>(extraData[*offset]) << 8) | extraData[*offset + 1];
	*offset += 2;
	if (nalSize == 0 || extraDataSize - *offset < nalSize) {
		return false;
	}

	output->insert(output->end(), kAnnexBStartCode, kAnnexBStartCode + sizeof(kAnnexBStartCode));
	output->insert(output->end(), extraData + *offset, extraData + *offset + nalSize);
	*offset += nalSize;
	return true;
}

bool ConvertAvcConfigurationToAnnexB(const uint8_t* extraData, size_t extraDataSize, std::vector<uint8_t>* output)
{
	if (!IsAvcDecoderConfigurationRecord(extraData, extraDataSize) || !output) {
		return false;
	}

	output->clear();
	size_t offset = 5;
	if (extraDataSize - offset < 1) {
		return false;
	}

	const uint8_t spsCount = extraData[offset++] & 0x1f;
	for (uint8_t i = 0; i < spsCount; ++i) {
		if (!AppendAvcParameterSet(extraData, extraDataSize, &offset, output)) {
			return false;
		}
	}

	if (extraDataSize - offset < 1) {
		return false;
	}

	const uint8_t ppsCount = extraData[offset++];
	for (uint8_t i = 0; i < ppsCount; ++i) {
		if (!AppendAvcParameterSet(extraData, extraDataSize, &offset, output)) {
			return false;
		}
	}

	return !output->empty();
}

bool ConvertLengthPrefixedParameterSetsToAnnexB(const uint8_t* extraData, size_t extraDataSize, std::vector<uint8_t>* output)
{
	if (!extraData || !output || extraDataSize < 3 || StartsWithAnnexBStartCode(extraData, extraDataSize)) {
		return false;
	}

	output->clear();
	size_t offset = 0;
	while (offset < extraDataSize) {
		if (extraDataSize - offset < 2) {
			return false;
		}

		const uint16_t nalSize = (static_cast<uint16_t>(extraData[offset]) << 8) | extraData[offset + 1];
		offset += 2;
		if (nalSize == 0 || extraDataSize - offset < nalSize) {
			return false;
		}

		const uint8_t nalType = NalType(extraData[offset]);
		if (nalType != 7 && nalType != 8) {
			return false;
		}

		output->insert(output->end(), kAnnexBStartCode, kAnnexBStartCode + sizeof(kAnnexBStartCode));
		output->insert(output->end(), extraData + offset, extraData + offset + nalSize);
		offset += nalSize;
	}

	return !output->empty();
}

} // namespace PlayasaH264
