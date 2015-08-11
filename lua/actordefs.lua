
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
	aiState = "wait",
	agility = 10,
	sightRange = 5,
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
	spendableExperience = 0,
	totalExperience = 0,
	skills = {
		melee = 2,
		handguns = 5,
		shotguns = 0,
		lockpick = 0,
		stealth = 0,
	},
	aiState = nil,
	agility = 10,
})

Actordefs.Savage = defineActor(Actordefs.Humanoid, {
	face = "s",
	name = "Savage",
	color = curses.red,
	hp = 3,
	maxHp = 3,
})

Actordefs.SavageChief = defineActor(Actordefs.Humanoid, {
	face = "s",
	name = "Savage Chief",
	color = curses.RED,
	hp = 5,
	maxHp = 5,
})

Actordefs.SavageShaman = defineActor(Actordefs.Humanoid, {
	face = "s",
	name = "Savage Shaman",
	color = curses.green,
	hp = 5,
	maxHp = 5,
	agility = 6
})

return Actordefs
