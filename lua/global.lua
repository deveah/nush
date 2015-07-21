
--
--	global.lua
--	Global definitions (mainly constants)
--

local Global = {}

--	true if debugging is enabled; debugging turns on logging various data
--	into the file designated by the `Global.logFilename` variable
Global.debug = true

--	Turns on the display of more info, like attack damage
Global.debugInfo = true

--	Whether to display animations, otherwise uses alternative visualisations
Global.animations = true

--	Length of each animation frame in seconds. For consistency with Windows
--	should be close to multiple of 10ms. Some terms may only draw at 30 fps,
--	so less than 0.03 causes lost frames
Global.animationFrameLength = 0.02

--	The default color (curses attr) for text.
--	Note that 'normal' and 'white' are the same under Windows
Global.defaultColor = "white"

--	the default name of the player character
Global.defaultName = "Player"

--	Name of the file used for logging (Note: also defined in nush.c)
Global.logFilename = "log.txt"

--	The help file shown with '?'
Global.helpFilename = "helpfile.txt"

--  Size of the screen. This could be initialised from curses.init(),
--  but that seems like a bad idea
Global.screenWidth =  80
Global.screenHeight = 25

--	Map object terrain array dimensions
Global.mapWidth =		80
Global.mapHeight =	20

--	Depth of the dungeon (how many maps it contains)
Global.dungeonDepth = 10

return Global
