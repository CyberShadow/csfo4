module csfo4.common.hook;

import std.traits;

import core.sys.windows.winbase;
import core.sys.windows.windef;

import csfo4.common.common;

nothrow @nogc:

enum trampolineLength = size_t.sizeof==8 ? 12 : 5;

void makeWritable(void[] mem)
{
	/*MEMORY_BASIC_INFORMATION mbi;
	VirtualQuery(mem.ptr, &mbi, mbi.sizeof).wenforce("VirtualQuery");

	DWORD newProtect;
	switch (mbi.Protect & 0x80)
	{
		case PAGE_EXECUTE:
		case PAGE_EXECUTE_READ:
			newProtect = PAGE_EXECUTE_WRITECOPY;
			break;
		case PAGE_NOACCESS:
		case PAGE_READONLY:
			newProtect = PAGE_READWRITE;
			break;
		case PAGE_EXECUTE_READWRITE:
		case PAGE_EXECUTE_WRITECOPY:
		case PAGE_READWRITE:
		case PAGE_WRITECOPY:
			return;
		default:
			error("Unknown protection");
	}*/
	DWORD newProtect = PAGE_EXECUTE_READWRITE;

	DWORD oldProtect;
	VirtualProtect(mem.ptr, mem.length, newProtect, &oldProtect).wenforce("VirtualProtect");
}

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
		makeWritable(target[0..trampolineLength]);
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

struct MethodHook(alias original, alias callback)
{
	enum methodName = Identity!(__traits(identifier, original));

	alias I = Identity!(__traits(parent, original));
	alias Fun = extern(Windows) ReturnType!original function(I, Parameters!original) nothrow @nogc;

	static assert(is(Fun == typeof(&callback)),
		"Mismatching hook function types.\nOriginal:\n\t" ~ Fun.stringof ~ "\nCallback:\n\t" ~ typeof(&callback).stringof);

	Fun* funPtr;
	Fun origPtr;

	enum int index = {
		int i;
	    static if (is(I S == super) && S.length)
			i += __traits(allMembers, S).length;
		foreach (member; __traits(derivedMembers, I))
			if (member == methodName)
				return i;
			else
				i++;
		assert(false, "Method not found");
	}();

	void initialize(I intf)
	{
		funPtr = &(cast(Fun**)intf)[0][index];
		origPtr = *funPtr;

		makeWritable((cast(void*)funPtr)[0..(void*).sizeof]);
		*funPtr = &callback;
	}

	void finalize()
	{
		if (funPtr && origPtr)
			*funPtr = origPtr;
	}

	ReturnType!original callNext(I self, Parameters!original args)
	{
		return origPtr(self, args);
	}
}
