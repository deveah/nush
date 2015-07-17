
--
--	actor.lua
--	Generic utility functions not belonging anywhere else
--

local Log = require "lua/log"
local Global = require "lua/global"

local Util = {}


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

--	Util.seqDelete() - removes an object from a numerical sequence, to go with
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

--	Util.listMethods() - Dump to the log the list of methods on an object
function Util.listMethods(obj)
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

return Util
