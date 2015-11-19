module csfo4.inject.inject;

import core.stdc.stdio;
import core.stdc.string;
import core.sys.windows.tlhelp32;
import core.sys.windows.windows;

import csfo4.common.common;
import csfo4.common.process;

nothrow @nogc:

extern(C)
void start()
{
	ExitProcess(inject() ? 0 : 1);
}

bool inject()
{
	char[MAX_PATH] szDllName = 0;
	GetFullPathNameA("mapfix.dll", cast(int)MAX_PATH, szDllName.ptr, null);
	debug printf("%s\n", szDllName.ptr);

	DWORD dwPID = FindPID(TEXT!"Fallout4.exe".ptr);
	enforce(dwPID, "Process not found!");

	HANDLE hProcess = OpenProcess(PROCESS_ALL_ACCESS, FALSE, dwPID).wenforce("OpenProcess");

	alias LoadLibraryA_t = typeof(&LoadLibraryA);
	auto LoadLibrary_p = cast(LoadLibraryA_t)GetRemoteProcAddress(dwPID, TEXT!"kernel32.dll".ptr, "LoadLibraryA");

	auto RemoteString = RemoteDup(hProcess, szDllName[0..strlen(szDllName.ptr)+1]);

	auto hThread = CreateRemoteThread(hProcess, null, 0, cast(LPTHREAD_START_ROUTINE)LoadLibrary_p, RemoteString, 0, null)
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
