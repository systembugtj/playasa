#pragma once

#include "../../../../../Thirdparty/pkg/ffmpeg_modern_dxva_mpeg2.h"

#include <windows.h>

namespace ModernFfmpegDxvaMpeg2Bridge {

// RFC-0047 phase 4c-ii: dynamic loader for playasa_dxva_mpeg2_parse_* exports.
class Consumer {
public:
	static Consumer& Instance();

	bool IsAvailable() const;
	int Create(PlayasaDxvaMpeg2ParseSession** session);
	void Destroy(PlayasaDxvaMpeg2ParseSession* session);
	int Open(PlayasaDxvaMpeg2ParseSession* session, const uint8_t* extraData, size_t extraDataSize);
	int ParseBuffer(PlayasaDxvaMpeg2ParseSession* session, const uint8_t* data, size_t dataSize, PlayasaDxvaMpeg2ParseOutput* output);

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

	typedef int (*ParseCreateFn)(PlayasaDxvaMpeg2ParseSession**);
	typedef void (*ParseDestroyFn)(PlayasaDxvaMpeg2ParseSession*);
	typedef int (*ParseOpenFn)(PlayasaDxvaMpeg2ParseSession*, const uint8_t*, size_t);
	typedef int (*ParseBufferFn)(PlayasaDxvaMpeg2ParseSession*, const uint8_t*, size_t, PlayasaDxvaMpeg2ParseOutput*);

	ParseCreateFn parseCreate_;
	ParseDestroyFn parseDestroy_;
	ParseOpenFn parseOpen_;
	ParseBufferFn parseBuffer_;
};

} // namespace ModernFfmpegDxvaMpeg2Bridge
