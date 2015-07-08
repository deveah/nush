
--
--	global.lua
--	Global definitions (mainly constants)
--

local Global = {}

--	true if debugging is enabled; debugging turns on logging various data
--	into the file designated by the `Global.logFilename` variable
Global.debug = true

--	the default name of the player character
Global.defaultName = "Player"

--	Name of the file used for logging
Global.logFilename = "log.txt"

--  Size of the screen. This could be initialised from curses.init(),
--  but that seems like a bad idea
Global.screenWidth =  80
Global.screenHeight = 24

--	Map object terrain array dimensions
Global.mapWidth =		80
Global.mapHeight =	20

--	Depth of the dungeon (how many maps it contains)
Global.dungeonDepth = 10

return Global

