import std.algorithm.sorting;
import std.conv;
import std.exception;
import std.format;
import std.meta;
import std.stdio;

import ae.utils.array;
import ae.utils.meta;
import ae.utils.xmlbuild;

enum PType : ubyte
{
	Bool,
	Byte,
	UByte,
	Int,
	UInt,
	Float,
	String,
	Array,
	Object,
}

static struct PArray
{
	uint[] ids;
}

static struct PObject
{
	string[uint] ids;
}

static struct PObjectDelta
{
	string[uint] addedValueIDs;
	uint[] removedIDs;
}

alias PTypes = AliasSeq!(
	bool,
	byte,
	ubyte,
	int,
	uint,
	float,
	string,
	PArray,
	PObject,
);

enum PType ptypeOf(T) = cast(PType)staticIndexOf!(T, PTypes);

static struct PValue
{
	PType type;

	union
	{
		PTypes values;
	}

	ref T get(T)()
	{
		assert(type == ptypeOf!T, "This PValue contains a %s, not %s".format(type, ptypeOf!T));
		return values[ptypeOf!T];
	}

	void set(T)(auto ref T value)
	{
		type = ptypeOf!T;
		values[ptypeOf!T] = value;
	}

	this(T)(T value) { set(value); }

	string toString()
	{
		foreach (t; RangeTuple!(enumLength!PType))
			if (t == this.type)
				return "%(%s%)".format([values[t]]);
		assert(false, "Unknown type!");
	}
}

PValue[uint] dictionary;
uint[uint] parents;

string getPath(uint key)
{
	auto pvalue = key in dictionary;
	if (!pvalue)
		return "!";
	else
	if (key !in parents)
		return "#";
	else
	{
		auto parentKey = parents[key];
		auto pparent = parentKey in dictionary;
		if (!pparent)
			return "?";
		switch (pparent.type)
		{
			case PType.Object:
				return "%s.%s".format(getPath(parentKey), pparent.get!PObject.ids.get(key, "?"));
			case PType.Array:
				return "%s[%d]".format(getPath(parentKey), pparent.get!PArray.ids.indexOf(key));
			default:
				assert(false);
		}
	}
}

void handlePacket(ubyte[] packet)
{
	static struct Header { uint length; ubyte type; }
	static Header* header = null;

	if (!header)
	{
		enforce(packet.length == 5, "Invalid header packet size");
		header = cast(Header*)packet.ptr;

		writefln("Type %d, length %d", header.type, header.length);

		if (header.length == 0)
			header = null;

		return;
	}

	switch (header.type)
	{
		case 3:
		{
			while (packet.length)
			{
				ubyte type = packet[0];
				packet = packet[1..$];
				uint tag = *cast(uint*)packet.ptr;
				packet = packet[4..$];

				void showValue(T)(T value)
				{
					writefln("> Tag %d (%s), type %d (%s), value %(%s%)", tag, getPath(tag), type, T.stringof, [value]);

					static if (is(T == PObjectDelta))
					{
						auto p = tag in dictionary;
						if (p)
						{
							auto obj = &p.get!PObject();
							foreach (key, val; value.addedValueIDs)
								obj.ids[key] = val;
							foreach (key; value.removedIDs)
								obj.ids.remove(key);
						}
						else
							dictionary[tag] = PValue(PObject(value.addedValueIDs));
					}
					else
						dictionary[tag] = PValue(value);

					static if (is(T == PObjectDelta))
						foreach (key, val; dictionary[tag].get!PObject.ids)
							parents[key] = tag;
					static if (is(T == PArray))
						foreach (key; dictionary[tag].get!PArray.ids)
							parents[key] = tag;
				}

				T readValue(T)()
				{
					T value;
					static if (is(T == string))
					{
						auto index = packet.indexOf(0);
						enforce(index >= 0, "Unterminated string");
						value = cast(string)packet[0..index];
						packet = packet[index+1..$];
					}
					else
					static if (is(T == PArray))
					{
						foreach (n; 0..readValue!ushort())
							value.ids ~= readValue!uint();
					}
					else
					static if (is(T == PObjectDelta))
					{
						foreach (n; 0..readValue!ushort())
						{
							auto key = readValue!uint();
							auto val = readValue!string();
							value.addedValueIDs[key] = val;
						}
						foreach (n; 0..readValue!ushort())
							value.removedIDs ~= readValue!uint();
					}
					else
					static if (is(T : double))
					{
						value = *cast(T*)packet.ptr;
						packet = packet[T.sizeof..$];
					}
					return value;
				}

				string value;
				switch (type)
				{
					case 0: showValue(readValue!bool        ()); break;
					case 1: showValue(readValue!byte        ()); break;
					case 2: showValue(readValue!ubyte       ()); break;
					case 3: showValue(readValue!int         ()); break;
					case 4: showValue(readValue!uint        ()); break;
					case 5: showValue(readValue!float       ()); break;
					case 6: showValue(readValue!string      ()); break;
					case 7: showValue(readValue!PArray      ()); break;
					case 8: showValue(readValue!PObjectDelta()); break;
					default: writefln("> Tag %d, type %s (unknown)", tag, type); goto unknown;
				}
			}
			unknown:
			break;
		}
		case 4:
		{
			static struct MapHeader
			{
				uint w, h;
				static struct Coord { float x, y; }
				Coord a, b, c;
				static assert(MapHeader.sizeof == 32);
			}
			auto mapHeader = cast(MapHeader*)packet.ptr;
			writeln("> ", *mapHeader);
			break;
		}
		default:
			break;
	}

	header = null;
}

void dumpDictionary()
{
	bool[uint] visited;

	void dumpKey(uint key, int depth)
	{
		visited[key] = true;
		auto pvalue = key in dictionary;
		writefln("%*s[%d] %s", depth*2, "", key, !pvalue ? "null" : pvalue.type >= PType.Array ? "" : pvalue.toString());
		if (pvalue && pvalue.type == PType.Array)
			foreach (child; pvalue.get!PArray().ids)
				dumpKey(child, depth+1);
		if (pvalue && pvalue.type == PType.Object)
			foreach (child, name; pvalue.get!PObject().ids)
			{
				writefln("%*s  %s:", depth*2, "", name);
				dumpKey(child, depth+2);
			}
	}

	foreach (key; dictionary.keys.sort())
		if (key !in visited)
			dumpKey(key, 0);
	
	import std.file;
	std.file.write("dict.xml", dumpDictionaryXML());
}

string dumpDictionaryXML()
{
	auto xml = newXml;
/*
	svg.xmlns = "http://www.w3.org/2000/svg";
	svg["version"] = "1.1";
	auto text = svg.text(["x" : "0", "y" : "15", "fill" : "red"]);
	text = "I love SVG";

	auto s = svg.toString();
	string s1 = `<svg xmlns="http://www.w3.org/2000/svg" version="1.1"><text fill="red" x="0" y="15">I love SVG</text></svg>`;
	string s2 = `<svg xmlns="http://www.w3.org/2000/svg" version="1.1"><text x="0" y="15" fill="red">I love SVG</text></svg>`;
	assert(s == s1 || s == s2, s);
*/

	XmlBuildNode dumpKey(uint key, XmlBuildNode x)
	{
		auto pvalue = key in dictionary;
		auto props = ["id" : text(key), "type" : pvalue ? text(pvalue.type) : "null"];
	//	if (key in parents)
	//		props["parent"] = text(parents[key]);
		if (!pvalue)
			return x.value(props);
		else
		if (pvalue.type < PType.Array)
			return x.value(merge(props, ["value" : pvalue.toString()]));
		else
		if (pvalue.type == PType.Array)
		{
			auto node = x.value(props);
			foreach (child; pvalue.get!PArray().ids)
				dumpKey(child, node);
			return node;
		}
		else
		if (pvalue && pvalue.type == PType.Object)
		{
			auto node = x.value(props);
			foreach (child, name; pvalue.get!PObject().ids)
			{
				auto node2 = node.item(["name":name]);
				dumpKey(child, node2);
			}
			return node;
		}
		else
			assert(false);
	}

	return dumpKey(0, xml).toString();
}
