
--
--	particle.lua
--	Particle object definition and methods
--
--	An particle is an object that's drawn on the map but not a full Actor
--	(this is a subset of Actor). It has the following members:
--	* face (string) - a character describing how it looks in-game
--	*	color (curses constant) - the color of 
--	* x, y (integers) - the position on the map

local Log = require "lua/log"
local Game = require "lua/game"

local Particle = {}
Particle.__index = Particle


--	Particle.new() - creates a new object, initializing its members with
--	default data; returns the created object
function Particle.new()
	local a = {}
	setmetatable(a, Particle)

	--	initialize members
	a.face = ""
	a.color = ""
	a.map = nil
	a.x = 0	--	although 0,0 is not a valid coordinate for the particle,
	a.y = 0	--	the value signifies that an actual position has not been set
	return a
end

--	Particle:toString() - returns a string describing the Particle object
function Particle:toString()
	return "<particle " .. tostring(self) .. " " .. self.face .. ">"
end

--	Particle:setFace() - sets the face of the given Particle object; does not
--	return anything
function Particle:setFace(face)
	Log:write(self:toString() .. " changed face to '" .. face .. "'.")
	self.face = face
end

--	Particle:setColor() - sets the color of the given Particle object; does not
--	return anything
function Particle:setColor(color)
	Log:write(self:toString() .. " changed color to '" .. color .. "'.")
	self.color = color
end

--	Particle:setMap() - sets the map of the given Particle object; does not
--	return anything
function Particle:setMap(map)
	Log:write(self:toString() .. " has been placed on " .. map:toString())
	self.map = map
end

--	Particle:setPosition() - sets the (x, y) position of the given Particle;
--	does not return anything
function Particle:setPosition(x, y)
	Log:write(self:toString() .. " placed at (" .. x .. ", " .. y .. ").")
	self.x = x
	self.y = y
end

--	Particle:draw() - draw this particle on the map if it should be visible from
--	the player character's point of view; returns nothing.
function Particle:draw(xOffset, yOffset)
	if Game.player.sightMap[self.x][self.y] then
		curses.attr(self.color)
		curses.write(self.x + xOffset, self.y + yOffset, self.face)
	end
end


return Particle
