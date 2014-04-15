
CC = gcc
CFLAGS = -Wall -Wextra -g
LIBS = -lcurses -llua

SOURCE = src/mazga.c
EXECUTABLE = mazga

lua52:
	$(CC) $(SOURCE) -o $(EXECUTABLE) $(LIBS) $(CFLAGS) -DUSE_LUA52

luajit:
	$(CC) $(SOURCE) -o $(EXECUTABLE) $(LIBS) $(CFLAGS) -DUSE_LUAJIT

clean:
	rm $(EXECUTABLE)

