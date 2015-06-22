
--
--	log.lua
--	Logging interface
--

local Global = require "lua/global"

local Log = {}
Log.__index = Log

--	Log.new() - creates a new Log object, initializing its members with default
--	data; does not return anything
function Log.new(filename)
	local l = {}
	setmetatable(l, Log)

	--	logging only works when debugging is activated
	if Global.debug then
		l.file = io.open(filename, "w")
	end

	return l
end

--	Log:write() - writes to the attached log file; does not return anything
function Log:write(data)
	--	logging only works when debugging is activated
	if not Global.debug then
		return nil
	end

	self.file:write(os.date() .. ": " .. data .. "\n")
end

--	Log:terminate() - terminates the resources allocated by the creation of
--	the Log object; does not return anything
function Log:terminate()
	--	logging only works when debugging is activated
	if not Global.debug then
		return nil
	end

	self.file:close()
end

return Log

