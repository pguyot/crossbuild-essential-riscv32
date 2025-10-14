#!/bin/bash
set -euo pipefail

MABI=$1
MARCH=$2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "Building libidn2 for ${ARCH} (${MARCH};${MABI})"

# Define ABI-specific library path
LIB_DIR="${TARGET}-${MABI}"

LIBIDN2_VERSION=2.3.7
BUILD_DIR=$(pwd)/build/libidn2
INSTALL_DIR=$(pwd)/build/libidn2-${MABI}

# Get libidn2 source from Ubuntu
if [ ! -d "libidn2-${LIBIDN2_VERSION}" ]; then
    log_info "Getting libidn2 source from Ubuntu..."
    apt-get source libidn2
    # Find the extracted directory
    LIBIDN2_SRC_DIR=$(ls -d libidn2*/ 2>/dev/null | head -1 | sed 's:/$::')
    if [ -z "$LIBIDN2_SRC_DIR" ]; then
        log_error "Failed to extract libidn2 source"
        exit 1
    fi
    # Rename if necessary
    if [ "$LIBIDN2_SRC_DIR" != "libidn2-${LIBIDN2_VERSION}" ] && [ ! -d "libidn2-${LIBIDN2_VERSION}" ]; then
        log_info "Renaming $LIBIDN2_SRC_DIR to libidn2-${LIBIDN2_VERSION}"
        mv "$LIBIDN2_SRC_DIR" libidn2-${LIBIDN2_VERSION}
    fi
fi

# Create build directory
rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}
cd libidn2-${LIBIDN2_VERSION}

# Configure and build libidn2
log_info "Configuring libidn2..."
./configure \
    --prefix=/usr \
    --host=${TARGET} \
    --build=x86_64-linux-gnu \
    CC="${CC}" \
    CFLAGS="${CFLAGS} -I$(pwd)/../build/libunistring-${MABI}/usr/include/${LIB_DIR}" \
    LDFLAGS="${LDFLAGS} -L$(pwd)/../build/libunistring-${MABI}/usr/lib/${LIB_DIR}" \
    --disable-static \
    --enable-shared

log_info "Building libidn2..."
make -j${JOBS}

# Install to package directory
log_info "Installing libidn2 to package directory..."
rm -rf ${INSTALL_DIR}
mkdir -p ${INSTALL_DIR}
make install DESTDIR=${INSTALL_DIR}

# Create runtime package with ABI-specific name
PKG_NAME="libidn2-0-${MABI}"
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
Version: ${LIBIDN2_VERSION}-0ubuntu1
Multi-Arch: same
Section: libs
Priority: optional
Depends: libunistring5-${MABI}
Maintainer: ${MAINTAINER}
Description: Internationalized domain names (IDNA2008/TR46) library (${ARCH} ${MARCH}-${MABI} cross-compile)
 Libidn2 implements the revised algorithm for internationalized domain
 names called IDNA2008/TR46.
 .
 This package contains the shared library for RISC-V 32-bit (${MARCH};${MABI}).
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build ${RUNTIME_DIR} build/${PKG_NAME}_${LIBIDN2_VERSION}-0ubuntu1_${ARCH}.deb
log_info "Created: ${PKG_NAME}_${LIBIDN2_VERSION}-0ubuntu1_${ARCH}.deb"

log_info "libidn2 build complete!"
