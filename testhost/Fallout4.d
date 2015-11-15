// This example doesn't use the runtime at all, since
// it specifies the entry point and doesn't use any
// language facilities that require runtime support.
// Therefore, it doesn't even require slimlib.

// The makefile has two targets: optlink (default) and
// unilink. UniLink will produce a much smaller executable.

// The compiler will emit some meta-information for
// every module. It's only a few bytes in size, though.
module hello;

import core.stdc.stdio;

// Disable ModuleInfo generation for LDC.
version(LDC) pragma(LDC_no_moduleinfo);

// We only need this for the function signatures.
import win32.windows;

extern(Windows) void __imp_LoadLibraryA();

// No magic names needed.
extern(C)
void start()
{
	printf("%p - &LoadLibraryA\n", &LoadLibraryA);
	printf("%p - &__imp_LoadLibraryA\n", &__imp_LoadLibraryA);
	printf("%p - *cast(void**)&__imp_LoadLibraryA\n", *cast(void**)&__imp_LoadLibraryA);
	auto hmKernel32 = GetModuleHandle("kernel32.dll");
	printf("%p - GetProcAddress(...)\n", GetProcAddress(hmKernel32, "LoadLibraryA"));
	printf("%p - GetModuleHandle(...)\n", hmKernel32);

	//int result;
	do
	{
		//result = MessageBox(null, "Hello, world!", "SlimD", MB_ICONINFORMATION | MB_OKCANCEL);
		printf("Hello, world!\n");
		char[1024] buf;
		gets(buf.ptr);
	}
	while (true);
}
