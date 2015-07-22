
--
--	item.lua
--	Item object definition and methods
--
--	Item types have the following members:
--	* equipSlot  (Actor.EquipSlots.*) - equipment slot, nil if not equippable
--	* stackable (bool)
--	TODO: list the other non-itemtype specific members here
--
--	Item instances additionally have the following members:
--	* map        (Map) - nil if the item has been picked up or not on a map
--	* x/y       (ints) - meaningless if not on a map
--	* owner    (Actor) - The actor who has this item, nil otherwise
--	* equipped  (bool) - whether equipped (in equipSlot)
--	* count      (int) - size of the stack, if stackable
--	TODO: list the other members here

local Global = require "lua/global"
local Game = require "lua/game"
local Log = require "lua/log"
local Util = require "lua/util"

local Item = {}

--	Item:new() - creates a new Item object, initializing its members with
--	default data; returns the created Item object
function Item:new(count)
	local i = {}
	setmetatable(i, {__index = self})

	i.map = nil
	i.owner = nil
	i.x = 0
	i.y = 0
	i.equipped = false
	i.count = count

	Game:addItem(i)

	return i
end

--	Item:destroy() - remove an item from anything that holds a reference to it
--	so that it effectively ceases to exist and is garbage collected. Must not
--	be called twice. Returns nothing.
function Item:destroy()
	if self.owner then
		self.owner:removeItem(self)
	end
	if self.map then
		self:setMap(nil)
	end

	--	Forget
	Game:removeItem(self)
end

--	Item:toString() - returns a string describing the Item object
function Item:toString()
	local location
	if self.map then
		location = "on " .. self.map:toString() .. " at " .. self.x .. "," .. self.y
	elseif self.owner then
		location = "owned by " .. self.owner:toString() .. ", inv slot " .. self.owner:findItem(self)
	else
		location = "in limbo"
	end
	local equippedAs = ""
	if self.equipped then
		assert(self.owner)
		local eqslot = Util.tableFind(self.owner.equipment, self)
		equippedAs = " equipped in slot " .. eqslot
	end
	return "<item " .. tostring(self) .. " (" .. self:describe(true) .. ") " .. location .. equippedAs .. ">"
end

--	Item:describe() - returns the player-visible name/description of the item.
--	If optional arg 'fullyVisible' is true, then treat as full identified
function Item:describe(fullyVisible)
	if not self.count or self.count == 1 then
		return "a " .. self.name
	else
		return self.name .. " (x" .. self.count .. ")"
	end
end

--	Item:setName() - sets the name of the given Item object; does not return
--	anything
function Item:setName(name)
	Log:write("Item " .. self:toString() .. " was renamed to " ..
		name .. ".")
	
	self.name = name
end

--	Item:setFace() - sets the face of the given Item object; does not return
--	anything
function Item:setFace(face)
	Log:write("Item " .. self:toString() .. " has changed its face to " ..
		face .. ".")
	
	self.face = face
end

--	Item:setColor() - sets the color of the given Item object; does not return
--	anything
function Item:setColor(color)
	Log:write("Item " .. self:toString() .. " has changed its color to " ..
		color .. ".")
	
	self.color = color
end

--	Item:setMap() - sets the map on which this item is laying, possibly to nil;
--	does not return anything
function Item:setMap(map)
	if map then
		Log:write("Item " .. self:toString() .. " has been placed on " ..
			map:toString() .. ".")
		self.owner = nil
	else
		Log:write("Item " .. self:toString() .. " no longer on any map")
	end
	
	self.map = map
end

--	Item:setOwner() - sets the actor holding this item, possibly to nil;
--	does not return anything
function Item:setOwner(owner)
	if owner then
		Log:write("Item " .. self:toString() .. " is now owned by " .. owner:toString())
		self.map = nil
	else
		Log:write("Item " .. self:toString() .. " no longer owned.")
	end
	
	self.owner = owner
end

--	Item:setPosition() - sets the (x, y) position of the given Item object;
--	does not return anything
function Item:setPosition(x, y)
	Log:write("Item " .. self:toString() ..
		" has been placed at (" .. x .. ", " .. y .. ").")
	
	self.x = x
	self.y = y
end

--	Item:combineStack() - combine another stack of items into this one; the
--	other stack is destroyed. Returns nothing.
function Item:combineStack(otherStack)
	self.count = self.count + otherStack.count
	otherStack:destroy()
end


return Item

