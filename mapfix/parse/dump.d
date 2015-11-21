import std.algorithm.iteration;
import std.array;
import std.file;
import std.path;
import std.stdio;
import std.typecons;

import ae.utils.array;

import common;

void main(string[] args)
{
	string[] targets = args[1..$];
	if (!targets.length)
		targets = [`..\packets\`];
	foreach (target; targets)
	{
		string dir, mask;
		if (target.exists && target.isDir)
			list(dir, mask) = tuple(target, "*.bin");
		else
			list(dir, mask) = tuple(target.dirName, target.baseName);
		auto files = dirEntries(dir, mask, SpanMode.shallow).map!(de => de.name).array();
		auto packets = files.map!(fn => cast(ubyte[])std.file.read(fn)).array();
		foreach (packet; packets)
			handlePacket(packet);
	}

	writeln("======================================================");
	dumpDictionary();
}
