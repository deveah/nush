
--
--	main.lua
--	Entry point of application
--

local Game = require "lua/game"

--	the Game object is instantiated
Game:init()
Game:start()

--	the Game object will now take control of all user interactions
Game:loop()

--	terminate the game
Game:terminate()

