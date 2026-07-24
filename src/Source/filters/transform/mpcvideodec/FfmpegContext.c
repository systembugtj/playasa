

/* 
 * $Id: FfmpegContext.c 1233 2009-08-16 10:07:18Z casimir666 $
 *
 * (C) 2006-2007 see AUTHORS
 *
 * This file is part of mplayerc.
 *
 * Mplayerc is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * Mplayerc is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */


#define HAVE_AV_CONFIG_H

#include <windows.h>
#include <winnt.h>
#include <vfwmsgs.h>
#include "FfmpegContext.h"
#include "avcodec.h"


int IsVista()
{
	OSVERSIONINFO osver;

	osver.dwOSVersionInfoSize = sizeof( OSVERSIONINFO );
	
	if (	GetVersionEx( &osver ) && 
			osver.dwPlatformId == VER_PLATFORM_WIN32_NT && 
			(osver.dwMajorVersion >= 6 ) )
		return 1;

	return 0;
}

char* GetFFMpegPictureType(int nType)
{
	static char*	s_FFMpegPictTypes[] = { "? ", "I ", "P ", "B ", "S ", "SI", "SP" };
	int		nTypeCount = sizeof(s_FFMpegPictTypes)/sizeof(TCHAR)-1;

	return s_FFMpegPictTypes[min(nType, nTypeCount)];
}


unsigned long FFGetMBNumber(struct AVCodecContext* pAVCtx)
{
	if (!pAVCtx) {
		return 0;
	}
	if (pAVCtx->codec_id == CODEC_ID_MPEG2VIDEO) {
		return FFGetMpeg2MBNumber(pAVCtx);
	}
	if (pAVCtx->codec_id == CODEC_ID_H264 || pAVCtx->codec_id == CODEC_ID_VC1) {
		return FFGetMpegEncMBNumber(pAVCtx);
	}
	return 0;
}

int FFIsInterlaced(struct AVCodecContext* pAVCtx, int nHeight)
{
	if (pAVCtx->codec_id == CODEC_ID_H264)
	{
		return FFH264IsInterlaced(pAVCtx) ? 1 : 0;
	}
	else if (pAVCtx->codec_id == CODEC_ID_VC1)
	{
		return FFVC1IsInterlaced(pAVCtx) ? 1 : 0;
	}

	return 0;
}

int FFGetCodedPicture(struct AVCodecContext* pAVCtx)
{
	if (!pAVCtx) {
		return 0;
	}
	if (pAVCtx->codec_id == CODEC_ID_MPEG2VIDEO) {
		return FFGetMpeg2CodedPicture(pAVCtx);
	}
	if (pAVCtx->codec_id == CODEC_ID_H264 || pAVCtx->codec_id == CODEC_ID_VC1) {
		return FFGetMpegEncCodedPicture(pAVCtx);
	}
	return 0;
}

BOOL FFGetAlternateScan(struct AVCodecContext* pAVCtx)
{
	if (!pAVCtx) {
		return 0;
	}
	if (pAVCtx->codec_id == CODEC_ID_MPEG2VIDEO) {
		return FFGetMpeg2AlternateScan(pAVCtx);
	}
	if (pAVCtx->codec_id == CODEC_ID_H264 || pAVCtx->codec_id == CODEC_ID_VC1) {
		return FFGetMpegEncAlternateScan(pAVCtx);
	}
	return 0;
}
