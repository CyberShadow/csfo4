module mapfix.common.hook;

import core.sys.windows.winbase;
import core.sys.windows.windef;

import mapfix.common.common;

nothrow @nogc:

enum trampolineLength = size_t.sizeof==8 ? 12 : 5;

struct Hook
{
nothrow @nogc:
	ubyte* target;
	void* newFunc;
	ubyte[trampolineLength] origCode;

	this(T)(T target, T newFunc)
	{
		this.target  = cast(ubyte*)target;
		this.newFunc = newFunc;
		origCode[] = this.target[0..trampolineLength];
		unprotect();
		hook();
	}

	void unprotect()
	{
		DWORD old;
		VirtualProtect(target, trampolineLength, PAGE_EXECUTE_WRITECOPY, &old).wenforce("VirtualProtect");
	}

	void hook()
	{
		static if (size_t.sizeof == 8)
		{
			target[ 0] = 0x48;
			target[ 1] = 0xB8;
			*cast(void**)(&target[2]) = newFunc;
			target[10] = 0xFF;
			target[11] = 0xE0;
		}
		else
		{
			target[ 0] = 0xE9;
			size_t offset = newFunc - cast(void*)(target+5);
			*cast(size_t*)(&target[1]) = offset;
		}
	}

	void unhook()
	{
		target[0..trampolineLength] = origCode[];
	}
}
