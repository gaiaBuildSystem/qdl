# SPDX-License-Identifier: BSD-3-Clause
#
# Toolchain images producing statically linked qdl binaries.
# The qdl sources are not baked in: mount the tree at /src and an output
# directory at /out (see docker-compose.yml at the repository root).

FROM debian:trixie-slim AS base
RUN apt-get update && apt-get install -y --no-install-recommends \
		bzip2 ca-certificates cmake curl gcc git libc6-dev make meson \
		ninja-build pkgconf xz-utils \
	&& rm -rf /var/lib/apt/lists/*
COPY build-deps.sh build-qdl.sh /usr/local/bin/
WORKDIR /src

# Linux: static glibc. libusb is built without udev, so nothing needs NSS
# or dlopen at run time.
FROM base AS linux
RUN build-deps.sh linux
ENTRYPOINT ["build-qdl.sh", "linux"]

# Windows: cross-compile with mingw-w64.
FROM base AS windows
RUN apt-get update && apt-get install -y --no-install-recommends \
		gcc-mingw-w64-x86-64 \
	&& rm -rf /var/lib/apt/lists/*
COPY mingw-w64-x86_64.ini /usr/local/share/qdl/
RUN build-deps.sh windows
ENV STRIP=x86_64-w64-mingw32-strip
ENTRYPOINT ["build-qdl.sh", "windows"]
