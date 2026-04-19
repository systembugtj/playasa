/* 
 *	Copyright (C) 2003-2006 Gabest
 *	http://www.gabest.org
 *
 *  This Program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2, or (at your option)
 *  any later version.
 *   
 *  This Program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *   
 *  You should have received a copy of the GNU General Public License
 *  along with GNU Make; see the file COPYING.  If not, write to
 *  the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA. 
 *  http://www.gnu.org/copyleft/gpl.html
 *
 */

// stdafx.h : include file for standard system include files,
// or project specific include files that are used frequently, but
// are changed infrequently
//

#pragma once

/* 不使用 WIN32_LEAN_AND_MEAN：否则 Windows SDK 下 ddraw/d3d7（IDirect3DDevice7 等）可能不完整，DX7SubPic 无法编译 */
#define _ATL_CSTRING_EXPLICIT_CONSTRUCTORS	// some CString constructors will be explicit
#ifndef WINVER
#define WINVER			0x0600
#endif

#include <afx.h>
#include <afxwin.h>         // MFC core and standard components

// TODO: reference additional headers your program requires here

#include <streams.h>
#include <dvdmedia.h>
#include "..\DSUtil\DSUtil.h"

// Note: DirectX headers are NOT included in stdafx.h to avoid conflicts
// between DirectX 7 and DirectX 9. Include them locally in files that need them:
// - For DirectX 7: #define DIRECT3D_VERSION 0x0700 before including <ddraw.h> and <d3d.h>
// - For DirectX 9: #undef DIRECT3D_VERSION before including <d3d9.h>