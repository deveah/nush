
--
--	actor.lua
--	Actor object definition and methods
--
--	An Actor object has the following members:
--	*	name (string) - a name describing the actor type
--	* face (string) - a character describing how the actor looks in-game
--	*	color (curses constant) - the color of the actor in-game
--	*	map (Map object) - the map on which the Actor is currently
--	* x, y (integers) - the position of the Actor on the map
--	*	sightMap (two-dimensional boolean table) - a map showing the tiles
--			currently visible to the actor
--	*	alive (boolean) - true if the actor can act
--

local Global = require "lua/global"
local Game = require "lua/game"
local UI = require "lua/ui"

local Actor = {}
Actor.__index = Actor

--	Actor.new() - creates a new Actor object, initializing its members with
--	default data; returns the created Actor object
function Actor.new()
	local a = {}
	setmetatable(a, Actor)

	--	initialize members
	a.name = ""
	a.face = ""
	a.color = ""
	a.map = nil
	a.x = 0	--	although 0 is not a valid coordinate for the Actor to be on,
	a.y = 0	--	the value signifies that an actual position has not been set
	a.alive = true	--	by default, a newly created Actor is alive

	a.sightMap = {}
	for i = 1, Global.mapWidth do
		a.sightMap[i] = {}
		for j = 1, Global.mapHeight do
			a.sightMap[i][j] = false	--	by default, nothing is visible
		end
	end

	return a
end

--	Actor:toString() - returns a string describing the Actor object
function Actor:toString()
	return "<actor " .. tostring(self) .. " (" .. self.name .. ")>"
end

--	Actor:setName() - sets the name of the given Actor object; does not
--	return anything
function Actor:setName(name)
	Game.log:write("Actor " .. self:toString() ..
		" was renamed to " .. name .. ".")
	
	self.name = name
end

--	Actor:setFace() - sets the face of the given Actor object; does not
--	return anything
function Actor:setFace(face)
	Game.log:write("Actor " .. self:toString() ..
		" has changed its face to '" .. face .. "'.")

	self.face = face
end

--	Actor:setColor() - sets the color of the given Actor object; does not
--	return anything
function Actor:setColor(color)
	Game.log:write("Actor " .. self:toString() ..
		" has changed its color to '" .. color .. "'.")
	
	self.color = color
end

--	Actor:setMap() - sets the map of the given Actor object; does not
--	return anything
function Actor:setMap(map)
	Game.log:write("Actor " .. self:toString() ..
		" has been placed on " .. map:toString() .. ".")

	self.map = map
end

--	Actor:setPosition() - sets the (x, y) position of the given Actor object;
--	does not return anything
function Actor:setPosition(x, y)
	Game.log:write("Actor " .. self:toString() ..
		" has been placed at (" .. x .. ", " .. y .. ").")

	self.x = x
	self.y = y

	--	some tiles may trigger special messages for the player when being walked on
	if self.map.tile[self.x][self.y]["walk-message"] and self == Game.player then
		UI:message(self.map.tile[self.x][self.y]["walk-message"])
	end

	--	each repositioning triggers the recalculation of the sight map
	self:updateSight()
end

--	Actor:die() - kills the given actor, making it unable to act
function Actor:die()
	Game.log:write("Actor " .. self:toString() ..
		" has died.")
	self.alive = false
end

--	Actor:updateSight() - calculates the given actor's sight map;
--	does not return anything
function Actor:updateSight()
	local function traceRay(xOffset, yOffset, maxLength)
		--	the center of a tile is at (+0.5, +0.5)
		local currentX, currentY = self.x + 0.5, self.y + 0.5
		local currentLength = 0

		--	the point of origin is always visible
		self.sightMap[math.floor(currentX)][math.floor(currentY)] = true

		--	loop while advancing the ray's path
		while self.map:isInBounds(math.floor(currentX), math.floor(currentY))
			and not self.map:isOpaque(math.floor(currentX), math.floor(currentY)) 
			and currentLength < maxLength do
			currentX = currentX + xOffset
			currentY = currentY + yOffset
			currentLength = currentLength + 1
			self.sightMap[math.floor(currentX)][math.floor(currentY)] = true

			--	update the map memory for the player character
			if self == Game.player then
				self.map.memory[math.floor(currentX)][math.floor(currentY)] =
					self.map.tile[math.floor(currentX)][math.floor(currentY)].face
			end
		end
	end

	--	clear the previously calculated sight map
	for i = 1, Global.mapWidth do
		for j = 1, Global.mapHeight do
			self.sightMap[i][j] = false
		end
	end

	--	raytrace around the player
	for i = 1, 360 do
		local xOffset = math.cos(i * math.pi / 180)
		local yOffset = math.sin(i * math.pi / 180)
		traceRay(xOffset, yOffset, 5)
	end

	Game.log:write("Sight map calculated for " .. self:toString())
end

--	Actor:move() - attempts to move the given Actor object onto the tile
--	at the given pair of coordinates (x, y) of the same map it is currently
--	on; returns either true or false, depending on whether the move was
--	successful
function Actor:move(x, y)
	--	the actor must have a map to move on
	if not self.map then
		Game.log:write("Actor " .. self:toString() ..
			" attempted to move without an attached map!")
		return false
	end

	--	the actor's movements must keep it inside the boundaries of the map
	if not self.map:isInBounds(x, y) then
		Game.log:write("Actor " .. self:toString() ..
			" attempted to move to an out-of-bounds location!")
		return false
	end

	--	the actor cannot move onto a solid tile
	if self.map:isSolid(x, y) then
		Game.log:write("Actor " .. self:toString() ..
			" attempted to move onto a solid tile!")
		return false
	end

	--	the actor cannot move onto a tile that is occupied by another actor;
	--	instead, the actor who occupies that certain tile is attacked
	local actor = self.map:isOccupied(x, y)
	if actor and actor.alive then
		if self == Game.player then
			UI:message("You attack the " .. actor.name .. ".")
		end
		return self:meleeAttack(actor)
	end

	--	if all is well, update the actor's position
	self:setPosition(x, y)
	return true
end

--	Actor:meleeAttack() - makes the given actor attack another actor via
--	melee, killing the defending actor in the process; always returns true,
--	even if the hit was a miss
function Actor:meleeAttack(defender)
	if self == Game.player then
		UI:message("The " .. defender.name .. " dies!")
	end
	defender:die()
	return true
end

--	Actor:takeStairs() - makes the given actor use the stairs underneath it,
--	transferring the actor to another level of the dungeon; returns true if
--	the action was successfully completed, or false otherwise (trying to use
--	the stairs when not directly on them may be a cause)
function Actor:takeStairs()
	if self.map.tile[self.x][self.y].name == "Stairs down" then
		--	signal that the stairs have been descended
		if self == Game.player then
			UI:message("You descend the stairs.")
		end
		return true
	end

	if self.map.tile[self.x][self.y].name == "Stairs up" then
		--	signal that the stairs have been ascended
		if self == Game.player then
			UI:message("You ascend the stairs.")
		end
		return true
	end

	--	signal that there are no stairs to take
	if self == Game.player then
		UI:message("There are no stairs here.")
	end

	--	no action has been taken, so return false
	return false
end

--	Actor:act() - makes the given Actor object spend its turn; if the actor
--	is player-controlled, it requests input from the player and acts according
--	to the command(s) given; if the actor is not player-controlled, it
--	dispatches the reasoning to the AI functions; returns true or false,
--	depending on whether or not the turn was spent
function Actor:act()
	if self == Game.player then
		--	the actor is player controlled, so first inform the player of the
		--	current state of the game
		UI:drawScreen()

		--	and then request for input
		local k = curses.getch()
		Game.log:write("Read character: " .. k)

		return self:handleKey(k)
	else
		--	the actor is not player-controlled, so let the AI functions take over
		--	(not implemented, so return that the turn was successfully spent)
		return true
	end
end

--	Actor:handleKey() - makes the given actor spend its turn with a command
--	specified by the given key; returns true or false, depending on whether
--	the action was successful or not
function Actor:handleKey(key)
	--	system keys
	if key == "Q" then	--	quit
		if UI:prompt("Are you sure you want to exit?") then
			Game:halt("Player requested game termination.")
			return true	--	an exit request still spends a turn
		else
			return false
		end
	end

	--  message log
	if key == "p" then
		UI:messageLogScreen()
		return false  -- no time taken.
	end

	--	movement
	if key == "h" or key == "left" then	--	move left
		return self:move(self.x - 1, self.y)
	end

	if key == "j" or key == "down" then	--	move down
		return self:move(self.x, self.y + 1)
	end

	if key == "k" or key == "up"  then	--	move up
		return self:move(self.x, self.y - 1)
	end

	if key == "l" or key == "right" then	--	move right
		return self:move(self.x + 1, self.y)
	end

	--	use of stairs
	if key == ">" then
		return self:takeStairs()
	end

	--	there was no known action corresponding to the given key, so signal that
	--	there hasn't been taken any action to spend the turn with
	return false
end

return Actor

