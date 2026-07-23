/* 
 * $Id: DXVADecoderH264.cpp 1207 2009-08-02 15:35:14Z casimir666 $
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

#include "stdafx.h"
#include "..\..\..\DSUtil\DSUtil.h"
#include "DXVADecoderH264.h"
#include "MPCVideoDecFilter.h"
#include "VideoDecDXVAAllocator.h"

extern "C"
{
	#include "FfmpegContext.h"
}


CDXVADecoderH264::CDXVADecoderH264 (CMPCVideoDecFilter* pFilter, IAMVideoAccelerator*  pAMVideoAccelerator, DXVAMode nMode, int nPicEntryNumber)
				: CDXVADecoder (pFilter, pAMVideoAccelerator, nMode, nPicEntryNumber)
{
	m_bUseLongSlice = (GetDXVA1Config()->bConfigBitstreamRaw != 2);
	Init();
}

CDXVADecoderH264::CDXVADecoderH264 (CMPCVideoDecFilter* pFilter, IDirectXVideoDecoder* pDirectXVideoDec, DXVAMode nMode, int nPicEntryNumber, DXVA2_ConfigPictureDecode* pDXVA2Config)
				: CDXVADecoder (pFilter, pDirectXVideoDec, nMode, nPicEntryNumber, pDXVA2Config)
{
	m_bUseLongSlice = (m_pFilter->GetDXVA2Config()->ConfigBitstreamRaw != 2);
	Init();
}

CDXVADecoderH264::~CDXVADecoderH264()
{
	FFH264DestroyDxvaSession (m_pDxvaSession);
	m_pDxvaSession = NULL;
}

void CDXVADecoderH264::Init()
{
	/* RFC-0047 phase 3d: modern parse session needs no AVCodecContext at bind time. */
	m_pDxvaSession = FFH264CreateDxvaSession (
		FFH264IsModernDxvaParseAvailable () ? NULL : m_pFilter->GetAVCtx ());
	memset (&m_DXVAPicParams,	0, sizeof (m_DXVAPicParams));
	memset (&m_DXVAPicParams,   0, sizeof (DXVA_PicParams_H264));
	memset (&m_pSliceLong,	    0, sizeof (DXVA_Slice_H264_Long) *MAX_SLICES);
	memset (&m_pSliceShort,	    0, sizeof (DXVA_Slice_H264_Short)*MAX_SLICES);
	
	m_DXVAPicParams.MbsConsecutiveFlag					= 1;
	if(m_pFilter->GetPCIVendor() == 0x8086) 
		m_DXVAPicParams.Reserved16Bits					= 0x534c;
	else
		m_DXVAPicParams.Reserved16Bits					= 0;
	m_DXVAPicParams.ContinuationFlag					= 1;
	m_DXVAPicParams.Reserved8BitsA						= 0;
	m_DXVAPicParams.Reserved8BitsB						= 0;
	m_DXVAPicParams.MinLumaBipredSize8x8Flag			= 1;	// Improve accelerator performances
	m_DXVAPicParams.StatusReportFeedbackNumber			= 0;	// Use to report status

	for (int i =0; i<16; i++)
	{
		m_DXVAPicParams.RefFrameList[i].AssociatedFlag	= 1;
		m_DXVAPicParams.RefFrameList[i].bPicEntry		= 255;
		m_DXVAPicParams.RefFrameList[i].Index7Bits		= 127;
	}


	m_nNALLength		= 4;
	m_nMaxSlices		= 0;

	switch (GetMode())
	{
	case H264_VLD :
		AllocExecuteParams (3);
		break;
	default :
		ASSERT(FALSE);	SVPASSERT(FALSE);
	}
}


void CDXVADecoderH264::CopyBitstream(BYTE* pDXVABuffer, BYTE* pBuffer, UINT& nSize)
{
	CH264Nalu		Nalu;
	int				nDummy;
	int				nSlices = 0;
	int				nDxvaNalLength;

	Nalu.SetBuffer (pBuffer, nSize, m_nNALLength);
	nSize = 0;

#if 0
	// Test to place Nal on multiple of 128 bytes (seems to be not necessary)
	if(!m_bUseLongSlice)
	{
		while (Nalu.ReadNext())
		{
			switch (Nalu.GetType())
			{
			case NALU_TYPE_SLICE:
			case NALU_TYPE_IDR:
				// For AVC1, put startcode 0x000001
				pDXVABuffer[0]=pDXVABuffer[1]=0;pDXVABuffer[2]=1;
				
				// Copy NALU
				memcpy (pDXVABuffer+3, Nalu.GetDataBuffer(), Nalu.GetDataLength());
				
				// Complete with zero padding (buffer size should be a multiple of 128)
				nDummy		 = 128 - ((Nalu.GetDataLength()+3) %128);
				pDXVABuffer	+= Nalu.GetDataLength() + 3;
				memset (pDXVABuffer, 0, nDummy);
				pDXVABuffer	+= nDummy;

				// Update slice control buffer
				nDxvaNalLength									= Nalu.GetDataLength()+3+nDummy;
				m_pSliceShort[nSlices].BSNALunitDataLocation	= nSize;
				m_pSliceShort[nSlices].SliceBytesInBuffer		= nDxvaNalLength;

				nSize										   += nDxvaNalLength;
				nSlices++;
				break;
			}
		}
	}
	else
#endif
	{
		while (Nalu.ReadNext())
		{
			switch (Nalu.GetType())
			{
			case NALU_TYPE_SLICE:
			case NALU_TYPE_IDR:
				// For AVC1, put startcode 0x000001
				pDXVABuffer[0]=pDXVABuffer[1]=0;pDXVABuffer[2]=1;
        if(Nalu.GetDataLength() < 0) 
          break;

				// Copy NALU
        __try {
				  memcpy (pDXVABuffer+3, Nalu.GetDataBuffer(), Nalu.GetDataLength());
        }__except(EXCEPTION_EXECUTE_HANDLER) { break; }
				
				// Update slice control buffer
				nDxvaNalLength									= Nalu.GetDataLength()+3;
				m_pSliceShort[nSlices].BSNALunitDataLocation	= nSize;
				m_pSliceShort[nSlices].SliceBytesInBuffer		= nDxvaNalLength;

				nSize										   += nDxvaNalLength;
				pDXVABuffer									   += nDxvaNalLength;
				nSlices++;
				break;
			}
		}

		// Complete with zero padding (buffer size should be a multiple of 128)
		nDummy  = 128 - (nSize %128);

		memset (pDXVABuffer, 0, nDummy);
		m_pSliceShort[nSlices-1].SliceBytesInBuffer		+= nDummy;
		nSize											+= nDummy;
	}
}


void CDXVADecoderH264::Flush()
{
	ClearRefFramesList();
	m_DXVAPicParams.UsedForReferenceFlags	= 0;
	m_nOutPOC								= -1;
	m_rtLastFrameDisplayed					= 0;

	__super::Flush();
}

HRESULT CDXVADecoderH264::DecodeFrame (BYTE* pDataIn, UINT nSize, REFERENCE_TIME rtStart, REFERENCE_TIME rtStop)
{
	HRESULT						hr			= S_FALSE;
	CH264Nalu					Nalu;
	UINT						nSlices		= 0;
	int							nSurfaceIndex;
	int							nFieldType;
	int							nSliceType;
	int							nFramePOC;
	CComPtr<IMediaSample>		pSampleToDeliver;
	CComQIPtr<IMPCDXVA2Sample>	pDXVA2Sample;
	int							nDXIndex	= 0;
	UINT						nNalOffset	= 0;
	int							nOutPOC;
	REFERENCE_TIME				rtOutStart;

	DxvaH264PictureContext		pictureContext;

	Nalu.SetBuffer (pDataIn, nSize, m_nNALLength);

	/* RFC-0033/0047: DecodeBuffer + POC into contract (BuildPicParams runs after NALU loop). */
	memset(&pictureContext, 0, sizeof(pictureContext));
	pictureContext.picParams = m_DXVAPicParams;
	pictureContext.scalingMatrix = m_DXVAScalingMatrix;
	FFH264DecodeBufferSession (m_pDxvaSession, pDataIn, nSize, &pictureContext);
	nFramePOC = pictureContext.framePOC;
	nOutPOC = pictureContext.outPOC;
	rtOutStart = pictureContext.outRtStart;

	while (Nalu.ReadNext())
	{
		switch (Nalu.GetType())
		{
		case NALU_TYPE_SLICE:
		case NALU_TYPE_IDR:
				if(m_bUseLongSlice) 
				{
					m_pSliceLong[nSlices].BSNALunitDataLocation	= nNalOffset;
					m_pSliceLong[nSlices].SliceBytesInBuffer	= Nalu.GetDataLength()+3; //.GetRoundedDataLength();
					m_pSliceLong[nSlices].slice_id				= nSlices;
					FF264UpdateRefFrameSliceLongSession (m_pDxvaSession, &pictureContext, &m_pSliceLong[nSlices]);

					if (nSlices>0)
						m_pSliceLong[nSlices-1].NumMbsForSlice = m_pSliceLong[nSlices].NumMbsForSlice = m_pSliceLong[nSlices].first_mb_in_slice - m_pSliceLong[nSlices-1].first_mb_in_slice;
				}
				nSlices++; 
				nNalOffset += (UINT)(Nalu.GetDataLength() + 3);
				if (nSlices > MAX_SLICES) break;
				break;
		}
	}
	if (nSlices == 0) return S_FALSE;

	m_nMaxWaiting	= min (max (m_DXVAPicParams.num_ref_frames, 3), 8);

	/* BuildPicParams via contract (NULL buffer skips re-decode). Seed from post-NALU state. */
	pictureContext.picParams = m_DXVAPicParams;
	pictureContext.scalingMatrix = m_DXVAScalingMatrix;
	if (FAILED (FFH264ReadPictureContextSession (m_pDxvaSession, &pictureContext, NULL, 0, m_pFilter->GetPCIVendor()))){
		SVPASSERT(FALSE);
		return S_FALSE;
	}
	m_DXVAPicParams = pictureContext.picParams;
	m_DXVAScalingMatrix = pictureContext.scalingMatrix;
	nFieldType = pictureContext.fieldType;
	nSliceType = pictureContext.sliceType;

	// Wait I frame after a flush
	if (m_bFlushed && !pictureContext.intraPicFlag){
		SVPASSERT(S_FALSE);
		return S_FALSE;
	}

	
	CHECK_HR (GetFreeSurfaceIndex (nSurfaceIndex, &pSampleToDeliver, rtStart, rtStop));
	FFH264SetCurrentPictureSession (m_pDxvaSession, nSurfaceIndex, &pictureContext);

	CHECK_HR (BeginFrame(nSurfaceIndex, pSampleToDeliver));
	
	m_DXVAPicParams.StatusReportFeedbackNumber++;

//	TRACE("CDXVADecoderH264 : Decode frame %u\n", m_DXVAPicParams.StatusReportFeedbackNumber);

	// Send picture parameters
	CHECK_HR (AddExecuteBuffer (DXVA2_PictureParametersBufferType, sizeof(m_DXVAPicParams), &m_DXVAPicParams));
	CHECK_HR (Execute());

	// Add bitstream, slice control and quantization matrix
	CHECK_HR (AddExecuteBuffer (DXVA2_BitStreamDateBufferType, nSize, pDataIn, &nSize));

	if (m_bUseLongSlice)
	{
		CHECK_HR(AddExecuteBuffer(DXVA2_SliceControlBufferType,  sizeof(DXVA_Slice_H264_Long)*nSlices, m_pSliceLong));
	}
	else
	{
		CHECK_HR (AddExecuteBuffer (DXVA2_SliceControlBufferType, sizeof (DXVA_Slice_H264_Short)*nSlices, m_pSliceShort));
	}

	CHECK_HR (AddExecuteBuffer (DXVA2_InverseQuantizationMatrixBufferType, sizeof (DXVA_Qmatrix_H264), (void*)&m_DXVAScalingMatrix));

	// Decode bitstream
	CHECK_HR (Execute());

	CHECK_HR (EndFrame(nSurfaceIndex));

#ifdef _DEBUG
//	DisplayStatus();
#endif

	bool bAdded		= AddToStore (nSurfaceIndex, pSampleToDeliver, m_DXVAPicParams.RefPicFlag, rtStart, rtStop,
								  m_DXVAPicParams.field_pic_flag, (FF_FIELD_TYPE)nFieldType, 
								  (FF_SLICE_TYPE)nSliceType, nFramePOC);

	FFH264UpdateRefFramesListSession (m_pDxvaSession, &pictureContext);
	m_DXVAPicParams = pictureContext.picParams;
	ClearUnusedRefFrames();

	if (bAdded) 
	{
		hr				= DisplayNextFrame();

		if (nOutPOC != -1)
		{
			m_nOutPOC		= nOutPOC;
			m_rtOutStart	= rtOutStart;
		}
	}
	m_bFlushed		= false;
	SVPASSERTHR(hr);

    return hr;
}

void CDXVADecoderH264::RemoveUndisplayedFrame(int nPOC)
{
	// Find frame with given POC, and free the slot
	for (int i=0; i<m_nPicEntryNumber; i++)
	{
		if (m_pPictureStore[i].bInUse && m_pPictureStore[i].nCodecSpecific == nPOC)
		{
			m_pPictureStore[i].bDisplayed = true;
			RemoveRefFrame (i);
			return;
		}
	}
}

void CDXVADecoderH264::ClearUnusedRefFrames()
{
	// Remove old reference frames (not anymore a short or long ref frame)
	for (int i=0; i<m_nPicEntryNumber; i++)
	{
		if (m_pPictureStore[i].bRefPicture && m_pPictureStore[i].bDisplayed)
			if (!FFH264IsRefFrameInUseSession (m_pDxvaSession, i))
				RemoveRefFrame (i);
	}
}

void CDXVADecoderH264::SetExtraData (BYTE* pDataIn, UINT nSize)
{
	/* RFC-0047: NAL length + extradata parse via opaque DXVA session. */
	m_nNALLength = FFH264GetNalLengthSizeSession (m_pDxvaSession);
	FFH264ApplyExtradataSession (m_pDxvaSession, pDataIn, nSize, m_pSliceLong);
}


void CDXVADecoderH264::ClearRefFramesList()
{
	int		i;

	for (int i=0; i<m_nPicEntryNumber; i++)
	{
		if (m_pPictureStore[i].bInUse)
		{
			m_pPictureStore[i].bDisplayed = true;
			RemoveRefFrame (i);
		}
	}
}


HRESULT CDXVADecoderH264::DisplayStatus()
{
	HRESULT 			hr = E_INVALIDARG;
	DXVA_Status_H264 	Status;

	memset (&Status, 0, sizeof(Status));

	CHECK_HR (hr = CDXVADecoder::QueryStatus(&Status, sizeof(Status)));

	TRACE ("CDXVADecoderH264 : Status for the frame %u : bBufType = %u, bStatus = %u, wNumMbsAffected = %u\n", 
		Status.StatusReportFeedbackNumber,
		Status.bBufType,
		Status.bStatus,
		Status.wNumMbsAffected);

	return hr;
}


int CDXVADecoderH264::FindOldestFrame()
{
	int				nPos  = -1;
	REFERENCE_TIME	rtPos = _I64_MAX;

	for (int i=0; i<m_nPicEntryNumber; i++)
	{
		if (m_pPictureStore[i].bInUse && !m_pPictureStore[i].bDisplayed)
		{
			if (m_pPictureStore[i].nCodecSpecific == m_nOutPOC && m_pPictureStore[i].rtStart < rtPos)
			{
				nPos  = i;
				rtPos = m_pPictureStore[i].rtStart;
			}
		}
	}

	if (nPos != -1)
	{
		if (m_rtOutStart == _I64_MIN)
		{
			// If start time not set (no PTS for example), guess presentation time!
			m_rtOutStart = m_rtLastFrameDisplayed + m_pFilter->GetAvrTimePerFrame();
		}
		m_pPictureStore[nPos].rtStart	= m_rtOutStart;
		m_pPictureStore[nPos].rtStop	= m_rtOutStart + m_pFilter->GetAvrTimePerFrame();
		m_rtLastFrameDisplayed			= m_rtOutStart;
		m_pFilter->ReorderBFrames (m_pPictureStore[nPos].rtStart, m_pPictureStore[nPos].rtStop);
	}

	return nPos;
}
