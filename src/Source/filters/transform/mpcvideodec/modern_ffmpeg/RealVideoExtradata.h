#pragma once

// RFC-0032: RealVideo extradata from DirectShow VIDEOINFOHEADER (skip 26-byte Real header).

bool PlayasaBuildRealVideoExtradataFromVideoInfo(
	const BYTE* format,
	DWORD formatLength,
	uint8_t** outExtradata,
	int* outExtradataSize);
