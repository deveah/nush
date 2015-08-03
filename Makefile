
CC = gcc
CFLAGS = -Wall -Wextra -g -O1
# Whether to link with cursew for unicode support
CURSESW = 1
ifeq ($(OS),Windows_NT)
	CURSESW = 0
endif
ifeq ($(CURSESW),1)
	CURSES_LIBS = -lcursesw
	CFLAGS := $(CFLAGS) -DCURSESW
else
	CURSES_LIBS = -lcurses
endif
LUA52_LIBS = -llua
LUA51_LIBS = -llua
LUAJIT_LIBS = -lluajit-5.1

SOURCE = src/nush.c src/pathing.c
EXECUTABLE = nush
KEYTEST_EXE = keytest

all:  lua52

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

