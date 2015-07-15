
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <curses.h>
#ifndef PDCURSES
	/* bool defined by PDcurses */
	#include <stdbool.h>
#endif


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
bool curses_running = 0;
int num_interrupts = 0;

static void curses_set_running( lua_State *L, int state )
{
	curses_running = state;

	lua_getglobal( L, "curses" );
	lua_pushinteger( L, state );
	lua_setfield( L, -2, "running" );
}

static int curses_init( lua_State *L )
{
	initscr();
	cbreak();
	noecho();
	keypad( stdscr, TRUE );

#ifndef PDCURSES
	char *term = getenv("TERM");
	/* Include screen because it also needs more keys defined */
	bool is_xterm = term && (strstr(term, "xterm") || strstr(term, "screen"));
	if (is_xterm) {
		/* terminfo for TERM=xterm fails to list some escape codes for numpad keys;
		// which of the following don't work varies from terminal to terminal,
		// but every one I tried, plus screen, need some of these. */
		define_key("\033Oj", '*');
		define_key("\033Ok", '+');
		define_key("\033Om", '-');
		define_key("\033Oo", '/');
		/* Some unknown subset of the diagonal keys overlaps with home/end/page up/down,
		// better to consistently make them all overlap
		//define_key("\033[1~", KEY_A1);
		//define_key("\033[4~", KEY_C1);
		//define_key("\033[6~", KEY_C3);
		//define_key("\033[5~", KEY_A3); */
		define_key("\033[1~", KEY_HOME);
		define_key("\033[4~", KEY_END);
		define_key("\033[6~", KEY_NPAGE);
		define_key("\033[5~", KEY_PPAGE);
		define_key("\033[E",  KEY_B2);
		define_key("\033[2~", KEY_IC);
		define_key("\033[3~", KEY_DC);
		define_key("\033OM", '\n');  /* for screen */
	}
#endif


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

	curses_set_running( L, 1 );

	int x, y;
	getmaxyx( stdscr, y, x );

	lua_pushinteger( L, x );
	lua_pushinteger( L, y );

	return 2;
}

static void exit_curses()
{
	if ( curses_running ) {
		/* clear and refresh needed for pdcurses */
		clear();
		refresh();
		endwin();
		curses_set_running( L, 0 );
	}
}

static int curses_terminate( lua_State *L )
{
	(void)L;
	exit_curses();

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
	/* The following may or may not be on numpad */
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
	case KEY_HOME:
		lua_pushstring( L, "home" );
		break;
	case KEY_END:
		lua_pushstring( L, "end" );
		break;
	case KEY_PPAGE:
		lua_pushstring( L, "pageup" );
		break;
	case KEY_NPAGE:
		lua_pushstring( L, "pagedown" );
		break;
	case KEY_IC:
		lua_pushstring( L, "insert" );
		break;
	case KEY_DC:
		lua_pushstring( L, "delete" );
		break;

	/* numpad */
	case KEY_A1:
		lua_pushstring( L, "upleft" );
		break;
	case KEY_A3:
		lua_pushstring( L, "upright" );
		break;
	case KEY_C1:
		lua_pushstring( L, "downleft" );
		break;
	case KEY_C3:
		lua_pushstring( L, "downright" );
		break;
	case KEY_B2:
		lua_pushstring( L, "numpad5" );
		break;

	case KEY_ENTER:
	case '\n':
		lua_pushstring( L, "enter" );
		break;

#ifdef PDCURSES
	/* more numpad keycodes */
	case KEY_A2:
		lua_pushstring( L, "up" );
		break;
	case KEY_C2:
		lua_pushstring( L, "down" );
		break;
	case KEY_B1:
		lua_pushstring( L, "left" );
		break;
	case KEY_B3:
		lua_pushstring( L, "right" );
		break;
	case PADPLUS:
		lua_pushstring( L, "+" );
		break;
	case PADMINUS:
		lua_pushstring( L, "-" );
		break;
	case PADSTAR:
		lua_pushstring( L, "*" );
		break;
	case PADSLASH:
		lua_pushstring( L, "/" );
		break;
	case PADENTER:
		lua_pushstring( L, "enter" );
		break;
#endif
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

/* Note: this doesn't accept numpad enter under pdcurses */
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
	{	"clearLine",	curses_clearline },
	{	"refresh",		curses_refresh },
	{	"move",			curses_move },
	{	"cursor",		curses_cursor },
	{	"getstr",		curses_getstr },
	{	NULL,			NULL }
};

/*
static void lstop( lua_State *L, lua_Debug *ar ) {
	(void)ar;  // unused arg.
	lua_sethook( L, NULL, 0, 0 );
	luaL_error( L, "interrupted!" );
}
*/

#ifndef __WIN32
void interrupt_handler( int i )
{
	(void)i;

	if (++num_interrupts > 1) {  /* If luaL_error doesn't work */
		if( curses_running )
			exit_curses();
		printf("Interrupted. (Second Ctrl-C)\n");
		exit(1);
	} else {
		/* This seems to work whether we're in C or lua. Lua longjmps to the
		// error handler, which should interrupt any C routine.
		// (Ideally, would try lua_sethook first, and print C backtrace on 2nd Ctrl-C) */
		luaL_error(L, "interrupted!");

		/* Once control returns to lua, set debug hook which immediately throws an error
		//lua_sethook(L, lstop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1); */
	}
}
#endif

int main( int argc, char **argv )
{
	#ifdef USE_LUAJIT
		L = lua_open();
	#endif

	#ifdef USE_LUA52
		L = luaL_newstate();
	#endif

	#ifdef USE_LUA51
		L = lua_open();
	#endif

	printf("Initialized lua.\n");

	luaL_openlibs( L );
	printf("Initialized lua libraries.\n");

	#if defined(USE_LUAJIT) || defined(USE_LUA51)
		luaL_register( L, "curses", curses );
	#endif

	#ifdef USE_LUA52
		luaL_newlib( L, curses );
		lua_setglobal( L, "curses" );
	#endif

	init_constants( L );
	printf("Registered curses namespace.\n");

	/* Set ctrl-C handler, portably */
#ifndef __WIN32
	struct sigaction sa;
	sa.sa_handler = interrupt_handler;
	sa.sa_flags = 0;
	sigemptyset( &sa.sa_mask );
	sigaction( SIGINT, &sa, NULL );
	printf("Registered interrupt handler.\n");
#endif

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
		exit_curses();

	/* This should only happen when the error handler throws an error */
	if( r )
	{
		printf( ERROR_STRING, lua_tostring( L, -1 ) );
	}

	return 0;
}

