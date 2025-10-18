#!/bin/bash
set -euo pipefail

MABI=$1
MARCH=$2

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "Building zlib for ${ARCH} (${MARCH};${MABI})"

# Define ABI-specific library path
LIB_DIR="${TARGET}-${MABI}"

ZLIB_VERSION=1.3.1
PACKAGE_NAME=zlib1g-${MABI}
BUILD_DIR=$(pwd)/build/zlib
INSTALL_DIR=$(pwd)/build/${PACKAGE_NAME}

# Get zlib source from Ubuntu
if [ ! -d "zlib-${ZLIB_VERSION}" ]; then
    log_info "Getting zlib source from Ubuntu..."
    apt-get source zlib
    # Find the extracted directory
    ZLIB_SRC_DIR=$(ls -d zlib*/ 2>/dev/null | head -1 | sed 's:/$::')
    if [ -z "$ZLIB_SRC_DIR" ]; then
        log_error "Failed to extract zlib source"
        exit 1
    fi
    # Rename if necessary
    if [ "$ZLIB_SRC_DIR" != "zlib-${ZLIB_VERSION}" ] && [ ! -d "zlib-${ZLIB_VERSION}" ]; then
        log_info "Renaming $ZLIB_SRC_DIR to zlib-${ZLIB_VERSION}"
        mv "$ZLIB_SRC_DIR" zlib-${ZLIB_VERSION}
    fi
fi

# Create build directory
rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}
cd zlib-${ZLIB_VERSION}

# Configure and build zlib
log_info "Configuring zlib..."
CROSS_PREFIX=${TARGET}- \
CC="${CC}" \
CFLAGS="${CFLAGS}" \
./configure --prefix=${PREFIX}

log_info "Building zlib..."
make -j${JOBS}

# Install to package directory
log_info "Installing zlib to package directory..."
rm -rf ${INSTALL_DIR}
mkdir -p ${INSTALL_DIR}
make install DESTDIR=${INSTALL_DIR}

# Create runtime package with ABI-specific name
PKG_NAME_RUNTIME="zlib1g-${MABI}"
log_info "Creating ${PKG_NAME_RUNTIME} package..."
RUNTIME_DIR=$(pwd)/../build/${PKG_NAME_RUNTIME}-runtime
mkdir -p ${RUNTIME_DIR}/DEBIAN
mkdir -p ${RUNTIME_DIR}/usr/lib/${LIB_DIR}

# Copy runtime libraries (only versioned .so files, not the unversioned symlink)
cp -a ${INSTALL_DIR}${PREFIX}/lib/libz.so.* ${RUNTIME_DIR}/usr/lib/${LIB_DIR}/ || true

cat > ${RUNTIME_DIR}/DEBIAN/control << EOF
Package: ${PKG_NAME_RUNTIME}
Architecture: ${ARCH}
Version: ${ZLIB_VERSION}-0ubuntu1
Multi-Arch: same
Section: libs
Priority: optional
Maintainer: ${MAINTAINER}
Description: compression library - runtime (${ARCH} ${MARCH}-${MABI} cross-compile)
 zlib is a library implementing the deflate compression method found
 in gzip and PKZIP.  This package includes the shared library for
 RISC-V 32-bit (${MARCH};${MABI}).
 .
 This package is for cross-compiling.
EOF

cd ..
dpkg-deb --build ${RUNTIME_DIR} build/${PKG_NAME_RUNTIME}_${ZLIB_VERSION}-0ubuntu1_${ARCH}.deb
log_info "Created: ${PKG_NAME_RUNTIME}_${ZLIB_VERSION}-0ubuntu1_${ARCH}.deb"

# Create development package with ABI-specific name
PKG_NAME_DEV="zlib1g-dev-${MABI}"
log_info "Creating ${PKG_NAME_DEV} package..."
DEV_DIR=$(pwd)/build/${PKG_NAME_DEV}
mkdir -p ${DEV_DIR}/DEBIAN
mkdir -p ${DEV_DIR}/usr/lib/${LIB_DIR}
mkdir -p ${DEV_DIR}/usr/include/${LIB_DIR}

# Copy development files
cp -a ${INSTALL_DIR}${PREFIX}/include/*.h ${DEV_DIR}/usr/include/${LIB_DIR}/ || true
cp -a ${INSTALL_DIR}${PREFIX}/lib/libz.so ${DEV_DIR}/usr/lib/${LIB_DIR}/ || true
cp -a ${INSTALL_DIR}${PREFIX}/lib/*.a ${DEV_DIR}/usr/lib/${LIB_DIR}/ || true
mkdir -p ${DEV_DIR}/usr/lib/${LIB_DIR}/pkgconfig
cp -a ${INSTALL_DIR}${PREFIX}/lib/pkgconfig/*.pc ${DEV_DIR}/usr/lib/${LIB_DIR}/pkgconfig/ || true

# Fix pkg-config file paths
if [ -f ${DEV_DIR}/usr/lib/${LIB_DIR}/pkgconfig/zlib.pc ]; then
    sed -i "s|prefix=/usr|prefix=/usr|g" ${DEV_DIR}/usr/lib/${LIB_DIR}/pkgconfig/zlib.pc
    sed -i "s|libdir=.*|libdir=/usr/lib/${LIB_DIR}|g" ${DEV_DIR}/usr/lib/${LIB_DIR}/pkgconfig/zlib.pc
    sed -i "s|includedir=.*|includedir=/usr/include/${LIB_DIR}|g" ${DEV_DIR}/usr/lib/${LIB_DIR}/pkgconfig/zlib.pc
fi

cat > ${DEV_DIR}/DEBIAN/control << EOF
Package: ${PKG_NAME_DEV}
Architecture: ${ARCH}
Version: ${ZLIB_VERSION}-0ubuntu1
Multi-Arch: same
Section: libdevel
Priority: optional
Provides: libz-dev
Depends: ${PKG_NAME_RUNTIME} (= ${ZLIB_VERSION}-0ubuntu1), libc6-dev-${MABI}
Maintainer: ${MAINTAINER}
Description: compression library - development (${ARCH} ${MARCH}-${MABI} cross-compile)
 zlib is a library implementing the deflate compression method found
 in gzip and PKZIP.  This package includes the development support
 files for RISC-V 32-bit (${MARCH};${MABI}).
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build ${DEV_DIR} build/${PKG_NAME_DEV}_${ZLIB_VERSION}-0ubuntu1_${ARCH}.deb
log_info "Created: ${PKG_NAME_DEV}_${ZLIB_VERSION}-0ubuntu1_${ARCH}.deb"

log_info "zlib build complete!"
