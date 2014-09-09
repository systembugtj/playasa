#pragma once

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

	virtual bool CanUseCUDA();

};

class Utility
{
protected:
	GlobalSettings & m_CurrrentSettings;
public:
	void putCyrrenSettings(GlobalSettings & value)
	{
		this->m_CurrrentSettings = value;
	}
	GlobalSettings & getCurrentSetting()
	{
		return this->m_CurrrentSettings;
	}
	__declspec(property(get = getCurrentSetting, put = putCyrrenSettings)) GlobalSettings CurrentSettings;


public:
	Utility();
	~Utility();
};

extern Utility SysUtil;