
--
--	main.lua
--	Entry point of application
--

local Game = require "lua/game"

--	a new Game object is instantiated
local G = Game.new()
G:start()

--	the Game object will now take control of all user interactions
G:loop()

--	terminate the game
G:terminate()

