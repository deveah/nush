
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
--	* runDir (direction string, optional)
--	                    - (player only) if not nil, then in which
--	                      direction the player is moving in a straight line
--	* runStartX, runStartY  (integers, optional)
--	                    - (player only) From where running started
--	*	sightMap (2D boolean table) - a map showing the tiles
--	                      currently visible to the actor
--	* sightRange (int)  - Number of tiles the actor can see
--	* inventory (table) - Mapping from inventory slot (letter) to Items
--	* equipment (table) - Mapping from equipment slot to Items.
--	*	alive (boolean)   - true if the actor can act
--
--  Also, Actor has the following enums:
--	* InventorySlots    - List of inventory slots (e.g. "a")
--	* EquipSlots        - Table of equip slots (e.g. .meleeWeapon)
--

local Actor = {}
package.loaded['lua/actor'] = Actor

local Global = require "lua/global"
local Log = require "lua/log"
local Game = require "lua/game"
local UI = require "lua/ui"
local Particle = require "lua/particle"
local Tile = require "lua/tile"
local Util = require "lua/util"
local Itemdefs = require "lua/itemdefs"

--	Actor:new() - creates a new Actor object, initializing its members with
--	default data; returns the created Actor object
function Actor:new()
	local a = {}
	setmetatable(a, {__index = self})

	--	initialize members
	a.map = nil
	a.x = 0	--	although 0 is not a valid coordinate for the Actor to be on,
	a.y = 0	--	the value signifies that an actual position has not been set
	a.runDir = nil
	a.alive = true
	a.inventory = {}
	a.equipment = {}
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

	--	List items laying on this tile
	if self == Game.player then
		local items = self.map:itemsAtTile(self.x, self.y)
		if #items > 0 then
			local itemlist = ""
			for idx, item in ipairs(items) do
				if idx > 1 then
					itemlist = itemlist .. ", "
				end
				itemlist = itemlist .. item:describe()
			end
			UI:message("You see here " .. itemlist .. ".")
		end
	end

	--	each repositioning triggers the recalculation of the sight map
	self:updateSight()
end

--	Actor:setHp() - sets the hp of a given actor; returns nothing
function Actor:setHp(val)
	Log:write("Actor " .. self:toString() .. " set hp to " .. val)
	self.hp = val
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

--	Actor:dead() - checks if the given actor is still alive; if not,
--	triggers the 'die' method; returns true if the actor has died, and
--	false otherwise
function Actor:dead(reason)
	if self.hp <= 0 then
		self:die(reason)
		return true
	end
	return false
end

--	Actor:takeDamage() - makes the given actor take a given amount of damage;
--	also checks for death; does not return anything
function Actor:takeDamage(quantity, reason)
	self.hp = self.hp - quantity
	if self:dead() then
		if self:visible() then
			UI:message("{{red}}The " .. self.name .. " dies!")
		else
			UI:message("{{red}}Something died.")
		end
	end
end

----------------------------------- Inventory --------------------------------


--	list of all inventory slots
Actor.InventorySlots = {}
for i = 0, 25 do
	table.insert(Actor.InventorySlots, string.char(97 + i)) --	a-z
end
for i = 0, 25 do
	table.insert(Actor.InventorySlots, string.char(65 + i)) --	A-Z
end
--	Disallow certain letters, for menu scrolling and exit
Util.seqRemove(Actor.InventorySlots, "j")
Util.seqRemove(Actor.InventorySlots, "k")
Util.seqRemove(Actor.InventorySlots, "q")

--	set of all equipment slots
Actor.EquipSlots = {meleeWeapon = "meleeWeapon", rangedWeapon = "rangedWeapon"}
Util.makeStrict(Actor.EquipSlots)


--	Actor:unusedInventSlot() - returns the first unused inventory slot, or nil
--	none are free.
function Actor:unusedInventSlot()
	--	First try a-z, excluding jk for scrolling
	for _, slot in ipairs(Actor.InventorySlots) do
		if not self.inventory[slot] then
			return slot
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

--	Actor:hasItem() - searches the actor's inventory for an item of a given
--	name; returns either nil, in case the actor doesn't have such an item,
--	or the slot in which the item is placed
function Actor:hasItem(itemName)
	for slot, item in pairs(self.inventory) do
		if item.name == itemName then
			return slot
		end
	end
	return nil
end

--	Actor:addItem() - tries to add an item to the Actor's inventory, returns the
--	inventory slot (character) it was added in, or nil if there is no room.
function Actor:addItem(item)
	--	try stacking the item if possible (which destroys 'item')
	local slot = self:hasItem(item.name)
	if item.stackable and slot then
		self.inventory[slot]:combineStack(item)
		return slot
	else
		--	create a new slot in the inventory
		slot = self:unusedInventSlot()
		if not slot then
			return nil
		end

		item:setMap(nil)
		self.inventory[slot] = item

		return slot
	end
end

--	Actor:removeItem() - removes an item from the Actor's inventory (the caller
--	must ensure the item gets a new owner itself); does not return anything.
function Actor:removeItem(item)
	local slot = self:findItem(item)
	Log:write(self:toString() .. ":removeItem(" .. item:toString() .. ") from slot " .. tostring(slot))
	if slot then
		self:unequip(item)

		self.inventory[slot] = nil
		return
	end
	error(item:toString() .. " not in inventory")
end

--	Actor:equip() - Equips an item in the inventory in the slot item.equipSlot,
--	after unequipping existing equipment. Does not return anything.
function Actor:equip(item)
	Log:write(self:toString() .. " equipping " .. item:toString() .. " in " .. item.equipSlot)

	--	unequip existing
	if self.equipment[item.equipSlot] then
		self:unequip(self.equipment[item.equipSlot])
	end

	self.equipment[item.equipSlot] = item
	item.equipped = true

	if self == Game.player then
		if item.category == "Weapons" then
			UI:message("You now wield the " .. item:describe() .. ".")
		else
			UI:message("You equip on " .. item:describe() .. ".")
		end
	end
end

--	Actor:unequip() - Unequip an equipped item if it is equipped (otherwise
--	does nothing), ending any effects, etc. Returns true if it was unequipped.
function Actor:unequip(item)
	Log:write(self:toString() .. " unequipping " .. item:toString())
	local eqslot = Util.tableFind(self.equipment, item)
	if not eqslot then
		Log:write("...not equipped")
		return false
	end

	self.equipment[eqslot] = nil
	item.equipped = false

	if self == Game.player then
		--local weaponslots = {Actor.EquipSlots.meleeWeapon, Actor.EquipSlots.rangedWeapon}
		--if Util.tableFind(weaponslots, eqslot) then
		if item.category == "Weapons" then
			UI:message("You no longer wield the " .. item:describe() .. ".")
		else
			UI:message("You unequip the " .. item:describe() .. ".")
		end
	end
	return true
end

--	Actor:die() - kills the given actor, making it unable to act;
--	'reason' is an optional parameter which is used to trace the cause of death;
--	does not return anything
function Actor:die(reason)
	Log:write("Actor " .. self:toString() .. " has died.")
	self.alive = false
	--	By default, everything they were carrying is dropped.
	for _, item in pairs(self.inventory) do
		self:dropItem(item)
	end

	--	drop a corpse
	local corpse = Itemdefs[self.name .. " corpse"]:new()
	Game:addItem(corpse)
	corpse:setMap(self.map)
	corpse:setPosition(self.x, self.y)

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
		local x, y = math.floor(currentX), math.floor(currentY)
		local currentLength = 0

		--	loop while advancing the ray's path
		repeat
			self.sightMap[x][y] = true

			--	update the map memory for the player character
			if self == Game.player then
				self.map.memory[x][y] = self.map.tile[x][y].face
			end

			--	the point of origin and opaque obstacles are always visible
			if currentLength > 0 and self.map:isOpaque(x, y) then
				break
			end

			currentX = currentX + xOffset
			currentY = currentY + yOffset
			x = math.floor(currentX)
			y = math.floor(currentY)
			currentLength = currentLength + 1
		until currentLength > maxLength or not self.map:isInBounds(x, y)
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

	--	Update the player's memory of item positions
	if self == Game.player then
		for i = 1, #(Game.itemList) do
			local item = Game.itemList[i]
			if item.map == self.map and self.sightMap[item.x][item.y] then
				self.map.memory[item.x][item.y] = item.face
			end
		end
	end

	Log:write("Sight map calculated for " .. self:toString())
end


------------------------------ Actor actions ----------------------------------


--	Actor:canMoveTo() - returns whether this actor can enter a tile on the
--	current map, without having to attack the occupant or any other action.
function Actor:canMoveTo(x, y)
	if not self.map:isInBounds(x, y) or self.map:isSolid(x, y)
			or self.map:isOccupied(x, y) then
		return false
	end
	return true
end

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
		return (self:openDoor(x, y))
	end

	--	bumping into a locked door (for now) simply opens it
	if self.map.tile[x][y].name == "Locked door" then
		return self:unlockDoor(x, y)
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
	if actor then
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
	local weapon = self.equipment.meleeWeapon
	if not weapon then
		weapon = Itemdefs.Fists
	end

	--	calculate chance to hit
	if math.random() > weapon.accuracy then
		return false
	end

	local damage = math.random(weapon.minDamage, weapon.maxDamage)

	--	Report to player
	if self == Game.player then
		local extrainfo = ""
		if Global.debugInfo then
			extrainfo = " {" .. damage .. " damage}"
		end
		UI:message("You attack the " .. defender.name .. "." .. extrainfo)
	end

	defender:takeDamage(damage, "hit by " .. self.name)
	return true
end

--	Actor:rangedAttack() - called when the actor's projectile intercepts
--	another actor; returns true if the projectile hit (whether or not it caused
--	damage), false if it flies past.
function Actor:rangedAttack(defender, weapon)
	--	Calc hit
	if math.random() > weapon.accuracy then
		return false
	end

	--	Calc damage
	local damage = math.random(weapon.minDamage, weapon.maxDamage)

	--	Report to player
	if self == Game.player then
		local extrainfo = ""
		if Global.debugInfo then
			extrainfo = " {" .. damage .. " damage}"
		end

		if defender:visible() then
			UI:message("You hit the " .. defender.name .. "." .. extrainfo)
		else
			UI:message("You hit something." .. extrainfo)
		end
	end

	defender:takeDamage(damage, "shot by " .. self.name)
	return true
end

--	Actor:fireWeapon() - actor fires their weapon in some direction. Animates
--	the weapon firing and calls self:rangedAttack() on all targets.
--	Returns true if a turn was consumed.
function Actor:fireWeapon(direction)
	local weapon = self.equipment.rangedWeapon

	Log:write(self:toString() .. " firing weapon " .. tostring(weapon) .. " in direction " .. direction)
	if not weapon then
		--	self should not be Player, as Actor:playerFires() already checks
		--	whether nothing is equipped
		return false
	end

	--	consume ammo if possible
	if weapon.ammo then
		local slot = self:hasItem(weapon.ammo)
		if not slot then
			UI:message("You are out of ammo!")
			return false
		else
			local ammo = self.inventory[slot]
			ammo.count = ammo.count - 1
			if ammo.count == 0 then
				self:removeItem(ammo)
				ammo:destroy()
			end
		end
	end

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

	for i = 1, weapon.range do
		--	Aniamtion timing
		nexttick = clib.time() + Global.animationFrameLength

		x = x + diffx
		y = y + diffy
		bullet:setPosition(x, y)

		--	Check for collisions
		local actorHere = self.map:isOccupied(x, y)
		if actorHere then
			if self:rangedAttack(actorHere, weapon) then
				--bullet:setFace('%')
				hit = true
			end
		end

		--	shooting a locked door has a chance of breaking the lock
		if self.map.tile[x][y].locked then
			if math.random() < 0.1 then
				self.map.tile[x][y] = Tile.closedDoor
				UI:message("You break the lock!")
			else
				UI:message("You hit the lock, but it resists.")
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
		--	changed from 'item' to 'self.inventory[slot]' because the latter
		--	takes into account the item count after stacking it in inventory
		Log:write(self:toString() .. " picked up " .. self.inventory[slot]:toString())
		if self == Game.player then
			UI:message("Picked up {{yellow}}" .. slot .. "{{pop}} - " .. self.inventory[slot]:describe())
		end
		return true
	end
	Log:write(self:toString() .. " failed to pickup " .. self.inventory[slot]:toString())
	if self == Game.player then
		UI:message("Your inventory is already full!")
	end
	return false
end

--	Actor:dropItem() - Removes an item from the inventory, places it on the
--	floor below the actor; returns nothing
function Actor:dropItem(item)
	--	This unequips the item if needed
	self:removeItem(item)
	item:setMap(self.map)
	item:setPosition(self.x, self.y)
	if self == Game.player and self.alive then
		UI:message("You drop the " .. item:describe())
	end
end

--	Actor:straightMovement() - continue moving in a straight line (aka running)
--	until encountering something. Returns true if turn taken.
function Actor:straightMovement()
	local dirx, diry = Util.xyFromDirection(self.runDir)
	Log:write("player:straightMovement() continuing run in direction " .. self.runDir)

	--	Stop if any adjacent tile has something 'interesting' on it
	for x, y in self.map:neighbours(self.x, self.y) do
		--	Only consider tiles not adjacent to the starting one
		if Util.dist(x, y, self.runStartX, self.runStartY) > 1 then
			if	self.map:isOccupied(x, y) or
					#self.map:itemsAtTile(x, y) > 0 or
					self.map.tile[x][y].role == "stairs" or
					self.map.tile[x][y].role == "door" then
				self.runDir = nil
				return false
			end
		end
	end

	--	Try move; first check the tile is clear, otherwise would automatically
	--	open doors, attack enemies, etc.
	if self:canMoveTo(self.x + dirx, self.y + diry) then
		local moved = self:move(self.x + dirx, self.y + diry)
		if moved then
			return moved
		end
		--	This unexpected failure probably isn't a bug/error
		Log:write("While running, move() failed although canMoveTo()==true")
	end

	--	Cancel if couldn't move
	self.runDir = nil
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
		--	current state of the game, even if running (redrawing the screen for
		--	each step is slow but useful to the player)
		UI:drawScreen()
		curses.refresh()

		if self.runDir then
			--	The player is moving in a straight line
			return (self:straightMovement())
		else
			--	otherwise request for input
			local k = curses.getch()
			Log:write("Read character: " .. k)

			return (self:handleKey(k))
		end
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
	local weapon = self.equipment.rangedWeapon
	if not weapon then
		UI:message("You don't have a gun equipped!")
		return false
	end

	local dir = UI:promptDirection("Fire in which direction?")
	if not dir then
		return false
	end
	if dir == '.' then
		UI:message("You shoot yourself in the foot!")
		self:takeDamage(1, "shot self in foot")
		return true
	else
		return (self:fireWeapon(dir))
	end
end

--	Actor:handleRunKey() - Check whether the pressed key is a run key, if so, enters run mode and returns true, but this doesn't take any time
function Actor:handleRunKey(key)
	--	Check HJKL, etc
	local dir = UI:directionFromKey(key:lower())
	if dir then
		self.runDir = dir
		self.runStartX, self.runStartY = self.x, self.y
		return true
	end

	--	Check run prefix
	if key == "/" then
		dir = UI:promptDirection(nil)
		if dir == "." then
			UI:message("Not running in place.")
		elseif dir then
			self.runDir = dir
			self.runStartX, self.runStartY = self.x, self.y
		end
		return true --	handled '/'
	end
	return false  --	not handled
end

--	Actor:handleKey() - makes the given actor spend its turn with a command
--	specified by the given key; returns true or false, depending on whether
--	the action was successful or not
function Actor:handleKey(key)
	--	system keys
	if key == "Q" or key == "escape" then	--	quit
		if UI:prompt("Are you sure you want to exit?") then
			Game:halt("Player requested game termination.")

			--	output to the highscores file
			local f = io.open("scores.txt", "a")
			f:write(Game.player.name .. " quit on " .. Game.player.map.name .. "\n")
			f:close()

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

	if key == "?" or key == "F1" then
		UI:helpScreen()
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

	--	straight-line movement
	if self:handleRunKey(key) then
		return false
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
		local items = self.map:itemsAtTile(self.x, self.y)
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
		UI:inventoryScreen(Game.player)
		return false
	end

	--	debug keys
	--	dump globals
	if key == "F2" then
		UI:message("{{red}}(DEBUG) Dumped globals to logfile.")
		Util.dumpGlobals()
		return false
	end

	--	test graphics
	if key == "F3" then
		UI:testScreen()
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
	if key == ")" then
		UI:message("{{red}}(DEBUG) Teleported to next level.")
		self:teleportToMap(Game.mapList[self.map.num + 1])
	end
	if key == "(" then
		UI:message("{{red}}(DEBUG) Teleported to previous level.")
		self:teleportToMap(Game.mapList[self.map.num - 1])
	end

	--	there was no known action corresponding to the given key, so signal that
	--	there hasn't been taken any action to spend the turn with
	return false
end

--	Actor:teleportToMap() - place the actor on a random tile of the map (mainly
--	for debugging); does not return anything
function Actor:teleportToMap(map)
	if map then
		self.map = map
		self:setPosition(map:findRandomEmptySpace())
	end
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

--	Actor:unlockDoor() - makes the given actor unlock the door at a given
--	location; returns true if the action has been completed successfully,
--	and false otherwise
function Actor:unlockDoor(x, y)
	if not self.map:isInBounds(x, y) then
		return false
	end

	--	only doors can be unlocked
	if self.map.tile[x][y].role ~= "door" then
		if self == Game.player then
			UI:message("There's no door there!")
		end
		return false
	end

	--	only locked doors can be unlocked
	if not self.map.tile[x][y].locked then
		if self == Game.player then
			UI:message("That door isn't locked!")
		end
		return false
	end

	--	check to see if the actor has the right keycard
	if self:hasItem(self.map.tile[x][y].locked .. " keycard") then
		if self == Game.player then
			UI:message("{{green}}You open the locked door using your {{GREEN}}" ..
				self.map.tile[x][y].locked .. "{{pop}} keycard.")
		end
		self.map.tile[x][y] = Tile.openDoor
		return true
	else
		if self == Game.player then
			UI:message("The door requires a `" .. self.map.tile[x][y].locked .. "' keycard, which you do not have.")
		end
		return false
	end
end

return Actor

