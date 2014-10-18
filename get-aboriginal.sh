#!/bin/sh

# download Landley's Aboriginal uClibc cross compiler

echo "Downloading Landley's Aboriginal uClibc cross compiler"
echo
sleep 4
echo "This will take a while"
echo 
sleep 1

exit_error() {
	echo "$@"
	exit 1
}
COMPILER=cross-compiler
URL=http://landley.net/aboriginal/downloads/binaries
ARCH=`uname -m`
case $ARCH in
	arm*) ARCH=armv6l ;; # newest supported
	*64)echo "Tough luck. You have to build your own cross compiler"
		echo "from Aboriginal or uClibc or chance musl."
		exit 0 ;;
	*)ARCH=$ARCH ;;
esac
COMP=tar.bz2
PACKAGE=${COMPILER}-${ARCH}.${COMP}

dload() {
	wget -t0 -c ${URL}/$PACKAGE
	[ "$?" -ne 0 ] && exit error failed to download $PACKAGE
}
extract() {
	tar -xjvf $PACKAGE
	[ "$?" -ne 0 ] && exit error failed to extract $PACKAGE
}
if [ -f "0sources/$PACKAGE" ];then
	cp -a 0sources/$PACKAGE .
	extract
else	
	dload
	extract
fi
mv -f $PACKAGE 0sources
echo "successfully downloaded and extraxted $PACKAGE"
exit 0
