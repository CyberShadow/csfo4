module mapfix.proxy.dxgi;

import core.stdc.wchar_;
import core.sys.windows.basetyps;
import core.sys.windows.winbase;
import core.sys.windows.windef;
import core.sys.windows.winuser;

import mapfix.common.common;
import mapfix.common.hook;

nothrow @nogc __gshared:

pragma(startaddress, DllEntryPoint);

extern(System)
BOOL DllEntryPoint(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpReserved) nothrow @nogc
{
	if (fdwReason == DLL_PROCESS_ATTACH)
		initialize();
	return TRUE;
}

void initialize()
{
	WIN32_FIND_DATAW wfd = void;
	HANDLE hDir = FindFirstFileW(`Plugins\*.*`, &wfd);
	if (hDir != INVALID_HANDLE_VALUE)
		do
		{
			if (wfd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY && wfd.cFileName[0] != '.')
			{
				wchar[MAX_PATH] path = void;
				wcscpy(path.ptr, `Plugins\`);
				wcscat(path.ptr, wfd.cFileName.ptr);
				wcscat(path.ptr, `\`);
				wcscat(path.ptr, wfd.cFileName.ptr);
				wcscat(path.ptr, `.dll`);
				//MessageBoxW(null, path.ptr, "proxy", 0);
				LoadLibraryW(path.ptr);
			}
		}
		while (FindNextFileW(hDir, &wfd));
}

HMODULE hmTarget;

mixin template proxyFunc(string name, Return, Args...)
{
	alias ProxyFunc_t = typeof(&ProxyFunc);
	ProxyFunc_t ProxyFunc_p = null;

	extern(System)
	pragma(mangle, name)
	export
	Return ProxyFunc(Args args)
	{
		if (!ProxyFunc_p)
		{
			if (!hmTarget)
				loadTarget();
			ProxyFunc_p = cast(ProxyFunc_t)GetProcAddress(hmTarget, name);
		}
		return ProxyFunc_p(args);
	}
}

mixin proxyFunc!("CreateDXGIFactory" , HRESULT, REFIID, void **);
mixin proxyFunc!("CreateDXGIFactory1", HRESULT, REFIID, void **);

void loadTarget()
{
	wchar[MAX_PATH] path = void;
	GetSystemDirectoryW(path.ptr, MAX_PATH);
	wcscat(path.ptr, `\dxgi.dll`);
	hmTarget = LoadLibraryW(path.ptr);
}