#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# libidn2 build uses the riscv32 toolchain from common.sh
# CC, AR, RANLIB, CFLAGS, etc. are already set by common.sh

LIBIDN2_VERSION=2.3.7
PACKAGE_NAME=libidn2-0-riscv32-cross
BUILD_DIR=$(pwd)/build/libidn2
INSTALL_DIR=$(pwd)/build/${PACKAGE_NAME}

log_info "Building libidn2 for ${TARGET}"

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
    --prefix=${PREFIX} \
    --host=${TARGET} \
    --build=x86_64-linux-gnu \
    CC="${CC}" \
    CFLAGS="${CFLAGS}" \
    LDFLAGS="${LDFLAGS} -L${PREFIX}/lib" \
    --with-libunistring-prefix=${PREFIX} \
    --disable-static \
    --enable-shared

log_info "Building libidn2..."
make -j${JOBS}

# Install to package directory
log_info "Installing libidn2 to package directory..."
rm -rf ${INSTALL_DIR}
mkdir -p ${INSTALL_DIR}
make install DESTDIR=${INSTALL_DIR}

# Create runtime package (libidn2-0-riscv32-cross)
log_info "Creating libidn2-0-riscv32-cross package..."
RUNTIME_DIR=$(pwd)/../build/libidn2-0-riscv32-cross-runtime
mkdir -p ${RUNTIME_DIR}/DEBIAN
mkdir -p ${RUNTIME_DIR}${PREFIX}/lib

# Copy runtime libraries
cp -a ${INSTALL_DIR}${PREFIX}/lib/*.so* ${RUNTIME_DIR}${PREFIX}/lib/ || true

cat > ${RUNTIME_DIR}/DEBIAN/control << EOF
Package: libidn2-0-riscv32-cross
Version: ${LIBIDN2_VERSION}-0ubuntu1
Section: libs
Priority: optional
Architecture: all
Depends: libunistring5-riscv32-cross
Maintainer: ${MAINTAINER}
Description: Internationalized domain names (IDNA2008/TR46) library (for RISC-V 32-bit)
 Libidn2 implements the revised algorithm for internationalized domain
 names called IDNA2008/TR46.
 .
 This package contains the shared library for RISC-V 32-bit.
 .
 This package is for cross-compiling.
EOF

cd ..
dpkg-deb --build ${RUNTIME_DIR} build/libidn2-0-riscv32-cross_${LIBIDN2_VERSION}-0ubuntu1_all.deb
log_info "Created: libidn2-0-riscv32-cross_${LIBIDN2_VERSION}-0ubuntu1_all.deb"

log_info "libidn2 build complete!"
