#!/bin/sh
DISABLE_USR="s@^usr/@@"
BB=busybox
! [ -e bin/busybox ] && echo Run from chroot directory && exit

case $1 in
	install)
		$QEMU_ARM bin/busybox --list-full | $BB sed "$DISABLE_USR" | while read -r p; do 
			if ! [ -e $p ]; then 
				ln -s ../bin/busybox $p
			fi
		done
		;;
		
	remove)
		find . -type l | while read -r p; do 
			if $BB readlink $p | $BB grep -q busybox; then 
				rm $p
		fi
		done
		;;

	"") echo install or remove.
		;;
esac


