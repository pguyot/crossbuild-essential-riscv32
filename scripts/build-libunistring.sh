#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# libunistring build uses the riscv32 toolchain from common.sh
# CC, AR, RANLIB, CFLAGS, etc. are already set by common.sh

LIBUNISTRING_VERSION=1.1
PACKAGE_NAME=libunistring5-riscv32-cross
BUILD_DIR=$(pwd)/build/libunistring
INSTALL_DIR=$(pwd)/build/${PACKAGE_NAME}

log_info "Building libunistring for ${TARGET}"

# Get libunistring source from Ubuntu
if [ ! -d "libunistring-${LIBUNISTRING_VERSION}" ]; then
    log_info "Getting libunistring source from Ubuntu..."
    apt-get source libunistring
    # Find the extracted directory
    LIBUNISTRING_SRC_DIR=$(ls -d libunistring*/ 2>/dev/null | head -1 | sed 's:/$::')
    if [ -z "$LIBUNISTRING_SRC_DIR" ]; then
        log_error "Failed to extract libunistring source"
        exit 1
    fi
    # Rename if necessary
    if [ "$LIBUNISTRING_SRC_DIR" != "libunistring-${LIBUNISTRING_VERSION}" ] && [ ! -d "libunistring-${LIBUNISTRING_VERSION}" ]; then
        log_info "Renaming $LIBUNISTRING_SRC_DIR to libunistring-${LIBUNISTRING_VERSION}"
        mv "$LIBUNISTRING_SRC_DIR" libunistring-${LIBUNISTRING_VERSION}
    fi
fi

# Create build directory
rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}
cd libunistring-${LIBUNISTRING_VERSION}

# Configure and build libunistring
log_info "Configuring libunistring..."
./configure \
    --prefix=${PREFIX} \
    --host=${TARGET} \
    --build=x86_64-linux-gnu \
    CC="${CC}" \
    CFLAGS="${CFLAGS}" \
    --disable-static \
    --enable-shared

log_info "Building libunistring..."
make -j${JOBS}

# Install to package directory
log_info "Installing libunistring to package directory..."
rm -rf ${INSTALL_DIR}
mkdir -p ${INSTALL_DIR}
make install DESTDIR=${INSTALL_DIR}

# Create runtime package (libunistring5-riscv32-cross)
log_info "Creating libunistring5-riscv32-cross package..."
RUNTIME_DIR=$(pwd)/../build/libunistring5-riscv32-cross-runtime
mkdir -p ${RUNTIME_DIR}/DEBIAN
mkdir -p ${RUNTIME_DIR}${PREFIX}/lib

# Copy runtime libraries
cp -a ${INSTALL_DIR}${PREFIX}/lib/*.so* ${RUNTIME_DIR}${PREFIX}/lib/ || true

cat > ${RUNTIME_DIR}/DEBIAN/control << EOF
Package: libunistring5-riscv32-cross
Version: ${LIBUNISTRING_VERSION}-0ubuntu1
Section: libs
Priority: optional
Architecture: all
Maintainer: ${MAINTAINER}
Description: Unicode string library for C (for RISC-V 32-bit cross-compiling)
 The 'libunistring' library implements Unicode strings (in the UTF-8,
 UTF-16, and UTF-32 encodings), together with functions for Unicode
 characters (character names, classifications, properties) and
 functions for string processing (formatted output, width, word breaks,
 line breaks, normalization, case folding, regular expressions).
 .
 This package contains the shared library for RISC-V 32-bit.
 .
 This package is for cross-compiling.
EOF

cd ..
dpkg-deb --build ${RUNTIME_DIR} build/libunistring5-riscv32-cross_${LIBUNISTRING_VERSION}-0ubuntu1_all.deb
log_info "Created: libunistring5-riscv32-cross_${LIBUNISTRING_VERSION}-0ubuntu1_all.deb"

log_info "libunistring build complete!"
