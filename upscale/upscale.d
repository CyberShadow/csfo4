module csfo4.dll.upscale;

import std.traits;

import core.stdc.stdio;
import core.sys.windows.windows;
import core.sys.windows.winsock2;

import csfo4.common.common;
import csfo4.common.hook;
import csfo4.directx.d3d11;
import csfo4.directx.dxgi;

nothrow @nogc __gshared:

pragma(startaddress, DllEntryPoint);

/// Like WinMain, DllMain is not the true entry point of DLLs.
/// Rather, the C runtime calls DllMain after initializing itself.
/// We can circumvent the C runtime dependency by declaring the
/// entry point ourselves, which incidentally has the same
/// signature as DllMain.
extern(System)
BOOL DllEntryPoint(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpReserved) nothrow @nogc
{
	if (fdwReason == DLL_PROCESS_ATTACH)
		initialize();
	else
	if (fdwReason == DLL_PROCESS_DETACH)
		shutdown();
	return TRUE;
}

FunctionHook!(CreateWindowExA, CreateWindowExAMy) hkCreateWindowExA = void;
FunctionHook!(GetWindowRect, GetWindowRectMy) hkGetWindowRect = void;
FunctionHook!(D3D11CreateDeviceAndSwapChain, D3D11CreateDeviceAndSwapChainMy) hkD3D11CreateDeviceAndSwapChain = void;
MethodHook!(ID3D11DeviceContext.RSSetViewports, RSSetViewportsMy) hkRSSetViewPorts;

void initialize()
{
	hkCreateWindowExA              .initialize("user32.dll", "CreateWindowExA");
	hkGetWindowRect                .initialize("user32.dll", "GetWindowRect");
	hkD3D11CreateDeviceAndSwapChain.initialize("d3d11.dll", "D3D11CreateDeviceAndSwapChain");
}

void shutdown()
{
	hkCreateWindowExA              .finalize();
	hkGetWindowRect                .finalize();
	hkD3D11CreateDeviceAndSwapChain.finalize();
	hkRSSetViewPorts               .finalize();
}

HWND hWnd;
DWORD renderW, renderH, screenW, screenH;

extern(Windows)
HWND CreateWindowExAMy(DWORD dwExStyle, LPCSTR lpClassName, LPCSTR lpWindowName, DWORD dwStyle,
	int x, int y, int nWidth, int nHeight, HWND hWndParent, HMENU hMenu, HINSTANCE hInstance, LPVOID lpParam)
{
	screenW = GetSystemMetrics(SM_CXSCREEN);
	screenH = GetSystemMetrics(SM_CYSCREEN);
	renderW = nWidth;
	renderH = nHeight;

	return hkCreateWindowExA.callNext(dwExStyle, lpClassName, lpWindowName, dwStyle,
		x, y, screenW, screenH, hWndParent, hMenu, hInstance, lpParam);
}

extern(Windows)
BOOL GetWindowRectMy(HWND hWnd, LPRECT lpRect)
{
	auto bResult = hkGetWindowRect.callNext(hWnd, lpRect);
	if (bResult)
	{
		lpRect.right  = lpRect.left + (lpRect.right  - lpRect.left) * renderW / screenW;
		lpRect.bottom = lpRect.top  + (lpRect.bottom - lpRect.top ) * renderH / screenH;
	}
	return bResult;
}

extern(Windows)
HRESULT D3D11CreateDeviceAndSwapChainMy(
    IDXGIAdapter pAdapter,
    D3D11_DRIVER_TYPE DriverType,
    HMODULE Software,
    uint Flags,
    in D3D11_FEATURE_LEVEL* pFeatureLevels,
    uint FeatureLevels,
    uint SDKVersion,
    in DXGI_SWAP_CHAIN_DESC* pSwapChainDesc,
    /*out*/ IDXGISwapChain* ppSwapChain,
    /*out*/ ID3D11Device* ppDevice,
    D3D11_FEATURE_LEVEL* pFeatureLevel,
    ID3D11DeviceContext* ppImmediateContext,
)
{
	auto result = hkD3D11CreateDeviceAndSwapChain.callNext(
		pAdapter, DriverType, Software, Flags, pFeatureLevels, FeatureLevels, SDKVersion,
		pSwapChainDesc, ppSwapChain, ppDevice, pFeatureLevel, ppImmediateContext);
	if (ppImmediateContext && *ppImmediateContext)
	{
		auto intf = *ppImmediateContext;
		hkRSSetViewPorts.initialize(intf);
	}
	return result;
}

extern(Windows)
void RSSetViewportsMy(ID3D11DeviceContext self, UINT NumViewports, const D3D11_VIEWPORT *pViewports)
{
	auto viewports = (cast(D3D11_VIEWPORT*)pViewports)[0..NumViewports];

	foreach (ref viewport; viewports)
		if (viewport.Width == screenW && viewport.Height == screenH)
		{
			viewport.Width = renderW;
			viewport.Height = renderH;
		}

	hkRSSetViewPorts.callNext(self, NumViewports, pViewports);
}
