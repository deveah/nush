
#ifdef CURSESW
	/* Wide-char curses is an X/Open extension, but defining this
	   apparently isn't needed just to get utf8 support. */
	#define _XOPEN_SOURCE_EXTENDED 1
#endif

#ifdef __WIN32
	#define WIN32_LEAN_AND_MEAN
	#include <windows.h>
#else
	#include <sys/time.h>
	#include <langinfo.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <ctype.h>
#include <locale.h>
#include <time.h>
#include <unistd.h>
#include <signal.h>
#include <curses.h>
#ifndef PDCURSES
	/* bool defined by PDcurses */
	#include <stdbool.h>
#endif

#include "nush.h"

#define ERROR_STRING 		"Error: %s"
#define MAX_STRING_LENGTH 	80
#define LOGFILE			"log.txt"  /* Also defined in lua/global.lua */

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
bool utf8_enabled = 0;
int num_interrupts = 0;


/******************************** Utility Functions *************************/

/* microseconds since some arbitrary reference point */
long long microseconds() {
#ifdef __WIN32
	FILETIME systime;
	GetSystemTimeAsFileTime( &systime );
	return (((long long)systime.dwHighDateTime << 32)
		+ systime.dwLowDateTime) / 10LL;
#else
	struct timeval tv;
	gettimeofday( &tv, NULL );
	return tv.tv_sec * 1000000LL + tv.tv_usec;
#endif
}

/* Logs to the same file as Log:write() */
void log_printf( char *fmt, ... )
{
	FILE *file = fopen( LOGFILE, "a" );
	if ( !file )
		return;
	time_t thetime = time( NULL );
	char timestr[100];
	strftime( timestr, 100, "%c", localtime( &thetime ) );
	fprintf( file, "%s [C]: ", timestr );
	va_list ap;
	va_start( ap, fmt );
	vfprintf( file, fmt, ap );
	va_end( ap );
	fprintf( file, "\n" );
	fclose( file );
}

/* If a table is at the top of the lua stack, sets a field of it with an
   integer value; the table remains */
static void setfield_int( char *key, int val )
{
	lua_pushinteger( L, val );
	lua_setfield( L, -2, key );
}

/* If the nth function argument is a string, returns it, otherwise throw an
   error. Like luaL_checkstring() but that accepts integers */
static char *checkstring( lua_State *L, int arg )
{
	luaL_checktype( L, arg, LUA_TSTRING );
	return (char *)luaL_checkstring( L, arg );
}


/***************************** Curses IO library ****************************/

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

#ifdef NCURSES_VERSION
	log_printf( "ncurses %s.%d  NCURSES_WIDECHAR=%d", NCURSES_VERSION, NCURSES_VERSION_PATCH, NCURSES_WIDECHAR );
#elif defined(PDCURSES)
	log_printf( "pdcurses %d", PDC_BUILD );
#endif

#ifndef PDCURSES
	char *term = getenv("TERM");
	log_printf( "TERM=%s", term );
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
	log_printf( "COLORS=%d, COLOR_PAIRS=%d", COLORS, COLOR_PAIRS );

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
		curs_set( 1 );
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
	int x = luaL_checkinteger( L, 1 ),
		y = luaL_checkinteger( L, 2 );
	char *s = checkstring( L, 3 );

	mvaddstr( y, x, s );

	return 0;
}

static int curses_getch( lua_State *L )
{
	char s[4];
	int fkey, c = getch();

	for ( fkey = 1; fkey <= 15; fkey++ )
	{
		if ( c == KEY_F(fkey) ) {
			sprintf( s, "F%d", fkey );
			lua_pushstring( L, s );
			return 1;
		}
	}

	switch( c )
	{
	case '\x1b':  /* ESC / ^[ */
		lua_pushstring( L, "escape" );
		break;

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
	case PADSTOP:
		lua_pushstring( L, "delete" );
		break;
	case PAD0:
		lua_pushstring( L, "insert" );
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
	int a = luaL_checkinteger( L, 1 );
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
	int y = luaL_checkinteger( L, 1 );
	
	move( y, 0 );
	clrtoeol();

	return 0;
}


/* curses.clearbox(int width, int height) - clear every position in a box down-right from current
   cursor position. Doesn't move cursor; resets attributes. */
static int curses_clearbox( lua_State *L )
{
	int x, y;
	getyx( stdscr, y, x );
	int width = luaL_checkinteger( L, 1 );
	int height = luaL_checkinteger( L, 2 );

	/*chtype bkgd = getbkgd( stdscr );*/
	int xoff, yoff;
	attrset( A_NORMAL );
	for ( yoff = 0; yoff < height; yoff++ )
	{
		move( y + yoff, x );
		for ( xoff = 0; xoff < width; xoff++ )
			addch( ' ' );
	}

	move( y, x );
	return 0;
}

static int curses_refresh( lua_State *L )
{
	(void) L;

	refresh();

	return 0;
}

/* curses.redraw() - Cause the screen to be redrawn */
static int curses_redraw( lua_State *L )
{
	(void) L;
	/* touchwin/redrawwin works in ncurses, but not pdcurses under
	   Windows */
	clearok(stdscr, 1);
	return 0;
}

static int curses_move( lua_State *L )
{
	int x = luaL_checkinteger( L, 1 ),
		y = luaL_checkinteger( L, 2 );

	move( y, x );

	return 0;
}

static int curses_cursor( lua_State *L )
{
	int c = luaL_checkinteger( L, 1 );

	curs_set( c );

	return 0;
}

/* curses.vline(int length) - draw down from current cursor position */
static int curses_vline( lua_State *L )
{
	int length = luaL_checkinteger( L, 1 );
	vline( 0, length );
	return 0;
}

/* curses.hline(int length) - draw across from current cursor position */
static int curses_hline( lua_State *L )
{
	int length = luaL_checkinteger( L, 1 );
	hline( 0, length );
	return 0;
}

/* curses.box(int width, int height) - draw a box down-right from current
   cursor position. Doesn't move cursor. */
static int curses_box( lua_State *L )
{
	int x, y;
	getyx( stdscr, y, x );
	int width = luaL_checkinteger( L, 1 );
	int height = luaL_checkinteger( L, 2 );

	/* Drawing using box characters (vt100 or DOS codepage or fallback) */
	int xoff, yoff;
	addch( ACS_ULCORNER );
	for ( xoff = 1; xoff < width - 1; xoff++ )
		addch( ACS_HLINE );
	addch( ACS_URCORNER );
	for ( yoff = 1; yoff < height - 1; yoff++ )
	{
		mvaddch( y + yoff, x, ACS_VLINE );
		mvaddch( y + yoff, x + width - 1, ACS_VLINE );
	}
	move( y + height - 1, x );
	addch( ACS_LLCORNER );
	for ( xoff = 1; xoff < width - 1; xoff++ )
		addch( ACS_HLINE );
	addch( ACS_LRCORNER );

	move( y, x );
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

static void push_color_pair( char *name, int pairnum )
{
	setfield_int( name, COLOR_PAIR( pairnum ) );

	/* Convert 'name' to all-caps and push the bold version */
	char allcaps[32], *outch = allcaps;
	do {
		*outch++ = toupper( *name++ );
	} while ( *name );
	*outch = '\0';
	setfield_int( allcaps, COLOR_PAIR( pairnum ) + A_BOLD );
}

void init_constants( lua_State *L )
{
	lua_getglobal( L, "curses" );

	push_color_pair( "black",   C_BLACK );
	push_color_pair( "red",	    C_RED );
	push_color_pair( "green",   C_GREEN );
	push_color_pair( "yellow",  C_YELLOW );
	push_color_pair( "blue",    C_BLUE );
	push_color_pair( "magenta", C_MAGENTA );
	push_color_pair( "cyan",    C_CYAN );
	push_color_pair( "white",   C_WHITE );

	setfield_int( "normal",     A_NORMAL );
	setfield_int( "bold",       A_BOLD );
	setfield_int( "reverse",    A_REVERSE );
	/* The following three don't work widely, avoid using!! */
	setfield_int( "underline",  A_UNDERLINE ); /* Not on Windows */
	setfield_int( "standout",   A_STANDOUT );  /* Unpredictable */
	setfield_int( "blink",      A_BLINK );

	/* curses.utf8 says whether outputting utf8 is OK */
	lua_pushboolean( L, utf8_enabled );
	lua_setfield( L, -2, "utf8" );

	lua_pop( L, 1 );
}

luaL_Reg curses[] = {
	{	"init",			curses_init },
	{	"terminate",	curses_terminate },
	{	"write",		curses_write },
	{	"getch",		curses_getch },
	{	"attr",			curses_attr },
	{	"clear",		curses_clear },
	{	"clearLine",	curses_clearline },
	{	"clearBox",		curses_clearbox },
	{	"refresh",		curses_refresh },
	{	"redraw",		curses_redraw },
	{	"move",			curses_move },
	{	"cursor",		curses_cursor },
	{	"vline",		curses_vline },
	{	"hline",		curses_hline },
	{	"box",			curses_box },
	{	"getstr",		curses_getstr },
	{	NULL,			NULL }
};


/*************************** clib extended library **************************/

/* clib.sleep(seconds) - sleep for some number of seconds, with precision
   of at least 10 milliseconds */
static int clib_sleep( lua_State *L )
{
	double seconds = luaL_checknumber( L, 1 );
	if (seconds < 0)
		return 0;
#ifdef __WIN32
	/* Precision is only 10ms (or maybe 15ms?) */
	Sleep(seconds * 1e3);
#else
	usleep(seconds * 1e6);
#endif
	return 0;
}

/* clib.time() - Returns a time stamp in seconds, will millisecond precision,
   unlike lua's os.time() which has seconds precision. */
static int clib_time( lua_State *L )
{
	lua_pushnumber( L, 1e-6 * microseconds() );

	return 1;
}

/* clib.dijkstraMap(tiles, x, y, maxcost) - Given a 2D grid of Tiles, return a
   2D grid of ints giving the distance from (x,y) to every tile < maxcost away.
   Unreached tiles have the value maxcost. */
static int clib_dijkstramap( lua_State *L )
{
	long long spent_us = microseconds();

	int tiles_index = 1; /* first arg */
	luaL_checktype( L, tiles_index, LUA_TTABLE );

	/* Find map width and height */
	int w = lua_rawlen( L, tiles_index );
	lua_rawgeti( L, tiles_index, 1); /* tiles[1] */
	luaL_checktype( L, -1, LUA_TTABLE );
	int h = lua_rawlen( L, -1 );
	lua_pop( L, 1 );
	if ( h > 65535 || w > 65535 )
		luaL_error( L, "maps larger than 65535*65535 are unsupported" );

	if ( lua_type( L, 2 ) )

	int x = luaL_checkinteger( L, 2 );
	int y = luaL_checkinteger( L, 3 );
	double maxcost = luaL_checknumber( L, 4 );

	/* Member of Tile used for cost of a tile,
	   which should be either a bool or int */
	lua_pushstring( L, "solid" );
	int attr_index = lua_gettop( L );

	LuaMap *costmap = LuaMap_new( tiles_index, w, h, attr_index, 0 );
	LuaMap *dijkstra = compute_dijkstra_map( costmap, x, y, maxcost );
	LuaMap_push( dijkstra );
	LuaMap_free( dijkstra );
	LuaMap_free( map );

	spent_us = microseconds() - spent_us;
	log_printf("dijkstraMap done in %fs", spent_us * 1e-6);

	return 1;
}


luaL_Reg clib[] = {
	{	"sleep",		clib_sleep },
	{	"time",			clib_time },
	{	"dijkstraMap",		clib_dijkstramap },
	{	NULL,			NULL }
};


/************************************ main() ********************************/


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
	/* Delete log file here rather than in lua so that we can log to it
	   before log.lua runs */
	remove( LOGFILE );

	/* Reduce Esc delay to 100ms (there is no delay on Windows) */
#ifdef NCURSES_VERSION
	ESCDELAY = 100;
#endif

	setlocale( LC_CTYPE, "" );
#ifdef __WIN32
	/* Seems to lie, maybe pdcurses changes something */
	log_printf( "Codepage is %d", GetConsoleOutputCP() );
#else
	char *codeset = nl_langinfo( CODESET );
	utf8_enabled = strcmp( codeset, "UTF-8" ) == 0;
	log_printf( "Character set %s", codeset );
#endif

	#ifdef USE_LUAJIT
		L = lua_open();
	#endif

	#ifdef USE_LUA52
		L = luaL_newstate();
	#endif

	#ifdef USE_LUA51
		L = lua_open();
	#endif

	log_printf("Initialized lua.");

	luaL_openlibs( L );
	log_printf("Initialized lua libraries.");

	#if defined(USE_LUAJIT) || defined(USE_LUA51)
		luaL_register( L, "curses", curses );
		luaL_register( L, "clib", clib );
	#endif

	#ifdef USE_LUA52
		luaL_newlib( L, curses );
		lua_setglobal( L, "curses" );
		luaL_newlib( L, clib );
		lua_setglobal( L, "clib" );
	#endif

	init_constants( L );
	log_printf("Registered C libraries.");

	/* Set ctrl-C handler, portably */
#ifndef __WIN32
	struct sigaction sa;
	sa.sa_handler = interrupt_handler;
	sa.sa_flags = 0;
	sigemptyset( &sa.sa_mask );
	sigaction( SIGINT, &sa, NULL );
	log_printf("Registered interrupt handler.");
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

	log_printf("Shutting down.");
	if( curses_running )
	{
		log_printf("Unclean exit, exiting curses");
		exit_curses();
	}

	/* This should only happen when the error handler throws an error */
	if( r )
	{
		printf( ERROR_STRING "\n", lua_tostring( L, -1 ) );
		log_printf( ERROR_STRING, lua_tostring( L, -1 ) );
	}

	return 0;
}
