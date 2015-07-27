
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

/*	Lua 5.1 doesn't have lua_len(), but instead lua_objlen() */
#if !defined(lua_rawlen)
	#define lua_xlen lua_objlen
#else
	#define lua_xlen lua_rawlen
#endif

/* In nush.c */
extern long long microseconds();
extern void log_printf( char *fmt, ... ) __attribute__((format (printf, 1, 2)));


/* In pathing.c */

/* A 2D array of int read from/written to a 2D grid of Tiles */
typedef struct {
	int tiles_index;/* index in lua stack of the table which is the Tiles grid */
	int cost_key;   /* index in stack of string used as key on Tiles to get the cost */
	int w, h;
	int *tiles;     /* [w+1][h+1] grid of values with nothing stored at x=0 or y=0;
                           set to CMAP_UNCACHED_TILE if hasn't been loaded from lua */
} LuaMap;

LuaMap *LuaMap_new(int tiles_index, int w, int h, int cost_key, int initval);
void LuaMap_free(LuaMap *map);
void LuaMap_push(LuaMap *map);

LuaMap *compute_dijkstra_map( LuaMap *map, int x, int y, int maxcost );

extern lua_State *L;
