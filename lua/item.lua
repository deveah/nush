
--
--	item.lua
--	Item object definition and methods
--

local Global = require "lua/global"
local Game = require "lua/game"

local Item = {}
Item.__index = Item

--	Item.new() - creates a new Item object, initializing its members with
--	default data; returns the created Item object
function Item.new()
	local i = {}
	setmetatable(i, Item)

	i.name = ""
	i.face = ""
	i.color = ""
	i.map = nil
	i.x = 0
	i.y = 0

	return i
end

--	Item:toString() - returns a string describing the Item object
function Item:toString()
	return "<actor " .. tostring(self) .. " (" .. self.name .. ")>"
end

--	Item:setName() - sets the name of the given Item object; does not return
--	anything
function Item:setName(name)
	Game.log:write("Item " .. self:toString() .. " was renamed to " ..
		name .. ".")
	
	self.name = name
end

--	Item:setFace() - sets the face of the given Item object; does not return
--	anything
function Item:setFace(face)
	Game.log:write("Item " .. self:toString() .. " has changed its face to " ..
		face .. ".")
	
	self.face = face
end

--	Item:setColor() - sets the color of the given Item object; does not return
--	anything
function Item:setColor(color)
	Game.log:write("Item " .. self:toString() .. " has changed its color to " ..
		color .. ".")
	
	self.color = color
end

--	Item:setMap() - sets the map of the given Item object; does not return
--	anything
function Item:setMap(map)
	Game.log:write("Item " .. self:toString() .. " has been placed on " ..
		map:toString() .. ".")
	
	self.map = map
end

--	Item:setPosition() - sets the (x, y) position of the given Item object;
--	does not return anything
function Item:setPosition(x, y)
	Game.log:write("Item " .. self:toString() ..
		" has been placed at (" .. x .. ", " .. y .. ").")
	
	self.x = x
	self.y = y
end

return Item

