
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
--	*	locked (string, optional) - if it exists, it denotes the name of the keycard
--		which is used to unlock the door
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

Tile.upStairs = {
	["name"] = "Stairs up",
	["face"] = "<",
	["color"] = curses.white,
	["solid"] = false,
	["opaque"] = false,
	["role"] = "stairs",
	--"destination-map" added to copy
}

Tile.downStairs = {
	["name"] = "Stairs down",
	["face"] = ">",
	["color"] = curses.white,
	["solid"] = false,
	["opaque"] = false,
	["role"] = "stairs",
	--"destination-map" added to copy
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

		if actor.activeEffects["{{RED}}Burning"] then
			actor.activeEffects["{{RED}}Burning"] = nil
			if actor == Game.player then
				UI:message("{{GREEN}}The water extinguishes your fire.")
			end
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
	["opaque"] = false,
	["role"] = "door"
}

Tile.closedDoor = {
	["name"] = "Closed door",
	["face"] = "+",
	["color"] = curses.white,
	["solid"] = 10,
	["opaque"] = true,
	["role"] = "door"
}

Tile.hiddenDoor = {
	["name"] = "Wall",
	["face"] = "#",
	["color"] = curses.yellow,
	["solid"] = true,
	["opaque"] = true,
	["role"] = "door"
}

Tile.lockedDoor = {
	["name"] = "Locked door",
	["face"] = "+",
	["color"] = curses.red + curses.bold,
	["solid"] = true,
	["opaque"] = true,
	["role"] = "door"
	--"locked" added to copy
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

Tile.alarmTrap = {
	["name"] = "Alarm trap",
	["face"] = "^",
	["color"] = curses.WHITE,
	["solid"] = false,
	["opaque"] = false,
	["on-walk"] = function(actor)
		--	only the player can trigger traps
		if actor ~= Game.player then
			return
		end
		--	alert all enemies (which are on the same map as the player) of the player's location
		for _, enemy in pairs(Game.actorList) do
			if enemy ~= Game.player and enemy.map == Game.player.map then
				enemy.aiState = "chase"
			end
		end
		UI:message("{{RED}}You hear a loud alarming sound! You have triggered a trap!")
	end
}

Tile.fire = {
	["name"] = "Fire",
	["face"] = "#",
	["color"] = curses.RED,
	["solid"] = false,
	["opaque"] = false,
	["on-walk"] = function(actor)
		if actor == Game.player then
			UI:message("{{RED}}AAARGH! It burns!")
		end
		actor:addEffect("{{RED}}Burning", function(a)
			a:takeDamage(nil, 1, "burned to death")
			if a == Game.player then
				UI:message("{{RED}}You take damage from burning.")
			end
		end, 5)
	end
}

return Tile

