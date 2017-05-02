module csfo4.dxlog.d3d11;

import win32.directx.dxgitype;

import std.traits;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.wchar_;
import core.sys.windows.basetyps;
import core.sys.windows.winbase;
import core.sys.windows.windef;
import core.sys.windows.winuser;

import csfo4.directx.d3d11;

import ae.utils.meta;

import csfo4.common.common;
import csfo4.common.hook;

nothrow @nogc __gshared:

pragma(startaddress, DllEntryPoint);

extern(System)
BOOL DllEntryPoint(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpReserved) nothrow @nogc
{
	if (fdwReason == DLL_PROCESS_ATTACH)
		initialize();
	else
	if (fdwReason == DLL_PROCESS_DETACH)
		finalize();
	return TRUE;
}

FILE* log;

void initialize()
{
	log = fopen(`dxlog.log`, "wb");
}

void finalize()
{
	fclose(log);
}

enum Enum(alias s) = s;

void logValue(T)(ref T value)
{
	static if (is(T:int))
		fprintf(log, "%d", int(value));
	else
	static if (is(T:long))
		fprintf(log, "%lld", long(value));
	else
	static if (is(T:double))
		fprintf(log, "%f", double(value));
	else
	static if (is(typeof(cast(void*)value)))
	{
		auto p = cast(void*)value;
		if (p)
			fprintf(log, "%p", p);
		else
			fputs("NULL", log);
	}
	else
	static if (is(T : GUID))
		fprintf(log, "%08X-%04X-%04X-%02X%02X-%02X%02X%02X%02X%02X%02X",
			value.Data1,
			value.Data2,
			value.Data3,
			value.Data4[0],
			value.Data4[1],
			value.Data4[2],
			value.Data4[3],
			value.Data4[4],
			value.Data4[5],
			value.Data4[6],
			value.Data4[7],
		);
	else
	static if (is(T == struct))
	{
		fputs("{ ", log);
		bool first = true;
		foreach (i, field; value.tupleof)
		{
			if (!first)
				fputs(", ", log);
			else
				first = false;
			fputs(Enum!(value.tupleof[i].stringof[6..$] ~ " : "), log);
			logValue(field);
		}
		fputs(" }", log);
	}
	else
		fputs("...", log);

	static if (is(typeof(*value)))
	{
		if (value)
		{
			fputs(" -> ", log);
			logValue(*value);
		}
	}
}

void logArgs(string[] names, Args...)(Args args)
{
	foreach (i; RangeTuple!(args.length))
	{
		fputs(Enum!(names[i] ~ " = "), log);
		logValue(args[i]);

		if (i+1 < args.length)
			fputs(", ", log);
	}
}

void logFunc(alias fun)(Parameters!fun args, ReturnType!fun result)
{
	fputs(Enum!(__traits(identifier, fun) ~ "("), log);
	logArgs!([ParameterIdentifierTuple!fun])(args);
	fputs(") = ", log);
	logValue(result);
	fputs("\n", log);
}

template logMethod(I, alias fun)
{
	void logMethod(I self, Parameters!fun args, NotVoid!(ReturnType!fun) result)
	{
		fputs(Enum!(I.stringof ~ "::" ~ __traits(identifier, fun) ~ "("), log);
		logArgs!(["this", ParameterIdentifierTuple!fun])(self, args);
		static if (is(ReturnType!fun == void))
			fputs(")\n", log);
		else
		{	
			fputs(") = ", log);
			logValue(result);
			fputs("\n", log);
		}
		fflush(log);
	}
}

void hookMethod(I, string methodName)(ref void* ptr)
{
	alias method = Identity!(__traits(getMember, I, methodName));
	alias Fun = extern(Windows) ReturnType!method function(I, Parameters!method);
	__gshared static Fun origFun = null;

	extern(Windows) static ReturnType!method funHook(I self, Parameters!method args)
	{
		/*
		static if (methodName == "ResizeTarget")
		{
			//HRESULT result = S_OK;
			auto mutDesc = cast(DXGI_MODE_DESC*)args[0];
			mutDesc.Width /= 2;
			mutDesc.Height /= 2;
		}
		*/
		version(none)
		static if (methodName == "RSSetViewports")
		{
			auto NumViewports = args[0];
			auto pViewports = args[1];
			auto viewports = (cast(D3D11_VIEWPORT*)pViewports)[0..NumViewports];

			foreach (ref viewport; viewports)
				if (viewport.Width == 3840 && viewport.Height == 2160)
				{
					viewport.Width = 1920;
					viewport.Height = 1080;
				}
		}

		auto result = notVoid(origFun(self, args));

		version (none)
		static if (is(I : ID3D11Texture2D) && methodName == "GetDesc")
		{
			auto pDesc = args[0];
			if (pDesc.Width == 3840 && pDesc.Height == 2160)
			{
				pDesc.Width /= 2;
				pDesc.Height /= 2;
			}
		}

		logMethod!(I, method)(self, args, result);

		foreach (arg; args)
			hookArg(arg);

		static if (methodName == "QueryInterface")
		{
			auto riid = args[0];
			auto ppvObject = args[1];

			foreach (ref entry; iidLookup)
				if (entry.iid == *riid)
				{
					fputs("Found IID!\n", log);
					entry.hookFun(*ppvObject);
					break;
				}
		}

		version(none)
		static if (methodName == "CreateBuffer")
		{
			const D3D11_BUFFER_DESC* pDesc = args[0];
			const D3D11_SUBRESOURCE_DATA *pInitialData = args[1];
			ID3D11Buffer* ppBuffer = args[2];

			if (ppBuffer && pInitialData)
			{
				char[1024] filename = void;
				sprintf(filename.ptr, `C:\Temp\Fallout4\MyMods\csfo4\dxlog\buffers\%p.buf`, ppBuffer);
				FILE* f = fopen(filename.ptr, "wb");
				fwrite(pInitialData.pSysMem, pDesc.ByteWidth, 1, f);
				fclose(f);
			}
		}

		version(none)
		static if (methodName == "CreateTexture2D")
		{
			const D3D11_TEXTURE2D_DESC* pDesc = args[0];
			const D3D11_SUBRESOURCE_DATA *pInitialData = args[1];
			ID3D11Texture2D* ppTexture2D = args[2];

			if (ppTexture2D && pInitialData)
			{
				char[1024] filename = void;
				sprintf(filename.ptr, `C:\Temp\Fallout4\MyMods\csfo4\dxlog\textures\%p-%dx%d.tex`, ppTexture2D, pDesc.Width, pDesc.Height);
				FILE* f = fopen(filename.ptr, "wb");
				fwrite(pInitialData.pSysMem, pDesc.Width * pDesc.Height * pDesc.ArraySize * /*TODO*/4, 1, f);
				fclose(f);
			}
		}

		static if (!is(ReturnType!method == void))
			return result;
	}

	if (ptr !is &funHook)
	{
		if (origFun && origFun !is ptr)
		{
			debug(hooks)
			{
				fprintf(log, "Not re-hooking %s::%s (%08X -> %08X)\n",
					I.stringof.ptr,
					methodName.ptr,
					ptr,
					&funHook,
				);
				fflush(log);
			}
		}
		else
		{
			debug(hooks)
			{
				fprintf(log, "Hooking %s::%s (%08X -> %08X)\n",
					I.stringof.ptr,
					methodName.ptr,
					ptr,
					&funHook,
				);
				fflush(log);
			}

			origFun = cast(Fun)ptr;

			DWORD old;
			VirtualProtect(&ptr, (void*).sizeof, PAGE_EXECUTE_READWRITE, &old).wenforce("VirtualProtect");

			ptr = &funHook;
		}
	}
}

void hookInterface(I)(I intf)
{
	void** vtable = *cast(void***)intf;

	size_t index = 0;

	void hookMethods(J)()
	{
	    static if (is(J S == super) && S.length)
	    {
	    	static assert(S.length == 1, "Multiple interface inheritance");
	    	hookMethods!S();
	    }

	    foreach (member; __traits(derivedMembers, J))
	    	hookMethod!(I, member)(vtable[index++]);
	}

	hookMethods!I();
}

struct IIDLookupEntry
{
	IID iid;
	void function(void*) hookFun;

	static string genCode(string moduleName)()
	{
		string code;
		mixin(`static import ` ~ moduleName ~ `;`);
		mixin(`alias mod = ` ~ moduleName ~ `;`);
		foreach (memberName; __traits(allMembers, mod))
		{
			enum memberFQName = moduleName ~ `.` ~ memberName;
			mixin(`alias member = ` ~ memberFQName ~ `;`);
			static if (is(typeof(member) : const(IID)) && memberName.startsWith("IID_"))
			{
				enum typeName = memberName[4..$];
				enum typeFQName = moduleName ~ `.` ~ typeName;
				static if (mixin(`is(` ~ typeFQName ~ `)`))
					code ~= `IIDLookupEntry(` ~ memberFQName ~ `, (void* ptr) { return hookInterface(cast(` ~ typeFQName ~ `)ptr); }),` ~ '\n';
			}
		}
		return code;
	}
}

immutable IIDLookupEntry[] iidLookup = mixin("[" ~
	IIDLookupEntry.genCode!`csfo4.directx.d2d1` ~
	IIDLookupEntry.genCode!`csfo4.directx.d3d11` ~
	IIDLookupEntry.genCode!`csfo4.directx.d3d11shader` ~
	IIDLookupEntry.genCode!`csfo4.directx.dwrite` ~
	IIDLookupEntry.genCode!`csfo4.directx.dxgi` ~
	IIDLookupEntry.genCode!`csfo4.directx.dxinternal` ~
	IIDLookupEntry.genCode!`csfo4.directx.dxpublic` ~
	IIDLookupEntry.genCode!`csfo4.directx.xaudio2` ~
"]");
pragma(msg, iidLookup.length);

/// Hooks "out" parameters which are pointers to interfaces.
/// An interface is a pointer (inside an object),
/// which is pointing at a vtable pointer:
/// argument -> interface -> object -> vtable
void hookArg(T)(T value)
{
	static if (is(typeof(*value)))
	{
		alias I = typeof(*value);
		static if (is(I == interface) && is(I : std.c.windows.com.IUnknown))
		{
			if (value && *value)
			{
				I i = *value;
				hookInterface(i);
			}
		}
	}
}

HMODULE hmTarget;

mixin template proxyFunc(alias func)
{
	enum name = __traits(identifier, func);
	alias Return = ReturnType!func;
	alias Args = Parameters!func;

	alias ProxyFunc_t = typeof(&ProxyFunc);
	ProxyFunc_t ProxyFunc_p = null;

	extern(System)
	pragma(mangle, name)
	export
	Return ProxyFunc(Args args)
	{
	//	MessageBoxA(null, name, "dxlog", 0);
		if (!ProxyFunc_p)
		{
			if (!hmTarget)
				loadTarget();
			ProxyFunc_p = cast(ProxyFunc_t)GetProcAddress(hmTarget, name);
		}

		auto result = ProxyFunc_p(args);
		logFunc!func(args, result);
		foreach (arg; args)
			hookArg(arg);
		return result;
	}
}

mixin proxyFunc!D3D11CreateDeviceAndSwapChain;

void loadTarget()
{
	wchar[MAX_PATH] path = void;
	GetSystemDirectoryW(path.ptr, MAX_PATH);
	wcscat(path.ptr, `\d3d11.dll`);
	hmTarget = LoadLibraryW(path.ptr);
}
