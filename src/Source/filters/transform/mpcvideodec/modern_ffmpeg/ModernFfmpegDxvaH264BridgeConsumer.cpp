#include "../stdafx.h"
#include "ModernFfmpegDxvaH264BridgeConsumer.h"

namespace ModernFfmpegDxvaBridge {

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
	, parseFill_(NULL)
	, parseSetSurface_(NULL)
	, parseUpdateRef_(NULL)
	, parseIsRef_(NULL)
	, parseSliceLong_(NULL)
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

	parseCreate_ = reinterpret_cast<ParseCreateFn>(LoadRequiredProc("playasa_dxva_h264_parse_create"));
	parseDestroy_ = reinterpret_cast<ParseDestroyFn>(LoadRequiredProc("playasa_dxva_h264_parse_destroy"));
	parseOpen_ = reinterpret_cast<ParseOpenFn>(LoadRequiredProc("playasa_dxva_h264_parse_open"));
	parseBuffer_ = reinterpret_cast<ParseBufferFn>(LoadRequiredProc("playasa_dxva_h264_parse_buffer"));
	parseFill_ = reinterpret_cast<ParseFillFn>(LoadRequiredProc("playasa_dxva_h264_parse_fill_picture_context"));
	parseSetSurface_ = reinterpret_cast<ParseSetSurfaceFn>(LoadRequiredProc("playasa_dxva_h264_parse_set_surface_index"));
	parseUpdateRef_ = reinterpret_cast<ParseUpdateRefFn>(LoadRequiredProc("playasa_dxva_h264_parse_update_ref_frames"));
	parseIsRef_ = reinterpret_cast<ParseIsRefFn>(LoadRequiredProc("playasa_dxva_h264_parse_is_ref_in_use"));
	parseSliceLong_ = reinterpret_cast<ParseSliceLongFn>(LoadRequiredProc("playasa_dxva_h264_parse_update_slice_long"));

	loadSucceeded_ = parseCreate_ && parseDestroy_ && parseOpen_ && parseBuffer_ && parseFill_
		&& parseSetSurface_ && parseUpdateRef_ && parseIsRef_ && parseSliceLong_;
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

int Consumer::Create(PlayasaDxvaH264ParseSession** session)
{
	if (!EnsureLoaded() || !parseCreate_) {
		return 0;
	}
	return parseCreate_(session);
}

void Consumer::Destroy(PlayasaDxvaH264ParseSession* session)
{
	if (parseDestroy_) {
		parseDestroy_(session);
	}
}

int Consumer::Open(PlayasaDxvaH264ParseSession* session, const uint8_t* extraData, size_t extraDataSize, int32_t nalLengthSize)
{
	if (!parseOpen_) {
		return 0;
	}
	return parseOpen_(session, extraData, extraDataSize, nalLengthSize);
}

int Consumer::ParseBuffer(PlayasaDxvaH264ParseSession* session, const uint8_t* data, size_t dataSize, PlayasaDxvaH264ParseOutput* output)
{
	if (!parseBuffer_) {
		return 0;
	}
	return parseBuffer_(session, data, dataSize, output);
}

int Consumer::FillPictureContext(PlayasaDxvaH264ParseSession* session, int pciVendor, PlayasaDxvaH264ParseOutput* output)
{
	if (!parseFill_) {
		return 0;
	}
	return parseFill_(session, pciVendor, output);
}

void Consumer::SetSurfaceIndex(PlayasaDxvaH264ParseSession* session, int surfaceIndex)
{
	if (parseSetSurface_) {
		parseSetSurface_(session, surfaceIndex);
	}
}

void Consumer::UpdateRefFrames(PlayasaDxvaH264ParseSession* session, DXVA_PicParams_H264* picParams)
{
	if (parseUpdateRef_) {
		parseUpdateRef_(session, picParams);
	}
}

int Consumer::IsRefInUse(PlayasaDxvaH264ParseSession* session, int surfaceIndex)
{
	if (!parseIsRef_) {
		return 0;
	}
	return parseIsRef_(session, surfaceIndex);
}

void Consumer::UpdateSliceLong(PlayasaDxvaH264ParseSession* session, DXVA_PicParams_H264* picParams, DXVA_Slice_H264_Long* slice)
{
	if (parseSliceLong_) {
		parseSliceLong_(session, picParams, slice);
	}
}

} // namespace ModernFfmpegDxvaBridge
