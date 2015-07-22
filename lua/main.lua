
--
--	main.lua
--	Entry point of application
--

--	For compatibility with lua 5.1
if not table.unpack then
	table.unpack = unpack
end

local Log
local Game

--	main() - Errors are caught from within here
local function main()
	Game = require "lua/game"
	Log = require "lua/log"

	--	the Game object is instantiated
	Game:init()
	Game:start()

	--	the Game object will now take control of all user interactions
	Game:loop()

	--	terminate the game
	Game:terminate()
end

local function errorHandler(errmsg)
	return debug.traceback(errmsg, 2)
end

local success, errmsg = xpcall(main, errorHandler)
if not success then
	--	Need to terminate curses, otherwise the C code will, which will wipe
	--	the stacktrace from the screen
	if curses.running then
		curses.terminate()
	end
	print(errmsg)
	if Log then
		Log:write(errmsg)
	end
end
