// d3dx9_compat.h - Compatibility header for D3DX9 types

// This header provides minimal type definitions for D3DX9 when the full DirectX SDK is not available

// The actual D3DX functions are loaded dynamically via GetProcAddress



#pragma once



#include <d3d9.h>



// D3DXCOLOR - Simple color structure

struct D3DXCOLOR

{

    float r, g, b, a;



    D3DXCOLOR() : r(0.0f), g(0.0f), b(0.0f), a(1.0f) {}

    D3DXCOLOR(float _r, float _g, float _b, float _a) : r(_r), g(_g), b(_b), a(_a) {}

    D3DXCOLOR(DWORD argb)

    {

        a = ((argb >> 24) & 0xff) / 255.0f;

        r = ((argb >> 16) & 0xff) / 255.0f;

        g = ((argb >> 8) & 0xff) / 255.0f;

        b = (argb & 0xff) / 255.0f;

    }

    /** 与旧 D3DX 一致，便于以 D3DXCOLOR 调用 DrawText（底层仍为 DWORD） */
    operator D3DCOLOR() const
    {
        return D3DCOLOR_COLORVALUE(r, g, b, a);
    }

};



// D3DXVECTOR2 - 2D vector structure

struct D3DXVECTOR2

{

    float x, y;



    D3DXVECTOR2() : x(0.0f), y(0.0f) {}

    D3DXVECTOR2(float _x, float _y) : x(_x), y(_y) {}

};



// Minimal COM shapes for d3dx9_*.dll objects (CComPtr 需要 IUnknown 派生接口，而非仅前向声明)

struct ID3DXBuffer;

typedef ID3DXBuffer* LPD3DXBUFFER;



__interface ID3DXSprite : public IUnknown

{

    HRESULT STDMETHODCALLTYPE Begin(DWORD Flags);

    HRESULT STDMETHODCALLTYPE End(void);

};

typedef ID3DXSprite* LPD3DXSPRITE;



__interface ID3DXFont : public IUnknown

{

    HRESULT STDMETHODCALLTYPE DrawTextW(ID3DXSprite* pSprite, LPCWSTR pString, INT Count, LPRECT pRect, DWORD Format, D3DCOLOR Color);

};

typedef ID3DXFont* LPD3DXFONT;



__interface ID3DXLine : public IUnknown

{

    HRESULT STDMETHODCALLTYPE SetWidth(FLOAT fWidth);

    HRESULT STDMETHODCALLTYPE SetAntialias(BOOL bAntiAlias);

    HRESULT STDMETHODCALLTYPE Begin(void);

    HRESULT STDMETHODCALLTYPE Draw(D3DXVECTOR2* pVertexList, DWORD dwVertexListCount, D3DCOLOR Color);

    HRESULT STDMETHODCALLTYPE End(void);

};

typedef ID3DXLine* LPD3DXLINE;



#ifndef D3DXSPRITE_ALPHABLEND

#define D3DXSPRITE_ALPHABLEND 4

#endif



// D3DX_FILTER constants (minimal set)

#define D3DX_FILTER_NONE 0x00000001

#define D3DX_FILTER_POINT 0x00000002

#define D3DX_FILTER_LINEAR 0x00000003

#define D3DX_FILTER_TRIANGLE 0x00000004

#define D3DX_FILTER_BOX 0x00000005



// D3DX_SDK_VERSION - Define if not already defined

#ifndef D3DX_SDK_VERSION

#define D3DX_SDK_VERSION 43  // Use a reasonable default

#endif


