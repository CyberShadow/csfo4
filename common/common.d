module csfo4.common.common;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.windows.winbase;
import core.sys.windows.winnt;
import core.sys.windows.winuser;

import std.ascii;

nothrow @nogc:

template TEXT(string s)
{
	import std.conv : to;
	static immutable TCHAR[] TEXT = s.to!(TCHAR[]);
}

int icmp(T)(const(T)* a, const(T)* b)
{
	while (*a && *b && toLower(*a)==toLower(*b))
		a++, b++;
	return *b - *a;
}

bool startsWith(T)(in T[] a, in T[] b)
{
	return a.length >= b.length && a.ptr[0..b.length] == b;
}

T wenforce(T)(T value, string what)
{
	if (!value)
	{
		char* lpMsgBuf = null;
		FormatMessageA(
			FORMAT_MESSAGE_ALLOCATE_BUFFER |
			FORMAT_MESSAGE_FROM_SYSTEM |
			FORMAT_MESSAGE_IGNORE_INSERTS,
			null,
			GetLastError(),
			0,
			cast(LPSTR)&lpMsgBuf,
			0,
			null);

		char[1024] msg = void;
		sprintf(msg.ptr, "%.*s failed: %s\n", what.length, what.ptr, lpMsgBuf);
		error(msg.ptr[0..strlen(msg.ptr)]);
		ExitProcess(1);
	}
	return value;
}

T enforce(T)(T value, string msg)
{
	if (!value)
		error(msg);
	return value;
}

void error(in char[] msg)
{
	showMessage(msg);
	//ExitProcess(1);
	TerminateProcess(GetCurrentProcess(), 1);
}

void showMessage(in char[] msg)
{
	version (console)
		printf("%.*s\n", msg.length, msg.ptr);
	else
	{
		char[1024] buf;
		sprintf(buf.ptr, "%.*s\n", msg.length, msg.ptr);
		MessageBoxA(null, buf.ptr, "mapfix", 0);
	}
}

T[] newArr(T)(size_t size)
{
	return (cast(T*)malloc(size * T.sizeof))[0..size];
}
