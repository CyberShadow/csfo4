module mapfix.dll.mapfix;

import core.stdc.stdio;
import core.sys.windows.windows;
import core.sys.windows.winsock2;

import mapfix.common.common;
import mapfix.common.hook;

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

Hook hkSend = void;
alias send_t = typeof(&send);
send_t sendOrig;

void initialize()
{
	//MessageBoxA(null, "Hello from DLL\n", "mapfix", 0);
	sendOrig = cast(send_t) GetProcAddress(GetModuleHandleA("ws2_32.dll"), "send");
	hkSend = Hook(sendOrig, &sendMy);
}

void shutdown()
{
	hkSend.unhook();
}

align(1)
struct Header
{
	uint size;
	ubyte type;
	static assert(Header.sizeof == 5);
}

enum int MapHeaderSize = 32;
struct MapHeader
{
	uint width, height;
	ubyte[24] unknown;
	static assert(MapHeader.sizeof == MapHeaderSize);
}

bool gotHeader = false;
Header lastHeader = void;

extern(Windows)
int sendMy(SOCKET s, const(void)* buf, int len, int flags)
{
	debug(dump)
	{
	    CreateDirectoryA(`C:\Temp\Fallout4\MyMods\mapfix\packets`, null);
	    char[1024] fn;
	    static __gshared int index;
	    sprintf(fn.ptr, `C:\Temp\Fallout4\MyMods\mapfix\packets\packet-%08d.bin`.ptr, index++);
	    FILE* f = fopen(fn.ptr, "wb");
	    fwrite(buf, 1, len, f);
	    fclose(f);
	}

	if (!gotHeader)
	{
		enforce(len == 5, "Bad header packet size");
		lastHeader = *cast(Header*)buf;
		if (lastHeader.size)
			gotHeader = true;
	}
	else
	{
		enforce(len == lastHeader.size, "Bad data packet size");
		gotHeader = false;

		if (lastHeader.type == 4) // map data
		{
			enforce(len > 32, "Bad map packet size");
			auto header = cast(MapHeader*)buf;
			auto correctSize = MapHeaderSize + header.width * header.height;
			if (correctSize != len)
			{
				auto stride = (len - MapHeaderSize) / header.height;
				enforce(len == MapHeaderSize + stride * header.height, "Uneven map data stride");
				auto pixels = cast(ubyte*)buf + MapHeaderSize;
				foreach (y; 0..header.height)
					pixels[y*header.width..y*header.width+header.width] = pixels[y*stride..y*stride+header.width];
			}
		}
	}

	hkSend.unhook();
	auto result = sendOrig(s, buf, len, flags);
	hkSend.hook();
	return result;
}
