#!/bin/sh

# packages can be built individually if you wish


. ./build.conf

export MWD=`pwd`

ARCH=`uname -m`
CROSS_CC_EX=`find $MWD -type d -name '*cross-compiler*'`
if [ -z "$CROSS_CC_EX" ];then
	case $ARCH in 
		*64)echo "You will have to download a uClibc cross compiler"
			exit 0 ;;
		*)./get-aboriginal.sh ;;
	esac
fi


mk_initrd() {
	echo "
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

building packages for the initial ram disk"
	echo
	sleep 1
	for init_pkg in `cat INITRD`; do
		if [ "$init_pkg" = "findutils_static" ];then
			init_pkg=find_static
		fi
		init_pkg_exits=`ls ./0initrd/bin|grep "^${init_pkg%_*}"`
		if [ "$init_pkg_exits" ];then
			echo "$init_pkg exists ... skipping"
			sleep 0.5
			continue
		fi
		echo
		cd ${init_pkg}
		echo "
+=============================================================================+

building $init_pkg"
		sleep 1 
		sh ${init_pkg}.petbuild 2>&1 | tee ../0logs/${init_pkg}build.log
		if [ "$?" -eq 1 ];then 
			echo "$pkg build failure"
			case $HALT_ERRS in
				0) exit 1 ;;
			esac
		fi
		cd -
	done		
}

mk_initrd

echo "all done!" && exit 0
