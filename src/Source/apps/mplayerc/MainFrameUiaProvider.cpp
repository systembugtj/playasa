#include "stdafx.h"
#include "MainFrameUiaProvider.h"

#include "MainFrm.h"
#include "PlayerSeekBarUiaProvider.h"
#include "PlayerVideoViewUiaProvider.h"

namespace {

const wchar_t kMainWindowAutomationId[] = L"MainWindow";

HRESULT SetIntVariant(VARIANT* value, int intValue)
{
	if (!value) {
		return E_INVALIDARG;
	}

	VariantInit(value);
	value->vt = VT_I4;
	value->lVal = intValue;
	return S_OK;
}

HRESULT SetStringVariant(VARIANT* value, const wchar_t* text)
{
	if (!value) {
		return E_INVALIDARG;
	}

	VariantInit(value);
	value->vt = VT_BSTR;
	value->bstrVal = SysAllocString(text);
	return value->bstrVal ? S_OK : E_OUTOFMEMORY;
}

HRESULT ReturnFragment(IRawElementProviderFragment* fragment, IRawElementProviderFragment** provider)
{
	if (!provider) {
		return E_INVALIDARG;
	}

	*provider = fragment;
	if (fragment) {
		fragment->AddRef();
	}
	return S_OK;
}

}  // namespace

CMainFrameUiaProvider::CMainFrameUiaProvider(CMainFrame* frame)
	: refCount_(1)
	, frame_(frame)
	, videoViewProvider_(NULL)
	, seekBarProvider_(NULL)
{
	if (!frame_) {
		return;
	}

	videoViewProvider_ = new CPlayerVideoViewUiaProvider(frame_->GetVideoView());
	seekBarProvider_ = new CPlayerSeekBarUiaProvider(frame_->GetSeekBar());
	videoViewProvider_->SetFragmentParent(static_cast<IRawElementProviderFragment*>(this));
	videoViewProvider_->SetFragmentRoot(static_cast<IRawElementProviderFragmentRoot*>(this));
	seekBarProvider_->SetFragmentParent(static_cast<IRawElementProviderFragment*>(this));
	seekBarProvider_->SetFragmentRoot(static_cast<IRawElementProviderFragmentRoot*>(this));
	videoViewProvider_->SetNextSibling(static_cast<IRawElementProviderFragment*>(seekBarProvider_));
	seekBarProvider_->SetPreviousSibling(static_cast<IRawElementProviderFragment*>(videoViewProvider_));
}

CMainFrameUiaProvider::~CMainFrameUiaProvider()
{
	if (seekBarProvider_) {
		seekBarProvider_->Release();
		seekBarProvider_ = NULL;
	}
	if (videoViewProvider_) {
		videoViewProvider_->Release();
		videoViewProvider_ = NULL;
	}
}

ULONG STDMETHODCALLTYPE CMainFrameUiaProvider::AddRef()
{
	return static_cast<ULONG>(InterlockedIncrement(&refCount_));
}

ULONG STDMETHODCALLTYPE CMainFrameUiaProvider::Release()
{
	const ULONG refCount = static_cast<ULONG>(InterlockedDecrement(&refCount_));
	if (refCount == 0) {
		delete this;
	}
	return refCount;
}

HRESULT STDMETHODCALLTYPE CMainFrameUiaProvider::QueryInterface(REFIID riid, void** object)
{
	if (!object) {
		return E_INVALIDARG;
	}

	*object = NULL;
	if (riid == __uuidof(IUnknown) || riid == __uuidof(IRawElementProviderSimple)) {
		*object = static_cast<IRawElementProviderSimple*>(this);
	} else if (riid == __uuidof(IRawElementProviderFragment)) {
		*object = static_cast<IRawElementProviderFragment*>(this);
	} else if (riid == __uuidof(IRawElementProviderFragmentRoot)) {
		*object = static_cast<IRawElementProviderFragmentRoot*>(this);
	} else {
		return E_NOINTERFACE;
	}

	AddRef();
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CMainFrameUiaProvider::get_ProviderOptions(ProviderOptions* providerOptions)
{
	if (!providerOptions) {
		return E_INVALIDARG;
	}

	*providerOptions = ProviderOptions_ServerSideProvider;
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CMainFrameUiaProvider::GetPatternProvider(PATTERNID patternId, IUnknown** provider)
{
	if (!provider) {
		return E_INVALIDARG;
	}

	*provider = NULL;
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CMainFrameUiaProvider::GetPropertyValue(PROPERTYID propertyId, VARIANT* value)
{
	if (!value) {
		return E_INVALIDARG;
	}

	VariantInit(value);
	switch (propertyId) {
	case UIA_AutomationIdPropertyId:
		return SetStringVariant(value, kMainWindowAutomationId);
	case UIA_ControlTypePropertyId:
		return SetIntVariant(value, UIA_WindowControlTypeId);
	default:
		return S_OK;
	}
}

HRESULT STDMETHODCALLTYPE CMainFrameUiaProvider::get_HostRawElementProvider(IRawElementProviderSimple** provider)
{
	if (!provider) {
		return E_INVALIDARG;
	}

	*provider = NULL;
	return UiaHostProviderFromHwnd(frame_ ? frame_->m_hWnd : NULL, provider);
}

HRESULT STDMETHODCALLTYPE CMainFrameUiaProvider::Navigate(NavigateDirection direction, IRawElementProviderFragment** provider)
{
	if (!provider) {
		return E_INVALIDARG;
	}

	*provider = NULL;
	if ((direction == NavigateDirection_FirstChild || direction == NavigateDirection_LastChild) && seekBarProvider_) {
		*provider = static_cast<IRawElementProviderFragment*>(seekBarProvider_);
		seekBarProvider_->AddRef();
	}
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CMainFrameUiaProvider::GetRuntimeId(SAFEARRAY** runtimeId)
{
	if (!runtimeId) {
		return E_INVALIDARG;
	}

	*runtimeId = NULL;
	int values[] = { UiaAppendRuntimeId, static_cast<int>(reinterpret_cast<INT_PTR>(frame_ ? frame_->m_hWnd : NULL)) };
	SAFEARRAY* result = SafeArrayCreateVector(VT_I4, 0, _countof(values));
	if (!result) {
		return E_OUTOFMEMORY;
	}

	for (LONG index = 0; index < static_cast<LONG>(_countof(values)); index++) {
		SafeArrayPutElement(result, &index, &values[index]);
	}
	*runtimeId = result;
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CMainFrameUiaProvider::get_BoundingRectangle(UiaRect* rect)
{
	if (!rect) {
		return E_INVALIDARG;
	}

	rect->left = 0.0;
	rect->top = 0.0;
	rect->width = 0.0;
	rect->height = 0.0;
	if (!IsWindowUsable()) {
		return S_OK;
	}

	CRect windowRect;
	frame_->GetWindowRect(&windowRect);
	rect->left = static_cast<double>(windowRect.left);
	rect->top = static_cast<double>(windowRect.top);
	rect->width = static_cast<double>(windowRect.Width());
	rect->height = static_cast<double>(windowRect.Height());
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CMainFrameUiaProvider::GetEmbeddedFragmentRoots(SAFEARRAY** roots)
{
	if (!roots) {
		return E_INVALIDARG;
	}

	*roots = NULL;
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CMainFrameUiaProvider::SetFocus()
{
	if (IsWindowUsable()) {
		frame_->SetFocus();
	}
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CMainFrameUiaProvider::get_FragmentRoot(IRawElementProviderFragmentRoot** root)
{
	if (!root) {
		return E_INVALIDARG;
	}

	*root = static_cast<IRawElementProviderFragmentRoot*>(this);
	AddRef();
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CMainFrameUiaProvider::ElementProviderFromPoint(double x, double y, IRawElementProviderFragment** provider)
{
	if (!provider) {
		return E_INVALIDARG;
	}

	*provider = NULL;
	if (seekBarProvider_) {
		CPlayerSeekBar* seekBar = frame_->GetSeekBar();
		CRect seekRect;
		seekBar->GetWindowRect(&seekRect);
		if (seekRect.PtInRect(CPoint(static_cast<int>(x), static_cast<int>(y)))) {
			return ReturnFragment(static_cast<IRawElementProviderFragment*>(seekBarProvider_), provider);
		}
	}
	return ReturnFragment(static_cast<IRawElementProviderFragment*>(this), provider);
}

HRESULT STDMETHODCALLTYPE CMainFrameUiaProvider::GetFocus(IRawElementProviderFragment** provider)
{
	return ReturnFragment(static_cast<IRawElementProviderFragment*>(this), provider);
}

bool CMainFrameUiaProvider::IsWindowUsable() const
{
	return frame_ && ::IsWindow(frame_->m_hWnd);
}
