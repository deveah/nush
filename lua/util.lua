
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

return Util
