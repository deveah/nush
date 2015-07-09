
--
--	itemdefs.lua
--	Definitions of individual item types (inheriting from the base Item in
--	item.lua)
--

local Log = require "lua/log"
local Item = require "lua/item"

--	Collection of all item and item type definitions
local Itemdefs = {}

--	defineItem() - Given the base item type to inherit from, and table with
--	overridden data members, returns an item definition
local function defineItem(inheritFrom, definition)
	setmetatable(definition, {__index = inheritFrom})
	Log:write("meta " .. tostring(getmetatable(definition)))
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
Itemdefs.BaseItem.__index = Itemdefs.BaseItem


Itemdefs.Weapon = defineItem(Itemdefs.BaseItem, {
	category = "Weapons",
	equipAs = "weapon",
})

-------------------------------- Consumables ----------------------------------

Itemdefs.Consumable = defineItem(Itemdefs.BaseItem, {
	category = "Consumables",
	face = "&",
	consumable = true,
})
Itemdefs.Consumable.__index = Itemdefs.Consumable

Itemdefs.SugarBombs = defineItem(Itemdefs.Consumable, {
	name = "Sugar Bombs",
	color = curses.cyan + curses.bold,
})
Itemdefs.SugarBombs.__index = Itemdefs.SugarBombs

return Itemdefs
