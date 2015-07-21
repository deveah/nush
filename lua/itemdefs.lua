
--
--	itemdefs.lua
--	Definitions of individual item types (inheriting from the base Item in
--	item.lua)
--

local Log = require "lua/log"
local Item = require "lua/item"

--	Collection of all item and item type definitions
local Itemdefs = {}

--	defineItem() - Given the base item type to inherit from, and a table with
--	overridden data members, returns an item definition
local function defineItem(inheritFrom, definition)
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


Itemdefs.Weapon = defineItem(Itemdefs.BaseItem, {
	category = "Weapons",
	equipAs = "weapon",
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

return Itemdefs
