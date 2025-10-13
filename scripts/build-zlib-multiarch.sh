#!/bin/bash
# Build zlib1g and zlib1g-dev for riscv32 with Multi-Arch support

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# zlib version (match Ubuntu 24.04)
ZLIB_VERSION="1.3.1"
ZLIB_PKG_VERSION="1:${ZLIB_VERSION}.dfsg-3.1ubuntu2.1"
# Safe version for filenames (dpkg handles epoch internally)
ZLIB_FILE_VERSION="${ZLIB_VERSION}.dfsg-3.1ubuntu2.1"

log_info "Building zlib ${ZLIB_VERSION} for ${ARCH}"

# Download and extract zlib source
cd "$(dirname "${SCRIPT_DIR}")"
if [ ! -d "zlib-${ZLIB_VERSION}" ]; then
    log_info "Downloading zlib source..."
    wget -q https://www.zlib.net/zlib-${ZLIB_VERSION}.tar.gz
    tar xzf zlib-${ZLIB_VERSION}.tar.gz
    rm zlib-${ZLIB_VERSION}.tar.gz
fi

# Build zlib
cd zlib-${ZLIB_VERSION}
log_info "Configuring zlib..."

# Clean previous build
make distclean 2>/dev/null || true

# Configure for cross-compilation
# Use minimal CFLAGS for configure to avoid "too harsh" error
# The full CFLAGS will be used during make
CC=${CC} AR=${AR} RANLIB=${RANLIB} \
CFLAGS="-march=rv32gc -mabi=ilp32d -O2" \
./configure --prefix=/usr

log_info "Building zlib..."
make -j${JOBS}

# Create installation directory
INSTALL_DIR=$(pwd)/../build/zlib-install
rm -rf ${INSTALL_DIR}
mkdir -p ${INSTALL_DIR}

log_info "Installing zlib to temporary directory..."
make install DESTDIR=${INSTALL_DIR}

cd ..

# Create zlib1g package (runtime)
log_info "Creating zlib1g:${ARCH} package..."
RUNTIME_DIR=build/zlib1g_${ARCH}
rm -rf ${RUNTIME_DIR}
mkdir -p ${RUNTIME_DIR}/DEBIAN
mkdir -p ${RUNTIME_DIR}/usr/lib/${TARGET}

# Copy runtime library
cp -a ${INSTALL_DIR}/usr/lib/libz.so.* ${RUNTIME_DIR}/usr/lib/${TARGET}/

# Create control file
cat > ${RUNTIME_DIR}/DEBIAN/control << EOF
Package: zlib1g
Architecture: ${ARCH}
Version: ${ZLIB_PKG_VERSION}
Multi-Arch: same
Section: libs
Priority: optional
Maintainer: ${MAINTAINER}
Description: compression library - runtime (${ARCH} cross-compile)
 zlib is a library implementing the deflate compression method found
 in gzip and PKZIP.  This package includes the shared library for ${ARCH}.
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build --root-owner-group ${RUNTIME_DIR} build/zlib1g_${ZLIB_FILE_VERSION}_${ARCH}.deb
log_info "Created: zlib1g_${ZLIB_FILE_VERSION}_${ARCH}.deb"

# Create zlib1g-dev package (development)
log_info "Creating zlib1g-dev:${ARCH} package..."
DEV_DIR=build/zlib1g-dev_${ARCH}
rm -rf ${DEV_DIR}
mkdir -p ${DEV_DIR}/DEBIAN
mkdir -p ${DEV_DIR}/usr/lib/${TARGET}
mkdir -p ${DEV_DIR}/usr/include/${TARGET}

# Copy development files
cp -a ${INSTALL_DIR}/usr/lib/libz.so ${DEV_DIR}/usr/lib/${TARGET}/
cp -a ${INSTALL_DIR}/usr/lib/libz.a ${DEV_DIR}/usr/lib/${TARGET}/
cp -a ${INSTALL_DIR}/usr/lib/pkgconfig ${DEV_DIR}/usr/lib/${TARGET}/
cp -a ${INSTALL_DIR}/usr/include/*.h ${DEV_DIR}/usr/include/${TARGET}/

# Fix pkg-config file
sed -i "s|prefix=/usr|prefix=/usr/${TARGET}|g" ${DEV_DIR}/usr/lib/${TARGET}/pkgconfig/zlib.pc

# Create control file
cat > ${DEV_DIR}/DEBIAN/control << EOF
Package: zlib1g-dev
Architecture: ${ARCH}
Version: ${ZLIB_PKG_VERSION}
Multi-Arch: same
Section: libdevel
Priority: optional
Provides: libz-dev
Depends: zlib1g (= ${ZLIB_PKG_VERSION})
Maintainer: ${MAINTAINER}
Description: compression library - development (${ARCH} cross-compile)
 zlib is a library implementing the deflate compression method found
 in gzip and PKZIP.  This package includes development support files for ${ARCH}.
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build --root-owner-group ${DEV_DIR} build/zlib1g-dev_${ZLIB_FILE_VERSION}_${ARCH}.deb
log_info "Created: zlib1g-dev_${ZLIB_FILE_VERSION}_${ARCH}.deb"

log_info "zlib build complete!"
