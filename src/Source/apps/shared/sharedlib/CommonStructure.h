#pragma once

#include "CommonDefine.h"

struct eq_perset_setting
{
	/* Filter static config */
	CString szPersetName;
	int  i_band;
	float f_preamp;
	float f_amp[MAX_EQ_BAND];   /* Per band amp */
};