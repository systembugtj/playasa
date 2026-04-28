#include "stdafx.h"
#include "Mpeg2ModernDecodeAdapter.h"

#include <stdio.h>

namespace {

const char* const kBridgeDllName = "playasa_ffmpeg_modern_bridge.dll";

} // namespace

CMpeg2ModernDecodeAdapter::CMpeg2ModernDecodeAdapter()
	: m_module(NULL)
	, m_session(NULL)
	, m_create(NULL)
	, m_open(NULL)
	, m_decodeWithTiming(NULL)
	, m_receivePending(NULL)
	, m_flush(NULL)
	, m_lastError(NULL)
	, m_destroy(NULL)
{
	m_lastErrorText[0] = '\0';
}

CMpeg2ModernDecodeAdapter::~CMpeg2ModernDecodeAdapter()
{
	Close();
	if (m_module) {
		FreeLibrary(m_module);
		m_module = NULL;
	}
}

bool CMpeg2ModernDecodeAdapter::Open()
{
	Close();
	if (!LoadBridge()) {
		return false;
	}
	if (!m_create(PLAYASA_FFMPEG_MODERN_CODEC_MPEG2, &m_session) || !m_session) {
		SetError("Failed to create MPEG-2 FFmpeg modern bridge session");
		return false;
	}
	if (!m_open(m_session, NULL, 0)) {
		SetError(m_lastError(m_session));
		Close();
		return false;
	}

	m_lastErrorText[0] = '\0';
	return true;
}

int CMpeg2ModernDecodeAdapter::Decode(const unsigned char* data, size_t dataSize, int64_t pts, int64_t duration, PlayasaFfmpegModernFrameInfo* frameInfo)
{
	if (!m_session || !m_decodeWithTiming) {
		SetError("MPEG-2 FFmpeg modern bridge session is not open");
		return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
	}

	const int status = m_decodeWithTiming(m_session, data, dataSize, pts, duration, frameInfo);
	if (status == PLAYASA_FFMPEG_MODERN_STATUS_FAILURE) {
		SetError(m_lastError(m_session));
	}
	return status;
}

int CMpeg2ModernDecodeAdapter::ReceivePending(PlayasaFfmpegModernFrameInfo* frameInfo)
{
	if (!m_session || !m_receivePending) {
		SetError("MPEG-2 FFmpeg modern bridge session is not open");
		return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
	}

	const int status = m_receivePending(m_session, frameInfo);
	if (status == PLAYASA_FFMPEG_MODERN_STATUS_FAILURE) {
		SetError(m_lastError(m_session));
	}
	return status;
}

void CMpeg2ModernDecodeAdapter::Flush()
{
	if (m_session && m_flush) {
		m_flush(m_session);
	}
}

void CMpeg2ModernDecodeAdapter::Close()
{
	if (m_session && m_destroy) {
		m_destroy(m_session);
	}
	m_session = NULL;
}

bool CMpeg2ModernDecodeAdapter::IsOpen() const
{
	return m_session != NULL;
}

const char* CMpeg2ModernDecodeAdapter::LastError() const
{
	return m_lastErrorText;
}

bool CMpeg2ModernDecodeAdapter::LoadBridge()
{
	if (m_module) {
		return true;
	}

	m_module = LoadLibraryA(kBridgeDllName);
	if (!m_module) {
		SetError("Failed to load playasa_ffmpeg_modern_bridge.dll");
		return false;
	}

	m_create = reinterpret_cast<CreateFn>(LoadRequiredProc("playasa_ffmpeg_modern_create"));
	m_open = reinterpret_cast<OpenFn>(LoadRequiredProc("playasa_ffmpeg_modern_open"));
	m_decodeWithTiming = reinterpret_cast<DecodeWithTimingFn>(LoadRequiredProc("playasa_ffmpeg_modern_decode_with_timing"));
	m_receivePending = reinterpret_cast<ReceivePendingFn>(LoadRequiredProc("playasa_ffmpeg_modern_receive_pending"));
	m_flush = reinterpret_cast<FlushFn>(LoadRequiredProc("playasa_ffmpeg_modern_flush"));
	m_lastError = reinterpret_cast<LastErrorFn>(LoadRequiredProc("playasa_ffmpeg_modern_last_error"));
	m_destroy = reinterpret_cast<DestroyFn>(LoadRequiredProc("playasa_ffmpeg_modern_destroy"));

	if (!m_create || !m_open || !m_decodeWithTiming || !m_receivePending || !m_flush || !m_lastError || !m_destroy) {
		FreeLibrary(m_module);
		m_module = NULL;
		return false;
	}

	return true;
}

FARPROC CMpeg2ModernDecodeAdapter::LoadRequiredProc(const char* name)
{
	FARPROC proc = GetProcAddress(m_module, name);
	if (!proc) {
		char message[256] = { 0 };
		_snprintf_s(message, sizeof(message), _TRUNCATE, "Missing FFmpeg modern bridge export: %s", name);
		SetError(message);
	}
	return proc;
}

void CMpeg2ModernDecodeAdapter::SetError(const char* message)
{
	if (!message) {
		message = "Unknown MPEG-2 FFmpeg modern bridge error";
	}
	_snprintf_s(m_lastErrorText, sizeof(m_lastErrorText), _TRUNCATE, "%s", message);
}
