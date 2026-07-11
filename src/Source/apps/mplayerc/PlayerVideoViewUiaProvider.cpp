#include "stdafx.h"
#include "PlayerVideoViewUiaProvider.h"

#include "ChildView.h"

namespace {

const wchar_t kVideoViewAutomationId[] = L"VideoView";
const wchar_t kVideoViewName[] = L"Video view";

HRESULT ReturnSelfAsFragment(CPlayerVideoViewUiaProvider* self, IRawElementProviderFragment** provider)
{
	if (!provider) {
		return E_INVALIDARG;
	}

	*provider = static_cast<IRawElementProviderFragment*>(self);
	self->AddRef();
	return S_OK;
}

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

}  // namespace

CPlayerVideoViewUiaProvider::CPlayerVideoViewUiaProvider(CChildView* videoView)
	: refCount_(1)
	, videoView_(videoView)
	, parent_(NULL)
	, root_(NULL)
	, nextSibling_(NULL)
{
}

CPlayerVideoViewUiaProvider::~CPlayerVideoViewUiaProvider()
{
}

void CPlayerVideoViewUiaProvider::SetFragmentParent(IRawElementProviderFragment* parent)
{
	parent_ = parent;
}

void CPlayerVideoViewUiaProvider::SetFragmentRoot(IRawElementProviderFragmentRoot* root)
{
	root_ = root;
}

void CPlayerVideoViewUiaProvider::SetNextSibling(IRawElementProviderFragment* nextSibling)
{
	nextSibling_ = nextSibling;
}

ULONG STDMETHODCALLTYPE CPlayerVideoViewUiaProvider::AddRef()
{
	return static_cast<ULONG>(InterlockedIncrement(&refCount_));
}

ULONG STDMETHODCALLTYPE CPlayerVideoViewUiaProvider::Release()
{
	const ULONG refCount = static_cast<ULONG>(InterlockedDecrement(&refCount_));
	if (refCount == 0) {
		delete this;
	}
	return refCount;
}

HRESULT STDMETHODCALLTYPE CPlayerVideoViewUiaProvider::QueryInterface(REFIID riid, void** object)
{
	if (!object) {
		return E_INVALIDARG;
	}

	*object = NULL;
	if (riid == __uuidof(IUnknown) || riid == __uuidof(IRawElementProviderSimple)) {
		*object = static_cast<IRawElementProviderSimple*>(this);
	} else if (riid == __uuidof(IRawElementProviderFragment)) {
		*object = static_cast<IRawElementProviderFragment*>(this);
	} else {
		return E_NOINTERFACE;
	}

	AddRef();
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerVideoViewUiaProvider::get_ProviderOptions(ProviderOptions* providerOptions)
{
	if (!providerOptions) {
		return E_INVALIDARG;
	}

	*providerOptions = ProviderOptions_ServerSideProvider;
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerVideoViewUiaProvider::GetPatternProvider(PATTERNID patternId, IUnknown** provider)
{
	if (!provider) {
		return E_INVALIDARG;
	}

	*provider = NULL;
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerVideoViewUiaProvider::GetPropertyValue(PROPERTYID propertyId, VARIANT* value)
{
	if (!value) {
		return E_INVALIDARG;
	}

	VariantInit(value);
	switch (propertyId) {
	case UIA_AutomationIdPropertyId:
		return SetStringVariant(value, kVideoViewAutomationId);
	case UIA_NamePropertyId:
		return SetStringVariant(value, kVideoViewName);
	case UIA_ControlTypePropertyId:
		return SetIntVariant(value, UIA_PaneControlTypeId);
	default:
		return S_OK;
	}
}

HRESULT STDMETHODCALLTYPE CPlayerVideoViewUiaProvider::get_HostRawElementProvider(IRawElementProviderSimple** provider)
{
	if (!provider) {
		return E_INVALIDARG;
	}

	*provider = NULL;
	return UiaHostProviderFromHwnd(videoView_ ? videoView_->m_hWnd : NULL, provider);
}

HRESULT STDMETHODCALLTYPE CPlayerVideoViewUiaProvider::Navigate(NavigateDirection direction, IRawElementProviderFragment** provider)
{
	if (!provider) {
		return E_INVALIDARG;
	}

	*provider = NULL;
	switch (direction) {
	case NavigateDirection_Parent:
		if (parent_) {
			*provider = parent_;
			parent_->AddRef();
		}
		break;
	case NavigateDirection_NextSibling:
		if (nextSibling_) {
			*provider = nextSibling_;
			nextSibling_->AddRef();
		}
		break;
	default:
		break;
	}
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerVideoViewUiaProvider::GetRuntimeId(SAFEARRAY** runtimeId)
{
	if (!runtimeId) {
		return E_INVALIDARG;
	}

	*runtimeId = NULL;
	int values[] = { UiaAppendRuntimeId, static_cast<int>(reinterpret_cast<INT_PTR>(videoView_ ? videoView_->m_hWnd : NULL)) };
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

HRESULT STDMETHODCALLTYPE CPlayerVideoViewUiaProvider::get_BoundingRectangle(UiaRect* rect)
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

	CRect screenRect;
	if (!GetVideoScreenRect(screenRect)) {
		return S_OK;
	}

	rect->left = static_cast<double>(screenRect.left);
	rect->top = static_cast<double>(screenRect.top);
	rect->width = static_cast<double>(screenRect.Width());
	rect->height = static_cast<double>(screenRect.Height());
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerVideoViewUiaProvider::GetEmbeddedFragmentRoots(SAFEARRAY** roots)
{
	if (!roots) {
		return E_INVALIDARG;
	}

	*roots = NULL;
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerVideoViewUiaProvider::SetFocus()
{
	if (IsWindowUsable()) {
		videoView_->SetFocus();
	}
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerVideoViewUiaProvider::get_FragmentRoot(IRawElementProviderFragmentRoot** root)
{
	if (!root) {
		return E_INVALIDARG;
	}

	if (root_) {
		*root = root_;
		root_->AddRef();
		return S_OK;
	}

	*root = NULL;
	return S_OK;
}

bool CPlayerVideoViewUiaProvider::IsWindowUsable() const
{
	return videoView_ && ::IsWindow(videoView_->m_hWnd);
}

bool CPlayerVideoViewUiaProvider::GetVideoScreenRect(CRect& screenRect) const
{
	if (!IsWindowUsable()) {
		return false;
	}

	CRect videoRect = videoView_->GetVideoRect();
	if (videoRect.IsRectEmpty()) {
		videoView_->GetClientRect(&videoRect);
	}

	CPoint topLeft(videoRect.left, videoRect.top);
	CPoint bottomRight(videoRect.right, videoRect.bottom);
	videoView_->ClientToScreen(&topLeft);
	videoView_->ClientToScreen(&bottomRight);
	screenRect.SetRect(topLeft, bottomRight);
	return !screenRect.IsRectEmpty();
}
