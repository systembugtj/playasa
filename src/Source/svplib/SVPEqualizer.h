#pragma once

#include "..\apps\shared\sharedlib\CommonDefine.h"

class CSVPEqualizer
{
	int EqzInit(float pEQBandControlCurrent[MAX_EQ_BAND] , int i_rate = 0 );

public:
	CSVPEqualizer(void);
	~CSVPEqualizer(void);

	int* m_sys_44;
	int* m_sys_48;
	int m_rate;

	void EqzFilter(  double *out, double *in,
		int i_samples, int i_channels );
	int EqzInitBoth(float pEQBandControlCurrent[MAX_EQ_BAND]);
	void EqzClean( );
};
