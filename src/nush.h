
#ifdef USE_LUAJIT
	#include <luajit-2.0/lua.h>
	#include <luajit-2.0/lualib.h>
	#include <luajit-2.0/lauxlib.h>
#endif

#if defined(USE_LUA52) || defined(USE_LUA51)
	#include <lua.h>
	#include <lualib.h>
	#include <lauxlib.h>
#endif

/*	Lua 5.1 doesn't have lua_rawlen(), but instead lua_objlen() */
#if LUA_VERSION_NUM < 502
	#define lua_rawlen lua_objlen
#endif

/* In nush.c */
extern long long microseconds();
extern void log_printf( char *fmt, ... ) __attribute__((format (printf, 1, 2)));


/* In pathing.c */

/* Type used to store distances and values in LuaMap and Dijkstra and A* */
typedef float disttype;

/* A 2D array of int read from/written to a 2D grid of Tiles */
typedef struct {
	int tiles_index;/* index in lua stack of the table which is the Tiles grid */
	int attr_index; /* index in stack of string used as key on Tiles to get the cost */
	int w, h;
	disttype *tiles;/* [w+1][h+1] grid of values with nothing stored at x=0 or y=0;
                           set to CMAP_UNCACHED_TILE if hasn't been loaded from lua */
} LuaMap;

LuaMap *LuaMap_new(int tiles_index, int w, int h, int attr_index, disttype initval);
void LuaMap_free(LuaMap *map);
void LuaMap_push(LuaMap *map);

LuaMap *compute_dijkstra_map( LuaMap *map, int x, int y, disttype maxcost );

extern lua_State *L;
