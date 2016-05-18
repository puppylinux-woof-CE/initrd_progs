VERSION=1.0
RPM_TOPDIR=rpm.topdir
RPM_BUILDROOT=rpm.buildroot
CC = gcc
CFLAGS =
LDFLAGS =

all: waitmax

waitmax: waitmax.c
	$(CC) -s -o waitmax $(CFLAGS) $(LDFLAGS) waitmax.c

install:
	mkdir -p $(DESTDIR)/usr/bin
	install -m 755 waitmax $(DESTDIR)/usr/bin
	mkdir -p $(DESTDIR)/usr/share/man/man1
	gzip -c waitmax.1 > $(DESTDIR)/usr/share/man/man1/waitmax.1.gz

uninstall:
	rm -f $(DESTDIR)/usr/bin/waitmax
	rm -f $(DESTDIR)/usr/share/man/man1/waitmax.1.gz

clean:
	rm -rf *~ waitmax-$(VERSION) $(RPM_TOPDIR) $(RPM_BUILDROOT)

distclean:
	$(MAKE) clean
	rm -f waitmax-*.rpm waitmax-$(VERSION).tar.gz waitmax

dist:
	rm -rf waitmax-$(VERSION)
	mkdir -p waitmax-$(VERSION)
	cp COPYING configure Makefile waitmax.c waitmax.1 waitmax.spec waitmax-$(VERSION)
	tar czf waitmax-$(VERSION).tar.gz waitmax-$(VERSION)
	rm -rf waitmax-$(VERSION)

rpm:
	$(MAKE) dist
	mkdir -p $(RPM_TOPDIR)/RPMS
	mkdir -p $(RPM_TOPDIR)/SRPMS
	mkdir -p $(RPM_TOPDIR)/SOURCES
	mkdir -p $(RPM_TOPDIR)/BUILD
	mkdir -p $(RPM_TOPDIR)/SPECS
	cp waitmax-$(VERSION).tar.gz $(RPM_TOPDIR)/SOURCES
	rpmbuild -ba --buildroot "$$(pwd)/$(RPM_BUILDROOT)" --define "_topdir $$(pwd)/$(RPM_TOPDIR)" waitmax.spec
	mv -v $(RPM_TOPDIR)/RPMS/*/* .


