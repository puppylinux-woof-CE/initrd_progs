#CC = musl-gcc
#CC = musl-gcc --static
CC = gcc
CFLAGS = -W -Wall -Os -D_GNU_SOURCE -fno-strict-aliasing -Wno-multichar
LDFLAGS =
EXE = guess_fstype

default: $(EXE) tidy

$(EXE): guess_fstype.c main.c Makefile
	@echo "Single compile for guess_fstype ..."
	@$(CC) -o $@ guess_fstype.c main.c $(CFLAGS) $(LDFLAGS) -s
	@ls -l $@

tidy:
	@rm -f *.o *~ *.bak

clean: tidy
	@rm -f $(EXE)
install:
