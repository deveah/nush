
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

	--	show a friendly welcome message
	UI:message("Welcome to {{green}}Nush{{white}}! Please do not die often.")

	--	create the dungeon
	Log:write("Creating the dungeon...")
	for i = 1, Global.dungeonDepth do
		local map = Map.new(i, "Dungeon:" .. i)
		local levelType = math.random()
		if levelType < 0.3 then
			map:generateCave(40, 4, 8)
			map:spawnPoolsOfWater(3, 0.8)
			map:spawnPatchesOfGrass(1, 0.9)
		elseif levelType < 0.8 then
			map:generateRoomsAndCorridors(15, 4, 5)
			map:spawnMachinery(20, 0.1)
		else
			map:generateBSP()
		end
		self:addMap(map)
		Util.debugDumpMap(map)

		--	link with the previously created map (if it exists)
		if i > 1 then
			map:linkWith(self.mapList[i-1])
		end

		--	populate each map with other actors
		Log:write("Populating level " .. i .. " of the dungeon...")
		for j = 1, 10 do
			local actor = Actor.new()
			self:addActor(actor)
			actor:setName("Boogeyman")
			actor:setFace("b")
			actor:setColor(curses.red)
			actor:setMap(map)
			actor:setPosition(map:findRandomEmptySpace())
		end

		--	populate each map with a few items
		for j = 1, 10 do
			local item = Itemdefs.RedKeycard:new()
			self:addItem(item)
			item:setMap(map)
			item:setPosition(map:findRandomEmptySpace())
		end
	end

	--	create the player character
	Log:write("Creating the player character...")
	self.player = Actor.new()
	self:addActor(self.player)
	self.player:setName(playerName)
	self.player:setFace("@")
	self.player:setColor(curses.white)
	self.player:setMap(self.mapList[1])
	self.player:setPosition(self.player.map:findRandomEmptySpace())

	--	allow the event loop to run
	self.running = true

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
			Log:write("Current acting actor: " .. currentActor:toString() .. ")")

			--	the act() method of Actor objects returns true if the actor has spent
			--	its turn successfully; to prevent wasting turns, the event loop
			--	must make actors act until they come up with a valid move
			while currentActor.alive and not currentActor:act() do end

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
	Log:write("Added actor " .. actor:toString() .. " to actorList.")
end

--	Game:removeActor() - removes an item from the global actorList in case it
--	is destroyed.
--	Does not return anything
function Game:removeActor(actor)
	if not Util.seqRemove(self.actorList, actor) then
		error("bad call Game:removeActor(" .. actor:toString() .. ")")
	end
	Log:write("Remove actor " .. actor:toString() .. " from actorList.")
end

--	Game:addParticle() - adds a Particle object into the list of living
--	actors;	does not return anything
function Game:addParticle(particle)
	table.insert(self.particleList, particle)
	Log:write("Added particle " .. particle:toString() .. " to particleList.")
end

--	Game:removeParticle() - removes a particle from the global particleList.
--	Does not return anything
function Game:removeParticle(particle)
	if not Util.seqRemove(self.particleList, particle) then
		error("bad call Game:removeParticle(" .. particle:toString() .. ")")
	end
	Log:write("Remove particle " .. particle:toString() .. " from particleList.")
end

--	Game:addItem() - adds an Item object into the global list of items;
--	does not return anything
function Game:addItem(item)
	table.insert(self.itemList, item)
	Log:write("Added item " .. item:toString() .. " to itemList.")
end

--	Game:removeItem() - removes an item from the global itemList in case it is
--	destroyed. Do NOT call this to destroy an item, call item:destroy().
--	Does not return anything
function Game:removeItem(item)
	if not Util.seqRemove(self.itemList, item) then
		error("bad call Game:removeItem(" .. item:toString() .. ")")
	end
	Log:write("Remove item " .. item:toString() .. " from itemList.")
end

--	Game:itemsAtTile() - Returns sequence of items on some tile of a map
function Game:itemsAtTile(map, x, y)
	local ret = {}
	for _, item in ipairs(Game.itemList) do
		if item.map == map and item.x == x and item.y == y then
			table.insert(ret, item)
		end
	end
	return ret
end

--	Game:addMap() - adds a Map object into the list of dungeon levels;
--	does not return anything
function Game:addMap(map)
	table.insert(self.mapList, map)
	Log:write("Added map " .. map:toString() .. " to mapList.")
end

--	Game:halt() - makes the game terminate with a given reason;
--	does not return anything
function Game:halt(reason)
	Log:write("Halt: " .. reason)
	self.running = false
end

return Game
