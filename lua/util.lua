
--
--	actor.lua
--	Generic utility functions not belonging anywhere else
--

local Log = require "lua/log"
local Global = require "lua/global"

local Util = {}


--	Util.dist() - return straight-line distance between two tiles, counting
--	diagonals as distance 1.
function Util.dist(x1, y1, x2, y2)
	return math.max(math.abs(x1 - x2), math.abs(y1 - y2))
end

--	Util.xyFromDirection() - given a direction code like "l", "ul" (up-left),
--	or "." (self), returns x,y with -1 <= x,y <= 1
function Util.xyFromDirection(dir)
	if dir == "l" then
		return -1, 0
	elseif dir == "d" then
		return 0, 1
	elseif dir == "u" then
		return 0, -1
	elseif dir == "r" then
		return 1, 0
	elseif dir == "ul" then
		return -1, -1
	elseif dir == "ur" then
		return 1, -1
	elseif dir == "dl" then
		return -1, 1
	elseif dir == "dr" then
		return 1, 1
	elseif dir == "." then
		return 0, 0
	else
		error("Bad direction " .. tostring(dir))
	end
end

Util.dirToInt = {
	u = 0, ur = 1, r = 2, dr = 3, d = 4, dl = 5, l = 6, ul = 7, ['.'] = 8
}

Util.intToDir = {
	[0] = 'u', [1] = 'ur', [2] = 'r', [3] = 'dr', [4] = 'd',
	[5] = 'dl', [6] = 'l', [7] = 'ul', [8] = '.'
}

--	Util.clockwise() - returns the direction (e.g. "dr") rotated clockwise by
--	n/8 of a full circle.
function Util.clockwise(dir, n)
	if dir == "." then
		return "."
	end
	n = n or 1
	print(dir, n)
	print(Util.dirToInt[dir])
	return Util.intToDir[(Util.dirToInt[dir] + n) % 8]
end

--	Util.anticlockwise() - returns the direction (e.g. "dr") rotated
--	anticlockwise by n/8 of a full circle.
function Util.anticlockwise(dir, n)
	return Util.clockwise(dir, -n)
end

--	Util.iteratorToList() - given an iterator, exhaust it, returning a table
function Util.iteratorToList(iterator)
	local ret = {}
	for item in iterator do
		table.insert(ret, item)
	end
	return ret
end

--	Util.seqRemove() - removes an object from a list, to go with
--	table.insert and table.remove.
--	Returns true on success, false if it didn't exist.
function Util.seqRemove(seq, item)
	local pos
	for i,v in ipairs(seq) do
		if v == item then
			pos = i
			break
		end
	end
	if not pos then
		return false
	end
	table.remove(seq, pos)
	return true
end

--	Util.tableFind() - Search for a value in a table, returning its key if
--	found, otherwise nil.
function Util.tableFind(tbl, value)
	for k,v in pairs(tbl) do
		if v == value then
			return k
		end
	end
	return nil
end

--	Util.printMethods() - Dump to the log the list of methods on an object
function Util.printMethods(obj)
	Log:write("Listing methods...")
	while obj do
		for k,v in pairs(obj) do
			if rawget(obj, k) then  --	check not inherited
				if type(v) == "function" then
					Log:write("  " .. tostring(k) .. " = " .. tostring(v))
				end
			end
		end
		local meta = getmetatable(obj)
		obj = nil
		if meta then
			Log:write("  has metatable")
			obj = meta.__index
			if obj then
				Log:write("  ...with __index; recursing:")
			end
		end
	end
end

--	Util.dumpGlobals() - print to log all the global variables, useful for
--	finding missing 'local's
function Util.dumpGlobals()
	Log:write("Contents of _G:")
	for k,v in pairs(_G) do
		Log:write("  " .. k)
	end
end

function Util.debugDumpMap(map)
	Log:write("Dumping map " .. map:toString())
	for j = 1, Global.mapHeight do
		for i = 1, Global.mapWidth do
			Log.file:write(map.tile[i][j].face)
		end
		Log.file:write("\n")
	end
end

function Util.copyTable(tbl)
	if type(tbl) ~= "table" then
		return nil
	end

	local t = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			t[k] = Util.copyTable(v)
		else
			t[k] = v
		end
	end
	setmetatable(t, getmetatable(tbl))
	return t
end

--	Util.makeStrict() - Sets the metatable of a table so that attempting to
--	access non-existent members throws an error. Returns the same table.
function Util.makeStrict(tbl)
	local meta = getmetatable(tbl)
	if not meta then
		meta = {}
		setmetatable(tbl, meta)
	end
	if meta.__index then
		--	We could make the prototype strict instead, but that would be pretty dangerous
		error("Can't make strick; already has an __index metamethod")
	end

	meta.__index = function(tbl, key)
		error("Tried to retrieve non-existent member " .. tostring(key) .. " of strict table " .. tostring(tbl))
	end
	meta.__newindex = function(tbl, key, value)
		error("Tried to set non-existent member " .. tostring(key) .. " = " .. tostring(value) .. " of strict table " .. tostring(tbl))
	end

	return tbl
end

return Util
