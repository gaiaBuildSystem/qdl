#!/bin/sh
# SPDX-License-Identifier: BSD-3-Clause
#
# Build statically linked qdl binaries for Linux and Windows with Docker.
#
# Wraps the docker compose setup in docker-compose.yml (see that file for the
# image layout). Each target yields a self-contained, statically linked
# executable under ./dist/:
#
#   dist/linux-<arch>/qdl        Linux binary
#   dist/windows-x86_64/qdl.exe  Windows binary
set -eu

cd "$(dirname "$0")"

usage() {
	cat <<'EOF'
Build statically linked qdl binaries for Linux and Windows with Docker.

Usage: buildStatic.sh [linux|windows]...

  (no args)    Build both Linux and Windows.
  linux        Build the Linux binary only.
  windows      Build the Windows binary only.

Options:
  -h, --help   Show this help.

Environment:
  VERSION    Override the git-derived version baked into qdl.
  HOST_UID   Own ./dist files as this uid (default: current user).
  HOST_GID   Own ./dist files as this gid (default: current group).

Results land in ./dist/<target>-<arch>/.
EOF
}

# --- parse arguments ---------------------------------------------------
targets=""
for arg in "$@"; do
	case "$arg" in
	-h|--help)
		usage
		exit 0
		;;
	linux|windows)
		case " $targets " in
		*" $arg "*) ;; # already selected
		*) targets="$targets $arg" ;;
		esac
		;;
	*)
		echo "error: unknown argument '$arg' (use linux or windows)" >&2
		usage >&2
		exit 1
		;;
	esac
done
[ -n "$targets" ] || targets=" linux windows"

# --- preflight ---------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
	echo "error: docker is not installed or not on PATH" >&2
	exit 1
fi

# Prefer the modern 'docker compose' plugin over the legacy standalone binary.
if docker compose version >/dev/null 2>&1; then
	dc() { docker compose "$@"; }
elif command -v docker-compose >/dev/null 2>&1; then
	dc() { docker-compose "$@"; }
else
	echo "error: neither 'docker compose' nor 'docker-compose' available" >&2
	exit 1
fi

# Default to host-owned outputs so the files are usable without sudo.
export HOST_UID="${HOST_UID:-$(id -u)}"
export HOST_GID="${HOST_GID:-$(id -g)}"

if [ -n "${VERSION:-}" ]; then
	echo "Building qdl VERSION=${VERSION}..."
fi

# --- build -------------------------------------------------------------
dc build $targets
for t in $targets; do
	dc run --rm "$t"
done

echo ""
echo "Static binaries are in ./dist/:"
( cd dist 2>/dev/null && ls -1 ) || true
