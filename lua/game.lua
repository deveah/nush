
--
--	game.lua
--	Game object definition and methods
--
--	The Game object has the following members:
--	*	running (boolean) - indicates whether the game is active, and may receive
--			input from the user; if the game is not running, the event loop will
--			transition into a halting state, cleaning up all the relevant resources
--			and informing the user accordingly
--	*	actorList (table) - a list of all living actors that have the ability to
--			take their turns
--	*	itemList (table) - a list of all objects found on the dungeon floor;
--			all other objects must belong to actors, and are managed by themselves
--	*	mapList (table) - a list of all maps (levels) of the dungeon
--	* messageList (table) - a list of in-game messages
--	*	player (Actor object) - a shortcut to the player-controlled character;
--			although it also resides in the actorList table
--	* turnCount (integer) - the number of turns taken since the beginning of
--			the game; a turn is a period of time in which _all_ actors take their
--			turns
--	*	log (Log object) - used for logging debug data
--

local Global = require "lua/global"
local Map = require "lua/map"
local Actor = require "lua/actor"
local Log = require "lua/log"

local Game = {}
Game.__index = Game

--	Game.new() - creates a new Game object, initializing its members with
--	default data; returns the created Game object
function Game.new()
	local g = {}
	setmetatable(g, Game)

	--	initialize members
	g.running = false
	g.actorList = {}
	g.itemList = {}
	g.mapList = {}
	g.messageList = {}
	g.turnCount = 0

	return g
end

--	Game:start() - starts the given Game object, creating the world of
--	the game; does not return anything
function Game:start()
	--	initialize logging
	self.log = Log.new(Global.logFilename)
	self.log:write("Started logging.")

	--	set the random seed
	self.randomSeed = os.time()
	math.randomseed(self.randomSeed)
	self.log:write("Random seed is " .. self.randomSeed)

	--	create the dungeon
	self.log:write("Creating the dungeon...")
	for i = 1, Global.dungeonDepth do
		local map = Map.new()
		map:generateDummy()
		self:addMap(map)

		--	populate each map with other actors
		self.log:write("Populating level " .. i .. " of the dungeon...")
		for j = 1, 10 do
			local actor = Actor.new()
			self:addActor(actor)
			actor:setName("Boogeyman")
			actor:setFace("b")
			actor:setColor(curses.red)
			actor:setMap(map)
			actor:setPosition(math.random(2, Global.mapWidth - 1), math.random(2, Global.mapHeight - 1))
		end
	end

	--	create the player character
	self.log:write("Creating the player character...")
	self.player = Actor.new()
	self:addActor(self.player)
	self.player:setName("Player")
	self.player:setFace("@")
	self.player:setColor(curses.white)
	self.player:setMap(self.mapList[1])
	self.player:setPosition(40, 10)

	--	initialize the curses interface
	self.log:write("Initializing curses interface...")
	--Global.screenWidth, Global.screenHeight = curses.init()
	curses.init()
	self.log:write("Screen w/h: " .. Global.screenWidth .. "x" .. Global.screenHeight)

	--	allow the event loop to run
	self.running = true

	--	show a friendly welcome message
	self:message("Welcome to Nush! Please do not die often.")

	self.log:write("Game initialization successfully completed.")
end

--	Game:loop() - runs the main event loop of the game, dealing with user
--	interactions, turn scheduling, and everything else game related;
--	does not return anything
function Game:loop()
	self.log:write("Entered event loop.")
	while self.running do
		--	increase the turn counter
		self.turnCount = self.turnCount + 1

		--	mark the beginning of the turn
		self.log:write("Turn " .. self.turnCount .. " started.")

		--	loop through all the actors and make them take their turns
		for i = 1, #(self.actorList) do
			local currentActor = self.actorList[i]
			self.log:write("Current acting actor: " .. currentActor:toString() .. ")")

			--	the act() method of Actor objects returns true if the actor has spent
			--	its turn successfully; to prevent wasting turns, the event loop
			--	must make actors act until they come up with a valid move
			while not currentActor:act() do end

			--	if something triggered a game halt, cancel the rest of the actions
			--	of the remaining actors
			if not self.running then
				break
			end
		end

		--	mark the end of the turn
		self.log:write("Turn " .. self.turnCount .. " ended.")
	end
end

--	Game:terminate() - terminates the Game, and disposes of any resources
--	that were initialized during the game and require deinitialization;
--	does not return anything
function Game:terminate()
	self.log:write("Terminating game instance...")
	curses.terminate()
	self.log:terminate()
	io.write("Bye! Please submit any bugs you may have encountered!\n")
end

--	Game:drawScreen() - draws the main screen, which includes the map, HUD, and
--	message bars; does not return anything
function Game:drawScreen()
	--	the offsets from array indices to screen coordinates
	local xOffset, yOffset = -1, 2

	--	the map that we want to draw is the map the player-controlled character
	--	is currently on
	local map = self.player.map

	--	draw the terrain
	for i = 1, Global.mapWidth do
		for j = 1, Global.mapHeight do
			--	draw only tiles visible by the player, or in the player's memory
			if self.player.sightMap[i][j] then
				curses.attr(map.tile[i][j].color)
				curses.write(i + xOffset, j + yOffset, map.tile[i][j].face)
			elseif map.memory[i][j] ~= " " then
				curses.attr(curses.white)
				curses.write(i + xOffset, j + yOffset, map.memory[i][j])
			else
				curses.attr(curses.black)
				curses.write(i + xOffset, j + yOffset, " ")
			end
		end
	end

	--	draw the actors on the same map as the player, who are visible from
	--	the player character's point of view; only actors who are alive
	--	can be seen
	for i = 1, #(self.actorList) do
		if self.actorList[i].map == map
			and self.player.sightMap[self.actorList[i].x][self.actorList[i].y]
			and self.actorList[i].alive then
			curses.attr(self.actorList[i].color)
			curses.write(self.actorList[i].x + xOffset, self.actorList[i].y + yOffset,
				self.actorList[i].face)
		end
	end

	--	set the default color back
	curses.attr(curses.white)

	--	clear the message lines
	for i = 0, 2 do
		curses.clearLine(i)
	end

	--	draw the most recent 3 messages (if any)
	local offset = 0
	for i = #(self.messageList) - 2, #(self.messageList) do
		if i > 0 then
			curses.write(0, offset, self.messageList[i])
			offset = offset + 1
		end
	end

	--	draw the status line
	curses.write(0, 23, "Placeholder status line.")

	--	position the cursor on the player, so it may be easily seen
	curses.move(self.player.x + xOffset, self.player.y + yOffset)
end

--	Game:prompt() - prompts the player with a ok/cancel question, returning
--	true if the player has responded "ok", and false for every other reason
function Game:prompt(reason)
	--	show the user the reason for prompting
	self:message(reason .. " (ok/cancel)")

	--	update the screen so the prompt is visible
	self:drawScreen()

	--	read user input and act accordingly
	local k = curses.getch()
	if k == "o" then
		return true
	else
		--	show the user that the action has been cancelled
		self:message("Okay, then.")
		return false
	end
end

--	Game:addActor() - adds an Actor object into the list of living actors, and
--	attaches it to the game instance; does not return anything
function Game:addActor(actor)
	actor.gameInstance = self
	table.insert(self.actorList, actor)
	self.log:write("Added actor " .. actor:toString() .. " to actorList.")
end

--	Game:addItem() - adds an Item object into the list of items on the dungeon
--	floor, and attaches it to the game instance; does not return anything
function Game:addItem(item)
	item.gameInstance = self
	table.insert(self.itemList, item)
	self.log:write("Added item " .. item:toString() .. " to itemList.")
end

--	Game:addMap() - adds a Map object into the list of dungeon levels, and
--	attaches it to the game instance; does not return anything
function Game:addMap(map)
	map.gameInstance = self
	table.insert(self.mapList, map)
	self.log:write("Added map " .. map:toString() .. " to mapList.")
end

--	Game:halt() - makes the game terminate with a given reason;
--	does not return anything
function Game:halt(reason)
	self.log:write("Halt: " .. reason)
	self.running = false
end

--	Game:message() - pushes a message onto the message list, so the player
--	may see it in-game; does not return anything
function Game:message(text)
	self.log:write("Message logged: " .. text)
	table.insert(self.messageList, text)
end

return Game

