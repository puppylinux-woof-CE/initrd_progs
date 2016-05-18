#!/bin/bash

. ./build.conf && export MKFLG

export MWD=`pwd`

ARCH_LIST="default i486 x86_64 armv4l armv6l"
ARCH_LIST_EX="i486 i586 i686 x86_64 armv4l armv4tl armv5l armv6l m68k mips mips64 mipsel powerpc powerpc-440fp sh2eb sh2elf sh4 sparc"

if ! which make &>/dev/null ; then
	echo "It looks like development tools are not installed.."
	echo "Press enter to continue, CTRL-C to cancel" ; read zzz
fi

help_msg() {
	echo "Build static apps in the queue defined in build.conf
Usage:
  $0 [options]

  Options:
  -pkg pkg    : compile specific pkg only
  -all        : force building all *_static pkgs
  -copyall    : use all generated binaries to create initrd.gz
                otherwise only the ones specified in
                INITRD_PROGS='..' in build.conf
  -arch target: compile for target arch
  -sysgcc     : use system gcc
  -help       : show help and exit

  Valid <targets> for -arch:
      $ARCH_LIST_EX

  The most relevant <targets> for Puppy are:
      ${ARCH_LIST#default }

  Note that one target not yet supported by musl is aarch64 (arm64)
"
}

while [ "$1" ] ; do
	case $1 in
		-l|-sysgcc)
			USE_LOCAL_GCC=1
			which gcc &>/dev/null || { echo "No gcc aborting"; exit 1; }
			shift
			;;
		-all)
			FORCE_BUILD_ALL=1
			shift
			;;
		-copyall)
			COPY_ALL_BINARIES=1
			shift
			;;
		-pkg)
			[ "$2" = "" ] && { echo "Specify a pkg to compile" ; exit 1; }
			BUILD_PKG="$2"
			shift 2
			;;
		-arch)
			[ "$2" = "" ] && { echo "Specify a target arch" ; exit 1; }
			TARGET_ARCH="$2"
			shift 2
			;;
		-h|-help|--help)
			help_msg
			exit
			;;
		*)
			echo "Unrecognized option: $1"
			shift
			;;
	esac
done

ARCH=`uname -m`
case $ARCH in
	arm*) ARCH=armv6l ;; # newest supported
	*)    ARCH=$ARCH ;;
esac


###################################################################
#							MAIN
###################################################################

if [ "$USE_LOCAL_GCC" = "1" ] ; then
	echo
	echo "* Using system gcc"
	echo
else

	#############################
	##     aboriginal linux     #
	#############################
	case $ARCH in
		i?86) ARCH=i486 ;;
		x86_64) echo -n ;;
		*)
			echo -e "*** The cross-compilers from aboriginal linux"
			echo -e "*** work in x86 systems only, I guess."
			echo -e "\n* Run $0 -sysgcc to use the system gcc ... "
			echo -e "\n*** Exiting..."
			exit 1
	esac

	#--------------------------------------------------
	#             SELECT TARGET ARCH
	#--------------------------------------------------
	if [ "$TARGET_ARCH" != "" ] ; then
		for a in $ARCH_LIST ; do
			if [ "$TARGET_ARCH" = "$a" ] ; then
				VALID_TARGET_ARCH=1
				break
			fi
		done
		if [ "$VALID_TARGET_ARCH" = "" ] ; then
			echo "Invalid target arch: $TARGET_ARCH"
			exit 1
		else
			[ "$TARGET_ARCH" != "default" ] && ARCH=${TARGET_ARCH}
		fi
	fi

	if [ "$VALID_TARGET_ARCH" = "" ] ; then
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
	fi
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
	cp cross-compiler-${ARCH}/cc/lib/* cross-compiler-${ARCH}/lib
	echo
	echo "Using cross compiler from Aboriginal Linux"
	echo
	export OVERRIDE_ARCH=${ARCH}     # = cross compiling
	export XPATH=${PWD}/${CCOMP_DIR} # = cross compiling
	# see ./func
fi

#----------------------------------------------
mkdir -p 00_${ARCH}/bin 00_${ARCH}/log 0sources
#----------------------------------------------

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
		ls ./00_${ARCH}/bin | grep -q "^${sbin}" || return 1
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
	[ "$BUILD_PKG" != "" ] && PACKAGES="$BUILD_PKG"
	if [ "$FORCE_BUILD_ALL" = "1" ] ; then
		PACKAGES=$(find . -maxdepth 1 -type d -name '*_static' | sed 's|.*/||' | sort)
	fi
	for init_pkg in ${PACKAGES} ; do
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
		mkdir -p ../00_${ARCH}/log
		sh ${init_pkg}.petbuild 2>&1 | tee ../00_${ARCH}/log/${init_pkg}build.log
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
cd $MWD

rm -f .fatal #comment out to debug

[ "$DLD_ONLY" = "1" ] && exit

suspicious=$(
	ls 00_${ARCH}/bin/* | \
		while read bin ; do file $bin ; done | \
			grep -E 'dynamically|shared'
)
if [ "$suspicious" ] ; then
	echo
	echo "These files don't look good:"
	echo "$suspicious"
	echo
	echo -n "Press enter to continue, CTRL-C to end here.." ; read zzz
fi

#----------------------------------------------------
#            create initial ramdisk
#----------------------------------------------------

if [ "$INITRD_GZ" = "1" ] ; then
	echo
	echo -n "Press enter to create initrd.gz, CTRL-C to end here.." ; read zzz
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

	if [ "$COPY_ALL_BINARIES" = "1" ] ; then
		cp -av --remove-destination 00_${ARCH}/bin/* ZZ_initrd-expanded/bin
	else
		for PROG in ${INITRD_PROGS} ; do
			case $PROG in ""|'#'*) continue ;; esac
			if [ -f 00_${ARCH}/bin/${PROG} ] ; then
				cp -av --remove-destination \
					00_${ARCH}/bin/${PROG} ZZ_initrd-expanded/bin
			else
				echo "WARNING: 00_${ARCH}/bin/${PROG} not found"
			fi
		done
	fi

	echo
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
	echo
	echo -n "Press ENTER to generate initrd.gz ..." ; read zzz
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
	tar zcf $pkgx initrd.gz 00_${ARCH}
fi

echo
echo " - Output files -"
echo "initrd.gz: use it in a frugall install for example"
echo "$pkgx: to store or distribute"
echo
echo "Finished."

### END ###