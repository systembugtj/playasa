#pragma once

#include "ffmpeg_modern_bridge.h"

#include <windows.h>

// Dynamic loader for RealAudio FFmpeg modern bridge (cook / sipr / atrac3).
class CRealAudioModernDecodeAdapter
{
public:
	CRealAudioModernDecodeAdapter();
	~CRealAudioModernDecodeAdapter();

	bool Open(uint32_t codec, const PlayasaFfmpegModernAudioOpenParams* params);
	int DecodeAudio(const unsigned char* data, size_t dataSize, int64_t pts, PlayasaFfmpegModernAudioFrameInfo* frameInfo);
	int ReceiveAudio(PlayasaFfmpegModernAudioFrameInfo* frameInfo);
	void Flush();
	void Close();
	bool IsOpen() const;
	uint32_t OpenCodec() const;
	const char* LastError() const;

private:
	typedef int (*CreateFn)(uint32_t, PlayasaFfmpegModernSession*);
	typedef int (*OpenAudioFn)(PlayasaFfmpegModernSession, const PlayasaFfmpegModernAudioOpenParams*);
	typedef int (*DecodeAudioFn)(PlayasaFfmpegModernSession, const uint8_t*, size_t, int64_t, PlayasaFfmpegModernAudioFrameInfo*);
	typedef int (*ReceiveAudioFn)(PlayasaFfmpegModernSession, PlayasaFfmpegModernAudioFrameInfo*);
	typedef void (*FlushFn)(PlayasaFfmpegModernSession);
	typedef const char* (*LastErrorFn)(PlayasaFfmpegModernSession);
	typedef void (*DestroyFn)(PlayasaFfmpegModernSession);

	CRealAudioModernDecodeAdapter(const CRealAudioModernDecodeAdapter&);
	CRealAudioModernDecodeAdapter& operator=(const CRealAudioModernDecodeAdapter&);

	bool LoadBridge();
	FARPROC LoadRequiredProc(const char* name);
	void SetError(const char* message);

	HMODULE m_module;
	PlayasaFfmpegModernSession m_session;
	uint32_t m_codec;
	CreateFn m_create;
	OpenAudioFn m_openAudio;
	DecodeAudioFn m_decodeAudio;
	ReceiveAudioFn m_receiveAudio;
	FlushFn m_flush;
	LastErrorFn m_lastError;
	DestroyFn m_destroy;
	char m_lastErrorText[256];
};
