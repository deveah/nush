
--
--	tile.lua
--	Tile object definition and prototypes
--
--	A Tile object contains the following members:
--	*	name (string) - a name describing the type of terrain
--	*	face (string) - a character describing how the tile looks in-game
--	*	color (curses constant) - describes the color of tile in-game
--	*	solid (boolean) - whether or not the tile prevents actors from moving
--			onto it
--	* opaque (boolean) - whether or not the tile prevents actors from seeing
--			through it
--	*	on-walk (function, optional) - an event which is triggered when an actor
--			steps on the tile; the function takes a single argument, the actor object
--	* role (string, optional) - used to categorise different classes of tiles
--

local Game = require "lua/game"
local UI = require "lua/ui"

local Tile = {}

Tile.void = {
	["name"] = "Void",
	["face"] = " ",
	["color"] = curses.black,
	["solid"] = true,
	["opaque"] = false
}

Tile.floor = {
	["name"] = "Floor",
	["face"] = ".",
	["color"] = curses.white,
	["solid"] = false,
	["opaque"] = false
}

Tile.roomFloor = {
	["name"] = "Floor",
	["face"] = ".",
	["color"] = curses.white,
	["solid"] = false,
	["opaque"] = false
}

Tile.wall = {
	["name"] = "Wall",
	["face"] = "#",
	["color"] = curses.yellow,
	["solid"] = true,
	["opaque"] = true
}

Tile.grass = {
	["name"] = "Grass",
	["face"] = ",",
	["color"] = curses.green,
	["solid"] = false,
	["opaque"] = false,
	["on-walk"] = function(actor)
		if actor == Game.player then
			UI:message("{{cyan}}Your feet are tingled by the grass.")
		end
	end
}

Tile.waterVine = {
	["name"] = "Water vine",
	["face"] = "7",
	["color"] = curses.green,
	["solid"] = false,
	["opaque"] = true,
	["on-walk"] = function(actor)
		if actor == Game.player then
			UI:message("{{cyan}}Your feet are mushing through the water vine.")
		end
	end
}

Tile.mushroom = {
	["name"] = "Mushroom",
	["face"] = ":",
	["color"] = curses.white,
	["solid"] = false,
	["opaque"] = false
}

Tile.dirt = {
	["name"] = "Dirt",
	["face"] = ".",
	["color"] = curses.yellow,
	["solid"] = false,
	["opaque"] = false
}

Tile.spaceBerry = {
	["name"] = "Space berry",
	["face"] = "%",
	["color"] = curses.magenta,
	["solid"] = false,
	["opaque"] = false
}

Tile.shallowWater = {
	["name"] = "Shallow water",
	["face"] = "~",
	["color"] = curses.blue + curses.bold,
	["solid"] = false,
	["opaque"] = false,
	["on-walk"] = function(actor)
		if actor == Game.player then
			UI:message("{{cyan}}Your feet get cold from the water.")
		end
	end
}

Tile.ceilingDrip = {
	["name"] = "Floor",
	["face"] = ".",
	["color"] = curses.white + curses.bold,
	["solid"] = false,
	["opaque"] = false,
	["on-walk"] = function(actor)
		if actor == Game.player then
			UI:message("{{cyan}}Something is dripping from the ceiling.")
		end
	end
}

Tile.openDoor = {
	["name"] = "Open door",
	["face"] = "/",
	["color"] = curses.white,
	["solid"] = false,
	["opaque"] = false
}

Tile.closedDoor = {
	["name"] = "Closed door",
	["face"] = "+",
	["color"] = curses.white,
	["solid"] = true,
	["opaque"] = true
}

Tile.hiddenDoor = {
	["name"] = "Wall",
	["face"] = "#",
	["color"] = curses.yellow,
	["solid"] = true,
	["opaque"] = true
}

Tile.brokenComputer = {
	["name"] = "Broken computer",
	["face"] = "&",
	["color"] = curses.cyan,
	["solid"] = true,
	["opaque"] = false
}

Tile.pileOfElectronics = {
	["name"] = "Pile of electronics",
	["face"] = ";",
	["color"] = curses.cyan,
	["solid"] = false,
	["opaque"] = false
}

Tile.brokenMachinery = {
	["name"] = "Broken machinery",
	["face"] = "#",
	["color"] = curses.cyan,
	["solid"] = true,
	["opaque"] = false
}

return Tile

