
--
--	actordefs.lua
--	Definitions of individual actor types (inheriting from the base Actor
--	in actor.lua)
--

local Log = require "lua/log"
local Actor = require "lua/actor"

--	Collection of all enemy type definitions
local Actordefs = {}

--	defineActor() - Given the base actor type to inherit from, and a table with
--	overridden data members, returns an actor definition
local function defineActor(inheritFrom, definition)
	setmetatable(definition, {__index = inheritFrom})
	return definition
end

--	The base actor definition all others inherit from (put default values here
--	rather than in Actor:new())
Actordefs.BaseActor = defineActor(Actor, {
	category = "Misc",
	name = "",
	face = "",
	color = curses.white,
})

----------------------------------- Humanoids ---------------------------------

Actordefs.Humanoid = defineActor(Actordefs.BaseActor, {
	category = "Humanoids",
	face = "@",
})

Actordefs.Player = defineActor(Actordefs.Humanoid, {
	name = "",	--	automatically overwritten when the game starts
	color = curses.white,
	hp = 10,
	maxHp = 10,
	experience = 0,
	skills = {
		melee = 0,
		handguns = 0,
	},
})

Actordefs.Savage = defineActor(Actordefs.Humanoid, {
	name = "Savage",
	color = curses.red,
	hp = 3,
	maxHp = 3,
})

Actordefs.SavageChief = defineActor(Actordefs.Humanoid, {
	name = "Savage Chief",
	color = curses.RED,
	hp = 5,
	maxHp = 5,
})

return Actordefs
