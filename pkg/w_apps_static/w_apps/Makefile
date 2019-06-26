CC = gcc
STRIP = strip
#CC = musl-gcc
STATIC = -static

all: debdb2pupdb \
	find_cat \
	findpkgs-dep-helper \
	findpkgs-search-helper \
	pup_event_frontend_d \
	vercmp

debdb2pupdb:
	$(CC) $(STATIC) -O3 -fomit-frame-pointer -ffunction-sections -fdata-sections -fmerge-all-constants -Wl,--sort-common -Wl,-gc-sections -o debdb2pupdb debdb2pupdb.c
	$(STRIP) debdb2pupdb

find_cat:
	$(CC) $(STATIC) -O3 -fomit-frame-pointer -ffunction-sections -fdata-sections -fmerge-all-constants -Wl,--sort-common -Wl,-gc-sections -o find_cat find_cat.c
	$(STRIP) find_cat

findpkgs-dep-helper:
	$(CC) $(STATIC) -O3 -fomit-frame-pointer -ffunction-sections -fdata-sections -fmerge-all-constants -Wl,--sort-common -Wl,-gc-sections -o findpkgs-dep-helper findpkgs-dep-helper.c
	$(STRIP) findpkgs-dep-helper

findpkgs-search-helper:
	$(CC) $(STATIC) -O3 -fomit-frame-pointer -ffunction-sections -fdata-sections -fmerge-all-constants -Wl,--sort-common -Wl,-gc-sections -o findpkgs-search-helper findpkgs-search-helper.c
	$(STRIP) findpkgs-search-helper

pup_event_frontend_d:
	$(CC) $(STATIC) -O3 -fomit-frame-pointer -ffunction-sections -fdata-sections -fmerge-all-constants -Wl,--sort-common -Wl,-gc-sections -o pup_event_frontend_d pup_event_frontend_d.c
	$(STRIP) pup_event_frontend_d

vercmp:
	$(CC) $(STATIC) -O3 -fomit-frame-pointer -ffunction-sections -fdata-sections -fmerge-all-constants -Wl,--sort-common -Wl,-gc-sections -o vercmp vercmp.c
	$(STRIP) vercmp

clean:
	rm -f debdb2pupdb find_cat findpkgs-dep-helper findpkgs-search-helper vercmp pup_event_frontend_d
