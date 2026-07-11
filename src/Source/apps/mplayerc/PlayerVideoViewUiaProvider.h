#pragma once

#include <UIAutomation.h>

class CChildView;

// RFC-0028: virtual UIA fragment for the video presentation area (AutomationId=VideoView).
class CPlayerVideoViewUiaProvider :
	public IRawElementProviderSimple,
	public IRawElementProviderFragment
{
public:
	explicit CPlayerVideoViewUiaProvider(CChildView* videoView);

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

	void SetFragmentParent(IRawElementProviderFragment* parent);
	void SetFragmentRoot(IRawElementProviderFragmentRoot* root);
	void SetNextSibling(IRawElementProviderFragment* nextSibling);

private:
	~CPlayerVideoViewUiaProvider();

	bool IsWindowUsable() const;
	bool GetVideoScreenRect(CRect& screenRect) const;

	volatile LONG refCount_;
	CChildView* videoView_;
	IRawElementProviderFragment* parent_;
	IRawElementProviderFragmentRoot* root_;
	IRawElementProviderFragment* nextSibling_;
};
