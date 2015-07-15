
CC = gcc
CFLAGS = -Wall -Wextra -g
CURSES_LIBS = -lcurses
LUA52_LIBS = -llua
LUA51_LIBS = -llua
LUAJIT_LIBS = -lluajit-5.1

SOURCE = src/nush.c
EXECUTABLE = nush
KEYTEST_EXE = keytest

all:
	make lua52

lua52:
	$(CC) $(SOURCE) -o $(EXECUTABLE) $(CURSES_LIBS) $(LUA52_LIBS) $(CFLAGS) -DUSE_LUA52

lua51:
	$(CC) $(SOURCE) -o $(EXECUTABLE) $(CURSES_LIBS) $(LUA52_LIBS) $(CFLAGS) -DUSE_LUA51

luajit:
	$(CC) $(SOURCE) -o $(EXECUTABLE) $(CURSES_LIBS) $(LUAJIT_LIBS) $(CFLAGS) -DUSE_LUAJIT

keytest:
	$(CC) src/keytest.c -o $(KEYTEST_EXE) $(CURSES_LIBS) $(CFLAGS)

# Ignore 'keytest' unix executable under Windows
.PHONY: keytest

clean:
	rm $(EXECUTABLE) $(KEYTEST_EXE)

