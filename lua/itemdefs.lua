
--
--	itemdefs.lua
--	Definitions of individual item types (inheriting from the base Item in
--	item.lua)
--


--	Collection of all item and item type definitions
local Itemdefs = {}

--	This allows recursively requiring actor.lua
package.loaded['lua/itemdefs'] = Itemdefs

local Log = require "lua/log"
local Item = require "lua/item"
local Actor = require "lua/actor"

--	defineItem() - Given the base item type to inherit from, and a table with
--	overridden data members, returns an item definition
local function defineItem(inheritFrom, definition)
	--	Check for mistakes
	if inheritFrom.new ~= Item.new then
		error("Parent object does not inherit from Item")
	end
	setmetatable(definition, {__index = inheritFrom})
	return definition
end

--	The base item definition all others inherit from (put default values here
--	rather than in Item:new())
Itemdefs.BaseItem = defineItem(Item, {
	category = "Misc",
	name = "",
	face = "",
	color = curses.white,
	stackable = false,
})


--------------------------------- Weapons -------------------------------------

--	Weapons have the following additional members:
--	* minDamage  (int) - min and max damage before modifiers, armour, etc.
--	* maxDamage  (int) - ditto
--	* range      (int) - 0 if melee, otherwise range in tiles

Itemdefs.Weapon = defineItem(Itemdefs.BaseItem, {
	category = "Weapons",
	face = ")",
	examine = function(self)
		local ret
		if self.range == 0 then
			ret = "Melee"
		else
			ret = "Range: " .. self.range
		end
		return ret .. "   Damage: " .. self.minDamage .. "-" .. self.maxDamage
	end
})

Itemdefs.MeleeWeapon = defineItem(Itemdefs.Weapon, {
	color = curses.red,
	--equipSlot = Actor.EquipSlots.meleeWeapon,
	equipSlot = "meleeWeapon",
	range = 0,
})

Itemdefs.RangedWeapon = defineItem(Itemdefs.Weapon, {
	color = curses.green,
	--equipSlot = Actor.EquipSlots.rangedWeapon,
	equipSlot = "rangedWeapon",
})

--	Default melee weapon for the player if none equipped
Itemdefs.Fists = defineItem(Itemdefs.MeleeWeapon, {
	name = "Fists",
	minDamage = 0,
	maxDamage = 1,
	accuracy = 0.95,
})

--	These are pretty much placeholders.

Itemdefs.ShockBaton = defineItem(Itemdefs.MeleeWeapon, {
	name = "Shock baton",
	info = "A damaging electrified club without the hassle of lugging heavy equipment.",
	minDamage = 1,
	maxDamage = 3,
	accuracy = 0.95,
})

Itemdefs.DilithiumRazor = defineItem(Itemdefs.MeleeWeapon, {
	name = "Dilithium razor",
	info = "As sharp as it is light.",
	minDamage = 2,
	maxDamage = 5,
	accuracy = 0.9,
})

Itemdefs.Pistol = defineItem(Itemdefs.RangedWeapon, {
	name = "Pistol",
	info = "Ancient and unreliable projectile weapon still effective at putting holes into things.",
	range = 10,
	minDamage = 1,
	maxDamage = 5,
	accuracy = 0.6,
})

Itemdefs.Phaser = defineItem(Itemdefs.RangedWeapon, {
	name = "Phaser pistol",
	info = "Fires a concentrated blast of something or other.",
	range = 6,
	minDamage = 2,
	maxDamage = 8,
	accuracy = 0.7,
})


--------------------------------- Keycards ------------------------------------

Itemdefs.Keycard = defineItem(Itemdefs.BaseItem, {
	category = "Keycards",
	face = "$",
	info = "Opens a door of the corresponding color.",
})

Itemdefs.RedKeycard = defineItem(Itemdefs.Keycard, {
	name = "Red keycard",
	color = curses.red,
})

Itemdefs.GreenKeycard = defineItem(Itemdefs.Keycard, {
	name = "Green keycard",
	color = curses.green,
})

Itemdefs.BlueKeycard = defineItem(Itemdefs.Keycard, {
	name = "Blue keycard",
	color = curses.blue,
})

Itemdefs.SilverKeycard = defineItem(Itemdefs.Keycard, {
	name = "White keycard",
	color = curses.WHITE,
})

Itemdefs.GoldKeycard = defineItem(Itemdefs.Keycard, {
	name = "Gold keycard",
	color = curses.YELLOW,
})


-------------------------------- Consumables ----------------------------------

Itemdefs.Consumable = defineItem(Itemdefs.BaseItem, {
	category = "Consumables",
	face = "&",
	consumable = true,
})

Itemdefs.SugarBombs = defineItem(Itemdefs.Consumable, {
	name = "Sugar Bombs",
	info = "Excessively sugary breakfast cereal.",
	color = curses.CYAN,
})


----------------------------------- Corpses -----------------------------------

Itemdefs.Corpse = defineItem(Itemdefs.BaseItem, {
	category = "Corpses",
	face = "%",
})

Itemdefs["Savage corpse"] = defineItem(Itemdefs.Corpse, {
	name = "Savage corpse",
	info = "The remaining carcass of a once living Savage.",
	color = curses.red,
})

Itemdefs["Savage Chief corpse"] = defineItem(Itemdefs.Corpse, {
	name = "Savage Chief corpse",
	info = "The remaining carcass of a once living Savage Chief.",
	color = curses.red,
})

-------------------------------------- Ammo -----------------------------------

Itemdefs.Ammo = defineItem(Itemdefs.BaseItem, {
	category = "Ammo",
	face = "=",
	stackable = true,
	count = 1,
})

Itemdefs.Bullet = defineItem(Itemdefs.Ammo, {
	name = "Bullet",
	color = curses.yellow,
})

Itemdefs.EnergyCell = defineItem(Itemdefs.Ammo, {
	name = "Energy Cell",
	color = curses.cyan,
})

return Itemdefs
