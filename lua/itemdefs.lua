
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
	color = curses.white + curses.bold,
})

Itemdefs.GoldKeycard = defineItem(Itemdefs.Keycard, {
	name = "Gold keycard",
	color = curses.yellow + curses.bold
})

-------------------------------- Consumables ----------------------------------

Itemdefs.Consumable = defineItem(Itemdefs.BaseItem, {
	category = "Consumables",
	face = "&",
	consumable = true,
})

Itemdefs.SugarBombs = defineItem(Itemdefs.Consumable, {
	name = "Sugar Bombs",
	color = curses.cyan + curses.bold,
})

return Itemdefs
