
--
--	game.lua
--	Game object definition and methods
--
--	The Game object has the following members:
--	*	running (boolean) - indicates whether the game is active, and may receive
--			input from the user; if the game is not running, the event loop will
--			transition into a halting state, cleaning up all the relevant resources
--			and informing the user accordingly
--	*	actorList (list) - a list of all living actors that have the ability
--			to take their turns
--	*	particleList (list) - a list of all particles
--	*	itemList (list) - a list of all items whether on the floor or owned by
--			an actor
--	*	mapList (table) - a list of all maps (levels) of the dungeon
--	*	player (Actor object) - a shortcut to the player-controlled character;
--			although it also resides in the actorList table
--	* turnCount (integer) - the number of turns taken since the beginning of
--			the game; a turn is a period of time in which _all_ actors take their
--			turns
--

--	The singleton Game object
local Game = {}
--	This allows recursively requiring game.lua
package.loaded['lua/game'] = Game

local Global = require "lua/global"
local Util = require "lua/util"
local Map = require "lua/map"
local Actor = require "lua/actor"
local Log = require "lua/log"
local UI = require "lua/ui"
local Tile = require "lua/tile"
local Item = require "lua/item"
local Itemdefs = require "lua/itemdefs"
local Actordefs = require "lua/actordefs"
local Dungeon = require "lua/dungeon"


--	Game:init() - initialize members of a Game object with default data
function Game:init()
	self.running = false
	self.actorList = {}
	self.particleList = {}
	self.itemList = {}
	self.mapList = {}
	self.turnCount = 0
end

--	Game:start() - starts the given Game object, creating the world of
--	the game and initialising everything; does not return anything
function Game:start()
	--	set the random seed
	self.randomSeed = os.time()
	math.randomseed(self.randomSeed)
	Log:write("Random seed is " .. self.randomSeed)

	--	initialize the interface
	UI:init()

	--	draw the title screen
	local playerName = UI:drawTitleScreen()

	--	create the dungeon
	Log:write("Creating the dungeon...")
	for depth = 1, Global.dungeonDepth do
		local map = Map.new(depth, "Dungeon:" .. depth)
		local layout = Dungeon.layout[depth]
		if layout.generator == "cave" then
			map:generateCave(40, 4, 8)
			map:spawnPoolsOfWater(3, 0.8)
			map:spawnPatchesOfGrass(1, 0.9)
		elseif layout.generator == "rooms" then
			map:generateRoomsAndCorridors(15, 4, 5)
			map:spawnMachinery(20, 0.1)
			map:spawnTraps(2)
		elseif layout.generator == "bsp" then
			map:generateBSP()
			map:spawnTraps(2)
		else
			error("Unknown generator " .. layout.generator)
		end

		self:addMap(map)

		--	link with the previously created map (if it exists)
		if depth > 1 then
			map:linkWith(self.mapList[depth-1])
		end
		Util.debugDumpMap(map)

		--  Given spawnList is a table giving drop rates for items/enemies
		local function totalWeight(spawnList)
			local total = 0
			for k, v in pairs(spawnList) do
				if type(v) == "table" then
					total = total + v[1]
				else
					total = total + v
				end
			end
			return total
		end

		--	populate each map with other actors
		Log:write("Populating level " .. depth .. " of the dungeon...")
		for j = 1, Dungeon.layout[depth].nEnemies do
			local actor
			local wh = math.random() * totalWeight(Dungeon.layout[depth].enemies)
			local acc = 0  --	accumulated weight
			for k, v in pairs(Dungeon.layout[depth].enemies) do
				if wh >= acc and wh < acc + v then
					actor = Actordefs[k]:new()
				end
				acc = acc + v
			end
			self:addActor(actor)
			actor:initInventory()
			actor:setMap(map)
			actor:setPosition(map:findRandomEmptySpace())
		end

		--	populate each map with a few items
		for j = 1, Dungeon.layout[depth].nLoot do
			--	Combine default weights and overrides
			local spawnList = Util.mergeTables(
					Dungeon.defaultLootWeights(depth),
					Dungeon.layout[depth].loot
			)
			local wh = math.random() * totalWeight(spawnList)
			local item
			local acc = 0  --	accumulated weight
			for k, v in pairs(spawnList) do
				if type(v) == "table" then
					if wh >= acc and wh < acc + v[1] then
						item = Itemdefs[k]:new(math.random(v[2], v[3]))
					end
					acc = acc + v[1]
				else
					if wh >= acc and wh < acc + v then
						item = Itemdefs[k]:new()
					end
					acc = acc + v
				end
			end

			item:setMap(map)
			item:setPosition(map:findRandomEmptySpace())
		end
	end

	--	create the player character
	Log:write("Creating the player character...")
	self.player = Actordefs.Player:new()
	self:addActor(self.player)
	self.player:setName(playerName)
	self.player:setMap(self.mapList[1])
	self.player:setPosition(self.player.map:findRandomEmptySpace())

	--	Give initial equipment
	local phaser = Itemdefs.Phaser:new()
	self.player:addItem(phaser)
	self.player:equip(phaser)
	self.player:addItem(Itemdefs.EnergyCell:new(10))

	--	allow the event loop to run
	self.running = true

	--	show a friendly welcome message
	UI:message("Welcome to {{green}}Nush{{pop}}! Please do not die often.")

	curses.clear()
	UI:drawMessageBox("Welcome to {{green}}Nush{{pop}}!",
		{"You are a treasure hunter in the search for one last hit",
		 "to assure your safe retirement. Stories tell about a",
		 "abandoned distant human colony, home to a research base,",
		 "said to hold technologies beyond imagination. After a",
		 "long journey, you finally land on the planet. You take",
		 "a deep breath and enter through a rusty trap door...",
		 "",
		 "Press `any' key to continue."})
	curses.getch()

	Log:write("Game initialization successfully completed.")
end

--	Game:loop() - runs the main event loop of the game, dealing with user
--	interactions, turn scheduling, and everything else game related;
--	does not return anything
function Game:loop()
	Log:write("Entered event loop.")
	while self.running do
		--	increase the turn counter
		self.turnCount = self.turnCount + 1

		--	mark the beginning of the turn
		Log:write("Turn " .. self.turnCount .. " started.")

		--	loop through all the actors and make them take their turns
		for i = 1, #(self.actorList) do
			local currentActor = self.actorList[i]

			--	award action points equal to the actor's agility score, divided by 10;
			--	this way, actions which take small amount of action points can be
			--	done by actors in alternating order;
			--	the number of action points awarded each turn to the actors should be
			--	smaller than the lowest cost of an action
			currentActor.actionPoints = currentActor.actionPoints + currentActor.agility / 10

			--	the act() method returns the number of action points spent to make
			--	a specific action
			while currentActor.alive and currentActor.actionPoints >= 0 do
				Log:write("Currently acting: " .. tostring(currentActor) ..
					" actionpoints: " .. currentActor.actionPoints)
				currentActor.actionPoints = currentActor.actionPoints - currentActor:act()
			end

			--	The sightMap may be out of date as soon as the next actor acts;
			--	Game.player.sightMapStale is set when this happens but other actors
			--	aren't tracked, so be cautious!
			if currentActor ~= Game.player then
				currentActor.sightMapStale = true
			end

			--	if something triggered a game halt, cancel the rest of the actions
			--	of the remaining actors
			if not self.running then
				break
			end
		end

		--	mark the end of the turn
		Log:write("Turn " .. self.turnCount .. " ended.")
	end
end

--	Game:terminate() - terminates the Game, and disposes of any resources
--	that were initialized during the game and require deinitialization;
--	does not return anything
function Game:terminate()
	Log:write("Terminating game instance...")
	UI:terminate()
	Log:terminate()
	io.write("Bye! Please submit any bugs you may have encountered!\n")
end

--	Game:addActor() - adds an Actor object into the list of living actors;
--	does not return anything
function Game:addActor(actor)
	table.insert(self.actorList, actor)
	Log:write("Added ", actor, " to actorList.")
end

--	Game:removeActor() - removes an item from the global actorList in case it
--	is destroyed.
--	Does not return anything
function Game:removeActor(actor)
	if not Util.seqRemove(self.actorList, actor) then
		error("bad call Game:removeActor(" .. tostring(actor) .. ")")
	end
	Log:write("Remove ", actor, " from actorList.")
end

--	Game:addParticle() - adds a Particle object into the list of living
--	actors;	does not return anything
function Game:addParticle(particle)
	table.insert(self.particleList, particle)
	Log:write("Added ", particle, " to particleList.")
end

--	Game:removeParticle() - removes a particle from the global particleList.
--	Does not return anything
function Game:removeParticle(particle)
	if not Util.seqRemove(self.particleList, particle) then
		error("bad call Game:removeParticle(" .. tostring(particle) .. ")")
	end
	Log:write("Remove ", particle, " from particleList.")
end

--	Game:addItem() - adds an Item object into the global list of items;
--	does not return anything
function Game:addItem(item)
	table.insert(self.itemList, item)
	Log:write("Added ", item, " to itemList.")
end

--	Game:removeItem() - removes an item from the global itemList in case it is
--	destroyed. Do NOT call this to destroy an item, call item:destroy().
--	Does not return anything
function Game:removeItem(item)
	if not Util.seqRemove(self.itemList, item) then
		error("bad call Game:removeItem(" .. tostring(item) .. ")")
	end
	Log:write("Remove ", item, " from itemList.")
end

--	Game:addMap() - adds a Map object into the list of dungeon levels;
--	does not return anything
function Game:addMap(map)
	table.insert(self.mapList, map)
	Log:write("Added ", map, " to mapList.")
end

--	Game:halt() - makes the game terminate with a given reason;
--	does not return anything
function Game:halt(reason)
	Log:write("Halt: " .. reason)
	self.running = false
end

--	Game:clearPlayerCaches() - Should be called when then player moves or the
--	map changes. Returns nothing.
function Game:clearPlayerCaches()
	self.playerDistMap = nil
	self.fleeMap = nil
	self.player.sightMapStale = true
end

--	Game:getPlayerDistMap() - return a cached 2D map of distances in tiles from
--	the player.
function Game:getPlayerDistMap()
	if not self.playerDistMap then
		self.playerDistMap =
			clib.dijkstraMap(Game.player.map.tile, 999, Game.player.x, Game.player.y)
		self.playerDistMap.maxcost = 999
	end
	return self.playerDistMap
end

--	Game:getFleeMap() - return a cached 2D map of distances which directs
--	actors how to flee from the player (does not work yet).
function Game:getFleeMap()
	if not self.fleeMap then
		local dists = self:getPlayerDistMap()
		local fleemap = {}
		for i = 1, Global.mapWidth do
			fleemap[i] = {}
			for j = 1, Global.mapHeight do
				local dist = dists[i][j]
				if dist < 999 then
					fleemap[i][j] = 100 - 1.4 * dist
				end
			end
		end
		self.fleeMap = clib.dijkstraMap(Game.player.map.tile, 999, fleemap)
		self.fleeMap.maxcost = 999
	end
	return self.fleeMap
end


return Game
