// stdafx.h : include file for standard system include files,
// or project specific include files that are used frequently, but
// are changed infrequently
//

#pragma once

/* 与解决方案 common.props 及 VS2022+ ATL 头文件一致，避免 LCMapStringEx 等 API 声明缺失 */
#define WINVER 0x0A00
#define _WIN32_WINNT 0x0A00
#define _WIN32_IE  0x0700
#define _RICHEDIT_VER  0x0200

#include <windows.h>
#include <tchar.h>
#include <string>
#include <vector>

#include <atlbase.h>
#include <atlapp.h>
#include <atlmisc.h>
// TODO: reference additional headers your program requires here
