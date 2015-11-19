module csfo4.common.hook;

import std.traits;

import core.sys.windows.winbase;
import core.sys.windows.windef;

import csfo4.common.common;

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

struct FunctionHook(alias original, alias callback)
{
	static assert(is(typeof(&original) == typeof(&callback)),
		"Mismatching hook function types.\nOriginal:\n\t" ~ typeof(&original).stringof ~ "\nCallback:\n\t" ~ typeof(&callback).stringof);
	alias Fun = typeof(&original);

	Hook hook;
	Fun origPtr;

	void initialize(const char* dll, const char* fun)
	{
		origPtr = cast(Fun) GetProcAddress(GetModuleHandleA(dll), fun);
		hook = Hook(origPtr, &callback);
	}

	void finalize()
	{
		hook.unhook();
	}

	ReturnType!original callNext(Parameters!original args)
	{
		hook.unhook();
		ReturnType!original result = origPtr(args);
		hook.hook();
		return result;
	}
}
