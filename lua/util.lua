
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

--	Util.isalpha() - whether the first character of a string is in [a-zA-Z]
function Util.isalpha(char)
	char = char:byte()
	return (char >= 97 and char <= 122) or (char >= 65 and char <= 90)
end

--	Util.stringSplit() - Given a string, returns a list of pieces split by a
--	delimiter, which is a pattern.
function Util.stringSplit(str, delimiter)
	local ret = {}
	local start = 1
	for pos in str:gmatch("()" .. delimiter) do
		table.insert(ret, str:sub(start, pos - 1))
		start = pos + 1
	end
	table.insert(ret, str:sub(start))
	return ret
end

--	Util.stringLastMatch() - like string.match() but returns last match.
--	If there is a match, returns the captures from the pattern, otherwise
--	returns nil. If pattern specifies no captures, then the whole match is
--	returned.
--	before:  if given, returns the last matching starting before this point
function Util.stringLastMatch(str, pattern, init, before)
	init = init or 1
	before = before or #str + 1
	local ret = {}
	while true do
		local captures = {str:match("()" .. pattern, init)}
		local pos = captures[1]
		--print("captures", table.unpack(captures))
		if not pos or pos >= before then
			--	Return previous match.
			if #ret == 0 then
				return nil  --	No match at all
			end
			--	First pop the pos of the last match
			pos = table.remove(ret, 1)
			--	If pattern contains no captures, then add whole match 
			if #ret == 0 then
				ret = {str:match(pattern, pos)}
			end
			return table.unpack(ret)
		end
		init = pos + 1
		ret = captures
	end
end

--	Test Util.stringLastMatch()
local function _test_stringLastMatch()
	assert(Util.tableEqual( {Util.stringLastMatch(" ", "1.")}, {nil} ))
	assert(Util.tableEqual( {Util.stringLastMatch("12 13 14", "1.")}, {"14"} ))
	assert(Util.tableEqual( {Util.stringLastMatch("12 13 14", "1.", 2)}, {"14"} ))
	assert(Util.tableEqual( {Util.stringLastMatch("12 13 14", "()(1.)")}, {7, "14"} ))
	assert(Util.tableEqual( {Util.stringLastMatch("12 13 14", "()(1.)", 1, 5)}, {4, "13"} ))
	assert(Util.tableEqual( {Util.stringLastMatch("12 13 14", "()(1.)", 1, 4)}, {1, "12"} ))
	assert(Util.tableEqual( {Util.stringLastMatch("12 13 14", "()(1.)", 5, 5)}, {nil} ))
	assert(Util.tableEqual( {Util.stringLastMatch("12 13 14", "()(1.)", 4, 5)}, {4, "13"} ))
	print("success")
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

--	Util.tableSize() - Number of keys in a table.
--	Warning: can be less than #tbl if some of the list elements are nil!
function Util.tableSize(tbl)
	local ret = 0
	for key, val in pairs(tbl) do
		ret = ret + 1
	end
	return ret
end

--	Util.tableEqual() - Whether two tables are element-wise equal
function Util.tableEqual(tbl1, tbl2)
	local len1 = 0
	for key, val in pairs(tbl1) do
		if tbl2[key] ~= val then
			return false
		end
		len1 = len1 + 1
	end

	-- Check whether there are any keys in tbl2 we didn't visit
	if Util.tableSize(tbl2) ~= len1 then
		return false
	end
	return true
end

local function _test_tableEqual()
	assert(Util.tableEqual({1, nil, 3}, {1, nil, 3}) == true)
	assert(Util.tableEqual({1, nil, 3}, {1, 2, 3}) == false)
	assert(Util.tableEqual({1, 2, 3}, {1, nil, 3}) == false)
	assert(Util.tableEqual({1, 2, 3, x = 4}, {1, 2, 3, x = 4}) == true)
	assert(Util.tableEqual({1, 2, 3, x = 4}, {1, 2, 3}) == false)
	assert(Util.tableEqual({1, 2, 3}, {1, 2, 3, x = 4}) == false)
	print("success")
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
	Log:write("Dumping map ", map)
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

--	Util.fileExists() - a naive approach to checking whether a file exists or not;
--	returns a boolean with the outcome.
function Util.fileExists(filename)
	local f = io.open(filename, "r")
	if f ~= nil then
		f:close()
		return true
	else
		return false
	end
end

--	Util.clamp(): clamps a value to be between `min' and `max'.
function Util.clamp(val, min, max)
	if val < min then
		return min
	end
	if val > max then
		return max
	end
	return val
end

-- _test_stringLastMatch()
-- _test_tableEqual()
-- os.exit()

return Util
