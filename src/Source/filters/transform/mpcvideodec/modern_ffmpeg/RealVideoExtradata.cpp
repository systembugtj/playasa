#include "../stdafx.h"

#include "RealVideoExtradata.h"

#include <stdint.h>

namespace {

const DWORD kRealVideoHeaderSkipBytes = 26;

}

bool PlayasaBuildRealVideoExtradataFromVideoInfo(
	const BYTE* format,
	DWORD formatLength,
	uint8_t** outExtradata,
	int* outExtradataSize)
{
	if (!outExtradata || !outExtradataSize) {
		return false;
	}

	*outExtradata = NULL;
	*outExtradataSize = 0;
	if (!format || formatLength <= sizeof(VIDEOINFOHEADER)) {
		return false;
	}

	int extraDataLength = static_cast<int>(formatLength - sizeof(VIDEOINFOHEADER));
	if (extraDataLength <= 0) {
		return false;
	}

	if (extraDataLength > static_cast<int>(kRealVideoHeaderSkipBytes)) {
		extraDataLength -= static_cast<int>(kRealVideoHeaderSkipBytes);
	}

	uint8_t* extradata = static_cast<uint8_t*>(calloc(1, extraDataLength));
	if (!extradata) {
		return false;
	}

	const uint8_t* payload = format + sizeof(VIDEOINFOHEADER) + kRealVideoHeaderSkipBytes;
	memcpy(extradata, payload, extraDataLength);
	*outExtradata = extradata;
	*outExtradataSize = extraDataLength;
	return true;
}
