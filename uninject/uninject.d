module mapfix.uninject.uninject;

import core.stdc.stdio;
import core.stdc.string;
import core.sys.windows.tlhelp32;
import core.sys.windows.windows;

import mapfix.common.common;
import mapfix.common.process;

nothrow @nogc:

extern(C)
void start()
{
	ExitProcess(uninject() ? 0 : 1);
}

bool uninject()
{
	DWORD dwPID = FindPID(TEXT!"Fallout4.exe".ptr);
	enforce(dwPID, "Process not found!");

	HANDLE hProcess = OpenProcess(PROCESS_ALL_ACCESS, FALSE, dwPID).wenforce("OpenProcess");

	alias FreeLibrary_t = typeof(&FreeLibrary);
	auto FreeLibrary_p = cast(FreeLibrary_t)GetRemoteProcAddress(dwPID, TEXT!"kernel32.dll".ptr, "FreeLibrary");

	auto hModule = GetRemoteModuleHandle(dwPID, TEXT!"mapfix.dll".ptr);
	enforce(hModule, "Module not found");

	auto hThread = CreateRemoteThread(hProcess, null, 0, cast(LPTHREAD_START_ROUTINE)FreeLibrary_p, hModule, 0, null)
		.wenforce("CreateRemoteThread");

	DWORD dwWaitResult = WaitForSingleObject(hThread, INFINITE);
	debug printf("Wait result: %d\n", dwWaitResult);

	DWORD dwExitCode;
	GetExitCodeThread(hThread, &dwExitCode)
		.wenforce("GetExitCodeThread");
	debug printf("Exit code: %d\n", dwExitCode);

	CloseHandle(hProcess);
	return true;
}
