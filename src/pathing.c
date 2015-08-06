/* -*- c-basic-offset: 8 -*- */
/* This file contains A*, Dijkstra, reading from/writing out 2D grids of Lua
   values, and priority queues */

#include <stdio.h>
#include <stdlib.h>
#include "nush.h"


/* Dijkstra/A* node */
typedef struct {
	disttype f;   /* sorted by */
	disttype g;
	unsigned short x, y;  /* Count from 1! */
} Node;


/* Returns true if Qelem at index idx1 is <= in order to idx2 */
static int lesseq(Node lhs, Node rhs) {
	return lhs.f <= rhs.f;
}

void error(const char *msg) {
	log_printf("%s", msg);
	luaL_error(L, msg);
}


/****************************** Priority Queue *******************************/
/* Binary heap priority queue to retrieve minimum element */


/* Element of the priority queue (passed around by value) */
typedef Node Qelem;

typedef struct { 
	Qelem *data;
	int size;
	int allocated;
} PQueue;

PQueue *PQueue_new()
{
	PQueue *pq = malloc(sizeof(PQueue));
	pq->size = 0;
	pq->allocated = 48;
	pq->data = malloc(sizeof(Qelem) * pq->allocated);
	return pq;
}

void PQueue_free(PQueue *pq)
{
	free(pq->data);
}

int PQueue_size(PQueue *pq)
{
	return pq->size;
}

#define LEFT_CHILD(idx) (2*idx+1)
#define PARENT(idx) ((idx-1)/2)

/* Return a least element */
Qelem PQueue_pop(PQueue *pq)
{
	if (!pq->size)
		error("pop from empty queue");

	Qelem ret = pq->data[0];

	/* Bubble up the hole from root until finding a spot to put to_insert */
	int hole = 0;
	Qelem to_insert = pq->data[--pq->size];  /* pop off end */
	while (LEFT_CHILD(hole) < pq->size)
	{
		/* Find the smallest child */
		int left_child = LEFT_CHILD(hole), right_child = left_child + 1;
		int smallest = left_child;
		if (right_child < pq->size && lesseq(pq->data[right_child], pq->data[left_child]))
			smallest = right_child;

		if (lesseq(to_insert, pq->data[smallest]))
			break;  /* smaller than both children */
		pq->data[hole] = pq->data[smallest];
		hole = smallest;
	}
	pq->data[hole] = to_insert;

	return ret;
}

void PQueue_push(PQueue *pq, Qelem element)
{
	if (pq->size == pq->allocated)
	{
		pq->allocated *= 2;
		pq->data = realloc(pq->data, sizeof(Qelem) * pq->allocated);
	}

	/* Bubble down the value until its parent isn't larger */
	int hole = pq->size++;  /* where to place */
	while (hole > 0)
	{
		int parent = PARENT(hole);
		if (lesseq(pq->data[parent], element))
			break;
		pq->data[hole] = pq->data[parent];
		hole = parent;
	}
	pq->data[hole] = element;
}


/********************************** LuaMap ***********************************/
/* Lazily query a lua list-of-lists data structure encoding a map,
   caching previous results. */


#define LUAMAP_UNCACHED_TILE -424242.

/* Create a LuaMap that isn't linked to a Lua value, just filled with an
   initial value. */
LuaMap *LuaMap_new(int w, int h, disttype initval)
{
	LuaMap *map = malloc(sizeof(LuaMap));
	map->tiles_index = 0;   /* marks this LuaMap as not tied to a table */
	map->attr_index = 0;    /* unused */
	map->default_value = 0; /* unused */
	map->w = w;
	map->h = h;
	map->tiles = malloc(sizeof(disttype) * (w + 1) * (h + 1));
	int i;
	for (i = 0; i < (w+1)*(h+1); i++)
		map->tiles[i] = initval;
	return map;
}

/* Create a LuaMap that caches the values in a lua 2D grid (list-of-lists).
   tiles_index:   Lua stack index of the grid.
   attr_index:    0 if it's a grid of raw values, or the Lua stack index of a
                  string to use as a key.
   default_value: Value assigned to 'nil' tiles.
*/
LuaMap *LuaMap_from_table(int tiles_index, int attr_index, int w, int h, disttype default_value)
{
	/* Tiles start uncached only if there's a table to read from */
	LuaMap *ret = LuaMap_new(w, h, LUAMAP_UNCACHED_TILE);
	ret->tiles_index = tiles_index;
	ret->attr_index = attr_index;
	ret->default_value = default_value;
	return ret;
}

void LuaMap_free(LuaMap *map)
{
	free(map->tiles);
}

disttype LuaMap_read(LuaMap *map, int x, int y)
{
	int to_pop = 0;
	disttype *tile = &map->tiles[(x - 1) + (y - 1) * map->w];
	if (*tile != LUAMAP_UNCACHED_TILE)
		return *tile;
	if (!map->tiles_index)
		error("LuaMap_read() called on a LuaMap without a table data source");

	/* Read the value from the map */
	lua_rawgeti(L, map->tiles_index, x);    /* push tiles[x] */
	lua_rawgeti(L, -1, y);                  /* push tiles[x][y] */
	to_pop = 2;
	if (map->attr_index)                    /* get an attribute of tiles[x][y] */
	{
		to_pop++;
		lua_pushvalue(L, map->attr_index);
		lua_gettable(L, -2);            /* pop key and push cost */
	}
	/* Convert to value */
	int type = lua_type(L, -1);
	if (type == LUA_TBOOLEAN)               /* tiles[x][y].key */
	{
		if (lua_toboolean(L, -1))
			*tile = 999999;         /* true: impassable */
		else
			*tile = 1;              /* cost = 1 for cost maps */
	}
	else if (type == LUA_TNIL)
		*tile = map->default_value;
	else
		*tile = lua_tonumber(L, -1);
	lua_pop(L, to_pop);

	return *tile;
}

void LuaMap_write(LuaMap *map, int x, int y, disttype value)
{
	map->tiles[(x - 1) + (y - 1) * map->w] = value;
}

/* Push this map of onto the lua stack as a 2D list-of-lists-of-ints.
   Tiles which haven't been set with LuaMap_write() become 'false' */
void LuaMap_push(LuaMap *map)
{
	lua_createtable(L, map->w, 0);

	int x, y;
	for (x = 1; x <= map->w; x++)
	{
		lua_createtable(L, map->h, 0);
		for (y = 1; y <= map->h; y++)
		{
			disttype value = map->tiles[(x - 1) + (y - 1) * map->w];
			if (value == LUAMAP_UNCACHED_TILE)
				lua_pushboolean(L, 0);
			else
				lua_pushnumber(L, value);
			lua_rawseti(L, -2, y);
		}
		lua_rawseti(L, -2, x);
	}
}


/********************************* Dijkstra map ******************************/


/* compute_dijkstra_map internal */
static void dijvisit(PQueue *pq, LuaMap *map, LuaMap *dists, Node parent, int xoff, int yoff)
{
	int x = parent.x + xoff, y = parent.y + yoff;
	if (x < 1 || x > map->w || y < 1 || y > map->h)
		return;

	disttype cost = parent.f + LuaMap_read(map, x, y);
	/* Give a slight penalty to diagonal moves, to prevent unnecessary zig-zagging */
	if (xoff && yoff)
		cost += 0.001;

	/* Check against best known cost both before and after pushing/popping from PQ */
	if (cost < LuaMap_read(dists, x, y))
	{
		Node node;
		node.f = cost;
		node.x = x; node.y = y;
		PQueue_push(pq, node);
	}
}

/* Starting from roots pushed into pq, update distmap with minimal distances from roots.
   costmap: A map giving the cost to step onto each tile.
   distmap: Initially filled with either a large constant (maxcost) if unvisited,
            or a lower value if a goal node.
 */
static void compute_dijkstra(PQueue *pq, LuaMap *costmap, LuaMap *distmap)
{
	while (PQueue_size(pq))
	{
		Node node = PQueue_pop(pq);
		/* Skip if not better than known */
		if (node.f >= LuaMap_read(distmap, node.x, node.y))
			continue;
		LuaMap_write(distmap, node.x, node.y, node.f);

		int xoff, yoff;
		for (xoff = -1; xoff <= 1; xoff++)
		{
			for (yoff = -1; yoff <= 1; yoff++)
			{
				if (xoff || yoff)
					dijvisit(pq, costmap, distmap, node, xoff, yoff);
			}
		}
	}
}

/* Computes a LuaMap giving the weighted shortest-path distance from (x,y) to
   every tile up to maxcost cost away. Unreached tiles have the value maxcost. */
LuaMap *single_source_dijkstra_map(LuaMap *costmap, int x, int y, disttype maxcost)
{
	PQueue *pq = PQueue_new();
	LuaMap *distmap = LuaMap_new(costmap->w, costmap->h, maxcost);

	/* Start node. We store the distance in Node.f */
	Node node;
	node.f = 0;
	node.x = x; node.y = y;
	PQueue_push(pq, node);

	compute_dijkstra(pq, costmap, distmap);
	PQueue_free(pq);
	return distmap;
}

/* Computes for every 'tile' the minimum over all goals of
   min(maxcost, distance(goal, tile) + cost of goal tile). */
void multiple_source_dijkstra_map(LuaMap *costmap, LuaMap *distmap, disttype maxcost)
{
	PQueue *pq = PQueue_new();

	/* Find all sources in distmap and push them onto the queue.
	   Possible optimisation would be to use lua_next to only visit
	   tiles that aren't nil. */
	int x, y;
	for (x = 1; x <= distmap->w; x++)
	{
		for (y = 1; y <= distmap->h; y++)
		{
			disttype value = LuaMap_read(distmap, x, y);
			if (value < maxcost)
			{
				Node node;
				node.f = value;
				node.x = x; node.y = y;
				PQueue_push(pq, node);
			}
			/* Write maxcost to this tile even if it's a goal, so
			   that when it's popped off the queue it isn't
			   immediately disregarded. */
			LuaMap_write(distmap, x, y, maxcost);
		}
	}

	log_printf("multiple_source_dijkstra_map: found and pushed %d sources", pq->size);
	compute_dijkstra(pq, costmap, distmap);
	PQueue_free(pq);
	return;
}

/*********************************** Testing *********************************/

/*
int main() {
	srand(time(NULL));

	PQueue *pq = PQueue_new();
	Node n;

	int i, j;
	for (i = 0; i < 1000; i++) {
		n.value = rand() % 90;
		PQueue_push(pq, n);
	}

	while (PQueue_size(pq)) {
		n = PQueue_pop(pq);
		printf("%d ", n.value);
	}
	puts("\n");

	PQueue_free(pq);
	return 0;
}
*/
