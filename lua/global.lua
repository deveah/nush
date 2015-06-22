
--
--	global.lua
--	Global definitions (mainly constants)
--

local Global = {}

--	true if debugging is enabled; debugging turns on logging various data
--	into the file designated by the `Global.logFilename` variable
Global.debug = true

--	Name of the file used for logging
Global.logFilename = "log.txt"

--	Map object terrain array dimensions
Global.mapWidth =		80
Global.mapHeight =	20

--	Depth of the dungeon (how many maps it contains)
Global.dungeonDepth = 10

return Global

