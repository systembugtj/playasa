#pragma once

#include <UIAutomation.h>

class CMainFrame;
class CPlayerSeekBarUiaProvider;

class CMainFrameUiaProvider :
	public IRawElementProviderSimple,
	public IRawElementProviderFragment,
	public IRawElementProviderFragmentRoot
{
public:
	explicit CMainFrameUiaProvider(CMainFrame* frame);

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

private:
	~CMainFrameUiaProvider();

	bool IsWindowUsable() const;

	volatile LONG refCount_;
	CMainFrame* frame_;
	CPlayerSeekBarUiaProvider* seekBarProvider_;
};
