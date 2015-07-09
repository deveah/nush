
--
--	main.lua
--	Entry point of application
--

local Game = require "lua/game"
local Log = require "lua/log"

--	main() - Errors are caught from within here
local function main()
	--	the Game object is instantiated
	Game:init()
	Game:start()

	--	the Game object will now take control of all user interactions
	Game:loop()

	--	terminate the game
	Game:terminate()
end

local function errorHandler(errmsg)
	return debug.traceback(errmsg)
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
