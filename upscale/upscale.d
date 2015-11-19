module csfo4.dll.upscale;

import core.stdc.stdio;
import core.sys.windows.windows;
import core.sys.windows.winsock2;

import csfo4.common.common;
import csfo4.common.hook;

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
FunctionHook!(PeekMessageA, PeekMessageAMy) hkPeekMessageA = void;

struct Fraction
{
	int dividend, divisor;
	int opMul(int x) @nogc nothrow { return x * dividend / divisor; }
}
enum fCW  = Fraction(2, 1);
enum fGWR = Fraction(1, 2);
enum fSWP = Fraction(1, 1);

void initialize()
{
	//MessageBoxA(null, "Hello from DLL\n", "mapfix", 0);
	hkCreateWindowExA.initialize("user32.dll", "CreateWindowExA");
	hkGetWindowRect  .initialize("user32.dll", "GetWindowRect");
//	hkPeekMessageA   .initialize("user32.dll", "PeekMessageA");
}

void shutdown()
{
//	hkCreateWindowExA.finalize();
//	hkGetWindowRect  .finalize();
}

HWND hWnd;

extern(Windows)
HWND CreateWindowExAMy(DWORD dwExStyle, LPCSTR lpClassName, LPCSTR lpWindowName, DWORD dwStyle,
	int x, int y, int nWidth, int nHeight, HWND hWndParent, HMENU hMenu, HINSTANCE hInstance, LPVOID lpParam)
{
	hWnd = hkCreateWindowExA.callNext(dwExStyle, lpClassName, lpWindowName, dwStyle,
		x, y, nWidth * fCW, nHeight * fCW, hWndParent, hMenu, hInstance, lpParam);

	static extern(Windows) DWORD ThreadProc(LPVOID lpParameter)
	{
		Sleep(999);
		RECT rect;
		hkGetWindowRect.callNext(hWnd, &rect);
		SetWindowPos(hWnd, null,
			rect.left,
			rect.top,
			(rect.right  - rect.left) * fSWP,
			(rect.bottom - rect.top ) * fSWP,
			SWP_NOSENDCHANGING | SWP_DEFERERASE | SWP_DEFERERASE | SWP_NOCOPYBITS | SWP_NOMOVE | SWP_NOOWNERZORDER | SWP_NOREDRAW | SWP_NOZORDER,
		);
		return 0;
	}

	DWORD dwThreadID;
	CreateThread(null, 0, &ThreadProc, null, 0, &dwThreadID);

	return hWnd;
}

extern(Windows)
BOOL GetWindowRectMy(HWND hWnd, LPRECT lpRect)
{
	auto bResult = hkGetWindowRect.callNext(hWnd, lpRect);
	if (bResult)
	{
		lpRect.right  = lpRect.left + (lpRect.right  - lpRect.left) * fGWR;
		lpRect.bottom = lpRect.top  + (lpRect.bottom - lpRect.top ) * fGWR;
	}
	return bResult;
}

extern(Windows)
BOOL PeekMessageAMy(LPMSG lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg)
{
	again:
	auto bResult = hkPeekMessageA.callNext(lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax, wRemoveMsg);
	if (bResult && lpMsg.message == WM_SIZE)
		goto again;
	return bResult;
}
