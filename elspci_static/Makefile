CC = gcc
CFLAGS = -Wall -O2 # -pedantic
LDFLAGS =

all: elspci

elspci : elspci.c
	$(CC) -o $@ ${CFLAGS} $(LDFLAGS) $^

clean:
	-rm -f elspci *~ core
