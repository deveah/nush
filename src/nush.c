
#ifdef USE_LUAJIT
	#include <luajit-2.0/lua.h>
	#include <luajit-2.0/lualib.h>
	#include <luajit-2.0/lauxlib.h>
#endif

#ifdef USE_LUA52
	#include <lua.h>
	#include <lualib.h>
	#include <lauxlib.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <curses.h>

#define ERROR_STRING 		"Error: %s\n"
#define MAX_STRING_LENGTH 	80

#define C_BLACK				1
#define C_RED				2
#define C_GREEN				3
#define C_YELLOW			4
#define C_BLUE				5
#define C_MAGENTA			6
#define C_CYAN				7
#define C_WHITE				8


lua_State *L = NULL;
int curses_running = 0;

static int curses_init( lua_State *L )
{
	initscr();
	cbreak();
	noecho();
	keypad( stdscr, TRUE );

#ifndef __WIN32
	use_default_colors();
#endif
	
	start_color();

#ifndef __WIN32
	init_pair( C_BLACK, COLOR_BLACK, -1 );
	init_pair( C_RED, COLOR_RED, -1 );
	init_pair( C_GREEN, COLOR_GREEN, -1 );
	init_pair( C_YELLOW, COLOR_YELLOW, -1 );
	init_pair( C_BLUE, COLOR_BLUE, -1 );
	init_pair( C_MAGENTA, COLOR_MAGENTA, -1 );
	init_pair( C_CYAN, COLOR_CYAN, -1 );
	init_pair( C_WHITE, COLOR_WHITE, -1 );
#else
	init_pair( C_BLACK, COLOR_BLACK, 0 );
	init_pair( C_RED, COLOR_RED, 0 );
	init_pair( C_GREEN, COLOR_GREEN, 0 );
	init_pair( C_YELLOW, COLOR_YELLOW, 0 );
	init_pair( C_BLUE, COLOR_BLUE, 0 );
	init_pair( C_MAGENTA, COLOR_MAGENTA, 0 );
	init_pair( C_CYAN, COLOR_CYAN, 0 );
	init_pair( C_WHITE, COLOR_WHITE, 0 );
#endif

	curses_running = 1;

	int x, y;
	getmaxyx( stdscr, y, x );

	lua_pushinteger( L, x );
	lua_pushinteger( L, y );

	return 2;
}

static int curses_terminate( lua_State *L )
{
	(void) L;

	endwin();
	curses_running = 0;

	return 0;
}

static int curses_write( lua_State *L )
{
	int x = lua_tointeger( L, -3 ),
		y = lua_tointeger( L, -2 );
	char *s = (char*)lua_tostring( L, -1 );

	mvaddstr( y, x, s );

	return 0;
}

static int curses_getch( lua_State *L )
{
	char s[2];
	int c = getch();

	switch( c )
	{
	case KEY_UP:
		lua_pushstring( L, "up" );
		break;
	case KEY_DOWN:
		lua_pushstring( L, "down" );
		break;
	case KEY_LEFT:
		lua_pushstring( L, "left" );
		break;
	case KEY_RIGHT:
		lua_pushstring( L, "right" );
		break;
	case '\n':
		lua_pushstring( L, "enter" );
		break;
	default:
		s[0] = c;
		s[1] = 0;
		lua_pushstring( L, s );	
	}

	return 1;
}

static int curses_attr( lua_State *L )
{
	int a = lua_tointeger( L, -1 );
	
	attrset( a );

	return 0;
}

static int curses_clear( lua_State *L )
{
	(void) L;

	clear();

	return 0;
}

static int curses_clearline( lua_State *L )
{
	int y = lua_tointeger(L, -1);
	
	move( y, 0 );
	clrtoeol();

	return 0;
}

static int curses_refresh( lua_State *L )
{
	(void) L;

	refresh();

	return 0;
}

static int curses_move( lua_State *L )
{
	int x = lua_tointeger( L, -2 ),
		y = lua_tointeger( L, -1 );

	move( y, x );

	return 0;
}

static int curses_cursor( lua_State *L )
{
	int c = lua_tointeger( L, -1 );

	curs_set( c );

	return 0;
}

static int curses_getstr( lua_State *L )
{
	char str[MAX_STRING_LENGTH];

	echo();
	getnstr( str, MAX_STRING_LENGTH-1 );
	noecho();

	lua_pushstring( L, str );

	return 1;
}

void init_constants( lua_State *L )
{
	lua_getglobal( L, "curses" );

	lua_pushinteger( L, COLOR_PAIR( C_BLACK ) );
	lua_setfield( L, -2, "black" );

	lua_pushinteger( L, COLOR_PAIR( C_RED ) );
	lua_setfield( L, -2, "red" );

	lua_pushinteger( L, COLOR_PAIR( C_GREEN ) );
	lua_setfield( L, -2, "green" );

	lua_pushinteger( L, COLOR_PAIR( C_YELLOW ) );
	lua_setfield( L, -2, "yellow" );

	lua_pushinteger( L, COLOR_PAIR( C_BLUE ) );
	lua_setfield( L, -2, "blue" );
	
	lua_pushinteger( L, COLOR_PAIR( C_MAGENTA ) );
	lua_setfield( L, -2, "magenta" );
	
	lua_pushinteger( L, COLOR_PAIR( C_CYAN ) );
	lua_setfield( L, -2, "cyan" );
	
	lua_pushinteger( L, COLOR_PAIR( C_WHITE ) );
	lua_setfield( L, -2, "white" );

	lua_pushinteger( L, A_NORMAL );
	lua_setfield( L, -2, "normal" );

	lua_pushinteger( L, A_BOLD );
	lua_setfield( L, -2, "bold" );

	lua_pushinteger( L, A_REVERSE );
	lua_setfield( L, -2, "reverse" );
}

luaL_Reg curses[] = {
	{	"init",			curses_init },
	{	"terminate",	curses_terminate },
	{	"write",		curses_write },
	{	"getch",		curses_getch },
	{	"attr",			curses_attr },
	{	"clear",		curses_clear },
	{ "clearLine",	curses_clearline },
	{	"refresh",		curses_refresh },
	{	"move",			curses_move },
	{	"cursor",		curses_cursor },
	{	"getstr",		curses_getstr },
	{	NULL,			NULL }
};

static void lstop (lua_State *L, lua_Debug *ar) {
  (void)ar;  /* unused arg. */
  lua_sethook(L, NULL, 0, 0);
  luaL_error(L, "interrupted!");
}
void interrupt_handler( int i )
{
	/*	terminate curses */
	if( curses_running )
		endwin();
	
	lua_sethook(L, lstop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);

	exit(0);
}

int main( int argc, char **argv )
{
	#ifdef USE_LUAJIT
		L = lua_open();
	#endif

	#ifdef USE_LUA52
		L = luaL_newstate();
	#endif

	luaL_openlibs( L );

	#ifdef USE_LUAJIT
		luaL_register( L, "curses", curses );
	#endif

	#ifdef USE_LUA52
		luaL_newlib( L, curses );
		lua_setglobal( L, "curses" );
	#endif

	init_constants( L );

	signal( SIGINT, interrupt_handler );

	int r;

	if( argc < 2 )
	{
		r = luaL_dofile( L, "lua/main.lua" );
	}
	else
	{
		r = luaL_dofile( L, argv[1] );
	}

	if( curses_running )
		endwin();

	if( r )
	{
		printf( ERROR_STRING, lua_tostring( L, -1 ) );
	}

	return 0;
}

