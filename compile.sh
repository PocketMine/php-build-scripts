#!/bin/bash
[ -z "$PHP_VERSION" ] && PHP_VERSION="7.0.1"

PHP_IS_BETA="no"

ZEND_VM="GOTO"

ZLIB_VERSION="1.2.8"
POLARSSL_VERSION="2.2.0"
LIBMCRYPT_VERSION="2.5.8"
GMP_VERSION="6.1.0"
GMP_VERSION_DIR="6.1.0"
CURL_VERSION="curl-7_46_0"
READLINE_VERSION="6.3"
NCURSES_VERSION="5.9"
PHPNCURSES_VERSION="1.0.2"
PTHREADS_VERSION="3.1.5"
XDEBUG_VERSION="2.2.6"
PHP_POCKETMINE_VERSION="0.0.6"
#UOPZ_VERSION="2.0.4"
WEAKREF_VERSION="0.2.6"
PHPYAML_VERSION="2.0.0RC5"
YAML_VERSION="0.1.6"
#PHPLEVELDB_VERSION="0.1.4"
PHPLEVELDB_VERSION="2963815338edfebc5ab8c512bcd2b72f0357ac6e"
#LEVELDB_VERSION="1.18"
LEVELDB_VERSION="b633756b51390a9970efde9068f60188ca06a724" #Check MacOS
LIBXML_VERSION="2.9.1"
LIBPNG_VERSION="1.6.20"
BCOMPILER_VERSION="1.0.2"

echo "[PocketMine] PHP compiler for Linux, MacOS and Android"
DIR="$(pwd)"
date > "$DIR/install.log" 2>&1
#trap "echo \"# \$(eval echo \$BASH_COMMAND)\" >> \"$DIR/install.log\" 2>&1" DEBUG
uname -a >> "$DIR/install.log" 2>&1
echo "[INFO] Checking dependecies"
type make >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"make\""; read -p "Press [Enter] to continue..."; exit 1; }
type autoconf >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"autoconf\""; read -p "Press [Enter] to continue..."; exit 1; }
type automake >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"automake\""; read -p "Press [Enter] to continue..."; exit 1; }
type libtool >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"libtool\" or \"libtool-bin\""; read -p "Press [Enter] to continue..."; exit 1; }
type m4 >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"m4\""; read -p "Press [Enter] to continue..."; exit 1; }
type wget >> "$DIR/install.log" 2>&1 || type curl >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"wget\" or \"curl\""; read -p "Press [Enter] to continue..."; exit 1; }
type getconf >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"getconf\""; read -p "Press [Enter] to continue..."; exit 1; }
type gzip >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"gzip\""; read -p "Press [Enter] to continue..."; exit 1; }
type bzip2 >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"bzip2\""; read -p "Press [Enter] to continue..."; exit 1; }

#Needed to use aliases
shopt -s expand_aliases
type wget >> "$DIR/install.log" 2>&1
if [ $? -eq 0 ]; then
	alias download_file="wget --no-check-certificate -q -O -"
else
	type curl >> "$DIR/install.log" 2>&1
	if [ $? -eq 0 ]; then
		alias download_file="curl --insecure --silent --location"
	else
		echo "error, curl or wget not found"
	fi
fi

#if type llvm-gcc >/dev/null 2>&1; then
#	export CC="llvm-gcc"
#	export CXX="llvm-g++"
#	export AR="llvm-ar"
#	export AS="llvm-as"
#	export RANLIB=llvm-ranlib
#else
	export CC="gcc"
	export CXX="g++"
	#export AR="gcc-ar"
	export RANLIB=ranlib
#fi

COMPILE_FOR_ANDROID=no
HAVE_MYSQLI="--enable-embedded-mysqli --enable-mysqlnd --with-mysqli=mysqlnd"
COMPILE_TARGET=""
COMPILE_CURL="default"
COMPILE_FANCY="no"
HAS_ZEPHIR="no"
IS_CROSSCOMPILE="no"
IS_WINDOWS="no"
DO_OPTIMIZE="no"
DO_STATIC="no"
COMPILE_DEBUG="no"
COMPILE_LEVELDB="no"
FLAGS_LTO=""

LD_PRELOAD=""

while getopts "::t:oj:srcdlxzff:" OPTION; do

	case $OPTION in
		t)
			echo "[opt] Set target to $OPTARG"
			COMPILE_TARGET="$OPTARG"
			;;
		j)
			echo "[opt] Set make threads to $OPTARG"
			THREADS="$OPTARG"
			;;
		r)
			echo "[opt] Will compile readline and ncurses"
			COMPILE_FANCY="yes"
			;;
		d)
			echo "[opt] Will compile profiler and xdebug"
			COMPILE_DEBUG="yes"
			;;
		c)
			echo "[opt] Will force compile cURL"
			COMPILE_CURL="yes"
			;;
		x)
			echo "[opt] Doing cross-compile"
			IS_CROSSCOMPILE="yes"
			;;
		l)
			echo "[opt] Will compile with LevelDB support"
			COMPILE_LEVELDB="yes"
			;;
		s)
			echo "[opt] Will compile everything statically"
			DO_STATIC="yes"
			CFLAGS="$CFLAGS -static"
			;;
		z)
			echo "[opt] Will add PocketMine C PHP extension"
			HAS_ZEPHIR="yes"
			;;
		f)
			echo "[opt] Enabling abusive optimizations..."
			DO_OPTIMIZE="yes"
			#FLAGS_LTO="-fvisibility=hidden -flto"
			ffast_math="-fno-math-errno -funsafe-math-optimizations -fno-signed-zeros -fno-trapping-math -ffinite-math-only -fno-rounding-math -fno-signaling-nans" #workaround SQLite3 fail
			CFLAGS="$CFLAGS -O2 -DSQLITE_HAVE_ISNAN $ffast_math -ftree-vectorize -fomit-frame-pointer -funswitch-loops -fivopts"
			if [ "$COMPILE_TARGET" != "mac" ] && [ "$COMPILE_TARGET" != "mac32" ] && [ "$COMPILE_TARGET" != "mac64" ]; then
				CFLAGS="$CFLAGS -funsafe-loop-optimizations -fpredictive-commoning -ftracer -ftree-loop-im -frename-registers -fcx-limited-range"
			fi
			
			if [ "$OPTARG" == "arm" ]; then
				CFLAGS="$CFLAGS -mfpu=vfp"
			elif [ "$OPTARG" == "x86_64" ]; then
				CFLAGS="$CFLAGS -mmmx -msse -msse2 -msse3 -mfpmath=sse -free -msahf -ftree-parallelize-loops=4"
			elif [ "$OPTARG" == "x86" ]; then
				CFLAGS="$CFLAGS -mmmx -msse -msse2 -mfpmath=sse -m128bit-long-double -malign-double -ftree-parallelize-loops=4"
			fi
			;;
		\?)
			echo "Invalid option: -$OPTION$OPTARG" >&2
			exit 1
			;;
	esac
done

#TODO Uncomment this when php-leveldb supports PHP7 properly
#if [ $(gcc -dumpversion | sed -e 's/\.\([0-9][0-9]\)/\1/g' -e 's/\.\([0-9]\)/0\1/g' -e 's/^[0-9]\{3,4\}$/&00/') -gt 40800 ]; then
	#COMPILE_LEVELDB="yes"
#fi
COMPILE_LEVELDB="no"

GMP_ABI=""
TOOLCHAIN_PREFIX=""

if [ "$IS_CROSSCOMPILE" == "yes" ]; then
	export CROSS_COMPILER="$PATH"
	if [[ "$COMPILE_TARGET" == "win" ]] || [[ "$COMPILE_TARGET" == "win32" ]]; then
		TOOLCHAIN_PREFIX="i686-w64-mingw32"
		[ -z "$march" ] && march=i686;
		[ -z "$mtune" ] && mtune=pentium4;
		CFLAGS="$CFLAGS -mconsole"
		CONFIGURE_FLAGS="--host=$TOOLCHAIN_PREFIX --target=$TOOLCHAIN_PREFIX --build=$TOOLCHAIN_PREFIX"
		IS_WINDOWS="yes"
		GMP_ABI="32"
		echo "[INFO] Cross-compiling for Windows 32-bit"
	elif [ "$COMPILE_TARGET" == "win64" ]; then
		TOOLCHAIN_PREFIX="x86_64-w64-mingw32"
		[ -z "$march" ] && march=x86_64;
		[ -z "$mtune" ] && mtune=nocona;
		CFLAGS="$CFLAGS -mconsole"
		CONFIGURE_FLAGS="--host=$TOOLCHAIN_PREFIX --target=$TOOLCHAIN_PREFIX --build=$TOOLCHAIN_PREFIX"
		IS_WINDOWS="yes"
		GMP_ABI="64"
		echo "[INFO] Cross-compiling for Windows 64-bit"
	elif [ "$COMPILE_TARGET" == "android" ] || [ "$COMPILE_TARGET" == "android-armv6" ]; then
		COMPILE_FOR_ANDROID=yes
		[ -z "$march" ] && march=armv6;
		[ -z "$mtune" ] && mtune=arm1136jf-s;
		TOOLCHAIN_PREFIX="arm-linux-musleabi"
		CONFIGURE_FLAGS="--host=$TOOLCHAIN_PREFIX --enable-static-link --disable-ipv6"
		CFLAGS="-static $CFLAGS"
		CXXFLAGS="-static $CXXFLAGS"
		LDFLAGS="-static"
		echo "[INFO] Cross-compiling for Android ARMv6"
	elif [ "$COMPILE_TARGET" == "android-armv7" ]; then
		COMPILE_FOR_ANDROID=yes
		[ -z "$march" ] && march=armv7-a;
		[ -z "$mtune" ] && mtune=cortex-a8;
		TOOLCHAIN_PREFIX="arm-linux-musleabi"
		CONFIGURE_FLAGS="--host=$TOOLCHAIN_PREFIX --enable-static-link --disable-ipv6"
		CFLAGS="-static $CFLAGS"
		CXXFLAGS="-static $CXXFLAGS"
		LDFLAGS="-static"
		echo "[INFO] Cross-compiling for Android ARMv7"
	elif [ "$COMPILE_TARGET" == "rpi" ]; then
		TOOLCHAIN_PREFIX="arm-linux-gnueabihf"
		[ -z "$march" ] && march=armv6zk;
		[ -z "$mtune" ] && mtune=arm1176jzf-s;
		if [ "$DO_OPTIMIZE" == "yes" ]; then
			CFLAGS="$CFLAGS -mfloat-abi=hard -mfpu=vfp"
		fi
		CONFIGURE_FLAGS="--host=$TOOLCHAIN_PREFIX"
		[ -z "$CFLAGS" ] && CFLAGS="-uclibc";
		echo "[INFO] Cross-compiling for Raspberry Pi ARMv6zk hard float"
	elif [ "$COMPILE_TARGET" == "armv7" ]; then
		TOOLCHAIN_PREFIX="arm-linux-gnueabihf"
		[ -z "$march" ] && march=armv7-a;
		[ -z "$mtune" ] && mtune=cortex-a8;
		CONFIGURE_FLAGS="--host=$TOOLCHAIN_PREFIX"
		[ -z "$CFLAGS" ] && CFLAGS="-uclibc";
		echo "[INFO] Cross-compiling for ARMv7"
	elif [ "$COMPILE_TARGET" == "mac" ]; then
		[ -z "$march" ] && march=prescott;
		[ -z "$mtune" ] && mtune=generic;
		CFLAGS="$CFLAGS -fomit-frame-pointer";
		TOOLCHAIN_PREFIX="i686-apple-darwin10"
		CONFIGURE_FLAGS="--host=$TOOLCHAIN_PREFIX"
		#zlib doesn't use the correct ranlib
		RANLIB=$TOOLCHAIN_PREFIX-ranlib
		LEVELDB_VERSION="1bd4a335d620b395b0a587b15804f9b2ab3c403f"
		CFLAGS="$CFLAGS -Qunused-arguments -Wno-error=unused-command-line-argument-hard-error-in-future"
		ARCHFLAGS="-Wno-error=unused-command-line-argument-hard-error-in-future"
		GMP_ABI="32"
		echo "[INFO] Cross-compiling for Intel MacOS"
	elif [ "$COMPILE_TARGET" == "ios" ] || [ "$COMPILE_TARGET" == "ios-armv6" ]; then
		[ -z "$march" ] && march=armv6;
		[ -z "$mtune" ] && mtune=arm1176jzf-s;
		TOOLCHAIN_PREFIX="arm-apple-darwin10"
		CONFIGURE_FLAGS="--host=$TOOLCHAIN_PREFIX --target=$TOOLCHAIN_PREFIX -miphoneos-version-min=4.2"
	elif [ "$COMPILE_TARGET" == "ios-armv7" ]; then
		[ -z "$march" ] && march=armv7-a;
		[ -z "$mtune" ] && mtune=cortex-a8;
		TOOLCHAIN_PREFIX="arm-apple-darwin10"
		CONFIGURE_FLAGS="--host=$TOOLCHAIN_PREFIX --target=$TOOLCHAIN_PREFIX -miphoneos-version-min=4.2"
		if [ "$DO_OPTIMIZE" == "yes" ]; then
			CFLAGS="$CFLAGS -mfpu=neon"
		fi
	else
		echo "Please supply a proper platform [android android-armv6 android-armv7 rpi mac ios ios-armv6 ios-armv7 win win32 win64] to cross-compile"
		exit 1
	fi
elif [[ "$COMPILE_TARGET" == "linux" ]] || [[ "$COMPILE_TARGET" == "linux32" ]]; then
	[ -z "$march" ] && march=i686;
	[ -z "$mtune" ] && mtune=pentium4;
	CFLAGS="$CFLAGS -m32";
	GMP_ABI="32"
	echo "[INFO] Compiling for Linux x86"
elif [ "$COMPILE_TARGET" == "linux64" ]; then
	[ -z "$march" ] && march=x86-64;
	[ -z "$mtune" ] && mtune=nocona;
	CFLAGS="$CFLAGS -m64"
	GMP_ABI="64"
	echo "[INFO] Compiling for Linux x86_64"
elif [ "$COMPILE_TARGET" == "rpi" ]; then
	[ -z "$march" ] && march=armv6zk;
	[ -z "$mtune" ] && mtune=arm1176jzf-s;
	CFLAGS="$CFLAGS -mfloat-abi=hard -mfpu=vfp";
	echo "[INFO] Compiling for Raspberry Pi ARMv6zk hard float"
elif [ "$COMPILE_TARGET" == "armv7" ]; then
	[ -z "$march" ] && march=armv7-a;
	[ -z "$mtune" ] && mtune=cortex-a8;
	CFLAGS="$CFLAGS -mfpu=vfp";
	echo "[INFO] Compiling for ARMv7"
elif [[ "$COMPILE_TARGET" == "mac" ]] || [[ "$COMPILE_TARGET" == "mac32" ]]; then
	[ -z "$march" ] && march=prescott;
	[ -z "$mtune" ] && mtune=generic;
	CFLAGS="$CFLAGS -m32 -arch i386 -fomit-frame-pointer -mmacosx-version-min=10.5";
	if [ "$DO_STATIC" == "no" ]; then
		LDFLAGS="$LDFLAGS -Wl,-rpath,@loader_path/../lib";
		export DYLD_LIBRARY_PATH="@loader_path/../lib"
	fi
	LEVELDB_VERSION="1bd4a335d620b395b0a587b15804f9b2ab3c403f"
	CFLAGS="$CFLAGS -Qunused-arguments -Wno-error=unused-command-line-argument-hard-error-in-future"
	ARCHFLAGS="-Wno-error=unused-command-line-argument-hard-error-in-future"
	GMP_ABI="32"
	echo "[INFO] Compiling for Intel MacOS x86"
elif [ "$COMPILE_TARGET" == "mac64" ]; then
	[ -z "$march" ] && march=core2;
	[ -z "$mtune" ] && mtune=generic;
	CFLAGS="$CFLAGS -m64 -arch x86_64 -fomit-frame-pointer -mmacosx-version-min=10.5";
	if [ "$DO_STATIC" == "no" ]; then
		LDFLAGS="$LDFLAGS -Wl,-rpath,@loader_path/../lib";
		export DYLD_LIBRARY_PATH="@loader_path/../lib"
	fi
	LEVELDB_VERSION="1bd4a335d620b395b0a587b15804f9b2ab3c403f"
	CFLAGS="$CFLAGS -Qunused-arguments -Wno-error=unused-command-line-argument-hard-error-in-future"
	ARCHFLAGS="-Wno-error=unused-command-line-argument-hard-error-in-future"
	GMP_ABI="64"
	echo "[INFO] Compiling for Intel MacOS x86_64"
elif [ "$COMPILE_TARGET" == "ios" ]; then
	[ -z "$march" ] && march=armv7-a;
	[ -z "$mtune" ] && mtune=cortex-a8;
	echo "[INFO] Compiling for iOS ARMv7"
elif [ -z "$CFLAGS" ]; then
	if [ `getconf LONG_BIT` == "64" ]; then
		echo "[INFO] Compiling for current machine using 64-bit"
		CFLAGS="-m64 $CFLAGS"
		GMP_ABI="64"
	else
		echo "[INFO] Compiling for current machine using 32-bit"
		CFLAGS="-m32 $CFLAGS"
		GMP_ABI="32"
	fi
fi

if [ "$TOOLCHAIN_PREFIX" != "" ]; then
		export CC="$TOOLCHAIN_PREFIX-gcc"
		export CXX="$TOOLCHAIN_PREFIX-g++"
		export AR="$TOOLCHAIN_PREFIX-ar"
		export RANLIB="$TOOLCHAIN_PREFIX-ranlib"
		export CPP="$TOOLCHAIN_PREFIX-cpp"
		export LD="$TOOLCHAIN_PREFIX-ld"
fi

echo "#include <stdio.h>" > test.c
echo "int main(void){" >> test.c
echo "printf(\"Hello world\n\");" >> test.c
echo "return 0;" >> test.c
echo "}" >> test.c


type $CC >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"$CC\""; read -p "Press [Enter] to continue..."; exit 1; }

[ -z "$THREADS" ] && THREADS=1;
[ -z "$march" ] && march=native;
[ -z "$mtune" ] && mtune=native;
[ -z "$CFLAGS" ] && CFLAGS="";

if [ "$DO_STATIC" == "no" ]; then
	[ -z "$LDFLAGS" ] && LDFLAGS="-Wl,-rpath='\$\$ORIGIN/../lib' -Wl,-rpath-link='\$\$ORIGIN/../lib'";
fi

[ -z "$CONFIGURE_FLAGS" ] && CONFIGURE_FLAGS="";

if [ "$mtune" != "none" ]; then
	$CC -march=$march -mtune=$mtune $CFLAGS -o test test.c >> "$DIR/install.log" 2>&1
	if [ $? -eq 0 ]; then
		CFLAGS="-march=$march -mtune=$mtune -fno-gcse $CFLAGS"
	fi
else
	$CC -march=$march $CFLAGS -o test test.c >> "$DIR/install.log" 2>&1
	if [ $? -eq 0 ]; then
		CFLAGS="-march=$march -fno-gcse $CFLAGS"
	fi
fi

rm test.* >> "$DIR/install.log" 2>&1
rm test >> "$DIR/install.log" 2>&1

export CC="$CC"
export CXX="$CXX"
export CFLAGS="-O2 -fPIC $CFLAGS"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="$LDFLAGS"
export CPPFLAGS="$CPPFLAGS"
export LIBRARY_PATH="$DIR/bin/php7/lib:$LIBRARY_PATH"

rm -r -f install_data/ >> "$DIR/install.log" 2>&1
rm -r -f bin/ >> "$DIR/install.log" 2>&1
mkdir -m 0755 install_data >> "$DIR/install.log" 2>&1
mkdir -m 0755 bin >> "$DIR/install.log" 2>&1
mkdir -m 0755 bin/php7 >> "$DIR/install.log" 2>&1
cd install_data
set -e

#PHP 5
echo -n "[PHP] downloading $PHP_VERSION..."

if [[ "$PHP_IS_BETA" == "yes" ]]; then
	download_file "https://downloads.php.net/~ab/php-$PHP_VERSION.tar.gz" | tar -zx >> "$DIR/install.log" 2>&1
	mv php-$PHP_VERSION php
else
	download_file "http://php.net/get/php-$PHP_VERSION.tar.gz/from/this/mirror" | tar -zx >> "$DIR/install.log" 2>&1
	mv php-$PHP_VERSION php
fi

echo " done!"

if [ "$COMPILE_FANCY" == "yes" ]; then
	if [ "$DO_STATIC" == "yes" ]; then
		EXTRA_FLAGS="--without-shared --with-static"
	else
		EXTRA_FLAGS="--with-shared --without-static"
	fi
	#ncurses
	echo -n "[ncurses] downloading $NCURSES_VERSION..."
	download_file "http://ftp.gnu.org/gnu/ncurses/ncurses-$NCURSES_VERSION.tar.gz" | tar -zx >> "$DIR/install.log" 2>&1
	mv ncurses-$NCURSES_VERSION ncurses
	echo -n " checking..."
	cd ncurses
	./configure --prefix="$DIR/bin/php7" \
	--without-ada \
	--without-manpages \
	--without-progs \
	--without-tests \
	--with-normal \
	--with-pthread \
	--without-debug \
	$EXTRA_FLAGS \
	$CONFIGURE_FLAGS >> "$DIR/install.log" 2>&1
	echo -n " compiling..."
	make -j $THREADS >> "$DIR/install.log" 2>&1
	echo -n " installing..."
	make install >> "$DIR/install.log" 2>&1
	echo -n " cleaning..."
	cd ..
	rm -r -f ./ncurses
	echo " done!"
	HAVE_NCURSES="--with-ncurses=$DIR/bin/php7"

	if [ "$DO_STATIC" == "yes" ]; then
		EXTRA_FLAGS="--enable-shared=no --enable-static=yes"
	else
		EXTRA_FLAGS="--enable-shared=yes --enable-static=no"
	fi
	#readline
	set +e
	echo -n "[readline] downloading $READLINE_VERSION..."
	download_file "http://ftp.gnu.org/gnu/readline/readline-$READLINE_VERSION.tar.gz" | tar -zx >> "$DIR/install.log" 2>&1
	mv readline-$READLINE_VERSION readline
	echo -n " checking..."
	cd readline
	./configure --prefix="$DIR/bin/php7" \
	--with-curses="$DIR/bin/php7" \
	--enable-multibyte \
	$EXTRA_FLAGS \
	$CONFIGURE_FLAGS >> "$DIR/install.log" 2>&1
	echo -n " compiling..."
	if make -j $THREADS >> "$DIR/install.log" 2>&1; then
		echo -n " installing..."
		make install >> "$DIR/install.log" 2>&1
		HAVE_READLINE="--with-readline=$DIR/bin/php7"
	else
		echo -n " disabling..."
		HAVE_READLINE="--without-readline"
	fi
	echo -n " cleaning..."
	cd ..
	rm -r -f ./readline
	echo " done!"
	set -e
else
	HAVE_NCURSES="--without-ncurses"
	HAVE_READLINE="--without-readline"
fi


if [ "$DO_STATIC" == "yes" ]; then
	EXTRA_FLAGS="--static"
else
	EXTRA_FLAGS="--shared"
fi

#zlib
echo -n "[zlib] downloading $ZLIB_VERSION..."
download_file "https://github.com/madler/zlib/archive/v$ZLIB_VERSION.tar.gz" | tar -zx >> "$DIR/install.log" 2>&1
mv zlib-$ZLIB_VERSION zlib
echo -n " checking..."
cd zlib
RANLIB=$RANLIB ./configure --prefix="$DIR/bin/php7" \
$EXTRA_FLAGS >> "$DIR/install.log" 2>&1
echo -n " compiling..."
make -j $THREADS >> "$DIR/install.log" 2>&1
echo -n " installing..."
make install >> "$DIR/install.log" 2>&1
echo -n " cleaning..."
cd ..
rm -r -f ./zlib
	if [ "$DO_STATIC" != "yes" ]; then
		rm -f "$DIR/bin/php7/lib/libz.a"
	fi
echo " done!"

export jm_cv_func_working_malloc=yes
export ac_cv_func_malloc_0_nonnull=yes
export jm_cv_func_working_realloc=yes
export ac_cv_func_realloc_0_nonnull=yes

#mcrypt
echo -n "[mcrypt] downloading $LIBMCRYPT_VERSION..."
download_file "http://sourceforge.net/projects/mcrypt/files/Libmcrypt/$LIBMCRYPT_VERSION/libmcrypt-$LIBMCRYPT_VERSION.tar.gz" | tar -zx >> "$DIR/install.log" 2>&1
mv libmcrypt-$LIBMCRYPT_VERSION libmcrypt
echo -n " checking..."
cd libmcrypt
rm -f config.guess
download_file "http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD" > config.guess
rm -f config.sub
download_file "http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD" > config.sub
RANLIB=$RANLIB ./configure --prefix="$DIR/bin/php7" \
--disable-posix-threads \
--enable-static \
--disable-shared \
$CONFIGURE_FLAGS >> "$DIR/install.log" 2>&1
sed -i=".backup" 's,/* #undef malloc */,#undef malloc,' config.h
sed -i=".backup" 's,/* #undef realloc */,#undef realloc,' config.h
echo -n " compiling..."
make -j $THREADS >> "$DIR/install.log" 2>&1
echo -n " installing..."
make install >> "$DIR/install.log" 2>&1
echo -n " cleaning..."
cd ..
rm -r -f ./libmcrypt
echo " done!"

if [ "$IS_CROSSCOMPILE" == "yes" ]; then
	EXTRA_FLAGS=""
else
	EXTRA_FLAGS="--disable-assembly"
fi

#GMP
echo -n "[GMP] downloading $GMP_VERSION..."
download_file "https://gmplib.org/download/gmp/gmp-$GMP_VERSION.tar.bz2" | tar -jx >> "$DIR/install.log" 2>&1
mv gmp-$GMP_VERSION_DIR gmp
echo -n " checking..."
cd gmp
RANLIB=$RANLIB ./configure --prefix="$DIR/bin/php7" \
$EXTRA_FLAGS \
--disable-posix-threads \
--enable-static \
--disable-shared \
$CONFIGURE_FLAGS ABI="$GMP_ABI" >> "$DIR/install.log" 2>&1
echo -n " compiling..."
make -j $THREADS >> "$DIR/install.log" 2>&1
echo -n " installing..."
make install >> "$DIR/install.log" 2>&1
echo -n " cleaning..."
cd ..
rm -r -f ./gmp
echo " done!"

if [ "$(uname -s)" != "Darwin" ] || [ "$IS_CROSSCOMPILE" == "yes" ] || [ "$COMPILE_CURL" == "yes" ]; then
	#if [ "$DO_STATIC" == "yes" ]; then
	#	EXTRA_FLAGS=""
	#else
	#	EXTRA_FLAGS="shared no-static"
	#fi


	#PolarSSL
	echo -n "[PolarSSL] downloading $POLARSSL_VERSION..."
	download_file "https://polarssl.org/download/mbedtls-${POLARSSL_VERSION}-gpl.tgz" | tar -zx >> "$DIR/install.log" 2>&1
	mv mbedtls-${POLARSSL_VERSION} polarssl
	echo -n " checking..."
	cd polarssl
	sed -i=".backup" 's,DESTDIR=/usr/local,,g' Makefile
	echo -n " compiling..."
	DESTDIR="$DIR/bin/php7" RANLIB=$RANLIB make -j $THREADS lib >> "$DIR/install.log" 2>&1
	echo -n " installing..."
	DESTDIR="$DIR/bin/php7" make install >> "$DIR/install.log" 2>&1
	echo -n " cleaning..."
	cd ..
	rm -r -f ./polarssl
	echo " done!"
fi

if [ "$(uname -s)" == "Darwin" ] && [ "$IS_CROSSCOMPILE" != "yes" ] && [ "$COMPILE_CURL" != "yes" ]; then
   HAVE_CURL="shared,/usr"
else
	if [ "$DO_STATIC" == "yes" ]; then
		EXTRA_FLAGS="--enable-static --disable-shared"
	else
		EXTRA_FLAGS="--disable-static --enable-shared"
	fi

	#curl
	echo -n "[cURL] downloading $CURL_VERSION..."
	download_file "https://github.com/bagder/curl/archive/$CURL_VERSION.tar.gz" | tar -zx >> "$DIR/install.log" 2>&1
	mv curl-$CURL_VERSION curl
	echo -n " checking..."
	cd curl
	./buildconf --force >> "$DIR/install.log" 2>&1
	RANLIB=$RANLIB ./configure --disable-dependency-tracking \
	--enable-ipv6 \
	--enable-optimize \
	--enable-http \
	--enable-ftp \
	--disable-dict \
	--enable-file \
	--without-librtmp \
	--disable-gopher \
	--disable-imap \
	--disable-pop3 \
	--disable-rtsp \
	--disable-smtp \
	--disable-telnet \
	--disable-tftp \
	--disable-ldap \
	--disable-ldaps \
	--without-libidn \
	--with-zlib="$DIR/bin/php7" \
	--without-ssl \
	--with-polarssl="$DIR/bin/php7" \
	--enable-threaded-resolver \
	--prefix="$DIR/bin/php7" \
	$EXTRA_FLAGS \
	$CONFIGURE_FLAGS >> "$DIR/install.log" 2>&1
	echo -n " compiling..."
	make -j $THREADS >> "$DIR/install.log" 2>&1
	echo -n " installing..."
	make install >> "$DIR/install.log" 2>&1
	echo -n " cleaning..."
	cd ..
	rm -r -f ./curl
	echo " done!"
	HAVE_CURL="$DIR/bin/php7"
fi

#bcompiler
#echo -n "[bcompiler] downloading $BCOMPILER_VERSION..."
#download_file "http://pecl.php.net/get/bcompiler-$BCOMPILER_VERSION.tgz" | tar -zx >> "$DIR/install.log" 2>&1
#mv bcompiler-$BCOMPILER_VERSION "$DIR/install_data/php/ext/bcompiler"
#echo " done!"

#PHP ncurses
#echo -n "[PHP ncurses] downloading $PHPNCURSES_VERSION..."
#download_file "http://pecl.php.net/get/ncurses-$PHPNCURSES_VERSION.tgz" | tar -zx >> "$DIR/install.log" 2>&1
#mv ncurses-$PHPNCURSES_VERSION "$DIR/install_data/php/ext/ncurses"
#echo " done!"


if [ "$DO_STATIC" == "yes" ]; then
	EXTRA_FLAGS="--disable-shared --enable-static"
else
	EXTRA_FLAGS="--enable-shared --disable-static"
fi
#YAML
echo -n "[YAML] downloading $YAML_VERSION..."
if [ "$COMPILE_FOR_ANDROID" == "yes" ]; then
	download_file "https://github.com/yaml/libyaml/archive/$YAML_VERSION.tar.gz" | tar -zx >> "$DIR/install.log" 2>&1
	mv libyaml-$YAML_VERSION yaml
	cd yaml
	./bootstrap >> "$DIR/install.log" 2>&1	
else
	download_file "http://pyyaml.org/download/libyaml/yaml-$YAML_VERSION.tar.gz" | tar -zx >> "$DIR/install.log" 2>&1
	mv yaml-$YAML_VERSION yaml
	cd yaml
fi

echo -n " checking..."

RANLIB=$RANLIB ./configure \
--prefix="$DIR/bin/php7" \
$EXTRA_FLAGS \
$CONFIGURE_FLAGS >> "$DIR/install.log" 2>&1
sed -i=".backup" 's/ tests win32/ win32/g' Makefile
echo -n " compiling..."
make -j $THREADS all >> "$DIR/install.log" 2>&1
echo -n " installing..."
make install >> "$DIR/install.log" 2>&1
echo -n " cleaning..."
cd ..
rm -r -f ./yaml
echo " done!"

if [ "$COMPILE_LEVELDB" == "yes" ]; then
	#LevelDB
	echo -n "[LevelDB] downloading $LEVELDB_VERSION..."
	download_file "https://github.com/PocketMine/leveldb/archive/$LEVELDB_VERSION.tar.gz" | tar -zx >> "$DIR/install.log" 2>&1
	#download_file "https://github.com/Mojang/leveldb-mcpe/archive/$LEVELDB_VERSION.tar.gz" | tar -zx >> "$DIR/install.log" 2>&1
	mv leveldb-$LEVELDB_VERSION leveldb
	echo -n " checking..."
	cd leveldb
	echo -n " compiling..."
	if [ "$DO_STATIC" == "yes" ]; then
		CFLAGS="$CFLAGS -I$DIR/bin/php7/include" CXXFLAGS="$CXXFLAGS -I$DIR/bin/php7/include" LDFLAGS="$LDFLAGS -L$DIR/bin/php7/lib" make -j $THREADS libleveldb.a >> "$DIR/install.log" 2>&1
	else
		CFLAGS="$CFLAGS -I$DIR/bin/php7/include" CXXFLAGS="$CXXFLAGS -I$DIR/bin/php7/include" LDFLAGS="$LDFLAGS -L$DIR/bin/php7/lib" make -j $THREADS >> "$DIR/install.log" 2>&1
	fi
	echo -n " installing..."
	cp libleveldb* "$DIR/bin/php7/lib/"
	cp -r include/leveldb "$DIR/bin/php7/include/leveldb"
	echo -n " cleaning..."
	cd ..
	rm -r -f ./leveldb
	echo " done!"
fi

if [ "$DO_STATIC" == "yes" ]; then
	EXTRA_FLAGS="--enable-shared=no --enable-static=yes"
else
	EXTRA_FLAGS="--enable-shared=yes --enable-static=no"
fi

#libpng
echo -n "[libpng] downloading $LIBPNG_VERSION..."
download_file "https://sourceforge.net/projects/libpng/files/libpng16/$LIBPNG_VERSION/libpng-$LIBPNG_VERSION.tar.gz" | tar -zx >> "$DIR/install.log" 2>&1
mv libpng-$LIBPNG_VERSION libpng
echo -n " checking..."
cd libpng
LDFLAGS="$LDFLAGS -L${DIR}/bin/php7/lib" CPPFLAGS="$CPPFLAGS -I${DIR}/bin/php7/include" RANLIB=$RANLIB ./configure \
--prefix="$DIR/bin/php7" \
$EXTRA_FLAGS \
$CONFIGURE_FLAGS >> "$DIR/install.log" 2>&1
echo -n " compiling..."
make -j $THREADS >> "$DIR/install.log" 2>&1
echo -n " installing..."
make install >> "$DIR/install.log" 2>&1
echo -n " cleaning..."
cd ..
rm -r -f ./libpng
echo " done!"

#libxml2
#echo -n "[libxml2] downloading $LIBXML_VERSION..."
#download_file "ftp://xmlsoft.org/libxml2/libxml2-$LIBXML_VERSION.tar.gz" | tar -zx >> "$DIR/install.log" 2>&1
#mv libxml2-$LIBXML_VERSION libxml2
#echo -n " checking..."
#cd libxml2
#RANLIB=$RANLIB ./configure \
#--disable-ipv6 \
#--with-libz="$DIR/bin/php7" \
#--prefix="$DIR/bin/php7" \
#$EXTRA_FLAGS \
#$CONFIGURE_FLAGS >> "$DIR/install.log" 2>&1
#echo -n " compiling..."
#make -j $THREADS >> "$DIR/install.log" 2>&1
#echo -n " installing..."
#make install >> "$DIR/install.log" 2>&1
#echo -n " cleaning..."
#cd ..
#rm -r -f ./libxml2
#echo " done!"






# PECL libraries

#TODO Uncomment this when it's ready for PHP7
#if [[ "$DO_STATIC" != "yes" ]] && [[ "$COMPILE_DEBUG" == "yes" ]]; then
#	#xdebug
#	echo -n "[PHP xdebug] downloading $XDEBUG_VERSION..."
#	download_file "http://pecl.php.net/get/xdebug-$XDEBUG_VERSION.tgz" | tar -zx >> "$DIR/install.log" 2>&1
#	mv xdebug-$XDEBUG_VERSION "$DIR/install_data/php/ext/xdebug"
#	echo " done!"
#	HAS_XDEBUG="--enable-xdebug=shared"
#else
#	HAS_XDEBUG=""
#fi

#if [ "$COMPILE_DEBUG" == "yes" ]; then
#	#profiler
#	echo -n "[PHP profiler] downloading latest..."
#	download_file "https://github.com/krakjoe/profiler/archive/master.tar.gz" | tar -zx >> "$DIR/install.log" 2>&1
#	mv profiler-master "$DIR/install_data/php/ext/profiler"
#	echo " done!"
#	HAS_PROFILER="--enable-profiler --with-profiler-max-frames=1000"
#else
#	HAS_PROFILER=""
#fi

#pthreads
echo -n "[PHP pthreads] downloading $PTHREADS_VERSION..."
download_file "http://pecl.php.net/get/pthreads-$PTHREADS_VERSION.tgz" | tar -zx >> "$DIR/install.log" 2>&1
#download_file "https://github.com/krakjoe/pthreads/archive/$PTHREADS_VERSION.tar.gz" | tar -zx >> "$DIR/install.log" 2>&1
mv pthreads-$PTHREADS_VERSION "$DIR/install_data/php/ext/pthreads"
echo " done!"

HAS_POCKETMINE=""
if [ "$HAS_ZEPHIR" == "yes" ]; then
	echo -n "[C PocketMine extension] downloading $PHP_POCKETMINE_VERSION..."
	download_file https://github.com/PocketMine/PocketMine-MP-Zephir/archive/$PHP_POCKETMINE_VERSION.tar.gz | tar -zx >> "$DIR/install.log" 2>&1
	mv PocketMine-MP-Zephir-$PHP_POCKETMINE_VERSION/pocketmine/ext "$DIR/install_data/php/ext/pocketmine"
	rm -r PocketMine-MP-Zephir-$PHP_POCKETMINE_VERSION/
	HAS_POCKETMINE="--enable-pocketmine"
	echo " done!"
fi

#uopz
#echo -n "[PHP uopz] downloading $UOPZ_VERSION..."
#download_file "http://pecl.php.net/get/uopz-$UOPZ_VERSION.tgz" | tar -zx >> "$DIR/install.log" 2>&1
#mv uopz-$UOPZ_VERSION "$DIR/install_data/php/ext/uopz"
#echo " done!"

#WeakRef
#TODO Remove when there is support for PHP7
#echo -n "[PHP Weakref] downloading $WEAKREF_VERSION..."
#download_file "http://pecl.php.net/get/Weakref-$WEAKREF_VERSION.tgz" | tar -zx >> "$DIR/install.log" 2>&1
#mv Weakref-$WEAKREF_VERSION "$DIR/install_data/php/ext/weakref"
#echo " done!"

#PHP YAML
echo -n "[PHP YAML] downloading $PHPYAML_VERSION..."
#download_file "http://pecl.php.net/get/yaml-$PHPYAML_VERSION.tgz" | tar -zx >> "$DIR/install.log" 2>&1
#mv yaml-$PHPYAML_VERSION "$DIR/install_data/php/ext/yaml"
download_file "https://github.com/php/pecl-file_formats-yaml/archive/$PHPYAML_VERSION.tar.gz" | tar -zx >> "$DIR/install.log" 2>&1
mv pecl-file_formats-yaml-$PHPYAML_VERSION "$DIR/install_data/php/ext/yaml"
echo " done!"

if [ "$COMPILE_LEVELDB" == "yes" ]; then
	#PHP LevelDB
	echo -n "[PHP LevelDB] downloading $PHPLEVELDB_VERSION..."
	#download_file "http://pecl.php.net/get/leveldb-$PHPLEVELDB_VERSION.tgz" | tar -zx >> "$DIR/install.log" 2>&1
	download_file "https://github.com/PocketMine/php-leveldb/archive/$PHPLEVELDB_VERSION.tar.gz" | tar -zx >> "$DIR/install.log" 2>&1
	mv php-leveldb-$PHPLEVELDB_VERSION "$DIR/install_data/php/ext/leveldb"
	echo " done!"
	HAS_LEVELDB=--with-leveldb="$DIR/bin/php7"
else
	HAS_LEVELDB=""
fi


echo -n "[PHP]"

if [ "$DO_OPTIMIZE" != "no" ]; then
	echo -n " enabling optimizations..."
	PHP_OPTIMIZATION="--enable-inline-optimization "
else
	PHP_OPTIMIZATION="--disable-inline-optimization "
fi
echo -n " checking..."
cd php
rm -f ./aclocal.m4 >> "$DIR/install.log" 2>&1
rm -rf ./autom4te.cache/ >> "$DIR/install.log" 2>&1
rm -f ./configure >> "$DIR/install.log" 2>&1
./buildconf --force >> "$DIR/install.log" 2>&1
if [ "$IS_CROSSCOMPILE" == "yes" ]; then
	sed -i=".backup" 's/pthreads_working=no/pthreads_working=yes/' ./configure
	if [ "$IS_WINDOWS" != "yes" ]; then
		if [ "$COMPILE_FOR_ANDROID" == "no" ]; then
			export LIBS="$LIBS -lpthread -ldl -lresolv"
		else
			export LIBS="$LIBS -lpthread -lresolv"
		fi
	else
		export LIBS="$LIBS -lpthread"
	fi

	mv ext/mysqlnd/config9.m4 ext/mysqlnd/config.m4
	sed  -i=".backup" "s{ext/mysqlnd/php_mysqlnd_config.h{config.h{" ext/mysqlnd/mysqlnd_portability.h
	CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-opcache=no"
elif [ "$DO_STATIC" == "yes" ]; then
	export LIBS="$LIBS -ldl"
fi

if [ "$IS_WINDOWS" != "yes" ]; then
	HAVE_PCNTL="--enable-pcntl"
else
	HAVE_PCNTL="--disable-pcntl"
	cp -f ./win32/build/config.* ./main >> "$DIR/install.log" 2>&1
	sed 's:@PREFIX@:$DIR/bin/php7:' ./main/config.w32.h.in > ./wmain/config.w32.h 2>> "$DIR/install.log"
fi

if [[ "$(uname -s)" == "Darwin" ]] && [[ "$IS_CROSSCOMPILE" != "yes" ]]; then
	sed -i=".backup" 's/flock_type=unknown/flock_type=bsd/' ./configure
	export EXTRA_CFLAGS=-lresolv
fi

#--enable-weakref \#

if [[ "$COMPILE_DEBUG" == "yes" ]]; then
	HAS_DEBUG="--enable-debug"
else
	HAS_DEBUG="--disable-debug"
fi

RANLIB=$RANLIB CFLAGS="$CFLAGS $FLAGS_LTO" LDFLAGS="$LDFLAGS $FLAGS_LTO" ./configure $PHP_OPTIMIZATION --prefix="$DIR/bin/php7" \
--exec-prefix="$DIR/bin/php7" \
--with-curl="$HAVE_CURL" \
--with-zlib="$DIR/bin/php7" \
--with-zlib-dir="$DIR/bin/php7" \
--with-mcrypt="$DIR/bin/php7" \
--with-gmp="$DIR/bin/php7" \
--with-png-dir="$DIR/bin/php7" \
--with-yaml="$DIR/bin/php7" \
--with-gd \
$HAVE_NCURSES \
$HAVE_READLINE \
$HAS_LEVELDB \
$HAS_POCKETMINE \
$HAS_XDEBUG \
$HAS_PROFILER \
$HAS_DEBUG \
--enable-mbstring \
--enable-calendar \
--enable-pthreads \
--disable-fileinfo \
--disable-libxml \
--disable-xml \
--disable-dom \
--disable-simplexml \
--disable-xmlreader \
--disable-xmlwriter \
--disable-cgi \
--disable-session \
--disable-pdo \
--without-pear \
--without-iconv \
--without-pdo-sqlite \
--with-pic \
--enable-phar \
--enable-ctype \
--enable-sockets \
--enable-shared=no \
--enable-static=yes \
--enable-shmop \
--enable-maintainer-zts \
--disable-short-tags \
$HAVE_PCNTL \
$HAVE_MYSQLI \
--enable-bcmath \
--enable-cli \
--enable-zip \
--enable-ftp \
--with-zend-vm=$ZEND_VM \
--enable-opcache=yes \
$CONFIGURE_FLAGS >> "$DIR/install.log" 2>&1
echo -n " compiling..."
if [ "$COMPILE_FOR_ANDROID" == "yes" ]; then
	sed -i=".backup" 's/-export-dynamic/-all-static/g' Makefile
fi
sed -i=".backup" 's/PHP_BINARIES. pharcmd$/PHP_BINARIES)/g' Makefile
sed -i=".backup" 's/install-programs install-pharcmd$/install-programs/g' Makefile

if [[ "$COMPILE_LEVELDB" == "yes" ]] && [[ "$DO_STATIC" == "yes" ]]; then
	sed -i=".backup" 's/--mode=link $(CC)/--mode=link $(CXX)/g' Makefile
fi

make -j $THREADS >> "$DIR/install.log" 2>&1
echo -n " installing..."
make install >> "$DIR/install.log" 2>&1

if [[ "$(uname -s)" == "Darwin" ]] && [[ "$IS_CROSSCOMPILE" != "yes" ]]; then
	set +e
	install_name_tool -delete_rpath "$DIR/bin/php7/lib" "$DIR/bin/php7/bin/php" >> "$DIR/install.log" 2>&1
	install_name_tool -change "$DIR/bin/php7/lib/libz.1.dylib" "@loader_path/../lib/libz.1.dylib" "$DIR/bin/php7/bin/php" >> "$DIR/install.log" 2>&1
	install_name_tool -change "$DIR/bin/php7/lib/libcurl.4.dylib" "@loader_path/../lib/libcurl.4.dylib" "$DIR/bin/php7/bin/php" >> "$DIR/install.log" 2>&1
	install_name_tool -change "$DIR/bin/php7/lib/libyaml-0.2.dylib" "@loader_path/../lib/libyaml-0.2.dylib" "$DIR/bin/php7/bin/php" >> "$DIR/install.log" 2>&1
	install_name_tool -change "$DIR/bin/php7/lib/libreadline.$READLINE_VERSION.dylib" "@loader_path/../lib/libreadline.$READLINE_VERSION.dylib" "$DIR/bin/php7/bin/php" >> "$DIR/install.log" 2>&1
	install_name_tool -change "$DIR/bin/php7/lib/libhistory.$READLINE_VERSION.dylib" "@loader_path/../lib/libhistory.$READLINE_VERSION.dylib" "$DIR/bin/php7/bin/php" >> "$DIR/install.log" 2>&1
	install_name_tool -change "$DIR/bin/php7/lib/libform.6.0.dylib" "@loader_path/../lib/libform.6.0.dylib" "$DIR/bin/php7/bin/php" >> "$DIR/install.log" 2>&1
	install_name_tool -change "$DIR/bin/php7/lib/libmenu.6.0.dylib" "@loader_path/../lib/libmenu.6.0.dylib" "$DIR/bin/php7/bin/php" >> "$DIR/install.log" 2>&1
	install_name_tool -change "$DIR/bin/php7/lib/libncurses.6.0.dylib" "@loader_path/../lib/libncurses.6.0.dylib" "$DIR/bin/php7/bin/php" >> "$DIR/install.log" 2>&1
	install_name_tool -change "$DIR/bin/php7/lib/libpanel.6.0.dylib" "@loader_path/../lib/libpanel.6.0.dylib" "$DIR/bin/php7/bin/php" >> "$DIR/install.log" 2>&1
	install_name_tool -change "$DIR/bin/php7/lib/libleveldb.dylib.1.18" "@loader_path/../lib/libleveldb.dylib.1.18" "$DIR/bin/php7/bin/php" >> "$DIR/install.log" 2>&1
	install_name_tool -change "$DIR/bin/php7/lib/libpng16.16.dylib" "@loader_path/../lib/libpng16.16.dylib" "$DIR/bin/php7/bin/php" >> "$DIR/install.log" 2>&1
	
	#install_name_tool -change "$DIR/bin/php7/lib/libssl.1.0.0.dylib" "@loader_path/../lib/libssl.1.0.0.dylib" "$DIR/bin/php7/bin/php" >> "$DIR/install.log" 2>&1
	#install_name_tool -change "$DIR/bin/php7/lib/libssl.1.0.0.dylib" "@loader_path/../lib/libssl.1.0.0.dylib" "$DIR/bin/php7/lib/libcurl.4.dylib" >> "$DIR/install.log" 2>&1
	#install_name_tool -change "$DIR/bin/php7/lib/libcrypto.1.0.0.dylib" "@loader_path/../lib/libcrypto.1.0.0.dylib" "$DIR/bin/php7/bin/php" >> "$DIR/install.log" 2>&1
	#install_name_tool -change "$DIR/bin/php7/lib/libcrypto.1.0.0.dylib" "@loader_path/../lib/libcrypto.1.0.0.dylib" "$DIR/bin/php7/lib/libcurl.4.dylib" >> "$DIR/install.log" 2>&1
	#chmod 0777 "$DIR/bin/php7/lib/libssl.1.0.0.dylib" >> "$DIR/install.log" 2>&1
	#install_name_tool -change "$DIR/bin/php7/lib/libcrypto.1.0.0.dylib" "@loader_path/libcrypto.1.0.0.dylib" "$DIR/bin/php7/lib/libssl.1.0.0.dylib" >> "$DIR/install.log" 2>&1
	#chmod 0755 "$DIR/bin/php7/lib/libssl.1.0.0.dylib" >> "$DIR/install.log" 2>&1
	set -e
fi

echo -n " generating php.ini..."
trap - DEBUG
TIMEZONE=$(date +%Z)
echo "date.timezone=$TIMEZONE" > "$DIR/bin/php7/bin/php.ini"
echo "short_open_tag=0" >> "$DIR/bin/php7/bin/php.ini"
echo "asp_tags=0" >> "$DIR/bin/php7/bin/php.ini"
echo "phar.readonly=0" >> "$DIR/bin/php7/bin/php.ini"
echo "phar.require_hash=1" >> "$DIR/bin/php7/bin/php.ini"
#echo "zend_extension=uopz.so" >> "$DIR/bin/php7/bin/php.ini"
if [[ "$COMPILE_DEBUG" == "yes" ]]; then
	echo "zend.assertions=1" >> "$DIR/bin/php7/bin/php.ini"
else
	echo "zend.assertions=-1" >> "$DIR/bin/php7/bin/php.ini"
fi

if [ "$IS_CROSSCOMPILE" != "yes" ] && [ "$DO_STATIC" == "no" ]; then
	echo ";zend_extension=xdebug.so" >> "$DIR/bin/php7/bin/php.ini"
	echo "zend_extension=opcache.so" >> "$DIR/bin/php7/bin/php.ini"
	echo "opcache.enable=1" >> "$DIR/bin/php7/bin/php.ini"
	echo "opcache.enable_cli=1" >> "$DIR/bin/php7/bin/php.ini"
	echo "opcache.save_comments=1" >> "$DIR/bin/php7/bin/php.ini"
	echo "opcache.fast_shutdown=0" >> "$DIR/bin/php7/bin/php.ini"
	echo "opcache.max_accelerated_files=4096" >> "$DIR/bin/php7/bin/php.ini"
	echo "opcache.interned_strings_buffer=8" >> "$DIR/bin/php7/bin/php.ini"
	echo "opcache.memory_consumption=128" >> "$DIR/bin/php7/bin/php.ini"
	echo "opcache.optimization_level=0xffffffff" >> "$DIR/bin/php7/bin/php.ini"
fi

if [ "$HAVE_CURL" == "shared,/usr" ]; then
	echo "extension=curl.so" >> "$DIR/bin/php7/bin/php.ini"
fi

echo " done!"
cd "$DIR"
echo -n "[INFO] Cleaning up..."
rm -r -f install_data/ >> "$DIR/install.log" 2>&1
rm -f bin/php7/bin/curl* >> "$DIR/install.log" 2>&1
rm -f bin/php7/bin/curl-config* >> "$DIR/install.log" 2>&1
rm -f bin/php7/bin/c_rehash* >> "$DIR/install.log" 2>&1
rm -f bin/php7/bin/openssl* >> "$DIR/install.log" 2>&1
rm -r -f bin/php7/man >> "$DIR/install.log" 2>&1
rm -r -f bin/php7/php >> "$DIR/install.log" 2>&1
rm -r -f bin/php7/misc >> "$DIR/install.log" 2>&1
date >> "$DIR/install.log" 2>&1
echo " done!"
echo "[PocketMine] You should start the server now using \"./start.sh.\""
echo "[PocketMine] If it doesn't work, please send the \"install.log\" file to the Bug Tracker."
