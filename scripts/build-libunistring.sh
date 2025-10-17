#!/bin/bash
set -euo pipefail

MABI=$1
MARCH=$2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "Building libunistring for ${ARCH} (${MARCH};${MABI})"

# Define ABI-specific library path
LIB_DIR="${TARGET}-${MABI}"

LIBUNISTRING_VERSION=1.1
BUILD_DIR=$(pwd)/build/libunistring
INSTALL_DIR=$(pwd)/build/libunistring-${MABI}

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
    --prefix=/usr \
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

# Create runtime package with ABI-specific name
PKG_NAME="libunistring5-${MABI}"
log_info "Creating ${PKG_NAME} package..."
cd ..
RUNTIME_DIR=$(pwd)/build/${PKG_NAME}
mkdir -p ${RUNTIME_DIR}/DEBIAN
mkdir -p ${RUNTIME_DIR}/usr/lib/${LIB_DIR}

# Copy runtime libraries
cp -a ${INSTALL_DIR}/usr/lib/*.so* ${RUNTIME_DIR}/usr/lib/${LIB_DIR}/ || true

cat > ${RUNTIME_DIR}/DEBIAN/control << EOF
Package: ${PKG_NAME}
Architecture: ${ARCH}
Version: ${LIBUNISTRING_VERSION}-0ubuntu1
Multi-Arch: same
Section: libs
Priority: optional
Maintainer: ${MAINTAINER}
Description: Unicode string library for C (${ARCH} ${MARCH}-${MABI} cross-compile)
 The 'libunistring' library implements Unicode strings (in the UTF-8,
 UTF-16, and UTF-32 encodings), together with functions for Unicode
 characters (character names, classifications, properties) and
 functions for string processing (formatted output, width, word breaks,
 line breaks, normalization, case folding, regular expressions).
 .
 This package contains the shared library for RISC-V 32-bit (${MARCH};${MABI}).
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build ${RUNTIME_DIR} build/${PKG_NAME}_${LIBUNISTRING_VERSION}-0ubuntu1_${ARCH}.deb
log_info "Created: ${PKG_NAME}_${LIBUNISTRING_VERSION}-0ubuntu1_${ARCH}.deb"

log_info "libunistring build complete!"
