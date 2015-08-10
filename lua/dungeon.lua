
--	dungeon.lua
--	Dungeon layout
--

local Actordefs = require "lua/actordefs"
local Itemdefs = require "lua/itemdefs"

local Dungeon = {}

Dungeon.layout = {
	{	-- level 1
		generator = "cave",
		nEnemies = 5,
		enemies = {
			["Savage"] = 0.8,
			["SavageChief"] = 0.2
		},
		nLoot = 50,
		loot = {
			["ShockBaton"] = 0.05,
			["DilithiumRazor"] = 0.05,
			["RustyKnife"] = 0.05,
			["BrassKnuckles"] = 0.05,
			["Bullet"] = 0.1,
			["EnergyCell"] = 0.2,
			["SugarBombs"] = 0.2,
			["SingleShotgun"] = 0.05,
			["SawedOffShotgun"] = 0.05,
			["Slug"] = 0.2
		}
	},
	{	-- level 2
		generator = "cave",
		nEnemies = 7,
		enemies = {
			["Savage"] = 0.7,
			["SavageChief"] = 0.2,
			["SavageShaman"] = 0.1
		},
		nLoot = 10,
		loot = {
			["ShockBaton"] = 0.1,
			["DilithiumRazor"] = 0.1,
			["Bullet"] = 0.1,
			["EnergyCell"] = 0.2,
			["SugarBombs"] = 0.5
		}
	},
	{	-- level 3
		generator = "rooms",
		nEnemies = 10,
		enemies = {
			["Savage"] = 0.6,
			["SavageChief"] = 0.2,
			["SavageShaman"] = 0.6
		},
		nLoot = 10,
		loot = {
			["ShockBaton"] = 0.1,
			["DilithiumRazor"] = 0.1,
			["Bullet"] = 0.1,
			["EnergyCell"] = 0.2,
			["SugarBombs"] = 0.3,
			["RedKeycard"] = 0.04,
			["GreenKeycard"] = 0.04,
			["BlueKeycard"] = 0.04,
			["SilverKeycard"] = 0.04,
			["GoldKeycard"] = 0.04
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
			["ShockBaton"] = 0.05,
			["DilithiumRazor"] = 0.1,
			["Bullet"] = 0.15,
			["EnergyCell"] = 0.2,
			["SugarBombs"] = 0.3,
			["RedKeycard"] = 0.04,
			["GreenKeycard"] = 0.04,
			["BlueKeycard"] = 0.04,
			["SilverKeycard"] = 0.04,
			["GoldKeycard"] = 0.04
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
			["ShockBaton"] = 0.05,
			["DilithiumRazor"] = 0.1,
			["Bullet"] = 0.15,
			["EnergyCell"] = 0.2,
			["SugarBombs"] = 0.3,
			["RedKeycard"] = 0.04,
			["GreenKeycard"] = 0.04,
			["BlueKeycard"] = 0.04,
			["SilverKeycard"] = 0.04,
			["GoldKeycard"] = 0.04
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
			["ShockBaton"] = 0.05,
			["DilithiumRazor"] = 0.1,
			["Bullet"] = 0.15,
			["EnergyCell"] = 0.2,
			["SugarBombs"] = 0.3,
			["RedKeycard"] = 0.04,
			["GreenKeycard"] = 0.04,
			["BlueKeycard"] = 0.04,
			["SilverKeycard"] = 0.04,
			["GoldKeycard"] = 0.04
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
			["ShockBaton"] = 0.05,
			["DilithiumRazor"] = 0.1,
			["Bullet"] = 0.15,
			["EnergyCell"] = 0.2,
			["SugarBombs"] = 0.3,
			["RedKeycard"] = 0.04,
			["GreenKeycard"] = 0.04,
			["BlueKeycard"] = 0.04,
			["SilverKeycard"] = 0.04,
			["GoldKeycard"] = 0.04
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
			["ShockBaton"] = 0.05,
			["DilithiumRazor"] = 0.1,
			["Bullet"] = 0.15,
			["EnergyCell"] = 0.2,
			["SugarBombs"] = 0.3,
			["RedKeycard"] = 0.04,
			["GreenKeycard"] = 0.04,
			["BlueKeycard"] = 0.04,
			["SilverKeycard"] = 0.04,
			["GoldKeycard"] = 0.04
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
			["ShockBaton"] = 0.05,
			["DilithiumRazor"] = 0.1,
			["Bullet"] = 0.15,
			["EnergyCell"] = 0.2,
			["SugarBombs"] = 0.3,
			["RedKeycard"] = 0.04,
			["GreenKeycard"] = 0.04,
			["BlueKeycard"] = 0.04,
			["SilverKeycard"] = 0.04,
			["GoldKeycard"] = 0.04
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
			["ShockBaton"] = 0.05,
			["DilithiumRazor"] = 0.1,
			["Bullet"] = 0.15,
			["EnergyCell"] = 0.2,
			["SugarBombs"] = 0.3,
			["RedKeycard"] = 0.04,
			["GreenKeycard"] = 0.04,
			["BlueKeycard"] = 0.04,
			["SilverKeycard"] = 0.04,
			["GoldKeycard"] = 0.04
		}
	}
}

return Dungeon

