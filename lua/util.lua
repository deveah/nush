
--
--	actor.lua
--	Generic utility functions not belonging anywhere else
--

local Log = require "lua/log"

local Util = {}

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

function Util.listMethods(obj)
	Log:write("Listing methods...")
	while obj do
		for k,v in pairs(obj) do
			--if type(v) == "function" then
				Log:write("  " .. tostring(k) .. " = " .. tostring(v))
			--end
		end
		local meta = getmetatable(obj)
		obj = nil
		if meta then
			Log:write("  has metatable:")
			for k,v in pairs(meta) do
				--if type(v) == "function" then
					Log:write("  " .. tostring(k) .. " = " .. tostring(v))
				--end
			end

			obj = meta.__index
			if obj then
				Log:write("  ...with __index:")
			end
		end
	end
end

return Util
