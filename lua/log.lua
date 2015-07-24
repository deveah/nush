
--
--	log.lua
--	Logging interface
--

local Global = require "lua/global"

local Log = {}
Log.__index = Log

--	Log.new() - creates a new Log object, initializing its members with default
--	data; returns the Log object
--	dontDelete is an optional arg that should only be used for Global.logFilename
function Log.new(filename, dontDelete)
	local l = {}
	setmetatable(l, Log)

	--	logging only works when debugging is activated
	if Global.debug then
		--	Use append mode because log_printf in C appends to the same file
		--	Lua docs seem to say that "a" erases the file, but doesn't work for me.
		if not dontDelete then
			os.remove(filename)
		end
		l.file = io.open(filename, "a+")
	end

	return l
end

--	Log:write() - converts all arguments to strings, concatenates them, and
--	writes them to the attached log file; does not return anything.
function Log:write(...)
	--	logging only works when debugging is activated
	if not self.file then
		return nil
	end
	local text = ""
	for i = 1, select('#', ...) do
		text = text .. tostring(select(i, ...))
	end

	self.file:write(os.date() .. ": " .. text .. "\n")
	self.file:flush()
end

--	Log:terminate() - terminates the resources allocated by the creation of
--	the Log object; does not return anything
function Log:terminate()
	if not self.file then
		return nil
	end

	self.file:close()
	self.file = nil
end

--	initialize logging
Log = Log.new(Global.logFilename, true)
Log:write("Started logging.")

--	Can call .new() on this Log instance to create further Logs
return Log

