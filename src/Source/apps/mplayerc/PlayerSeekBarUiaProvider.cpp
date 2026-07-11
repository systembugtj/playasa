#include "stdafx.h"
#include "PlayerSeekBarUiaProvider.h"

#include "PlayerSeekBar.h"

namespace {

const wchar_t kSeekBarAutomationId[] = L"SeekBar";
const wchar_t kSeekBarName[] = L"Seek bar";
const int kLargeChangeDivisor = 10;
const int kSmallChangeDivisor = 100;

HRESULT ReturnSelfAsFragment(CPlayerSeekBarUiaProvider* self, IRawElementProviderFragment** provider)
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

HRESULT SetBoolVariant(VARIANT* value, bool boolValue)
{
	if (!value) {
		return E_INVALIDARG;
	}

	VariantInit(value);
	value->vt = VT_BOOL;
	value->boolVal = boolValue ? VARIANT_TRUE : VARIANT_FALSE;
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

double GetRangeStep(__int64 minimum, __int64 maximum, int divisor)
{
	const __int64 range = maximum - minimum;
	if (range <= 0) {
		return 0.0;
	}

	return static_cast<double>(range / divisor);
}

}  // namespace

CPlayerSeekBarUiaProvider::CPlayerSeekBarUiaProvider(CPlayerSeekBar* seekBar)
	: refCount_(1)
	, seekBar_(seekBar)
	, parent_(NULL)
	, root_(NULL)
	, previousSibling_(NULL)
{
}

CPlayerSeekBarUiaProvider::~CPlayerSeekBarUiaProvider()
{
}

void CPlayerSeekBarUiaProvider::SetFragmentParent(IRawElementProviderFragment* parent)
{
	parent_ = parent;
}

void CPlayerSeekBarUiaProvider::SetPreviousSibling(IRawElementProviderFragment* previousSibling)
{
	previousSibling_ = previousSibling;
}

ULONG STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::AddRef()
{
	return static_cast<ULONG>(InterlockedIncrement(&refCount_));
}

ULONG STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::Release()
{
	const ULONG refCount = static_cast<ULONG>(InterlockedDecrement(&refCount_));
	if (refCount == 0) {
		delete this;
	}

	return refCount;
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::QueryInterface(REFIID riid, void** object)
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
	} else if (riid == __uuidof(IRangeValueProvider)) {
		*object = static_cast<IRangeValueProvider*>(this);
	} else {
		return E_NOINTERFACE;
	}

	AddRef();
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::get_ProviderOptions(ProviderOptions* providerOptions)
{
	if (!providerOptions) {
		return E_INVALIDARG;
	}

	*providerOptions = ProviderOptions_ServerSideProvider;
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::GetPatternProvider(PATTERNID patternId, IUnknown** provider)
{
	if (!provider) {
		return E_INVALIDARG;
	}

	*provider = NULL;
	if (patternId == UIA_RangeValuePatternId) {
		*provider = static_cast<IRangeValueProvider*>(this);
		AddRef();
	}

	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::GetPropertyValue(PROPERTYID propertyId, VARIANT* value)
{
	if (!value) {
		return E_INVALIDARG;
	}

	VariantInit(value);
	switch (propertyId) {
	case UIA_AutomationIdPropertyId:
		return SetStringVariant(value, kSeekBarAutomationId);
	case UIA_NamePropertyId:
		return SetStringVariant(value, kSeekBarName);
	case UIA_ControlTypePropertyId:
		return SetIntVariant(value, UIA_SliderControlTypeId);
	case UIA_IsEnabledPropertyId:
		return SetBoolVariant(value, seekBar_ && seekBar_->IsSeekEnabled());
	case UIA_IsKeyboardFocusablePropertyId:
		return SetBoolVariant(value, false);
	case UIA_RangeValueValuePropertyId:
		value->vt = VT_R8;
		return get_Value(&value->dblVal);
	case UIA_RangeValueMinimumPropertyId:
		value->vt = VT_R8;
		return get_Minimum(&value->dblVal);
	case UIA_RangeValueMaximumPropertyId:
		value->vt = VT_R8;
		return get_Maximum(&value->dblVal);
	case UIA_RangeValueIsReadOnlyPropertyId:
		return SetBoolVariant(value, !(seekBar_ && seekBar_->IsSeekEnabled()));
	default:
		return S_OK;
	}
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::get_HostRawElementProvider(IRawElementProviderSimple** provider)
{
	if (!provider) {
		return E_INVALIDARG;
	}

	*provider = NULL;
	return UiaHostProviderFromHwnd(seekBar_ ? seekBar_->m_hWnd : NULL, provider);
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::Navigate(NavigateDirection direction, IRawElementProviderFragment** provider)
{
	if (!provider) {
		return E_INVALIDARG;
	}

	*provider = NULL;
	if (direction == NavigateDirection_Parent && parent_) {
		*provider = parent_;
		parent_->AddRef();
	} else if (direction == NavigateDirection_PreviousSibling && previousSibling_) {
		*provider = previousSibling_;
		previousSibling_->AddRef();
	}
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::GetRuntimeId(SAFEARRAY** runtimeId)
{
	if (!runtimeId) {
		return E_INVALIDARG;
	}

	*runtimeId = NULL;
	int values[] = { UiaAppendRuntimeId, static_cast<int>(reinterpret_cast<INT_PTR>(seekBar_ ? seekBar_->m_hWnd : NULL)) };
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

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::get_BoundingRectangle(UiaRect* rect)
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
	seekBar_->GetWindowRect(&windowRect);
	rect->left = static_cast<double>(windowRect.left);
	rect->top = static_cast<double>(windowRect.top);
	rect->width = static_cast<double>(windowRect.Width());
	rect->height = static_cast<double>(windowRect.Height());
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::GetEmbeddedFragmentRoots(SAFEARRAY** roots)
{
	if (!roots) {
		return E_INVALIDARG;
	}

	*roots = NULL;
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::SetFocus()
{
	if (IsWindowUsable()) {
		seekBar_->SetFocus();
	}

	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::get_FragmentRoot(IRawElementProviderFragmentRoot** root)
{
	if (!root) {
		return E_INVALIDARG;
	}

	if (root_) {
		*root = root_;
		root_->AddRef();
		return S_OK;
	}

	*root = static_cast<IRawElementProviderFragmentRoot*>(this);
	AddRef();
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::ElementProviderFromPoint(double x, double y, IRawElementProviderFragment** provider)
{
	if (!provider) {
		return E_INVALIDARG;
	}

	*provider = NULL;
	if (!IsWindowUsable()) {
		return S_OK;
	}

	CRect windowRect;
	seekBar_->GetWindowRect(&windowRect);
	if (windowRect.PtInRect(CPoint(static_cast<int>(x), static_cast<int>(y)))) {
		return ReturnSelfAsFragment(this, provider);
	}

	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::GetFocus(IRawElementProviderFragment** provider)
{
	return ReturnSelfAsFragment(this, provider);
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::SetValue(double value)
{
	if (!seekBar_ || !seekBar_->IsSeekEnabled()) {
		return HRESULT_FROM_WIN32(ERROR_INVALID_STATE);
	}

	__int64 minimum = 0;
	__int64 maximum = 0;
	GetRange(minimum, maximum);
	const __int64 target = max(minimum, min(maximum, static_cast<__int64>(value)));
	seekBar_->SetAutomationPos(target);
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::get_Value(double* value)
{
	if (!value) {
		return E_INVALIDARG;
	}

	*value = seekBar_ ? static_cast<double>(seekBar_->GetPosReal()) : 0.0;
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::get_IsReadOnly(BOOL* isReadOnly)
{
	if (!isReadOnly) {
		return E_INVALIDARG;
	}

	*isReadOnly = (seekBar_ && seekBar_->IsSeekEnabled()) ? FALSE : TRUE;
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::get_Maximum(double* maximum)
{
	if (!maximum) {
		return E_INVALIDARG;
	}

	__int64 minimumRange = 0;
	__int64 maximumRange = 0;
	GetRange(minimumRange, maximumRange);
	*maximum = static_cast<double>(maximumRange);
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::get_Minimum(double* minimum)
{
	if (!minimum) {
		return E_INVALIDARG;
	}

	__int64 minimumRange = 0;
	__int64 maximumRange = 0;
	GetRange(minimumRange, maximumRange);
	*minimum = static_cast<double>(minimumRange);
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::get_LargeChange(double* largeChange)
{
	if (!largeChange) {
		return E_INVALIDARG;
	}

	__int64 minimum = 0;
	__int64 maximum = 0;
	GetRange(minimum, maximum);
	*largeChange = GetRangeStep(minimum, maximum, kLargeChangeDivisor);
	return S_OK;
}

HRESULT STDMETHODCALLTYPE CPlayerSeekBarUiaProvider::get_SmallChange(double* smallChange)
{
	if (!smallChange) {
		return E_INVALIDARG;
	}

	__int64 minimum = 0;
	__int64 maximum = 0;
	GetRange(minimum, maximum);
	*smallChange = GetRangeStep(minimum, maximum, kSmallChangeDivisor);
	return S_OK;
}

void CPlayerSeekBarUiaProvider::GetRange(__int64& minimum, __int64& maximum) const
{
	minimum = 0;
	maximum = 0;
	if (seekBar_) {
		seekBar_->GetRange(minimum, maximum);
	}
}

bool CPlayerSeekBarUiaProvider::IsWindowUsable() const
{
	return seekBar_ && ::IsWindow(seekBar_->m_hWnd);
}
