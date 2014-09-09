#pragma once

#include <atlcoll.h>
#include "CommonStructure.h"

class GlobalSettings
{
public:
	virtual void putHardwareDecoderFailCount(int value);
	virtual int  getHardwareDecoderFailCount();
	__declspec(property(get = getHardwareDecoderFailCount, put = putHardwareDecoderFailCount)) int HardwareDecoderFailCount;

	virtual void putUserGPUCUDA(int value);
	virtual int getUserGPUCUDA();
	__declspec(property(get = getUserGPUCUDA, put = putUserGPUCUDA)) int UserGPUCUDA;

	virtual void putUseGPUAcel(int value);
	virtual int  getUseGPUAcel();
	__declspec(property(get = getUseGPUAcel, put = putUseGPUAcel)) int UseGPUAcel;

	virtual void putNoMoreDXVA(bool value);
	virtual bool getNoMoreDXVA();
	__declspec(property(get = getNoMoreDXVA, put = putNoMoreDXVA)) bool NoMoreDXVA;

	virtual CAtlMap<DWORD, eq_perset_setting >& getEqPerset();
	__declspec(property(get = getEqPerset)) CAtlMap<DWORD, eq_perset_setting >& EqPerset;


	virtual void putGSubFontRatio(double value);
	virtual double getGSubFontRatio();
	__declspec(property(get = getGSubFontRatio, put = putGSubFontRatio)) double GSubFontRatio;

	virtual void putAeroGlassAvalibility(BOOL value);
	virtual BOOL getAeroGlassAvalibility();
	__declspec(property(get = getAeroGlassAvalibility, put = putAeroGlassAvalibility)) BOOL AeroGlassAvalibility;

	virtual void putRGBOnly(bool value);
	virtual bool getRGBOnly();
	__declspec(property(get = getRGBOnly, put = putRGBOnly)) bool RGBOnly;
	
	virtual void putExternalSubtitleTime(bool value);
	virtual bool getExternalSubtitleTime();
	__declspec(property(get = getExternalSubtitleTime, put = putExternalSubtitleTime)) bool ExternalSubtitleTime;

	virtual void putLanguage(int value);
	virtual int getLanguage();
	__declspec(property(get = getLanguage, put = putLanguage)) int Language;
	
	virtual void putAutoIconvSubGB2BIG(int value);
	virtual int getAutoIconvSubGB2BIG();
	__declspec(property(get = getAutoIconvSubGB2BIG, put = putAutoIconvSubGB2BIG)) int AutoIconvSubGB2BIG;

	virtual void putAutoIconvSubBig2GB(int value);
	virtual int getAutoIconvSubBig2GB();
	__declspec(property(get = getAutoIconvSubBig2GB, put = putAutoIconvSubBig2GB)) int AutoIconvSubBig2GB;

	// Funciton
	virtual bool CanUseCUDA();
	virtual void Direct3DCreate9Ex(UINT SDKVersion, LPVOID**);
	virtual UINT GetBottomSubOffset();
	virtual COLORREF GetColorFromTheme(CString clrName, COLORREF clrDefault);
	virtual UINT GetProfileInt(LPCTSTR lpszSection, LPCTSTR lpszEntry, int nDefault);
	virtual BOOL WriteProfileInt(LPCTSTR lpszSection, LPCTSTR lpszEntry, int nValue);	
};

class Utility
{
protected:
	GlobalSettings * m_pCurrrentSettings;
public:
	void putCyrrenSettings(GlobalSettings & value)
	{
		this->m_pCurrrentSettings = &value;
	}
	GlobalSettings & getCurrentSetting()
	{
		return *this->m_pCurrrentSettings;
	}
	__declspec(property(get = getCurrentSetting, put = putCyrrenSettings)) GlobalSettings & CurrentSettings;


public:
	Utility();
	~Utility();
};

extern Utility SysUtil;