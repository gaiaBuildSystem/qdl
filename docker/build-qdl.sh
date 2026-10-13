#!/bin/sh
# SPDX-License-Identifier: BSD-3-Clause
#
# Build a static qdl from the source tree mounted at /src and copy the
# result to /out. Runs inside the images defined in docker/Dockerfile.
# Usage: build-qdl.sh linux|windows
set -eu

TARGET=$1
BUILD=/tmp/build-$TARGET
OUT=/out/$TARGET-$(uname -m)

# The bind-mounted tree is owned by the host user; let git describe it.
git config --global --add safe.directory /src

set -- -Dtests=disabled -Dnbdkit=disabled -Dzip-container=enabled \
	--buildtype=release --prefer-static
[ -n "${VERSION:-}" ] && set -- "$@" -DVERSION="$VERSION"

case "$TARGET" in
linux)
	export PKG_CONFIG_LIBDIR=/opt/deps/lib/pkgconfig
	set -- "$@" -Dc_link_args=-static
	EXE=qdl
	;;
windows)
	set -- "$@" --cross-file /usr/local/share/qdl/mingw-w64-x86_64.ini
	EXE=qdl.exe
	OUT=/out/windows-x86_64
	;;
*)
	echo "usage: $0 linux|windows" >&2
	exit 1
	;;
esac

rm -rf "$BUILD"
meson setup "$BUILD" /src "$@"
meson compile -C "$BUILD"

mkdir -p "$OUT"
cp "$BUILD/$EXE" "$OUT/"
${STRIP:-strip} "$OUT/$EXE"
[ -n "${HOST_UID:-}" ] && chown -R "$HOST_UID:${HOST_GID:-$HOST_UID}" /out
echo "Built $OUT/$EXE"
