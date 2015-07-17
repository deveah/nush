
--
--	actor.lua
--	Actor object definition and methods
--
--	An Actor object has the following members:
--	*	name (string)     - a name describing the actor type
--	* face (string)     - a character describing how the actor looks in-game
--	*	color (curses constant) - the color of the actor in-game
--	*	map (Map object)  - the map on which the Actor is currently
--	* x, y (integers)   - the position of the Actor on the map
--	*	sightMap (2D boolean table) - a map showing the tiles
--	                      currently visible to the actor
--	* sightRange (int)  - Number of tiles the actor can see
--	* inventory (table) - Mapping from inventory slot (letter) to Items
--	*	alive (boolean)   - true if the actor can act
--

local Global = require "lua/global"
local Log = require "lua/log"
local Game = require "lua/game"
local UI = require "lua/ui"
local Particle = require "lua/particle"
local Tile = require "lua/tile"
local Util = require "lua/util"

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
	a.alive = true
	a.inventory = {}
	a.sightRange = 5

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
	Log:write("Actor " .. self:toString() ..
		" was renamed to " .. name .. ".")
	
	self.name = name
end

--	Actor:setFace() - sets the face of the given Actor object; does not
--	return anything
function Actor:setFace(face)
	Log:write("Actor " .. self:toString() ..
		" has changed its face to '" .. face .. "'.")

	self.face = face
end

--	Actor:setColor() - sets the color of the given Actor object; does not
--	return anything
function Actor:setColor(color)
	Log:write("Actor " .. self:toString() ..
		" has changed its color to '" .. color .. "'.")
	
	self.color = color
end

--	Actor:setMap() - sets the map of the given Actor object; does not
--	return anything
function Actor:setMap(map)
	Log:write("Actor " .. self:toString() ..
		" has been placed on " .. map:toString() .. ".")

	self.map = map
end

--	Actor:setPosition() - sets the (x, y) position of the given Actor object;
--	does not return anything
function Actor:setPosition(x, y)
	Log:write("Actor " .. self:toString() ..
		" has been placed at (" .. x .. ", " .. y .. ").")

	self.x = x
	self.y = y

	--	some tiles may trigger special events when being walked on
	local f = self.map.tile[self.x][self.y]["on-walk"]
	if f and type(f) == "function" then
		f(self)
	end

	--	each repositioning triggers the recalculation of the sight map
	self:updateSight()
end

--	Actor:visible() - returns whether this actor is visible to the player
function Actor:visible()
	return self.map == Game.player.map and Game.player.sightMap[self.x][self.y]
end

--	Actor:draw() - draw this actor on the map if it should be visible from
--	the player character's point of view; returns nothing.
function Actor:draw(xOffset, yOffset)
	if self:visible() then
		curses.attr(self.color)
		curses.write(self.x + xOffset, self.y + yOffset, self.face)
	end
end

----------------------------------- Inventory --------------------------------

--	Actor:unusedInventSlot() - returns the first unused inventory slot, or nil
--	none are free.
function Actor:unusedInventSlot()
	--	First try a-z, excluding jk for scrolling
	for i = 0, 25 do
		local char = string.char(97 + i)
		if char ~= "j" and char ~= "k" and not self.inventory[char] then
			return char
		end
	end
	--	Try A-Z
	for i = 0, 25 do
		local char = string.char(65 + i)
		if not self.inventory[char] then
			return char
		end
	end
	return nil
end

--	Actor:findItem() - Given an item, return the inventory slot it is in, or
--	nil if none. Also accepts an inventory slot for convenience.
function Actor:findItem(item_or_slot)
	if self.inventory[item_or_slot] then  --  it's an inventory slot
		return item
	end
	for slot,item in pairs(self.inventory) do
		if item == item_or_slot then
			return slot
		end
	end
	return nil
end

--	Actor:addItem() - tries to add an item to the Actor's inventory, returns the
--	inventory slot (character) it was added in, or nil if there is no room.
function Actor:addItem(item)
	local slot = self:unusedInventSlot()
	if not slot then
		return nil
	end
	self.inventory[slot] = item
	item:setMap(nil)
	return slot
end

--	Actor:removeItem() - removes an item from the Actor's inventory (the caller
--	must ensure the item gets a new owner itself); does not return anything.
function Actor:removeItem(item_or_slot)
	local slot = self:findItem(item_or_slot)
	if slot then
		self.inventory[item] = nil
		return
	end
	error(item_or_slot:toString() .. " not in inventory")
end

--	Actor:die() - kills the given actor, making it unable to act;
--	'reason' is an optional parameter which is used to trace the cause of death;
--	does not return anything
function Actor:die(reason)
	Log:write("Actor " .. self:toString() ..
		" has died.")
	self.alive = false
	--	By default, everything they were carrying is dropped.
	for _, item in pairs(self.inventory) do
		self:dropItem(item)
	end

	--	check if the dead actor is the player, and if so, terminate the game
	if self == Game.player then
		UI:message("{{RED}}You die... {{red}}Press any key to exit.")
		UI:drawScreen()
		curses.getch()

		--	output to the highscores file
		local f = io.open("scores.txt", "a")
		f:write(Game.player.name .. " died on " .. Game.player.map.name .. ", " .. reason .. "\n")
		f:close()
		Game.running = false
	end
end


----------------------------------- FOV --------------------------------------

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
			self.sightMap[math.floor(currentX)][math.floor(currentY)] = true

			--	update the map memory for the player character
			if self == Game.player then
				self.map.memory[math.floor(currentX)][math.floor(currentY)] =
					self.map.tile[math.floor(currentX)][math.floor(currentY)].face
			end

			currentX = currentX + xOffset
			currentY = currentY + yOffset
			currentLength = currentLength + 1
		end

		--	make sure the final point in the ray's path is visible
		if self.map:isInBounds(math.floor(currentX), math.floor(currentY)) then
			self.sightMap[math.floor(currentX)][math.floor(currentY)] = true
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
		traceRay(xOffset, yOffset, self.sightRange)
	end

	Log:write("Sight map calculated for " .. self:toString())
end


------------------------------ Actor actions ----------------------------------

--	Actor:move() - attempts to move the given Actor object onto the tile
--	at the given pair of coordinates (x, y) of the same map it is currently
--	on; returns either true or false, depending on whether the move was
--	successful
function Actor:move(x, y)
	--	No movement (e.g. pressed ./numpad5) counts as waiting
	if x == self.x and y == self.y then
		Log:write("Actor " .. self:toString() .. " waiting.")
		if self == Game.player then
			UI:message("You wait.")
		end
		return true
	end

	--	the actor must have a map to move on
	if not self.map then
		Log:write("Actor " .. self:toString() ..
			" attempted to move without an attached map!")
		return false
	end

	--	the actor's movements must keep it inside the boundaries of the map
	if not self.map:isInBounds(x, y) then
		Log:write("Actor " .. self:toString() ..
			" attempted to move to an out-of-bounds location!")
		return false
	end

	--	bumping into a closed door opens it
	if self.map.tile[x][y] == Tile.closedDoor then
		return self:openDoor(x, y)
	end

	--	bumping into a hidden door reveals it
	if self.map.tile[x][y] == Tile.hiddenDoor then
		if self == Game.player then
			UI:message("{{yellow}}You find a hidden door!")
		end

		self.map.tile[x][y] = Tile.closedDoor
		return true
	end

	--	the actor cannot move onto a solid tile
	if self.map:isSolid(x, y) then
		Log:write("Actor " .. self:toString() ..
			" attempted to move onto a solid tile!")
		return false
	end

	--	the actor cannot move onto a tile that is occupied by another actor;
	--	instead, the actor who occupies that certain tile is attacked
	local actor = self.map:isOccupied(x, y)
	if actor and actor.alive then
		return (self:meleeAttack(actor))
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
		UI:message("You attack the " .. defender.name .. ".")
		UI:message("{{red}}The " .. defender.name .. " dies!")
	end
	defender:die("hit by " .. self.name)
	return true
end

--	Actor:rangedAttack() - called when the actor's projectile intercepts
--	another actor; returns true if the projectile hit (whether or not it caused
--	damage), false if it flies past.
function Actor:rangedAttack(defender)
	if math.random() > 0.6 then --	temp 60% chance to hit
		return false
	end
	if self == Game.player then
		if defender:visible() then
			UI:message("You hit the " .. defender.name .. ".")
			UI:message("{{red}}The " .. defender.name .. " dies!")
		else
			UI:message("You hit something.")
		end
	end
	defender:die("shot by " .. self.name)
	return true
end

--	Actor:fireWeapon() - actor fires their weapon in some direction. Animates
--	the weapon firing and calls self:rangedAttack() on all targets.
--	Returns true (always) if a turn consumed.
function Actor:fireWeapon(direction)
	--	Range of the weapon
	local range = 7

	local bulletIcons = {
		l = '-', r = '-', u = '|', d = '|',
		ul = '\\', dr = '\\', ur = '/', dl = '/'
	}

	local bullet = Particle.new()
	Game:addParticle(bullet)
	bullet:setMap(self.map)
	bullet:setFace(bulletIcons[direction])
	bullet:setColor(curses.red)

	local x, y = self.x, self.y
	local diffx, diffy = Util.xyFromDirection(direction)
	local nexttick
	local hit = false --	Have hit something

	for i = 1, range do
		--	Aniamtion timing
		nexttick = clib.time() + Global.animationFrameLength

		x = x + diffx
		y = y + diffy
		bullet:setPosition(x, y)

		--	Check for collisions
		local actorHere = self.map:isOccupied(x, y)
		if actorHere then
			if self:rangedAttack(actorHere) then
				--bullet:setFace('%')
				hit = true
			end
		end
		if self.map:isSolid(x, y) then
			--bullet:setFace('%')
			hit = true
		end

		--	Display
		UI:drawScreen()
		curses.refresh()
		if Global.animations then
			clib.sleep(nexttick - clib.time())
		end

		if hit then break end
	end
	Game:removeParticle(bullet)

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
		self.map = self.map.tile[self.x][self.y]["destination-map"]
		self:updateSight()	-- force update of sight map
		return true
	end

	if self.map.tile[self.x][self.y].name == "Stairs up" then
		--	signal that the stairs have been ascended
		if self == Game.player then
			UI:message("You ascend the stairs.")
		end
		self.map = self.map.tile[self.x][self.y]["destination-map"]
		self:updateSight()	-- force update of sight map
		return true
	end

	--	signal that there are no stairs to take
	if self == Game.player then
		UI:message("There are no stairs here.")
	end

	--	no action has been taken, so return false
	return false
end

--	Actor:tryPickupItem() - Transfers an item to this actor's inventory if
--	there is room; returns true on success, else false
function Actor:tryPickupItem(item)
	local slot = self:addItem(item)
	if slot then
		Log:write(self:toString() .. " picked up " .. item:toString())
		if self == Game.player then
			UI:message("Picked up {{yellow}}" .. slot .. "{{white}} - " .. item:describe())
		end
		return true
	end
	Log:write(self:toString() .. " failed to pickup " .. item:toString())
	if self == Game.player then
		UI:message("Your inventory is already full!")
	end
	return false
end

--	Actor:dropItem() - Removes an item from the inventory, places it on the
--	floor below the actor; returns nothing
function Actor:dropItem(item)
	self:removeItem(item)
	item:setMap(self.map)
	item:setPosition(self.x, self.y)
	if self == Game.player and self.alive then
		UI:message("You drop the " .. item:describe())
	end
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
		Log:write("Read character: " .. k)

		return (self:handleKey(k))
	else
		--	the actor is not player-controlled, so let the AI functions take over
		--	(not implemented, so return that the turn was successfully spent)
		return true
	end
end


------------------------------- Player control --------------------------------

--	Actor:playerFires() - handle the player wanting to shoot, returns whether
--	successful.
--	TODO: allow proper targetting rather than only firing in a direction
function Actor:playerFires()
	local dir = UI:promptDirection("Fire in which direction?")
	if not dir then
		return false
	end
	if dir == '.' then
		UI:message("You shoot yourself in the foot!")
		self:die("shot self in foot")
		return true
	else
		return (self:fireWeapon(dir))
	end
end

--	Actor:handleKey() - makes the given actor spend its turn with a command
--	specified by the given key; returns true or false, depending on whether
--	the action was successful or not
function Actor:handleKey(key)
	--	system keys
	if key == "Q" or key == "escape" then	--	quit
		if UI:prompt("Are you sure you want to exit?") then
			Game:halt("Player requested game termination.")
			return true	--	an exit request still spends a turn
		else
			return false
		end
	end

	--	redraw the screen if corrupted
	if key == "R" or  key == "\x12" or key == "\x0c" then  -- ^R or ^L
		UI:drawScreen()
		curses.redraw()
		return false
	end

	--  message log
	if key == "p" then
		UI:messageLogScreen()
		return false  -- no time taken.
	end

	--	movement
	local dir, dirx, diry = UI:directionFromKey(key)
	if dir then
		return (self:move(self.x + dirx, self.y + diry))
	end

	--	fire
	if key == "f" then
		return (self:playerFires())
	end

	--	use of stairs
	if key == ">" or key == "<" then
		return (self:takeStairs())
	end

	--	close door
	if key == "c" then
		local dir, dirx, diry = UI:promptDirection("Close where?")
		if dir then
			return self:closeDoor(self.x + dirx, self.y + diry)
		elseif self == Game.player then
			UI:message("Okay, then.")	-- signal that no action has been taken
			return false
		end
	end

	--	pick up
	if key == "," or key == "g" then
		local items = Game:itemsAtTile(self.map, self.x, self.y)
		Log:write("Trying to pickup: items:" .. tostring(items))
		if #items == 0 then
			UI:message("There's nothing here to pick up!")
			return false
		else
			--	TODO: handle more than one item
			self:tryPickupItem(items[1])
		end
	end

	--	show inventory
	if key == "i" then
		UI:drawInventoryScreen(Game.player)
		return false
	end

	--	debug keys
	--	dump globals
	if key == "#" then
		UI:message("{{red}}(DEBUG) Dumped globals to logfile.")
		Util.dumpGlobals()
		return false
	end

	--	make the whole map temporarily visible to the player
	if key == "$" then
		UI:message("{{red}}(DEBUG) Map made temporarily visible.")
		for i = 1, 80 do
			for j = 1, 20 do
				Game.player.sightMap[i][j] = true
			end
		end
	end

	--	teleport player to next/previous map
	if key == "(" then
		UI:message("{{red}}(DEBUG) Teleported to next level.")
		Game.player.map = Game.mapList[Game.player.map.num + 1]
		Game.player.x, Game.player.y = Game.player.map:findRandomEmptySpace()
		Game.player:updateSight()
	end
	if key == ")" then
		UI:message("{{red}}(DEBUG) Teleported to previous level.")
		Game.player.map = Game.mapList[Game.player.map.num - 1]
		Game.player.x, Game.player.y = Game.player.map:findRandomEmptySpace()
		Game.player:updateSight()
	end

	--	there was no known action corresponding to the given key, so signal that
	--	there hasn't been taken any action to spend the turn with
	return false
end

--	Actor:openDoor() - makes the given actor open a door at a given location;
--	returns true if the action has been successfully completed, and false
--	otherwise
function Actor:openDoor(x, y)
	if not self.map:isInBounds(x, y) then
		return false
	end

	--	only closed doors can be opened
	if self.map.tile[x][y] ~= Tile.closedDoor then
		if self == Game.player then
			UI:message("There's no closed door there!")
		end
		return false
	end

	if self == Game.player then
		UI:message("You open the door.")
	end

	self.map.tile[x][y] = Tile.openDoor

	--	force the update of the field of view
	self:updateSight()

	--	the action has been completed successfully
	return true
end

--	Actor:closeDoor() - makes the given actor close a door at a given location;
--	returns true if the action has been successfully completed, and false
--	otherwise
function Actor:closeDoor(x, y)
	if not self.map:isInBounds(x, y) then
		return false
	end

	--	only open doors can be closed
	if self.map.tile[x][y] ~= Tile.openDoor then
		if self == Game.player then
			UI:message("There's no open door there!")
		end
		return false
	end

	if self == Game.player then
		UI:message("You close the door.")
	end

	self.map.tile[x][y] = Tile.closedDoor

	--	force the update of the field of view
	self:updateSight()

	--	the action has been completed successfully
	return true
end

return Actor

