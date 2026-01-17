// ----------------------------------------------------------------------------
// WavPack lib for Matroska
// ----------------------------------------------------------------------------
// Copyright christophe.paris@free.fr
// Parts by David Bryant http://www.wavpack.com
// Distributed under the BSD Software License
// ----------------------------------------------------------------------------

#include "..\wavpack\wputils.h"
#include "wavpack_common.h"

// ----------------------------------------------------------------------------

#if defined(_WIN32)

#ifdef _DEBUG

#include <stdio.h>
#include <stdarg.h>
#include <string.h>

void DebugLog(const char *pFormat,...) {
    char szInfo[2000];
    
    // Format the variable length parameter list
    va_list va;
    va_start(va, pFormat);
    
    vsprintf_s(szInfo, sizeof(szInfo), pFormat, va);
    strcat_s(szInfo, sizeof(szInfo), "\r\n");
    OutputDebugStringA(szInfo);
    
    va_end(va);
}

#endif

#endif

// ----------------------------------------------------------------------------