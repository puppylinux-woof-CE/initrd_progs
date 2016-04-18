#!/bin/sh
# packages can be built individually if you wish

. ./build.conf && export MKFLG

export MWD=`pwd`

if ! which make &>/dev/null ; then
	echo "It looks like development tools are not installed.."
	echo "Press enter to continue, CTRL-C to cancel" ; read zzz
fi

ARCH=`uname -m`
case $ARCH in
	arm*) ARCH=armv6l ;; # newest supported
	*)    ARCH=$ARCH ;;
esac

###################################################################
#				CROSS COMPILER from ABORIGINAL LINUX
###################################################################

function aboriginal_cross_compiler() {
	# download Landley's Aboriginal cross compiler
	echo
	echo "Download W.Landley's Aboriginal cross compiler"
	echo -n "Press enter to continue, CTRL-C to cancel..." ; read zzz
	local COMPILER=cross-compiler
	local URL=http://landley.net/aboriginal/downloads/binaries
	local page=$(wget -q -O -  http://landley.net/aboriginal/downloads/binaries/)
	if echo "$page" | grep -q '\.tar\.gz' ; then
		COMP='tar.gz'
	elif echo "$page" | grep -q '\.tar\.bz2' ; then
		COMP='tar.bz2'
	elif echo "$page" | grep -q '\.tar\.xz' ; then
		COMP='tar.xz'
	else
 		echo "Could not determine compression type"
		#error, look in 0sources... offline mode
		p=$(find 0sources -type f -name '*compiler*'$(uname -m)'*' | head -1)
		if [ -f "$p" ] ; then
			PACKAGE=${p##*/}
			ARCH=$(uname -m)
			echo ; echo "Found $PACKAGE in 0sources..."
		else
			echo ; return 1
		fi
	fi
	###
	case $ARCH in i686)
		if [ "$COMP" ] ; then
			if echo "$page" | grep -q 'i486' ; then ASK=1 ; fi
		else
			i486=${PACKAGE//i686/i486}
			[ -f "0sources/$i486" ] && ASK=1
		fi
		if [ "$ASK" ] ; then
			echo ; echo -n "Use i486 instead of i686? [Y/n]: " ; read answer
			case $answer in
				n|N) echo -n ;;
				*)
					[ ! "$COMP" ] && PACKAGE=${i486}
					ARCH=i486
					;;
			esac
		fi
	esac
	sleep 1
	###
	[ "$COMP" ] && PACKAGE=${COMPILER}-${ARCH}.${COMP}
	## download
	if [ ! -f "0sources/${PACKAGE}" ];then
		wget -P 0sources ${URL}/${PACKAGE}
		if [ $? -ne 0 ] ; then
			rm -f ${URL}/${PACKAGE}
			echo "failed to download ${PACKAGE}"
			return 1
		fi
	fi
	[ "$DLD_ONLY" = "1" ] && return 0
	## extract
	tar --directory=$PWD -xaf 0sources/${PACKAGE}
	if [ $? -ne 0 ] ; then
		rm -rf ${PACKAGE%.tar.*} #directory
		rm -f 0sources/${PACKAGE}
		echo "failed to extract ${PACKAGE}"
		return 1
	fi
	echo ; echo "successfully downloaded and extracted ${PACKAGE}"
}



###################################################################
#							MAIN
###################################################################

mkdir -p 0initrd/bin 0logs 0sources

MUSL_GCC="$(which musl-gcc 2>/dev/null)"

case $1 in
	l|local)
		MUSL_GCC="$(whereis musl-gcc 2>/dev/null | head -1 | sed 's|.* ||')"
		if [ -f "$MUSL_GCC" ] ; then
			chmod +x $MUSL_GCC
		else
			echo "Need musl-gcc"
			exit 1
		fi
		;;
	a|aboriginal)
		[ -f "$MUSL_GCC" ] && chmod -x $MUSL_GCC
		;;
esac

if [ -x "$MUSL_GCC" ] ; then
	echo
	echo "Using musl-gcc. If you want to download and use "
	echo "a recent cross compiler from Aboriginal Linux, then:"
	echo "  chmod -x $MUSL_GCC "
	echo
	echo -n "Press enter to continue or CTRL-C to cancel..." ; read zzz
	rm -f cross-compile
else
	## aboriginal linux
	CROSS_CC_EX=`find $MWD -type d -name '*cross-compiler*' | head -1`
	if [ -z "$CROSS_CC_EX" ];then
		aboriginal_cross_compiler
		if [ $? -ne 0 ] ; then
			if [ "$DLD_ONLY" = "1" ] ; then
				echo "Could not download cross compiler !!"
			else
				echo "WARNING: It's *not* advised to continue, but you can still continue"
				echo "Press CTRL-C to cancel and ENTER to continue"
				read zzz
			fi
		fi
	else
		echo ; echo "Using cross compiler from Aboriginal Linux" ; echo
	fi
	CROSS_CC_EX=`find $MWD -type d -name '*cross-compiler*' | head -1`
	if [ -d "$CROSS_CC_EX" ] ; then
		export OVERRIDE_ARCH=${CROSS_CC_EX##*-}
		ARCH=${OVERRIDE_ARCH}
		echo '#!/bin/sh
		XPATH='${CROSS_CC_EX}'
		ARCH='${ARCH}'
		if [ "$MUSL_INCLUDE" ] || [ "$MUSL_INCLUDE_ONLY" ] ; then
			export C_INCLUDE_PATH=${XPATH}/include:${C_INCLUDE_PATH}
			export CPLUS_INCLUDE_PATH=${XPATH}/include:${CPLUS_INCLUDE_PATH}
		fi
		if [ ! "$MUSL_INCLUDE_ONLY" ] ; then
			export LIBRARY_PATH=${XPATH}/lib:${LIBRARY_PATH}
			export PATH=${XPATH}/bin:$PATH
			export LD_LIBRARY_PATH=${XPATH}/lib:${LD_LIBRARY_PATH}
		fi
		case $1 in
			source) ok=1 ;;
			"") make ${MKFLG} CC=${ARCH}-gcc LD=${ARCH}-ld LDFLAGS=-static ;;
			*) exec "$@" ;;
		esac' > cross-compile
		chmod +x cross-compile
	fi
fi

#############

function check_bin() {
	local init_pkg=$1
	case $init_pkg in
		""|'#'*) continue ;;
		coreutils_static) static_bins='cp' ;;
		e2fsprogs_static) static_bins='fsck e2fsck resize2fs' ;;
		findutils_static) static_bins='find' ;;
		fuse_static) static_bins='fusermount' ;;
		module-init-tools_static) static_bins='lsmod modprobe' ;;
		util-linux_static) static_bins='losetup' ;;
		*) static_bins=${init_pkg%_*} ;;
	esac
	for sbin in ${static_bins} ; do
		ls ./0initrd/bin | grep -q "^${sbin}" || return 1
	done
}

build_pkgs() {
	rm -f .fatal
	if [ "$DLD_ONLY" = "1" ] ; then
		echo "Downloading packages only" ; echo
	else
		echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		echo
		echo "building packages for the initial ram disk"
		echo
	fi
	sleep 1
	for init_pkg in ${INITRD} ; do
		if [ -f .fatal ] ; then
			echo "Exiting.." ; rm -f .fatal
			exit 1
		fi
		[ -d "${init_pkg}_static" ] && init_pkg=${init_pkg}_static
		check_bin $init_pkg
		if [ $? -eq 0 ] ; then ##found
			echo "$init_pkg exists ... skipping"
			continue
		fi
		####
		echo
		cd ${init_pkg}
		if [ "$DLD_ONLY" = "1" ] ; then
			echo
			echo "downloading $init_pkg"
		else
			echo "+=============================================================================+"
			echo
			echo "building $init_pkg"
		fi
		sleep 1 
		sh ${init_pkg}.petbuild 2>&1 | tee ../0logs/${init_pkg}build.log
		if [ "$?" -eq 1 ];then 
			echo "$pkg build failure"
			case $HALT_ERRS in
				0) exit 1 ;;
			esac
		fi
		cd $MWD
		## extra check
		check_bin $init_pkg
		if [ $? -ne 0 ] ; then ##not found
			echo "target binary does not exist... exiting"
			[ "$HALT_ERRS" = "1" ] && exit 1
		fi
	done
}

build_pkgs

if [ "$DLD_ONLY" = "1" ] ; then
	rm -f cross-compile .fatal
	exit
fi

### create initial ramdisk

if [ "$INITRD_GZ" = "1" ] ; then
	echo
	echo "============================================"
	echo "Now creating the initial ramdisk (initrd.gz) (for 'huge' kernels)"
	echo "============================================"
	echo
	initrdtree=$(find 0initrd -maxdepth 1 -name 'initrd-tree*')
	if [ ! -f "$initrdtree"  ] ; then
		echo "Need initrd-tree0 from woof ce"
		exit 1
	fi
	rm -rf ZZ_initrd-expanded
	mkdir -p ZZ_initrd-expanded
	tar --directory=ZZ_initrd-expanded --strip=1 -zxf ${initrdtree}
	tar --directory=ZZ_initrd-expanded -zxf 0initrd/dev.tar.gz
	tar --directory=ZZ_initrd-expanded -zxf 0initrd/lib.tar.gz
	cp -a --remove-destination 0initrd/bin/* ZZ_initrd-expanded/bin
	rm -f ZZ_initrd-expanded/bin/readme
	cd ZZ_initrd-expanded
	for app in awk sed ; do
		if [ -f bin/${app} ] ; then
			echo -n "Use busybox ${app} instead of the full version? [Y/n]: "
			read answer
			case $answer in
				n|N) echo -n ;;
				*) rm -fv bin/${app} ;;
			esac
		fi
	done
	( 
		cd bin
		sh bb-create-symlinks
		if [ -f bash ] ; then
			echo -n "Use bash as the init shell? [y/N]: " ; read answer
			case $answer in
				y|Y) rm -f sh ; ln -sv bash sh ;;
				*)
					rm -f sh ; ln -sv busybox sh
					echo -n "Remove bash? [Y/n]: " ; read answer
					case $answer in
						n|N) echo -n ;;
						*) rm -fv bash ;;
					esac
					;;
			esac
		fi
	)
	if [ -f ../0initrd/DISTRO_SPECS ] ; then
		cp -fv ../0initrd/DISTRO_SPECS .
		. ../0initrd/DISTRO_SPECS
	else
		[ -f /etc/DISTRO_SPECS ] && DS=/etc/DISTRO_SPECS
		[ -f /initrd/DISTRO_SPECS ] && DS=/initrd/DISTRO_SPECS
		cp -fv ${DS} .
		. ${DS}
	fi
	[ -f ../0initrd/init ] && cp -fv ../0initrd/init .
	sed -i 's|^PUPDESKFLG=.*|PUPDESKFLG=0|' init
	echo
	echo "If you have anything to add or remove from ZZ_initrd-expanded do it now"
	echo -n "Press ENTER to create initrd.gz ..." ; read zzz
	echo
	####
	find . | cpio -o -H newc > ../initrd
	cd ..
	gzip -f initrd
	if [ $? -eq 0 ] ; then
		echo
		echo "initrd.gz has been created"
		echo "You can inspect ZZ_initrd-expanded to see the final results"
	else
		echo "ERROR" ; exit 1
	fi
else
	echo "Not creating initrd.gz"
fi

if [ "$DISTRO_BINARY_COMPAT" ] ; then
	pkgx=initrd_progs-$(date "+%Y%m%d")-${DISTRO_FILE_PREFIX}-${DISTRO_VERSION}-${ARCH}.tar.gz
	rm -f $pkgx
	tar zcf $pkgx initrd.gz 0initrd/bin
fi

rm -f cross-compile #comment out to debug

echo
echo "all done!"

### END ###