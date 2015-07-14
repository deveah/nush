// Utility to test curses keyboard handling.
// This includes VT220_KEYPAD define which has been left out of nush.c for
// simplicity, as it doesn't seem needed.

#include <string.h>
#include <stdlib.h>
#include <stdbool.h>
#include <signal.h>
#include <curses.h>

// Attempt to use VT220 keyboard emulation in xterm and libvte-base terminal
// emulators (e.g. gnome and xfce), which causes them to send separate escape
// codes for numpad keys which don't overlap with other keys like HOME.
#define VT220_KEYPAD

// Escape sequences to set and unset VT220 function key emulation
// DCSS also sends reset codes 1051, 1052, 1060 to disable other emulation
// types, probably not needed (see http://rtfm.etla.org/xterm/ctlseq.html)
#define SET_VT220_KEYPAD "\033[?1061h"
#define RESET_VT220_KEYPAD "\033[?1061l"

bool is_xterm = false;
bool vt220_keypad = false;

void quit( int i )
{
	(void)i;

	clear();
	refresh();
	endwin();
	if (vt220_keypad)
		puts(RESET_VT220_KEYPAD);	
	exit(0);
}

int main(void) {
	char *term = getenv("TERM");
	// Include screen because it also needs more keys defined
	is_xterm = term && (strstr(term, "xterm") || strstr(term, "screen"));

#ifdef VT220_KEYPAD
	if (is_xterm) {
		puts(SET_VT220_KEYPAD);
		vt220_keypad = true;
	}
#endif
	initscr();
	noecho();
	keypad(stdscr, TRUE);

	signal(SIGINT, quit);

	int y = 0;

	if (is_xterm) {

		if (vt220_keypad) {
			// VT220 keypad escape codes, of course not in terminfo for 'xterm'
			define_key("\033Oj", '*');
			define_key("\033Ol", '+'); // differs
			define_key("\033Om", '-');
			define_key("\033On", KEY_DC);  // delete
			define_key("\033Oo", '/');
			define_key("\033Op", KEY_IC);  // insert
			define_key("\033Oq", KEY_C1);  // numpad...
			define_key("\033Or", KEY_DOWN);
			define_key("\033Os", KEY_C3);
			define_key("\033Ot", KEY_LEFT);
			define_key("\033Ou", KEY_B2);
			define_key("\033Ov", KEY_RIGHT);
			define_key("\033Ow", KEY_A1);
			define_key("\033Ox", KEY_UP);
			define_key("\033Oy", KEY_A3);
			// Also, numpad enter may send KEY_ENTER instead of \n
			mvprintw(y++, 0, "Attempting to switch xterm-compatible to vt220 keyboard mode\n");
		} else {
			// For xterm & libvte
			define_key("\033Oj", '*');
			define_key("\033Ok", '+');  // differs
			define_key("\033Om", '-');
			define_key("\033Oo", '/');
		}

		// terminfo for TERM=xterm fails to list some escape codes for numpad keys;
		// which of the following don't work varies from terminal to terminal,
		// but every one I tried, plus screen, need some of these.
		// Some unknown subset of the diagonal keys overlaps with home/end/page up/down,
		// better to consistently make them all overlap
		//define_key("\033[1~", KEY_A1);
		//define_key("\033[4~", KEY_C1);
		//define_key("\033[6~", KEY_C3);
		//define_key("\033[5~", KEY_A3);
		define_key("\033[1~", KEY_HOME);
		define_key("\033[4~", KEY_END);
		define_key("\033[6~", KEY_NPAGE);
		define_key("\033[5~", KEY_PPAGE);
		define_key("\033[E",  KEY_B2);
		define_key("\033[2~", KEY_IC);
		define_key("\033[3~", KEY_DC);
		define_key("\033OM", '\n');  // for screen
		mvprintw(y++, 0, "Defining additional vt100 keys for xterm\n");
	}

	while (1) {
		int key = getch();
		mvprintw(y, 0, "Key = %d 0%o", key, key);
		if (key < 256)		mvprintw(y, 16, "%c", key);
		if (key == KEY_A1)	mvprintw(y, 20, "A1");
		if (key == KEY_UP)	mvprintw(y, 20, "up");
		if (key == KEY_A3)	mvprintw(y, 20, "A3");
		if (key == KEY_C1)	mvprintw(y, 20, "C1");
		if (key == KEY_DOWN)	mvprintw(y, 20, "down");
		if (key == KEY_C3)	mvprintw(y, 20, "C3");
		if (key == KEY_LEFT)	mvprintw(y, 20, "left");
		if (key == KEY_B2)	mvprintw(y, 20, "B2");
		if (key == KEY_RIGHT)	mvprintw(y, 20, "right");
		if (key == KEY_PPAGE)	mvprintw(y, 20, "pageup");
		if (key == KEY_NPAGE)	mvprintw(y, 20, "pagedown");
		if (key == KEY_END)	mvprintw(y, 20, "end");
		if (key == KEY_HOME)	mvprintw(y, 20, "home");
		if (key == KEY_IC)	mvprintw(y, 20, "insert");
		if (key == KEY_DC)	mvprintw(y, 20, "delete");
		if (key == KEY_ENTER)	mvprintw(y, 20, "enter");
		if (key == 'Q') break;
		y++;
		refresh();
	}
	quit(0);
	return 0;
}
