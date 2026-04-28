#pragma once

#include <UIAutomation.h>

class CPlayerSeekBar;

class CPlayerSeekBarUiaProvider :
	public IRawElementProviderSimple,
	public IRawElementProviderFragment,
	public IRawElementProviderFragmentRoot,
	public IRangeValueProvider
{
public:
	explicit CPlayerSeekBarUiaProvider(CPlayerSeekBar* seekBar);
	void SetFragmentParent(IRawElementProviderFragment* parent);
	void SetFragmentRoot(IRawElementProviderFragmentRoot* root);

	ULONG STDMETHODCALLTYPE AddRef();
	ULONG STDMETHODCALLTYPE Release();
	HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** object);

	HRESULT STDMETHODCALLTYPE get_ProviderOptions(ProviderOptions* providerOptions);
	HRESULT STDMETHODCALLTYPE GetPatternProvider(PATTERNID patternId, IUnknown** provider);
	HRESULT STDMETHODCALLTYPE GetPropertyValue(PROPERTYID propertyId, VARIANT* value);
	HRESULT STDMETHODCALLTYPE get_HostRawElementProvider(IRawElementProviderSimple** provider);

	HRESULT STDMETHODCALLTYPE Navigate(NavigateDirection direction, IRawElementProviderFragment** provider);
	HRESULT STDMETHODCALLTYPE GetRuntimeId(SAFEARRAY** runtimeId);
	HRESULT STDMETHODCALLTYPE get_BoundingRectangle(UiaRect* rect);
	HRESULT STDMETHODCALLTYPE GetEmbeddedFragmentRoots(SAFEARRAY** roots);
	HRESULT STDMETHODCALLTYPE SetFocus();
	HRESULT STDMETHODCALLTYPE get_FragmentRoot(IRawElementProviderFragmentRoot** root);

	HRESULT STDMETHODCALLTYPE ElementProviderFromPoint(double x, double y, IRawElementProviderFragment** provider);
	HRESULT STDMETHODCALLTYPE GetFocus(IRawElementProviderFragment** provider);

	HRESULT STDMETHODCALLTYPE SetValue(double value);
	HRESULT STDMETHODCALLTYPE get_Value(double* value);
	HRESULT STDMETHODCALLTYPE get_IsReadOnly(BOOL* isReadOnly);
	HRESULT STDMETHODCALLTYPE get_Maximum(double* maximum);
	HRESULT STDMETHODCALLTYPE get_Minimum(double* minimum);
	HRESULT STDMETHODCALLTYPE get_LargeChange(double* largeChange);
	HRESULT STDMETHODCALLTYPE get_SmallChange(double* smallChange);

private:
	~CPlayerSeekBarUiaProvider();

	void GetRange(__int64& minimum, __int64& maximum) const;
	bool IsWindowUsable() const;

	volatile LONG refCount_;
	CPlayerSeekBar* seekBar_;
	IRawElementProviderFragment* parent_;
	IRawElementProviderFragmentRoot* root_;
};
