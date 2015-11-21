module csfo4.dll.mapfix;

import core.stdc.stdio;
import core.stdc.string;
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

FunctionHook!(send, sendMy) hkSend = void;

void initialize()
{
	//MessageBoxA(null, "Hello from DLL\n", "mapfix", 0);
	hkSend.initialize("ws2_32.dll", "send");
}

void shutdown()
{
	hkSend.finalize();
}

align(1)
struct Header
{
	uint size;
	ubyte type;
	static assert(Header.sizeof == 5);
}

struct Coord
{
	float x, y;
}

enum int MapHeaderSize = 32;
struct MapHeader
{
	uint width, height;
	Coord topLeft, topRight, bottomLeft;
	static assert(MapHeader.sizeof == MapHeaderSize);
}

bool gotHeader = false;
Header lastHeader = void;

MapHeader goodMapHeader;
ubyte[] goodPixels = null;

extern(Windows)
int sendMy(SOCKET s, const(void)* buf, int len, int flags)
{
	debug(dump)
	{
	    CreateDirectoryA(`C:\Temp\Fallout4\MyMods\csfo4\mapfix\packets`, null);
	    char[1024] fn;
	    static __gshared int index;
	    sprintf(fn.ptr, `C:\Temp\Fallout4\MyMods\csfo4\mapfix\packets\packet-%08d.bin`.ptr, index++);
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
			auto pixels = (cast(ubyte*)buf + MapHeaderSize)[0..header.width * header.height];
			auto correctSize = MapHeaderSize + header.width * header.height;
			if (correctSize != len)
			{
				auto stride = (len - MapHeaderSize) / header.height;
				enforce(len == MapHeaderSize + stride * header.height, "Uneven map data stride");
				foreach (y; 0..header.height)
					pixels[y*header.width..y*header.width+header.width] = pixels[y*stride..y*stride+header.width];
			}

			bool isBlank = true;
			foreach (p; pixels)
				if (p)
				{
					isBlank = false;
					break;
				}

			debug(force)
			if (GetTickCount() % 10)
				isBlank = true;

			if (isBlank && goodPixels.length == header.width * header.height)
			{
				// Although the coordinates permit the map to represent any parallelogram,
				// in practice it seems to be a cartesian-aligned rectangle (and can thus
				// be represented with two coordinate pairs intead of three).

				// Map units per pixel
				auto sx = (header.topRight.x - header.topLeft.x) / header.width;
				auto sy = (header.bottomLeft.y - header.topLeft.y) / header.height;

				// Delta (in map units)
				auto mdx = header.topLeft.x - goodMapHeader.topLeft.x;
				auto mdy = header.topLeft.y - goodMapHeader.topLeft.y;

				// Delta (in pixels)
				auto pdx = cast(int)(mdx / sx);
				auto pdy = cast(int)(mdy / sy);

				debug(fill)
				foreach (i, ref p; pixels)
					p = i%255;

				foreach (int oy; 0..header.height)
					foreach (int ox; 0..header.width)
					{
						int nx = ox - pdx;
						int ny = oy - pdy;
						if (nx >= 0 && nx < header.width && ny >= 0 && ny < header.height)
							pixels[ny*header.width+nx] = goodPixels[oy*header.width+ox];
					}

				debug(overlay)
				{
					import ae.utils.graphics.image;
					import ae.utils.graphics.draw;
					import ae.utils.graphics.fonts.draw;
					import ae.utils.graphics.fonts.font8x8;

					auto i = ImageRef!ubyte(header.width, header.height, header.width, pixels.ptr);
					auto ti = i.crop(40, 40, 500, 100);

					char[1024] str;
					sprintf(str.ptr, "topLeft = (%f, %f)\ntopRight = (%f, %f)\nbottomLeft = (%f, %f)\ns=(%f, %f)\nmd=(%f, %f)\npd=(%d, %d)",
						header.topLeft.tupleof, header.topRight.tupleof, header.bottomLeft.tupleof,
						sx, sy, mdx, mdy, pdx, pdy,
					);

					ti.fill(ubyte(0));
					ti.drawText(10, 10, str[0..strlen(str.ptr)], font8x8, ubyte(255));
					ti.nearestNeighbor(ti.w*2, ti.h*2).blitTo(i, 40, 100);
				}
			}
			else
			{
				auto size = header.width * header.height;
				goodMapHeader = *header;
				goodPixels.setLength(size);
				goodPixels[] = pixels[0..size];
			}
		}
	}

	return hkSend.callNext(s, buf, len, flags);
}
