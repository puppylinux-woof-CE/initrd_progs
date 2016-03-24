CC = gcc
CFLAGS = -Wall
LDFLAGS = 

all : vercmp

vercmp : vercmp.c
	$(CC) -o $@ ${CFLAGS} $(LDFLAGS) $^
	
clean :
	rm vercmp