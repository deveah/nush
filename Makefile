
CC = gcc
CFLAGS = -Wall -Wextra -g
LUA52_LIBS = -lcurses -llua
LUA51_LIBS = -lcurses -llua
LUAJIT_LIBS = -lcurses -lluajit-5.1

SOURCE = src/nush.c
EXECUTABLE = nush
KEYTEST_EXE = keytest

all:
	make lua52

lua52:
	$(CC) $(SOURCE) -o $(EXECUTABLE) $(LUA52_LIBS) $(CFLAGS) -DUSE_LUA52

lua51:
	$(CC) $(SOURCE) -o $(EXECUTABLE) $(LUA52_LIBS) $(CFLAGS) -DUSE_LUA51

luajit:
	$(CC) $(SOURCE) -o $(EXECUTABLE) $(LUAJIT_LIBS) $(CFLAGS) -DUSE_LUAJIT

keytest:
	$(CC) src/keytest.c -o $(KEYTEST_EXE) $(CFLAGS) -lcurses

clean:
	rm $(EXECUTABLE) $(KEYTEST_EXE)

