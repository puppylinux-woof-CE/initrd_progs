initrd_progs
============

programs, including busybox, statically linked for the initial ram disk


This should produce all the statically linked programs required for a Puppy Linux initrd.gz

Usage
-----
Run `./build_all.sh` 

- hopefully a uClibc build environment downloads and nev vars are set up from http://landley.net/aboriginal/
- musl libc http://www.musl-libc.org is REQUIRED as not everything builds with uClibc
- you can do builds individually, if you can't figure it out, ask!

BUGS
----
Probably lots of them. I only did breif testing in Slacko64
- 64 bit uClibc doesn't download. You can build it manually
- possibly some builds aren't cleaned properly
- some builds revert to normal gcc
- some hard coding (especially build triplet - to be resolved shortly)
