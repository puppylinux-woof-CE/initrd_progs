#!/bin/sh
#
# - sourced by app_static.petbuild
# - xxx_download
# - xxx_build
# - uses functions from ../../func (already sourced by app_static.petbuild)
#
# $CC_INSTALL_DIR is exported by build.sh
#

# Versions:
ncurses_ver=6.1    #2018-01-27
libuuid_ver=1.0.3

#==========================================================
#                        NCURSES
#==========================================================

ncurses_download() {
	retrieve https://ftp.gnu.org/pub/gnu/ncurses/ncurses-${ncurses_ver}.tar.gz
}

ncurses_build() {
	if [ -f ${XPATH}/lib/libncurses.a ] ; then
		export NC_CFLAGS=$(${XPATH}/bin/ncurses6-config --cflags)
		export NC_LIBS=$(${XPATH}/bin/ncurses6-config --libs)
		export NCURSESW_CFLAGS=$NC_CFLAGS
		export NCURSESW_LIBS=$NC_LIBS
		export NCURSES_CFLAGS=$NC_LIBS
		export NCURSES_LIBS=$NC_LIBS
		return 0 # already done
	fi
	#--
	extract ncurses-${ncurses_ver}.tar.gz
	cd ncurses-${ncurses_ver}
	opts="--prefix=${XPATH}
--without-manpages
--without-progs
--without-tests
--disable-db-install
--without-ada
--without-gpm
--without-shared
--without-debug
--without-develop
--without-cxx
--without-cxx-binding
--disable-big-core
--disable-big-strings
"
	_configure
	_make ${MKFLG}
	_make install
	ret=$?
	cd ..
	[ $ret -eq 0 ] && rm -rf ncurses-${ncurses_ver}
	export NC_CFLAGS=$(${XPATH}/bin/ncurses6-config --cflags)
	export NC_LIBS=$(${XPATH}/bin/ncurses6-config --libs)
	export NCURSESW_CFLAGS=$NC_CFLAGS
	export NCURSESW_LIBS=$NC_LIBS
	export NCURSES_CFLAGS=$NC_LIBS
	export NCURSES_LIBS=$NC_LIBS
	return $ret
}

#==========================================================
#                       LIBUUID
#==========================================================

libuuid_download() {
	retrieve https://sourceforge.net/projects/libuuid/files/libuuid-${libuuid_ver}.tar.gz
}

libuuid_build() {
	if [ -f ${XPATH}/lib/libuuid.a ] ; then
		return 0
	fi
	extract libuuid-${libuuid_ver}.tar.gz
	cd libuuid-${libuuid_ver}
	opts="--prefix=${XPATH}" # cross compiler path
	_configure
	_make
	_make install
	rv=$?
	cd ..
	[ $rv -eq 0 ] && rm -rf libuuid-${libuuid_ver}
	return $rv
}

#==========================================================
#                      UTIL-LINUX
#==========================================================

util_linux_ver=2.34

util_linux_download() {
	retrieve https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v${util_linux_ver}/util-linux-${util_linux_ver}.tar.xz
}

util_linux_build() {
	extract util-linux-${util_linux_ver}.tar.xz
	cd util-linux-${util_linux_ver}
	 # cross compiler path
	opts="--prefix=${XPATH}
--disable-all-programs
--disable-symvers
--disable-nls
--enable-libblkid
--enable-libuuid
--enable-libmount
--enable-libsmartcols
--enable-libfdisk
--without-python
--without-systemd
--without-btrfs
--without-user
--without-udev
--without-ncursesw
"
	_configure
	_make
	_make install
	rv=$?
	cd ..
	if [ $rv -eq 0 ] ; then
		rm -rf util-linux-${util_linux_ver}
	fi
	return $rv
}

