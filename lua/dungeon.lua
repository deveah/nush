
--	dungeon.lua
--	Dungeon layout
--
--	A level layout consists of the following members:
--	* generator (string) - the type of map to be generated
--	*	nEnemies (integer) - number of enemies to spawn
--	* enemies (table) - a pair of (enemy name) => (chance to spawn)
--	*	nLoot (integer) - number of items to spawn
--	*	loot (table) - a pair of either:
--		(item name) => (chance to spawn), or
--		(item name) => { (chance to spawn), (min. count), (max. count) }
--

local Actordefs = require "lua/actordefs"
local Itemdefs = require "lua/itemdefs"

local Dungeon = {}

--	Dungeon.defaultLootWeights() - Returns a table with default item drop rate
--	at a certain dungeon depth, if not overridden in Dungeon.layout.
function Dungeon.defaultLootWeights(depth)
	return {
		["ShockBaton"] = 0.05,
		["DilithiumRazor"] = 0.1,
		["Bullet"] = { 0.15, 1, 10 },
		["EnergyCell"] = { 0.2, 1, 10 },
		["SugarBombs"] = 0.3,
		["RedKeycard"] = 0.04,
		["GreenKeycard"] = 0.04,
		["BlueKeycard"] = 0.04,
		["SilverKeycard"] = 0.04,
		["GoldKeycard"] = 0.04
	}

--[[
	--	Proposal for hierarchical item weighting:
	--	Weights within each category get normalised so they add to the specified
	--	total weight.
	--	E.g. this would make ammo 3 times as common as keycards,
	--	and Bullets 3/4 times as common as Slugs.
	return {
		--	Melee weapons
		{0.1,
			["ShockBaton"] = 1,
			["DilithiumRazor"] = 2,
			["RustyKnife"] = 5,
			["BrassKnuckles"] = 4,
		},
		--	Ranged weapons
		{0.1,
			["Pistol"] = 4,
			["Phaser"] = 1,
			["SingleShotgun"] = 2,
			["SawedOffShotgun"] = 2,
		},
		--	Ammo
		{0.3,
			["Bullet"] = { 3, 1, 10 },
			["EnergyCell"] = { 4, 1, 10 },
			["Slug"] = { 4, 1, 10 },
		},
		--	Keycards
		{0.1,
			["RedKeycard"] = 0.2,
			["GreenKeycard"] = 0.2,
			["BlueKeycard"] = 0.2,
			["SilverKeycard"] = 0.2,
			["GoldKeycard"] = 0.2,
		},
		--	Consumables
		{0.4,
			["SugarBombs"] = 1,
		},
	}
]]
end

Dungeon.layout = {
	{	-- level 1
		generator = "cave",
		nEnemies = 5,
		enemies = {
			["Rat"] = 0.5,
			["Savage"] = 0.4,
			["SavageChief"] = 0.1
		},
		nLoot = 50,
		loot = {
			["ShockBaton"] = 0.05,
			["DilithiumRazor"] = 0.05,
			["RustyKnife"] = 0.05,
			["BrassKnuckles"] = 0.05,
			["Bullet"] = { 0.1, 1, 10 },
			["EnergyCell"] = { 0.2, 1, 10 },
			["SugarBombs"] = 0.2,
			["SingleShotgun"] = 0.05,
			["SawedOffShotgun"] = 0.05,
			["Slug"] = { 0.2, 1, 10 }
		}
	},
	{	-- level 2
		generator = "cave",
		nEnemies = 7,
		enemies = {
			["Rat"] = 0.5,
			["Savage"] = 0.3,
			["SavageChief"] = 0.15,
			["SavageShaman"] = 0.05
		},
		nLoot = 10,
		loot = {
			["ShockBaton"] = 0.1,
			["DilithiumRazor"] = 0.1,
			["Bullet"] = { 0.1, 1, 10 },
			["EnergyCell"] = { 0.2, 1, 10 },
			["SugarBombs"] = 0.5
		}
	},
	{	-- level 3
		generator = "rooms",
		nEnemies = 10,
		enemies = {
			["Rat"] = 0.2,
			["Savage"] = 0.5,
			["SavageChief"] = 0.2,
			["SavageShaman"] = 0.1
		},
		nLoot = 10,
		loot = {
		}
	},
	{	-- level 4
		generator = "rooms",
		nEnemies = 12,
		enemies = {
			["Savage"] = 0.6,
			["SavageChief"] = 0.2,
			["SavageShaman"] = 0.6
		},
		nLoot = 15,
		loot = {
		}
	},
	{	-- level 5
		generator = "rooms",
		nEnemies = 15,
		enemies = {
			["Savage"] = 0.6,
			["SavageChief"] = 0.2,
			["SavageShaman"] = 0.6
		},
		nLoot = 15,
		loot = {
		}
	},
	{	-- level 6
		generator = "rooms",
		nEnemies = 12,
		enemies = {
			["Savage"] = 0.6,
			["SavageChief"] = 0.2,
			["SavageShaman"] = 0.6
		},
		nLoot = 15,
		loot = {
		}
	},
	{	-- level 7
		generator = "rooms",
		nEnemies = 12,
		enemies = {
			["Savage"] = 0.6,
			["SavageChief"] = 0.2,
			["SavageShaman"] = 0.6
		},
		nLoot = 15,
		loot = {
		}
	},
	{	-- level 8
		generator = "bsp",
		nEnemies = 12,
		enemies = {
			["Savage"] = 0.6,
			["SavageChief"] = 0.2,
			["SavageShaman"] = 0.6
		},
		nLoot = 15,
		loot = {
		}
	},
	{	-- level 9
		generator = "bsp",
		nEnemies = 12,
		enemies = {
			["Savage"] = 0.6,
			["SavageChief"] = 0.2,
			["SavageShaman"] = 0.6
		},
		nLoot = 15,
		loot = {
		}
	},
	{	-- level 10
		generator = "bsp",
		nEnemies = 12,
		enemies = {
			["Savage"] = 0.6,
			["SavageChief"] = 0.2,
			["SavageShaman"] = 0.6
		},
		nLoot = 15,
		loot = {
		}
	}
}

return Dungeon

