#include "../stdafx.h"
#include "ModernFfmpegDxvaVc1BridgeConsumer.h"

namespace ModernFfmpegDxvaVc1Bridge {

namespace {

const char* const kBridgeDllName = "playasa_ffmpeg_modern_bridge.dll";

} // namespace

Consumer& Consumer::Instance()
{
	static Consumer instance;
	return instance;
}

Consumer::Consumer()
	: module_(NULL)
	, loadAttempted_(false)
	, loadSucceeded_(false)
	, parseCreate_(NULL)
	, parseDestroy_(NULL)
	, parseOpen_(NULL)
	, parseBuffer_(NULL)
{
}

Consumer::~Consumer()
{
	if (module_) {
		FreeLibrary(module_);
		module_ = NULL;
	}
}

bool Consumer::IsAvailable() const
{
	return const_cast<Consumer*>(this)->EnsureLoaded();
}

bool Consumer::EnsureLoaded()
{
	if (loadAttempted_) {
		return loadSucceeded_;
	}

	loadAttempted_ = true;
	module_ = LoadLibraryA(kBridgeDllName);
	if (!module_) {
		return false;
	}

	parseCreate_ = reinterpret_cast<ParseCreateFn>(LoadRequiredProc("playasa_dxva_vc1_parse_create"));
	parseDestroy_ = reinterpret_cast<ParseDestroyFn>(LoadRequiredProc("playasa_dxva_vc1_parse_destroy"));
	parseOpen_ = reinterpret_cast<ParseOpenFn>(LoadRequiredProc("playasa_dxva_vc1_parse_open"));
	parseBuffer_ = reinterpret_cast<ParseBufferFn>(LoadRequiredProc("playasa_dxva_vc1_parse_buffer"));

	loadSucceeded_ = parseCreate_ && parseDestroy_ && parseOpen_ && parseBuffer_;
	if (!loadSucceeded_) {
		FreeLibrary(module_);
		module_ = NULL;
	}

	return loadSucceeded_;
}

FARPROC Consumer::LoadRequiredProc(const char* name)
{
	if (!module_) {
		return NULL;
	}
	return GetProcAddress(module_, name);
}

int Consumer::Create(PlayasaDxvaVc1ParseSession** session)
{
	if (!EnsureLoaded() || !parseCreate_) {
		return 0;
	}
	return parseCreate_(session);
}

void Consumer::Destroy(PlayasaDxvaVc1ParseSession* session)
{
	if (parseDestroy_) {
		parseDestroy_(session);
	}
}

int Consumer::Open(PlayasaDxvaVc1ParseSession* session, const uint8_t* extraData, size_t extraDataSize)
{
	if (!parseOpen_) {
		return 0;
	}
	return parseOpen_(session, extraData, extraDataSize);
}

int Consumer::ParseBuffer(PlayasaDxvaVc1ParseSession* session, const uint8_t* data, size_t dataSize, PlayasaDxvaVc1ParseOutput* output)
{
	if (!parseBuffer_) {
		return 0;
	}
	return parseBuffer_(session, data, dataSize, output);
}

} // namespace ModernFfmpegDxvaVc1Bridge
