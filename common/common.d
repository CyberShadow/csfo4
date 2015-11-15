module mapfix.common.common;

import core.stdc.stdio;
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
		//printf("%.*s failed!\n", what.length, what.ptr);
		error(what);
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

void error(string msg)
{
	showMessage(msg);
	ExitProcess(1);
}

void showMessage(string msg)
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
