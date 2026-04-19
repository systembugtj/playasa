#pragma once

#include <atlcoll.h>
#include "CommonStructure.h"

// 接口类：全部纯虚函数。若基类带未实现虚函数，MSVC 在构造子对象阶段会生成 GlobalSettings::`vftable'，
// 并解析到 GlobalSettings::putLanguage 等符号，而实现仅在 CMPlayerCApp::Settings 中，导致 LNK2001。
class GlobalSettings
{
public:
	virtual ~GlobalSettings() = default;

	virtual void putHardwareDecoderFailCount(int value) = 0;
	virtual int  getHardwareDecoderFailCount() = 0;
	__declspec(property(get = getHardwareDecoderFailCount, put = putHardwareDecoderFailCount)) int HardwareDecoderFailCount;

	virtual void putUseGPUCUDA(int value) = 0;
	virtual int getUseGPUCUDA() = 0;
	__declspec(property(get = getUseGPUCUDA, put = putUseGPUCUDA)) int UseGPUCUDA;

	virtual void putUseGPUAcel(int value) = 0;
	virtual int  getUseGPUAcel() = 0;
	__declspec(property(get = getUseGPUAcel, put = putUseGPUAcel)) int UseGPUAcel;

	virtual void putNoMoreDXVA(bool value) = 0;
	virtual bool getNoMoreDXVA() = 0;
	__declspec(property(get = getNoMoreDXVA, put = putNoMoreDXVA)) bool NoMoreDXVA;

	virtual CAtlMap<DWORD, eq_perset_setting >& getEqPerset() = 0;
	__declspec(property(get = getEqPerset)) CAtlMap<DWORD, eq_perset_setting >& EqPerset;


	virtual void putGSubFontRatio(double value) = 0;
	virtual double getGSubFontRatio() = 0;
	__declspec(property(get = getGSubFontRatio, put = putGSubFontRatio)) double GSubFontRatio;

	virtual void putAeroGlassAvalibility(BOOL value) = 0;
	virtual BOOL getAeroGlassAvalibility() = 0;
	__declspec(property(get = getAeroGlassAvalibility, put = putAeroGlassAvalibility)) BOOL AeroGlassAvalibility;

	virtual void putRGBOnly(bool value) = 0;
	virtual bool getRGBOnly() = 0;
	__declspec(property(get = getRGBOnly, put = putRGBOnly)) bool RGBOnly;
	
	virtual void putExternalSubtitleTime(bool value) = 0;
	virtual bool getExternalSubtitleTime() = 0;
	__declspec(property(get = getExternalSubtitleTime, put = putExternalSubtitleTime)) bool ExternalSubtitleTime;

	virtual void putLanguage(int value) = 0;
	virtual int getLanguage() = 0;
	__declspec(property(get = getLanguage, put = putLanguage)) int Language;
	
	virtual void putAutoIconvSubGB2BIG(int value) = 0;
	virtual int getAutoIconvSubGB2BIG() = 0;
	__declspec(property(get = getAutoIconvSubGB2BIG, put = putAutoIconvSubGB2BIG)) int AutoIconvSubGB2BIG;

	virtual void putAutoIconvSubBig2GB(int value) = 0;
	virtual int getAutoIconvSubBig2GB() = 0;
	__declspec(property(get = getAutoIconvSubBig2GB, put = putAutoIconvSubBig2GB)) int AutoIconvSubBig2GB;

	// Funciton
	virtual bool CanUseCUDA() = 0;
	virtual void Direct3DCreate9Ex(UINT SDKVersion, LPVOID**) = 0;
	virtual UINT GetBottomSubOffset() = 0;
	virtual COLORREF GetColorFromTheme(CString clrName, COLORREF clrDefault) = 0;
	// UNICODE 下 WinUser.h 会将 GetProfileInt/WriteProfileInt 宏映射为 *W，导致类成员名被替换、与其它 TU 的 vtable 不一致；此处临时取消宏。
#pragma push_macro("GetProfileInt")
#pragma push_macro("WriteProfileInt")
#ifdef GetProfileInt
#undef GetProfileInt
#endif
#ifdef WriteProfileInt
#undef WriteProfileInt
#endif
	virtual UINT GetProfileInt(LPCTSTR lpszSection, LPCTSTR lpszEntry, int nDefault) = 0;
	virtual BOOL WriteProfileInt(LPCTSTR lpszSection, LPCTSTR lpszEntry, int nValue) = 0;
#pragma pop_macro("WriteProfileInt")
#pragma pop_macro("GetProfileInt")
	virtual CString GetSVPSubStorePath(BOOL spdefault = false) = 0;
};

// 在 UNICODE 下 WinUser.h 将 GetProfileInt/WriteProfileInt 宏映射为 *W，直接写 s.GetProfileInt 会把成员名替换错；请用下列内联封装访问 GlobalSettings。
inline UINT GsGetProfileInt(GlobalSettings& s, LPCTSTR lpszSection, LPCTSTR lpszEntry, int nDefault)
{
#pragma push_macro("GetProfileInt")
#undef GetProfileInt
	return s.GetProfileInt(lpszSection, lpszEntry, nDefault);
#pragma pop_macro("GetProfileInt")
}

inline BOOL GsWriteProfileInt(GlobalSettings& s, LPCTSTR lpszSection, LPCTSTR lpszEntry, int nValue)
{
#pragma push_macro("WriteProfileInt")
#undef WriteProfileInt
	return s.WriteProfileInt(lpszSection, lpszEntry, nValue);
#pragma pop_macro("WriteProfileInt")
}

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