
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
--	* sightMap (2D bool table) - a map showing the tiles visible to the actor.
--	                      Computed at the start of a turn, stale after acting!
--	* sightMapStale (bool) - True if sightMap may be out of date.
--	* aiState (any?)    - (nonplayer only) Indicates current state of AI
--	* sightRange (int)  - Number of tiles the actor can see
--	* inventory (table) - Mapping from inventory slot (letter) to Items
--	* equipment (table) - Mapping from equipment slot to Items.
--	*	alive (boolean)   - true if the actor can act
--	* actionPoints (int) - the number of action points the actor currently has
--	* agility (int) - the number of action points the actor is awarded with each turn
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

local _nextId = 0

--	Actor:new() - creates a new Actor object, initializing its members with
--	default data; returns the created Actor object
function Actor:new()
	local a = {}
	setmetatable(a, {__index = self, __tostring = Actor.__tostring})
	--	Assign unique id
	a._id = _nextId
	_nextId = _nextId + 1

	--	initialize members
	a.map = nil
	a.x = 0	--	although 0 is not a valid coordinate for the Actor to be on,
	a.y = 0	--	the value signifies that an actual position has not been set
	a.runDir = nil
	a.alive = true
	a.inventory = {}
	a.equipment = {}
	a.actionPoints = 0

	a.sightMapStale = true
	a.sightMap = {}
	for i = 1, Global.mapWidth do
		a.sightMap[i] = {}
		for j = 1, Global.mapHeight do
			a.sightMap[i][j] = false	--	by default, nothing is visible
		end
	end

	return a
end

--	Actor:__tostring() - returns a string describing an Actor for debugging
function Actor:__tostring()
	return "<actor #" .. tostring(self._id) .. " (" .. self.name .. ")>"
end

--	Actor:setName() - sets the name of the given Actor object; does not
--	return anything
function Actor:setName(name)
	Log:write(self, " was renamed to " .. name .. ".")
	
	self.name = name
end

--	Actor:setFace() - sets the face of the given Actor object; does not
--	return anything
function Actor:setFace(face)
	Log:write(self, " has changed its face to '" .. face .. "'.")

	self.face = face
end

--	Actor:setColor() - sets the color of the given Actor object; does not
--	return anything
function Actor:setColor(color)
	Log:write(self, " has changed its color to '" .. color .. "'.")
	
	self.color = color
end

--	Actor:setMap() - sets the map of the given Actor object; does not
--	return anything
function Actor:setMap(map)
	Log:write(self, " has been placed on ", map, ".")

	self.map = map

	self.sightMapStale = true

	--	when the player moves the player distance map becomes stale
	if self == Game.player then
		Game:clearPlayerCaches()
	end
end

--	Actor:setPosition() - sets the (x, y) position of the given Actor object;
--	does not return anything
function Actor:setPosition(x, y)
	Log:write(self, " has been placed at (" .. x .. ", " .. y .. ").")

	self.x = x
	self.y = y

	self.sightMapStale = true

	--	when the player moves the player distance map becomes stale
	if self == Game.player then
		Game:clearPlayerCaches()
	end

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
end

--	Actor:setHp() - sets the hp of a given actor; returns nothing
function Actor:setHp(val)
	Log:write(self, " set hp to ", val)
	self.hp = val
end

--	Actor:addExperience() - adds an amount of experience points to the actor
function Actor:addExperience(val)
	self.spendableExperience = self.spendableExperience + val
	self.totalExperience = self.totalExperience + val
	--	TODO: is this check necessary? only the player is awarded experience points
	if self == Game.player then
		UI:message("{{WHITE}}You gain {{GREEN}}" .. val .. "{{pop}} experience points!")
	end
end

--	Actor:visible() - returns whether this actor is visible to the player.
function Actor:visible()
	--	Recompute player sightMap as needed
	if Game.player.sightMapStale then
		Game.player:updateSight()
	end
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
function Actor:takeDamage(attacker, quantity, reason)
	self.hp = self.hp - quantity
	if self:dead(reason) then
		if self:visible() then
			UI:message("{{red}}The " .. self.name .. " dies!")
		else
			UI:message("{{red}}You hear a thud.")
		end

		--	award experience points to the player unless they killed themselves
		if attacker == Game.player and self ~= Game.player then
			--	TODO: fixed number of experience points for now
			Game.player:addExperience(10)
		end
	end
end

--------------------------- Inventory and equipment --------------------------


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

		item:setOwner(self)
		self.inventory[slot] = item

		return slot
	end
end

--	Actor:removeItem() - removes an item from the Actor's inventory (the caller
--	must ensure the item gets a new owner itself); does not return anything.
--	Note: to destroy an item in inventory, just call item:destroy(), which then
--	calls owner:removeItem()
function Actor:removeItem(item)
	local slot = self:findItem(item)
	Log:write(self, ":removeItem(", item, ") from slot ", slot)
	if slot then
		self:unequip(item)  --	noop if not equipped

		item:setOwner(nil)
		self.inventory[slot] = nil
		return
	end
	error(tostring(item) .. " not in inventory")
end

--	Actor:equip() - Equips an item in the inventory in the slot item.equipSlot,
--	after unequipping existing equipment. Does not return anything.
function Actor:equip(item)
	Log:write(self, " equipping ", item, " in ", item.equipSlot)

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
	Log:write(self, " unequipping ", item)
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
	Log:write(self, " has died.")
	self.alive = false

	--	drop a corpse; the player character doesn't drop a corpse
	--	the corpse is dropped first, so that items belonging to the actor
	--	will stack above it, to be more easily noticed
	if self ~= Game.player then
		local corpse = Itemdefs[self.name .. " corpse"]:new()
		corpse:setMap(self.map)
		corpse:setPosition(self.x, self.y)
	end

	--	By default, everything they were carrying is dropped.
	if self ~= Game.player then
		for _, item in pairs(self.inventory) do
			self:dropItem(item)

			--	items are removed and then reinserted into Game.itemList, to assure
			--	that they're drawn after the corpse of the slain enemy
			Util.seqRemove(Game.itemList, item)
			Game:addItem(item)
		end
	end

	--	check if the dead actor is the player, and if so, terminate the game
	if self == Game.player then
		UI:message("{{RED}}You die... {{red}}Press any key to exit.")
		UI:drawScreen()
		curses.getch()

		--	output to the highscores file
		self:dumpToHighscoreFile(reason)
		UI:highscoreScreen()
		Game.running = false
	end
end

--	Actor:dumpToHighscoreFile() - dumps relevant data to scores.csv in
--	comma-separated format; does not return anything
function Actor:dumpToHighscoreFile(reasonOfDeath)
	--	if the file doesn't exist, write the header
	if not Util.fileExists("scores.csv") then
		local f = io.open("scores.csv", "w")
		f:write("playerName,score,placeOfDeath,reasonOfDeath\n")
		f:close()
	end

	local f = io.open("scores.csv", "a")
	f:write(self.name .. "," .. self.totalExperience .. "," .. self.map.name .. "," .. reasonOfDeath .. "\n")
	f:close()
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

	self.sightMapStale = false
	Log:write("Sight map calculated for ", self)
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
--	on; returns the number of action points spent, or 0 if the action wasn't
--	completed
function Actor:move(x, y)
	--	No movement (e.g. pressed ./numpad5) counts as waiting
	if x == self.x and y == self.y then
		Log:write(self, " waiting.")
		if self == Game.player then
			UI:message("You wait.")
		end
		return Global.actionCost.wait
	end

	--	the actor must have a map to move on
	if not self.map then
		Log:write(self, " attempted to move without an attached map!")
		return 0
	end

	--	the actor's movements must keep it inside the boundaries of the map
	if not self.map:isInBounds(x, y) then
		Log:write(self, " attempted to move to an out-of-bounds location!")
		return 0
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
		return 0
	end

	--	the actor cannot move onto a solid tile
	if self.map:isSolid(x, y) then
		Log:write(self, " attempted to move onto a solid tile!")
		return 0
	end

	--	the actor cannot move onto a tile that is occupied by another actor;
	--	instead, the actor who occupies that certain tile is attacked
	local actor = self.map:isOccupied(x, y)
	if actor then
		return (self:meleeAttack(actor))
	end

	--	if all is well, update the actor's position
	self:setPosition(x, y)
	return Global.actionCost.move
end

--	Actor:doAttack() - Apply a melee or ranged attack to a target, returns a
--	bool to say	whether the attack hit.
--	 ranged:  true if a ranged attack.
--	(Note: in future we'll likely have to separate out ranged and melee
--	attacks again, and just share code for the message)
function Actor:doAttack(defender, weapon, ranged)
	--	calculate whether attack hit
	local hit = (math.random() <= weapon.accuracy)

	local damage = math.random(weapon.minDamage, weapon.maxDamage)

	--	Report attack to player

	local extrainfo = ""
	if hit and Global.debugInfo then
		extrainfo = " {" .. damage .. " damage}"
	end

	local attackVerb = weapon.attack
	if hit == false then
		if self == Game.player then
			attackVerb = "miss"
		else
			attackVerb = "misses"
		end
	end

	local defenderName
	if defender == Game.player then
		defenderName = "you"
	elseif defender:visible() then
		defenderName = "the " .. defender.name
	else
		defenderName = "an unseen foe"
	end

	if self == Game.player then
		UI:message("You " .. attackVerb .. " " .. defenderName .. "!" .. extrainfo)
	elseif self:visible() then
		UI:message("The " .. self.name .. " " .. attackVerb .. " " .. defenderName .. "." .. extrainfo)
	elseif defender:visible() and ranged then
		UI:message("A shot misses " .. defenderName)
	end

	--	Do effects
	if hit then
		defender:takeDamage(self, damage, weapon.attack .. " by " .. self.name)
	end
	return hit
end

--	Actor:meleeAttack() - makes the given actor attack another actor via
--	melee, damaging the defending actor in the process; always returns true,
--	even if the hit was a miss
function Actor:meleeAttack(defender)
	local weapon = self.equipment.meleeWeapon
	if not weapon then
		weapon = Itemdefs.Fists
	end

	--	even though the player may have been undetected until now, a melee attack
	--	makes the enemy notice the player
	if self == Game.player and defender ~= Game.player then
		defender.aiState = "chase"
	end

	self:doAttack(defender, weapon, false)
	return Global.actionCost.meleeAttack
end

--	Actor:rangedAttack() - called when the actor's projectile intercepts
--	another actor; returns true if the projectile hit (whether or not it caused
--	damage), false if it flies past.
function Actor:rangedAttack(defender, weapon)
	return (self:doAttack(defender, weapon, true))
end

--	Actor:fireWeapon() - actor fires their weapon in some direction. Animates
--	the weapon firing and calls self:rangedAttack() on all targets.
--	Returns the number of action points consumed.
function Actor:fireWeapon(direction)
	local weapon = self.equipment.rangedWeapon

	Log:write(self, " firing weapon ", weapon, " in direction ", direction)
	if not weapon then
		--	Impossible if canFireWeapon() was checked (don't need player message)
		Log:write("...failed, no weapon")
		return 0
	end

	--	consume ammo if possible
	if weapon.ammo then
		local slot = self:hasItem(weapon.ammo)
		if not slot then
			--	Impossible if canFireWeapon() was checked (don't need player message)
			Log:write("...failed, out of ammo " .. weapon.ammo)
			return 0
		else
			local ammo = self.inventory[slot]
			ammo.count = ammo.count - 1
			if ammo.count == 0 then
				ammo:destroy()
			end
		end
	end

	if direction == "." then
		UI:message("You shoot yourself in the foot!")
		self:takeDamage(self, 3, "shot self in foot")
		return Global.actionCost.rangedAttack
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

	return Global.actionCost.rangedAttack
end

--	Actor:canFireWeapon() - A unified function to check whether the player or
--	an AI can shoot with their weapon. Returns either true, or (false, reason),
--	where	reason is the message to give to the player.
function Actor:canFireWeapon()
	local weapon = self.equipment.rangedWeapon
	if not weapon then
		Log:write(actor, " can't shoot, no rangedWeapon")
		return false, "You don't have a gun equipped!"
	end

	--	Ammo requirements
	if weapon.ammo then
		local slot = self:hasItem(weapon.ammo)
		if not slot then
			Log:write(actor, " can't shoot, out of ammo", weapon.ammo)
			return false, "You are out of ammo!"
		end
	end

	return true
end

--	Actor:ammoAmount() - Returns amount of ammo this actor has for this weapon
function Actor:ammoAmount(weapon)
	local slot = self:hasItem(weapon.ammo)
	if slot then
		return self.inventory[slot].count
	end
	return 0
end

--	Actor:takeStairs() - makes the given actor use the stairs underneath it,
--	transferring the actor to another level of the dungeon; returns the number
--	of spent action points, or 0 in case the action fails (trying to use
--	the stairs when not directly on them may be a cause)
function Actor:takeStairs()
	if self.map.tile[self.x][self.y].name == "Stairs down" then
		--	signal that the stairs have been descended
		if self == Game.player then
			UI:message("You descend the stairs.")
		end
		self:setMap(self.map.tile[self.x][self.y]["destination-map"])
		return Global.actionCost.takeStairs
	end

	if self.map.tile[self.x][self.y].name == "Stairs up" then
		--	signal that the stairs have been ascended
		if self == Game.player then
			UI:message("You ascend the stairs.")
		end
		self:setMap(self.map.tile[self.x][self.y]["destination-map"])
		return Global.actionCost.takeStairs
	end

	--	signal that there are no stairs to take
	if self == Game.player then
		UI:message("There are no stairs here.")
	end

	--	no action has been taken, so return 0
	return 0
end

--	Actor:tryPickupItem() - Transfers an item to this actor's inventory if
--	there is room; returns the number of action points spent
function Actor:tryPickupItem(item)
	local slot = self:addItem(item)
	if slot then
		if item.stackable then
			Log:write(self, " picked up ", item, " (now " .. self.inventory[slot].count .. ")")
			if self == Game.player then
				UI:message("Picked up {{yellow}}" .. slot .. "{{pop}} - " .. item:describe() .. ". You now have " .. self.inventory[slot].count .. ".")
			end
		else
			Log:write(self, " picked up ", item)
			if self == Game.player then
				UI:message("Picked up {{yellow}}" .. slot .. "{{pop}} - " .. item:describe())
			end
		end
		return Global.actionCost.pickupItem
	end
	Log:write(self, " failed to pickup ", self.inventory[slot])
	if self == Game.player then
		UI:message("Your inventory is already full!")
	end
	return 0
end

--	Actor:dropItem() - Removes an item from the inventory, places it on the
--	floor below the actor; returns the number of action points spent
function Actor:dropItem(item)
	--	This unequips the item if needed
	self:removeItem(item)
	item:setMap(self.map)
	item:setPosition(self.x, self.y)
	if self == Game.player and self.alive then
		UI:message("You drop the " .. item:describe())
	end
	return Global.actionCost.dropItem
end

--	Actor:straightMovement() - continue moving in a straight line (aka running)
--	until encountering something. Returns the number of action points spent.
function Actor:straightMovement()
	local dirx, diry = Util.xyFromDirection(self.runDir)
	Log:write(self, ":straightMovement() continuing run in direction " .. self.runDir)

	--	Stop if any adjacent tile has something 'interesting' on it
	for x, y in self.map:neighbours(self.x, self.y) do
		--	Only consider tiles not adjacent to the starting one
		if Util.dist(x, y, self.runStartX, self.runStartY) > 1 then
			if	self.map:isOccupied(x, y) or
					#self.map:itemsAtTile(x, y) > 0 or
					self.map.tile[x][y].role == "stairs" or
					self.map.tile[x][y].role == "door" then
				self.runDir = nil
				return 0
			end
		end
	end

	--	Try move; first check the tile is clear, otherwise would automatically
	--	open doors, attack enemies, etc.
	if self:canMoveTo(self.x + dirx, self.y + diry) then
		local moved = self:move(self.x + dirx, self.y + diry)
		if moved ~= 0 then
			return moved
		end
		--	This unexpected failure probably isn't a bug/error
		Log:write("While running, move() failed although canMoveTo()==true")
	end

	--	Cancel if couldn't move
	self.runDir = nil
	return 0
end

--	Actor:act() - makes the given Actor object spend its turn; if the actor
--	is player-controlled, it requests input from the player and acts according
--	to the command(s) given; if the actor is not player-controlled, it
--	dispatches the reasoning to the AI functions; returns true or false,
--	depending on whether or not the turn was spent
function Actor:act()
	--	Update field of view at beginning of turn (assuming actors on other maps
	--	don't act)
	if self.map == Game.player.map and self.sightMapStale then
		self:updateSight()
	end

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
		return (self:aiAct())
	end
end

------------------------------- Player control --------------------------------

--	Actor:playerFires() - handle the player wanting to shoot, returns action
--	points cost
--	TODO: allow proper targetting rather than only firing in a direction
function Actor:playerFires()
	assert(self == Game.player)

	--	Check ability to fire before prompting (but the gun may still jam, etc.)
	local canShoot, reason = self:canFireWeapon()
	if not canShoot then
		UI:message(reason)
		return 0
	end

	local dir = UI:promptDirection("Fire in which direction?")
	if not dir then
		return 0
	end
	return (self:fireWeapon(dir))
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
			self:dumpToHighscoreFile("quit")
			UI:highscoreScreen()

			return 100	--	an exit request still spends a turn
		else
			return 0
		end
	end

	--	redraw the screen if corrupted
	if key == "R" or  key == "\x12" or key == "\x0c" then  -- ^R or ^L
		UI:drawScreen()
		curses.redraw()
		return 0	-- no time taken.
	end

	if key == "?" or key == "F1" then
		UI:helpScreen()
		return 0	-- no time taken.
	end

	if key == "@" then
		UI:playerScreen()
		return 0	-- no time taken.
	end

	if key == "!" then
		UI:skillPointScreen()
		return 0	-- no time taken.
	end

	--  message log
	if key == "P" then
		UI:messageLogScreen()
		return 0  -- no time taken.
	end

	--	examine dialog
	if key == "\t" then
		UI:examineScreen()
		return 0	-- no time taken.
	end

	--	movement
	local dir, dirx, diry = UI:directionFromKey(key)
	if dir then
		return (self:move(self.x + dirx, self.y + diry))
	end

	--	straight-line movement
	if self:handleRunKey(key) then
		return 0	-- no time taken.
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
			return (self:closeDoor(self.x + dirx, self.y + diry))
		elseif self == Game.player then
			UI:message("Okay, then.")	-- signal that no action has been taken
			return 0	-- no time taken.
		end
	end

	--	pick door lock
	if key == "p" then
		local dir, dirx, diry = UI:promptDirection("Pick lock where?")
		if dir then
			return self:pickDoor(self.x + dirx, self.y + diry)
		elseif self == Game.player then
			UI:message("Okay, then.")	-- signal that no action has been taken
			return 0	-- no time taken.
		end
	end

	--	pick up
	if key == "," or key == "g" then
		local items = self.map:itemsAtTile(self.x, self.y)
		Log:write("Trying to pickup: items:", items)
		if #items == 0 then
			UI:message("There's nothing here to pick up!")
			return 0	-- no time taken.
		elseif #items == 1 then
			return (self:tryPickupItem(items[1]))
		else
			while true do
				local text = ""
				for idx, item in pairs(items) do
					text = text .. "[{{yellow}}" .. string.char(string.byte('a') + idx - 1) ..
						"{{pop}}] " .. item:describe() .. "\n"
				end

				UI:drawMessageBox("Pick up multiple items", text, " {{cyan}}ESC{{pop}} cancel ", 30, 2)
				
				local key = curses.getch()
				local keyId = string.byte(key) - string.byte('a') + 1
				if keyId > 0 and keyId <= #items then
					return (self:tryPickupItem(items[keyId]))
				end

				if key == "escape" then
					return 0	-- no action taken
				end
			end
		end
	end

	--	show inventory
	if key == "i" then
		UI:inventoryScreen(Game.player)
		return 0	-- no time taken.
	end

	--	debug keys
	--	dump globals
	if key == "F2" then
		UI:message("{{red}}(DEBUG) Dumped globals to logfile.")
		Util.dumpGlobals()
		return 0	-- no time taken.
	end

	--	test graphics
	if key == "F3" then
		UI:testScreen()
		return 0	-- no time taken.
	end

	--	make the whole map temporarily visible to the player
	if key == "$" then
		UI:message("{{red}}(DEBUG) Map made temporarily visible.")
		for i = 1, 80 do
			for j = 1, 20 do
				Game.player.sightMap[i][j] = true
			end
		end
		-- UI:drawScreen()
		-- curses.getch()
		-- Game.player.sightMapStale = true
		return 0	-- no time taken.
	end

	--	Show distance to the player
	if key == "F4" then
		UI:drawDijkstraMap(Game:getPlayerDistMap())
	end

	--	Show flee map
	if key == "F5" then
		UI:drawDijkstraMap(Game:getFleeMap())
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
	return 0
end

--	Actor:teleportToMap() - place the actor on a random tile of the map (mainly
--	for debugging); does not return anything
function Actor:teleportToMap(map)
	if map then
		self:setMap(map)
		self:setPosition(map:findRandomEmptySpace())
	end
end

--	Actor:openDoor() - makes the given actor open a door at a given location;
--	returns the number of action points spent
function Actor:openDoor(x, y)
	if not self.map:isInBounds(x, y) then
		return 0	-- no time taken
	end

	--	only closed doors can be opened
	if self.map.tile[x][y] ~= Tile.closedDoor then
		if self == Game.player then
			UI:message("There's no closed door there!")
		end
		return 0
	end

	if self == Game.player then
		UI:message("You open the door.")
	end

	self.map.tile[x][y] = Tile.openDoor

	--	the field of view may change
	self.map:markChanged()
	self.sightMapStale = true

	--	the action has been completed successfully
	return Global.actionCost.openDoor
end

--	Actor:closeDoor() - makes the given actor close a door at a given location;
--	returns true if the action has been successfully completed, and false
--	otherwise
function Actor:closeDoor(x, y)
	if not self.map:isInBounds(x, y) then
		return 0
	end

	--	only open doors can be closed
	if self.map.tile[x][y] ~= Tile.openDoor then
		if self == Game.player then
			UI:message("There's no open door there!")
		end
		return 0
	end

	if self == Game.player then
		UI:message("You close the door.")
	end

	self.map.tile[x][y] = Tile.closedDoor

	--	the field of view may change
	self.map:markChanged()
	self.sightMapStale = true

	--	the action has been completed successfully
	return Global.actionCost.closeDoor
end

--	Actor:unlockDoor() - makes the given actor unlock the door at a given
--	location; returns true if the action has been completed successfully,
--	and false otherwise
function Actor:unlockDoor(x, y)
	if not self.map:isInBounds(x, y) then
		return 0
	end

	--	only doors can be unlocked
	if self.map.tile[x][y].role ~= "door" then
		if self == Game.player then
			UI:message("There's no door there!")
		end
		return 0
	end

	--	only locked doors can be unlocked
	if not self.map.tile[x][y].locked then
		if self == Game.player then
			UI:message("That door isn't locked!")
		end
		return 0
	end

	--	check to see if the actor has the right keycard
	if self:hasItem(self.map.tile[x][y].locked .. " keycard") then
		if self == Game.player then
			UI:message("{{green}}You open the locked door using your {{GREEN}}" ..
				self.map.tile[x][y].locked .. "{{pop}} keycard.")
		end
		self.map.tile[x][y] = Tile.openDoor
		return Global.actionCost.unlockDoor
	else
		if self == Game.player then
			UI:message("The door requires a `" .. self.map.tile[x][y].locked .. "' keycard, which you do not have.")
		end
		return 0
	end
end

--	Actor:pickDoor() - makes the given actor pick the locked door at a given
--	location; returns the number of action points spent (a failed attempt at
--	picking a door still counts as a spent turn)
function Actor:pickDoor(x, y)
	if not self.map:isInBounds(x, y) then
		return 0
	end

	--	only doors can be picked
	if self.map.tile[x][y].role ~= "door" then
		if self == Game.player then
			UI:message("There's no door there!")
		end
		return 0
	end

	--	only locked doors can be picked
	if not self.map.tile[x][y].locked then
		if self == Game.player then
			UI:message("That door isn't locked!")
		end
		return 0
	end

	--	calculate the pick chance depending on the player's lockpick skill
	--	current formula: chance = lockpick skill / 10
	--		min: 0
	--		max: unbounded (TODO)
	local pickChance = self.skills.lockpick / 10

	if math.random() < pickChance then
		self.map.tile[x][y] = Tile.closedDoor
		if self == Game.player then
			UI:message("{{green}}You successfully pick the lock!")
		end
		return Global.actionCost.pickDoor
	else
		if self == Game.player then
			UI:message("You fail to pick the lock.")
		end
		return Global.actionCost.pickDoor
	end
end


-------------------------------------- AI -------------------------------------

--	Actor:aiAct() - AI player takes a turn. Returns action points spent.
function Actor:aiAct()
	--	Wait if not on the player's map
	if self.map ~= Game.player.map then
		return Global.actionCost.wait
	end

	if self.aiState == "wait" then
		--	Activate when it sees the player;
		--	the 'stealth' skill decides whether the player makes him/herself visible
		if		self.sightMap[Game.player.x][Game.player.y]
			and (Game.player.skills.stealth / 10) < math.random() then
			self.aiState = "chase"
		else
			return Global.actionCost.wait
		end
	end

	--	Temporary for testing fleeing
	if self.hp < self.maxHp then
		self.aiState = "flee"
	end

	if self.aiState == "chase" then
		--	Move towards player
		local distmap = Game:getPlayerDistMap()
		return (self:aiApproachGoals(distmap))
	end

	if self.aiState == "flee" then
		--	Move away from player
		local distmap = Game:getFleeMap()
		return (self:aiApproachGoals(distmap))
	end

	--	Wait
	return Global.actionCost.wait
end

--	Actor:aiApproachGoals() - actor AI logic which tries to move towards goals
--	given as a Dijkstra map, including meleeing the player if it bumps into
--	the player. Returns action points spent.
function Actor:aiApproachGoals(distmap)
	local debug = false
	local currentDist = distmap[self.x][self.y]

	if debug then Log:write(self, " chasing from ", self.x, ",", self.y, " currentDist=", currentDist) end

	--	list of {distance, x, y} tuples
	local choices = {}

	--	Consider all movement options (including melee attacks, and in future
	--	opening doors)
	for dirnum = 0, 7 do
		local dir = Util.intToDir[dirnum]
		local xoff, yoff = Util.xyFromDirection(dir)
		local x, y = self.x + xoff, self.y + yoff

		--	enemies can open closed doors; this is a side effect of lua's conversion
		--	of numbers to boolean values - the 'solid' attribute of a tile can be
		--	either a boolean, or a number value; if it's a number, it represents the
		--	cost of the movement on that tile;
		--	TODO: don't know if it's the cleanest way to approach this
		local canmove = self:canMoveTo(x, y) or self.map.tile[x][y] == Tile.closedDoor
		local dist = distmap[x][y]

		if debug then Log:write("  considering x,y=", x, ",", y, " canmove=", canmove, " dist=", dist) end

		if x == Game.player.x and y == Game.player.y then
			canmove = true
		end

		--	Only consider this tile if it doesn't move away from the goal
		--	but allow equal cost tiles so there is some chance to move around
		--	other actors blocking the path (this is very crude)
		if canmove and dist <= currentDist then
			table.insert(choices, {dist, x, y})
		end
	end

	--	Sort choices into ascending order by distance from goal.
	--	Randomise the list before sorting it so that enemies don't form lines.
	Util.seqShuffle(choices)
	table.sort(choices, function(x, y) return x[1] < y[1] end)

	--	Choose the first allowable movement which moves
	for idx = 1, #choices do
		local _, x, y = table.unpack(choices[idx])

		--	Double check we won't melee an ally (shouldn't be in choices)
		local actor = self.map:isOccupied(x, y)
		if debug then Log:write("  trying x,y=", x, ",", y, " actor=", actor) end
		if not actor or actor == Game.player then
			return (self:move(x, y))
		end
	end

	if debug then Log:write("  failed") end

	--	Can't find a helpful action, wait.
	return Global.actionCost.wait
end

return Actor

