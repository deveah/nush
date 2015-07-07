
--
--	map.lua
--	Map object definition and methods
--
--	A Map object contains the following members:
--	*	tile (table) - contains the terrain data in a two-dimensional array,
--			whose dimensions are defined in global.lua; all maps have the same
--			dimensions
--	*	memory (table) - contains a superficial memory of the terrain data;
--			the only thing that's memorised is the look of the terrain tile
--

local Global = require "lua/global"
local Game = require "lua/game"
local Tile = require "lua/tile"

local Map = {}
Map.__index = Map

--	Map.new() - creates a new Map object and initializes its members with
--	default data; returns the created Map object
function Map.new()
	local m = {}
	setmetatable(m, Map)

	m.tile = {}
	m.memory = {}

	--	initialize the terrain data with `void` tiles
	for i = 1, Global.mapWidth do
		m.tile[i] = {}
		m.memory[i] = {}
		for j = 1, Global.mapHeight do
			m.tile[i][j] = Tile.void
			m.memory[i][j] = " "
		end
	end

	return m
end

--	Map:toString() - returns a string describing the Map object
function Map:toString()
	return "<map " .. tostring(self) .. ">"
end

--	Map:isInBounds() - returns true if the given pair of coordinates (x, y)
--	is within bounds, or false otherwise
function Map:isInBounds(x, y)
	return	(x > 0) and (x <= Global.mapWidth) and
					(y > 0) and (y <= Global.mapHeight)
end

--	Map:isSolid() - returns true if the tile at the given pair of coordinates
--	(x, y) is solid, and false otherwise; in case the pair of coordinates is
--	out of bounds, the result is also false, to prevent movement outside
--	map boundaries
function Map:isSolid(x, y)
	if not self:isInBounds(x, y) then
		return false
	end

	return self.tile[x][y].solid
end

--	Map:isOpaque() - returns true if the tile at the given pair of coordinates
--	(x, y) is opaque, and false otherwise; in case the pair of coordinates is
--	out of bounds, the result is also false, to prevent unnecessary raytracing
function Map:isOpaque(x, y)
	if not self:isInBounds(x, y) then
		return false
	end

	return self.tile[x][y].opaque
end

--	Map:isOccupied() - returns the actor at the coordinates (x, y) of the given
--	map (if any), or false if the specified tile is not occupied
function Map:isOccupied(x, y)
	for i = 1, #(Game.actorList) do
		local actor = Game.actorList[i]
		if actor.map == self and actor.x == x and actor.y == y then
			return actor
		end
	end
	return false
end

--	Map:generateDummy() - generates a dummy map filled with floor tiles, and
--	surrounded with wall tiles; at random locations, the floor tiles may be
--	replaced by other tiles from the same class;
--	the function does not return anything
function Map:generateDummy()
	--	generate the basic map
	for i = 1, Global.mapWidth do
		for j = 1, Global.mapHeight do
			if i == 1 or j == 1 or i == Global.mapWidth or j == Global.mapHeight then
				self.tile[i][j] = Tile.wall
			else
				self.tile[i][j] = Tile.floor
			end
		end
	end

	--	add some other random tiles
	for i = 1, 10 do
		local x = math.random(2, 79)
		local y = math.random(2, 19)
		self.tile[x][y] = Tile.grass
	end
	for i = 1, 10 do
		local x = math.random(2, 79)
		local y = math.random(2, 19)
		self.tile[x][y] = Tile.shallowWater
	end
	for i = 1, 10 do
		local x = math.random(2, 79)
		local y = math.random(2, 19)
		self.tile[x][y] = Tile.ceilingDrip
	end
	for i = 1, 10 do
		local x = math.random(2, 79)
		local y = math.random(2, 19)
		self.tile[x][y] = Tile.wall
	end
end

--	Map:digRoom() - digs a rectangular room, filling it with a given floor-type
--	tile, and surrounding it with a given wall-type tile; does not return
--	anything
function Map:digRoom(x, y, w, h, floorTile, wallTile)
	for i = x, x+w-1 do
		for j = y, y+h-1 do
			if not self:isInBounds(i, j) then
				assert(false)
				return
			end

			if i == x or j == y or i == x+w-1 or j == y+h-1 then
				self.tile[i][j] = wallTile
			else
				self.tile[i][j] = floorTile
			end
		end
	end
end

--	Map:digLink() - digs a cooridor between two given points, filling it with
--	a given floor-type tile; does not return anything
function Map:digLink(x1, y1, x2, y2, floorTile)
	--	start from (x1, y1)
	local x, y = x1, y1

	--	directions in which to dig the corridor
	local dx, dy
	if x1 > x2 then dx = -1 else dx = 1 end
	if y1 > y2 then dy = -1 else dy = 1 end

	while x ~= x2 do
		if not self:isInBounds(x, y) then
			return
		end

		self.tile[x][y] = floorTile
		x = x + dx
	end

	while y ~= y2 do
		if not self:isInBounds(x, y) then
			return
		end

		self.tile[x][y] = floorTile
		y = y + dy
	end

	--	also cover the destination point (x2, y2)
	if self:isInBounds(x, y) then
		self.tile[x][y] = floorTile
	end
end

--	Map:isAreaEmpty() - checks if a given area is empty (ie. filled with
--	void tiles); returns a boolean value according to the result
function Map:isAreaEmpty(x, y, w, h)
	for i = x, x+w-1 do
		for j = y, y+h-1 do
			if not self:isInBounds(i, j) then
				return false
			end

			if self.tile[i][j] ~= Tile.void then
				return false
			end
		end
	end

	return true
end

--	Map:countNeighbours() - returns the number of a given type of neighbouring
--	tiles that surround a given coordinate
function Map:countNeighbours(x, y, tile)
	local count = 0
	for i = x-1, x+1 do
		for j = y-1, y+1 do
			if	self:isInBounds(i, j) and
					not (i == x and j == y) and
					self.tile[i][j] == tile then
				count = count + 1
			end
		end
	end

	return count
end

--	Map:generateRoomsAndCorridors() - generates a rooms-and-corridors map
--	with a given number of rooms, a given number of redundant links
--	between rooms, and a given number of locker rooms; does not return anything
function Map:generateRoomsAndCorridors(nRooms, nLoops, nLockers)
	local rooms = {}

	--	roomDistance() - calculates the distance between two rooms
	local function roomDistance(indexA, indexB)
		return math.sqrt(	(indexA.x - indexB.x) * (indexA.x - indexB.x) +
											(indexA.y - indexB.y) * (indexA.y - indexB.y))
	end

	--	closestRoom() - returns the index of the closest room to a given one
	local function closestRoom(toWhich)
		local min, minIndex = 999, 1
		for i = 1, #rooms do
			local dist = roomDistance(rooms[toWhich], rooms[i])
			if dist < min and i ~= toWhich then
				min = dist
				minIndex = i
			end
		end
		return minIndex
	end
	
	--	create the rooms
	for i = 1, nRooms do
		local rx, ry, rw, rh
		repeat
			rx = math.random(1, 70)
			ry = math.random(1, 15)
			rw = math.random(5, 8)
			rh = math.random(5, 7)

			--	rooms can only be placed at odd-valued coordinates
			if rx % 2 == 0 then rx = rx + 1 end
			if ry % 2 == 0 then ry = ry + 1 end

			--	rooms' dimensions can only have odd values
			if rw % 2 == 0 then rw = rw + 1 end
			if rh % 2 == 0 then rh = rh + 1 end
		until self:isInBounds(rx+rw, ry+rh) and
					self:isAreaEmpty(rx, ry, rw, rh)

		self:digRoom(rx, ry, rw, rh, Tile.floor, Tile.wall)
		table.insert(rooms, {x = rx, y = ry, w = rw, h = rh})

		--	link each room with the closest to it
		if i > 1 then
			local r = rooms[closestRoom(#rooms)]
			local sx = math.floor((r.x * 2 + r.w) / 2)
			local sy = math.floor((r.y * 2 + r.h) / 2)
			local dx = math.floor((rx * 2 + rw) / 2)
			local dy = math.floor((ry * 2 + rh) / 2)

			--	corridors' start- and end-points can only be at even coordinates
			if sx % 2 == 1 then sx = sx + 1 end
			if sy % 2 == 1 then sy = sy + 1 end
			if dx % 2 == 1 then dx = dx + 1 end
			if dy % 2 == 1 then dy = dy + 1 end
			self:digLink(sx, sy, dx, dy, Tile.floor)
		end
	end

	--	postprocess: add 'lockers' (little 1x1 rooms next to regular rooms,
	--	which should hidden and/or locked)
	for i = 1, nLockers do
		local x, y
		repeat
			x = math.random(1, 80)
			y = math.random(1, 20)
		until self.tile[x][y] == Tile.wall

		if	self:isInBounds(x-1, y) and
				self:isInBounds(x+1, y) and
				self.tile[x-1][y] == Tile.floor then
			self.tile[x+1][y] = Tile.floor
			self.tile[x][y] = Tile.closedDoor
		end

		if	self:isInBounds(x-1, y) and
				self:isInBounds(x+1, y) and
				self.tile[x+1][y] == Tile.floor then
			self.tile[x-1][y] = Tile.floor
			self.tile[x][y] = Tile.closedDoor
		end

		if	self:isInBounds(x, y-1) and
				self:isInBounds(x, y+1) and
				self.tile[x][y-1] == Tile.floor then
			self.tile[x][y+1] = Tile.floor
			self.tile[x][y] = Tile.closedDoor
		end

		if	self:isInBounds(x, y-1) and
				self:isInBounds(x, y+1) and
				self.tile[x][y+1] == Tile.floor then
			self.tile[x][y-1] = Tile.floor
			self.tile[x][y] = Tile.closedDoor
		end
	end

	--	postprocess: dig redundant links to make loops
	for i = 1, nLoops do
		local sourceRoom, destinationRoom
		repeat
			sourceRoom = math.random(1, #rooms)
			destinationRoom = math.random(1, #rooms)
		until	sourceRoom ~= destinationRoom and
					roomDistance(rooms[sourceRoom], rooms[destinationRoom]) < 20

		local sr, dr = rooms[sourceRoom], rooms[destinationRoom]
		local sx = math.floor((sr.x * 2 + sr.w) / 2)
		local sy = math.floor((sr.y * 2 + sr.h) / 2)
		local dx = math.floor((dr.x * 2 + dr.w) / 2)
		local dy = math.floor((dr.y * 2 + dr.h) / 2)

		--	corridors' start- and end-points can only be at even coordinates
		if sx % 2 == 1 then sx = sx + 1 end
		if sy % 2 == 1 then sy = sy + 1 end
		if dx % 2 == 1 then dx = dx + 1 end
		if dy % 2 == 1 then dy = dy + 1 end
		self:digLink(sx, sy, dx, dy, Tile.floor)
	end

	--	postprocess: surround corridors with wall tiles
	for i = 1, 80 do
		for j = 1, 20 do
			if	self.tile[i][j] == Tile.void and
					self:countNeighbours(i, j, Tile.floor) >= 1 then
				self.tile[i][j] = Tile.wall
			end
		end
	end

	--	postprocess: add rooms between rooms and corridors
	for i = 1, #rooms do
		for j = rooms[i].x, rooms[i].x + rooms[i].w - 1 do
			if self.tile[j][rooms[i].y] == Tile.floor then
				self.tile[j][rooms[i].y] = Tile.closedDoor
			end
			if self.tile[j][rooms[i].y + rooms[i].h - 1] == Tile.floor then
				self.tile[j][rooms[i].y + rooms[i].h - 1] = Tile.closedDoor
			end
		end

		for j = rooms[i].y, rooms[i].y + rooms[i].h - 1 do
			if self.tile[rooms[i].x][j] == Tile.floor then
				self.tile[rooms[i].x][j] = Tile.closedDoor
			end
			if self.tile[rooms[i].x + rooms[i].w - 1][j] == Tile.floor then
				self.tile[rooms[i].x + rooms[i].w - 1][j] = Tile.closedDoor
			end
		end
	end
end

--	Map:findRandomEmptySpace() - searches for a random empty space;
--	an empty space has a non-solid tile, and is occupied by no actor;
--	returns a pair of coordinates (x, y) which comply with the restrictions
function Map:findRandomEmptySpace()
	local x, y
	repeat
		x = math.random(1, 80)
		y = math.random(1, 20)
	until not self:isSolid(x, y) and
				not self:isOccupied(x, y)
	
	return x, y
end

return Map

