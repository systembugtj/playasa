#include "StdAfx.h"
#include "RealAudioModernDecodeAdapter.h"

#include <stdio.h>

namespace {

const char* const kBridgeDllName = "playasa_ffmpeg_modern_bridge.dll";

} // namespace

CRealAudioModernDecodeAdapter::CRealAudioModernDecodeAdapter()
	: m_module(NULL)
	, m_session(NULL)
	, m_codec(0)
	, m_create(NULL)
	, m_openAudio(NULL)
	, m_decodeAudio(NULL)
	, m_receiveAudio(NULL)
	, m_flush(NULL)
	, m_lastError(NULL)
	, m_destroy(NULL)
{
	m_lastErrorText[0] = '\0';
}

CRealAudioModernDecodeAdapter::~CRealAudioModernDecodeAdapter()
{
	Close();
	if (m_module) {
		FreeLibrary(m_module);
		m_module = NULL;
	}
}

bool CRealAudioModernDecodeAdapter::Open(uint32_t codec, const PlayasaFfmpegModernAudioOpenParams* params)
{
	Close();
	if (!codec || !params) {
		SetError("Invalid RealAudio modern open parameters");
		return false;
	}
	if (!LoadBridge()) {
		return false;
	}
	if (!m_create(codec, &m_session) || !m_session) {
		SetError("Failed to create RealAudio FFmpeg modern bridge session");
		return false;
	}
	if (!m_openAudio(m_session, params)) {
		SetError(m_lastError(m_session));
		Close();
		return false;
	}

	m_codec = codec;
	m_lastErrorText[0] = '\0';
	return true;
}

int CRealAudioModernDecodeAdapter::DecodeAudio(const unsigned char* data, size_t dataSize, int64_t pts, PlayasaFfmpegModernAudioFrameInfo* frameInfo)
{
	if (!m_session || !m_decodeAudio) {
		SetError("RealAudio FFmpeg modern bridge session is not open");
		return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
	}

	const int status = m_decodeAudio(m_session, data, dataSize, pts, frameInfo);
	if (status == PLAYASA_FFMPEG_MODERN_STATUS_FAILURE) {
		SetError(m_lastError(m_session));
	}
	return status;
}

int CRealAudioModernDecodeAdapter::ReceiveAudio(PlayasaFfmpegModernAudioFrameInfo* frameInfo)
{
	if (!m_session || !m_receiveAudio) {
		SetError("RealAudio FFmpeg modern bridge session is not open");
		return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
	}

	const int status = m_receiveAudio(m_session, frameInfo);
	if (status == PLAYASA_FFMPEG_MODERN_STATUS_FAILURE) {
		SetError(m_lastError(m_session));
	}
	return status;
}

void CRealAudioModernDecodeAdapter::Flush()
{
	if (m_session && m_flush) {
		m_flush(m_session);
	}
}

void CRealAudioModernDecodeAdapter::Close()
{
	if (m_session && m_destroy) {
		m_destroy(m_session);
	}
	m_session = NULL;
	m_codec = 0;
}

bool CRealAudioModernDecodeAdapter::IsOpen() const
{
	return m_session != NULL;
}

uint32_t CRealAudioModernDecodeAdapter::OpenCodec() const
{
	return m_codec;
}

const char* CRealAudioModernDecodeAdapter::LastError() const
{
	return m_lastErrorText;
}

bool CRealAudioModernDecodeAdapter::LoadBridge()
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
	m_openAudio = reinterpret_cast<OpenAudioFn>(LoadRequiredProc("playasa_ffmpeg_modern_open_audio"));
	m_decodeAudio = reinterpret_cast<DecodeAudioFn>(LoadRequiredProc("playasa_ffmpeg_modern_decode_audio"));
	m_receiveAudio = reinterpret_cast<ReceiveAudioFn>(LoadRequiredProc("playasa_ffmpeg_modern_receive_audio"));
	m_flush = reinterpret_cast<FlushFn>(LoadRequiredProc("playasa_ffmpeg_modern_flush"));
	m_lastError = reinterpret_cast<LastErrorFn>(LoadRequiredProc("playasa_ffmpeg_modern_last_error"));
	m_destroy = reinterpret_cast<DestroyFn>(LoadRequiredProc("playasa_ffmpeg_modern_destroy"));

	if (!m_create || !m_openAudio || !m_decodeAudio || !m_receiveAudio || !m_flush || !m_lastError || !m_destroy) {
		FreeLibrary(m_module);
		m_module = NULL;
		return false;
	}

	return true;
}

FARPROC CRealAudioModernDecodeAdapter::LoadRequiredProc(const char* name)
{
	FARPROC proc = GetProcAddress(m_module, name);
	if (!proc) {
		char message[256] = { 0 };
		_snprintf_s(message, sizeof(message), _TRUNCATE, "Missing RealAudio FFmpeg modern bridge export: %s", name);
		SetError(message);
	}
	return proc;
}

void CRealAudioModernDecodeAdapter::SetError(const char* message)
{
	if (!message) {
		message = "Unknown RealAudio FFmpeg modern bridge error";
	}
	_snprintf_s(m_lastErrorText, sizeof(m_lastErrorText), _TRUNCATE, "%s", message);
}
