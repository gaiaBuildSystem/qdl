#!/bin/sh
# SPDX-License-Identifier: BSD-3-Clause
#
# Build static-only copies of qdl's dependencies into $PREFIX.
# Usage: build-deps.sh linux|windows
set -eu

TARGET=$1
PREFIX=${PREFIX:-/opt/deps}
JOBS=$(nproc)

ZLIB_VER=1.3.1
LIBUSB_VER=1.0.29
LIBXML2_VER=2.14.5
LIBZIP_VER=1.11.4

case "$TARGET" in
linux)
	HOST=
	CMAKE_CROSS=
	;;
windows)
	HOST=x86_64-w64-mingw32
	CMAKE_CROSS="-DCMAKE_SYSTEM_NAME=Windows \
		-DCMAKE_C_COMPILER=$HOST-gcc \
		-DCMAKE_RC_COMPILER=$HOST-windres \
		-DCMAKE_FIND_ROOT_PATH=$PREFIX \
		-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
		-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
		-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY"
	;;
*)
	echo "usage: $0 linux|windows" >&2
	exit 1
	;;
esac

HOST_FLAG=${HOST:+--host=$HOST}
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"

WORK=$(mktemp -d)
cd "$WORK"

fetch() {
	curl -fsSL --retry 3 "$1" | tar -xf - ${2:+--$2}
}

# zlib
fetch "https://github.com/madler/zlib/releases/download/v$ZLIB_VER/zlib-$ZLIB_VER.tar.gz" gzip
(cd "zlib-$ZLIB_VER" &&
	CHOST=$HOST ./configure --static --prefix="$PREFIX" &&
	make -j"$JOBS" install)

# libusb
fetch "https://github.com/libusb/libusb/releases/download/v$LIBUSB_VER/libusb-$LIBUSB_VER.tar.bz2" bzip2
(cd "libusb-$LIBUSB_VER" &&
	./configure $HOST_FLAG --prefix="$PREFIX" \
		--disable-shared --enable-static --disable-udev &&
	make -j"$JOBS" install)

# libxml2 (qdl only parses local XML; drop every optional feature)
fetch "https://download.gnome.org/sources/libxml2/${LIBXML2_VER%.*}/libxml2-$LIBXML2_VER.tar.xz" xz
(cd "libxml2-$LIBXML2_VER" &&
	./configure $HOST_FLAG --prefix="$PREFIX" \
		--disable-shared --enable-static \
		--without-python --without-iconv --without-icu \
		--without-zlib --without-lzma --without-http \
		--without-readline --without-history &&
	make -j"$JOBS" install)

# libzip (deflate only)
fetch "https://libzip.org/download/libzip-$LIBZIP_VER.tar.xz" xz
cmake -S "libzip-$LIBZIP_VER" -B libzip-build -G Ninja $CMAKE_CROSS \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX="$PREFIX" \
	-DCMAKE_PREFIX_PATH="$PREFIX" \
	-DBUILD_SHARED_LIBS=OFF \
	-DENABLE_BZIP2=OFF -DENABLE_LZMA=OFF -DENABLE_ZSTD=OFF \
	-DENABLE_OPENSSL=OFF -DENABLE_GNUTLS=OFF -DENABLE_MBEDTLS=OFF \
	-DENABLE_COMMONCRYPTO=OFF -DENABLE_WINDOWS_CRYPTO=OFF \
	-DBUILD_TOOLS=OFF -DBUILD_REGRESS=OFF -DBUILD_OSSFUZZ=OFF \
	-DBUILD_EXAMPLES=OFF -DBUILD_DOC=OFF
cmake --build libzip-build --target install

cd /
rm -rf "$WORK"
