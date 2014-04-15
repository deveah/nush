
CC = gcc
CFLAGS = -Wall -Wextra -g
LUA52_LIBS = -lcurses -llua
LUAJIT_LIBS = -lcurses -lluajit-5.1

SOURCE = src/mazga.c
EXECUTABLE = mazga

all:
	make lua52

lua52:
	$(CC) $(SOURCE) -o $(EXECUTABLE) $(LUA52_LIBS) $(CFLAGS) -DUSE_LUA52

luajit:
	$(CC) $(SOURCE) -o $(EXECUTABLE) $(LUAJIT_LIBS) $(CFLAGS) -DUSE_LUAJIT

clean:
	rm $(EXECUTABLE)

