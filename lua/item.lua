
--
--	item.lua
--	Item object definition and methods
--

local Global = require "lua/global"
local Game = require "lua/game"
local Log = require "lua/log"

local Item = {}

--	Item:new() - creates a new Item object, initializing its members with
--	default data; returns the created Item object
function Item:new()
	local i = {}
	setmetatable(i, {__index = self})

	i.map = nil     --  map is nil if the item has been picked up or not on a map
	i.x = 0         --  x/y meaningless if not a the map
	i.y = 0

	return i
end

--	Item:toString() - returns a string describing the Item object
function Item:toString()
	local location
	if self.map then
		location = "on " .. self.map:toString() .. " at " .. self.x .. "," .. self.y
	else
		location = "not on a map"
	end
	return "<item " .. tostring(self) .. " (" .. self:describe(true) .. ") " .. location .. ">"
end

--	Item:describe() - returns the player-visible name/description of the item.
--	If optional arg 'fullyVisible' is true, then treat as full identified
function Item:describe(fullyVisible)
	return self.name
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

--	Item:setMap() - sets the map of the given Item object, possibly to nil;
--	does not return anything
function Item:setMap(map)
	if map then
		Log:write("Item " .. self:toString() .. " has been placed on " ..
			map:toString() .. ".")
	else
		Log:write("Item " .. self:toString() .. " no longer on any map")
	end
	
	self.map = map
end

--	Item:setPosition() - sets the (x, y) position of the given Item object;
--	does not return anything
function Item:setPosition(x, y)
	Log:write("Item " .. self:toString() ..
		" has been placed at (" .. x .. ", " .. y .. ").")
	
	self.x = x
	self.y = y
end

return Item

