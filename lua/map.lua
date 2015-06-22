
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
	for i = 1, #(self.gameInstance.actorList) do
		local actor = self.gameInstance.actorList[i]
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

return Map

