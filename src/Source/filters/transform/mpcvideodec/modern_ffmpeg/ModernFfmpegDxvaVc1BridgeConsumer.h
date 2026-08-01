#pragma once

#include "../../../../../Thirdparty/pkg/ffmpeg_modern_dxva_vc1.h"

#include <windows.h>

namespace ModernFfmpegDxvaVc1Bridge {

// RFC-0047 phase 4c-ii: dynamic loader for playasa_dxva_vc1_parse_* exports.
class Consumer {
public:
	static Consumer& Instance();

	bool IsAvailable() const;
	int Create(PlayasaDxvaVc1ParseSession** session);
	void Destroy(PlayasaDxvaVc1ParseSession* session);
	int Open(PlayasaDxvaVc1ParseSession* session, const uint8_t* extraData, size_t extraDataSize);
	int ParseBuffer(PlayasaDxvaVc1ParseSession* session, const uint8_t* data, size_t dataSize, PlayasaDxvaVc1ParseOutput* output);

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

	typedef int (*ParseCreateFn)(PlayasaDxvaVc1ParseSession**);
	typedef void (*ParseDestroyFn)(PlayasaDxvaVc1ParseSession*);
	typedef int (*ParseOpenFn)(PlayasaDxvaVc1ParseSession*, const uint8_t*, size_t);
	typedef int (*ParseBufferFn)(PlayasaDxvaVc1ParseSession*, const uint8_t*, size_t, PlayasaDxvaVc1ParseOutput*);

	ParseCreateFn parseCreate_;
	ParseDestroyFn parseDestroy_;
	ParseOpenFn parseOpen_;
	ParseBufferFn parseBuffer_;
};

} // namespace ModernFfmpegDxvaVc1Bridge
