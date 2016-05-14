#!/bin/bash
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
#							MAIN
###################################################################

mkdir -p 0initrd/bin 0logs 0sources
CCOMP_GCC="$(which musl-gcc 2>/dev/null)"

case $1 in
	l|local)
		CCOMP_GCC="$(whereis musl-gcc 2>/dev/null | head -1 | sed 's|.* ||')"
		if [ -f "$CCOMP_GCC" ] ; then
			chmod +x $CCOMP_GCC
		else
			echo "Need musl-gcc"
			exit 1
		fi
		;;
	a|aboriginal)
		[ -f "$CCOMP_GCC" ] && chmod -x $CCOMP_GCC
		;;
esac

if [ -x "$CCOMP_GCC" ] ; then
	echo
	echo "* Using system's musl-gcc. If you want to download and use "
	echo "* a recent cross compiler from Aboriginal Linux, then:"
	echo " chmod -x $CCOMP_GCC "
	echo
	echo "Type A and hit enter to use the aboriginal linux stuff"
	echo -n "Press enter to continue or CTRL-C to cancel... " ; read zzz
	case $zzz in a|A)
		chmod -x "$CCOMP_GCC"
		exec "$0"
	esac
	rm -f cross-compile
else

	#############################
	##     aboriginal linux     #
	#############################
	case $ARCH in
		i?86|x86_64) ok=1 ;;
		*)
			echo "*** The cross-compilers from aboriginal linux"
			echo "*** work in x86 systems only, I guess."
			echo "*** Exiting..."
			exit 1
	esac

	#--------------------------------------------------
	#             SELECT TARGET ARCH
	#--------------------------------------------------
	ARCH_LIST="default i486 x86_64 armv4 armv6l powerpc"
	echo
	echo "We're going to compile apps for the init ram disk"
	echo "Select the arch you want to compile to"
	echo
	x=1
	for a in $ARCH_LIST ; do
		case $a in
			default) echo "	${x}) default [${ARCH}]" ;;
			*) echo "	${x}) $a" ;;
		esac
		let x++
	done
	echo "	*) default [${ARCH}]"
	echo
	echo -n "Enter your choice: " ; read choice
	x=1
	for a in $ARCH_LIST ; do
		if [ "$x" = "$choice" ] ; then
			selected_arch=$a
			break
		fi
		let x++
	done
	#-
	case $selected_arch in
		default|"")ok=1 ;;
		*)
			case $ARCH in i?86)
				case $selected_arch in *64)
					echo
					echo "*** Trying to compile for a 64bit arch in a 32bit system?"
					echo "*** That's not possible.. exiting.."
					exit 1
				esac
			esac
			ARCH=$selected_arch
			;;
	esac
	
	echo
	echo "OK: $ARCH"
	sleep 1.5

	#--------------------------------------------------
	#      CROSS COMPILER FROM ABORIGINAL LINUX
	#--------------------------------------------------
	CCOMP_DIR=cross-compiler-${ARCH}
	URL=http://landley.net/aboriginal/downloads/binaries
	PACKAGE=${CCOMP_DIR}.tar.gz
	echo
	## download
	if [ ! -f "0sources/${PACKAGE}" ];then
		echo "Download cross compiler from Aboriginal Linux"
		echo -n "Press enter to continue, CTRL-C to cancel..." ; read zzz
		wget -c -P 0sources ${URL}/${PACKAGE}
		if [ $? -ne 0 ] ; then
			rm -rf ${CCOMP_DIR}
			echo "failed to download ${PACKAGE}"
			exit 1
		fi
	fi
	[ "$DLD_ONLY" = "1" ] && return 0
	## extract
	if [ ! -d "$CCOMP_DIR" ] ; then
		tar --directory=$PWD -xaf 0sources/${PACKAGE}
		if [ $? -ne 0 ] ; then
			rm -rf ${CCOMP_DIR}
			rm -fv 0sources/${PACKAGE}
			echo "failed to extract ${PACKAGE}"
			exit 1
		fi
	fi
	echo ; echo "successfully downloaded and extracted ${PACKAGE}"
	#-------------------------------------------------------------

	[ ! -d "$CCOMP_DIR" ] && { echo "$CCOMP_DIR not found"; exit 1; }
	#export FCCOMP_DIR=$PWD/cross-compiler-${ARCH}
	#export CCOMP_TRIPLET=$(find "${FCCOMP_DIR}" -maxdepth 1 -type d -name '*unknown-linux*')
	#export TRIPLET=${CCOMP_TRIPLET##*/}
	#find ${FCCOMP_DIR}/${TRIPLET}/bin | while read filez ; do
	#	[ ! -f "$filez" ] && continue
	#	name=${filez##*/}
	#	symlink=${FCCOMP_DIR}/bin/${TRIPLET}-${name}
	#	ln -fv $filez $symlink &>/dev/null
	#done
	cp cross-compiler-${ARCH}/cc/lib/* cross-compiler-${ARCH}/lib
	echo
	echo "Using cross compiler from Aboriginal Linux"
	echo
	export OVERRIDE_ARCH=${ARCH}
	echo '#!/bin/sh
XPATH='${PWD}/${CCOMP_DIR}'
ARCH='${ARCH}'
#TRIPLET='${TRIPLET}'
if [ "$CCOMP_INCLUDE" ] || [ "$CCOMP_INCLUDE_ONLY" ] ; then
	export C_INCLUDE_PATH=${XPATH}/include:${C_INCLUDE_PATH}
	export CPLUS_INCLUDE_PATH=${XPATH}/include:${CPLUS_INCLUDE_PATH}
fi
if [ ! "$CCOMP_INCLUDE_ONLY" ] ; then
	export LIBRARY_PATH=${LIB_PATH}${LIBRARY_PATH}
	export LD_LIBRARY_PATH=${LIB_PATH}${LD_LIBRARY_PATH}
	export PATH=${BIN_PATH}${XPATH}/bin:$PATH
fi
case $1 in
	source) ok=1 ;;
	"") make ${MKFLG} CC=${ARCH}-gcc LD=${ARCH}-ld LDFLAGS=-static ;;
	*) exec "$@" ;;
esac' > cross-compile
chmod +x cross-compile
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
	#ex: export ZINITRD=waitmax
	[ "$ZINITRD" ] && INITRD="$ZINITRD"
	for init_pkg in ${INITRD} ; do
		unset BIN_PATH LIB_PATH CCOMP_INCLUDE CCOMP_INCLUDE_ONLY
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

rm -f cross-compile .fatal #comment out to debug

[ "$DLD_ONLY" = "1" ] && exit

#----------------------------------------------------
#            create initial ramdisk
#----------------------------------------------------

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
		[ -f bin/${app} ] || continue
		echo -n "Use busybox ${app} instead of the full version? [Y/n]: "
		read answer
		case $answer in
			n|N) echo -n ;;
			*) rm -fv bin/${app} ;;
		esac
	done
	( 
		cd bin
		sh bb-create-symlinks 2>/dev/null
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
	pkgx=initrd_progs-$(date "+%Y%m%d")-${ARCH}.tar.gz
	rm -f $pkgx
	tar zcf $pkgx initrd.gz 0initrd/bin
fi

echo
echo "all done!"

### END ###