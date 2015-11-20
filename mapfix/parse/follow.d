import core.thread;

import std.algorithm.iteration;
import std.algorithm.sorting;
import std.array;
import std.file;

import common;

void main()
{
	auto getList()
	{
		return dirEntries(`..\packets\`, "*.bin", SpanMode.shallow).map!(de => de.name)
			.array()
			.sort()
			.map!(fn => cast(ubyte[])std.file.read(fn))
		;
	}

	auto lastList = getList();
	while (true)
	{
		Thread.sleep(10.msecs);
		auto list = getList();
		foreach (packet; list[lastList.length .. $])
			handlePacket(packet);
		lastList = list;
	}
}
