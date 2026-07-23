#pragma once

#include "../../../../../Thirdparty/pkg/ffmpeg_modern_dxva_h264.h"

#include <windows.h>

namespace ModernFfmpegDxvaBridge {

// RFC-0047 phase 3c: dynamic loader for playasa_dxva_h264_parse_* exports.
class Consumer {
public:
	static Consumer& Instance();

	bool IsAvailable() const;
	int Create(PlayasaDxvaH264ParseSession** session);
	void Destroy(PlayasaDxvaH264ParseSession* session);
	int Open(PlayasaDxvaH264ParseSession* session, const uint8_t* extraData, size_t extraDataSize, int32_t nalLengthSize);
	int ParseBuffer(PlayasaDxvaH264ParseSession* session, const uint8_t* data, size_t dataSize, PlayasaDxvaH264ParseOutput* output);
	int FillPictureContext(PlayasaDxvaH264ParseSession* session, int pciVendor, PlayasaDxvaH264ParseOutput* output);
	void SetSurfaceIndex(PlayasaDxvaH264ParseSession* session, int surfaceIndex);
	void UpdateRefFrames(PlayasaDxvaH264ParseSession* session, DXVA_PicParams_H264* picParams);
	int IsRefInUse(PlayasaDxvaH264ParseSession* session, int surfaceIndex);
	void UpdateSliceLong(PlayasaDxvaH264ParseSession* session, DXVA_PicParams_H264* picParams, DXVA_Slice_H264_Long* slice);

private:
	Consumer();
	~Consumer();

	Consumer(const Consumer&);
	Consumer& operator=(const Consumer&);

	bool EnsureLoaded();
	FARPROC LoadRequiredProc(const char* name);

	mutable HMODULE module_;
	bool loadAttempted_;
	bool loadSucceeded_;

	typedef int (*ParseCreateFn)(PlayasaDxvaH264ParseSession**);
	typedef void (*ParseDestroyFn)(PlayasaDxvaH264ParseSession*);
	typedef int (*ParseOpenFn)(PlayasaDxvaH264ParseSession*, const uint8_t*, size_t, int32_t);
	typedef int (*ParseBufferFn)(PlayasaDxvaH264ParseSession*, const uint8_t*, size_t, PlayasaDxvaH264ParseOutput*);
	typedef int (*ParseFillFn)(PlayasaDxvaH264ParseSession*, int, PlayasaDxvaH264ParseOutput*);
	typedef void (*ParseSetSurfaceFn)(PlayasaDxvaH264ParseSession*, int);
	typedef void (*ParseUpdateRefFn)(PlayasaDxvaH264ParseSession*, DXVA_PicParams_H264*);
	typedef int (*ParseIsRefFn)(PlayasaDxvaH264ParseSession*, int);
	typedef void (*ParseSliceLongFn)(PlayasaDxvaH264ParseSession*, DXVA_PicParams_H264*, DXVA_Slice_H264_Long*);

	ParseCreateFn parseCreate_;
	ParseDestroyFn parseDestroy_;
	ParseOpenFn parseOpen_;
	ParseBufferFn parseBuffer_;
	ParseFillFn parseFill_;
	ParseSetSurfaceFn parseSetSurface_;
	ParseUpdateRefFn parseUpdateRef_;
	ParseIsRefFn parseIsRef_;
	ParseSliceLongFn parseSliceLong_;
};

} // namespace ModernFfmpegDxvaBridge
