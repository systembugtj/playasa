#pragma once

#include "../../../../Thirdparty/pkg/ffmpeg_modern_bridge.h"

#include <windows.h>

class CMpeg2ModernDecodeAdapter
{
public:
	CMpeg2ModernDecodeAdapter();
	~CMpeg2ModernDecodeAdapter();

	bool Open(uint32_t codec, const unsigned char* extraData = NULL, size_t extraDataSize = 0);
	int Decode(const unsigned char* data, size_t dataSize, int64_t pts, int64_t duration, PlayasaFfmpegModernFrameInfo* frameInfo);
	int ReceivePending(PlayasaFfmpegModernFrameInfo* frameInfo);
	void Flush();
	void Close();
	bool IsOpen() const;
	const char* LastError() const;

private:
	typedef int (*CreateFn)(uint32_t, PlayasaFfmpegModernSession*);
	typedef int (*OpenFn)(PlayasaFfmpegModernSession, const uint8_t*, size_t);
	typedef int (*DecodeWithTimingFn)(PlayasaFfmpegModernSession, const uint8_t*, size_t, int64_t, int64_t, PlayasaFfmpegModernFrameInfo*);
	typedef int (*ReceivePendingFn)(PlayasaFfmpegModernSession, PlayasaFfmpegModernFrameInfo*);
	typedef void (*FlushFn)(PlayasaFfmpegModernSession);
	typedef const char* (*LastErrorFn)(PlayasaFfmpegModernSession);
	typedef void (*DestroyFn)(PlayasaFfmpegModernSession);

	CMpeg2ModernDecodeAdapter(const CMpeg2ModernDecodeAdapter&);
	CMpeg2ModernDecodeAdapter& operator=(const CMpeg2ModernDecodeAdapter&);

	bool LoadBridge();
	FARPROC LoadRequiredProc(const char* name);
	void SetError(const char* message);

	HMODULE m_module;
	PlayasaFfmpegModernSession m_session;
	CreateFn m_create;
	OpenFn m_open;
	DecodeWithTimingFn m_decodeWithTiming;
	ReceivePendingFn m_receivePending;
	FlushFn m_flush;
	LastErrorFn m_lastError;
	DestroyFn m_destroy;
	char m_lastErrorText[256];
};
