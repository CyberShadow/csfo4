module mapfix.common.process;

import core.sys.windows.tlhelp32;
import core.sys.windows.winbase;
import core.sys.windows.windef;

debug import core.stdc.stdio;

import mapfix.common.common;

nothrow @nogc:

DWORD FindPID(LPCTSTR szProgram)
{
	HANDLE thSnapShot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	wenforce(thSnapShot != INVALID_HANDLE_VALUE, "CreateToolhelp32Snapshot");

	PROCESSENTRY32 pe = {PROCESSENTRY32.sizeof};

	BOOL bOK = Process32First(thSnapShot, &pe);
	while (bOK)
	{
		if (!icmp(pe.szExeFile.ptr, szProgram))
		{
			return pe.th32ProcessID;
		}
		bOK = Process32Next(thSnapShot, &pe);
	}
	return 0;
}

HMODULE GetRemoteModuleHandle(DWORD dwProcessID, LPCTSTR szModuleName)
{
	auto thSnapShot = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, dwProcessID);
	wenforce(thSnapShot != INVALID_HANDLE_VALUE, "CreateToolhelp32Snapshot");

	MODULEENTRY32 me = {MODULEENTRY32.sizeof};

	BOOL bOK = Module32First(thSnapShot, &me);
	while (bOK)
	{
		if (!icmp(me.szModule.ptr, szModuleName))
			return me.modBaseAddr;
		bOK = Module32Next(thSnapShot, &me);
	}
	return null;
}

void* GetRemoteProcAddress(DWORD dwPID, LPCTSTR szModuleName, LPCSTR szFunctionName)
{
	HMODULE hMod = GetModuleHandle(szModuleName);
	debug printf("mod (local) : %p\n", hMod);

	void* lpFun = GetProcAddress(hMod, szFunctionName).wenforce("GetProcAddress");
	debug printf("fun (local) : %p\n", lpFun);

	HMODULE hModRemote = GetRemoteModuleHandle(dwPID, szModuleName);
	lpFun = (lpFun - cast(void*)hMod + cast(void*)hModRemote);

	debug printf("mod (remote): %p\n", hModRemote);
	debug printf("fun (remote): %p\n", lpFun);

	return lpFun;
}

void* RemoteDup(HANDLE hProcess, in void[] data)
{
	auto address = VirtualAllocEx(hProcess, null, data.length, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE)
		.wenforce("VirtualAllocEx");

	WriteProcessMemory(hProcess, address, data.ptr, data.length, null)
		.wenforce("WriteProcessMemory");

	return address;
}
