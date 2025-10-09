#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

ZLIB_VERSION=1.3.1
PACKAGE_NAME=zlib1g-riscv32-cross
BUILD_DIR=$(pwd)/build/zlib
INSTALL_DIR=$(pwd)/build/${PACKAGE_NAME}

log_info "Building zlib ${ZLIB_VERSION} for ${TARGET}"

# Download zlib source
if [ ! -f "zlib-${ZLIB_VERSION}.tar.gz" ]; then
    log_info "Downloading zlib ${ZLIB_VERSION}..."
    wget -q https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz
fi

# Extract source
log_info "Extracting zlib source..."
rm -rf zlib-${ZLIB_VERSION}
tar xzf zlib-${ZLIB_VERSION}.tar.gz

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

# Create runtime package (zlib1g-riscv32-cross)
log_info "Creating zlib1g-riscv32-cross package..."
RUNTIME_DIR=$(pwd)/../build/zlib1g-riscv32-cross-runtime
mkdir -p ${RUNTIME_DIR}/DEBIAN
mkdir -p ${RUNTIME_DIR}${PREFIX}/lib

# Copy runtime libraries
cp -a ${INSTALL_DIR}${PREFIX}/lib/*.so* ${RUNTIME_DIR}${PREFIX}/lib/ || true

cat > ${RUNTIME_DIR}/DEBIAN/control << EOF
Package: zlib1g-riscv32-cross
Version: ${ZLIB_VERSION}-0ubuntu1
Section: libs
Priority: optional
Architecture: all
Maintainer: ${MAINTAINER}
Description: compression library - runtime (for RISC-V 32-bit cross-compiling)
 zlib is a library implementing the deflate compression method found
 in gzip and PKZIP.  This package includes the shared library for
 RISC-V 32-bit.
 .
 This package is for cross-compiling.
EOF

cd ..
dpkg-deb --build ${RUNTIME_DIR} build/zlib1g-riscv32-cross_${ZLIB_VERSION}-0ubuntu1_all.deb
log_info "Created: zlib1g-riscv32-cross_${ZLIB_VERSION}-0ubuntu1_all.deb"

# Create development package (zlib1g-dev-riscv32-cross)
log_info "Creating zlib1g-dev-riscv32-cross package..."
DEV_DIR=$(pwd)/build/zlib1g-dev-riscv32-cross
mkdir -p ${DEV_DIR}/DEBIAN
mkdir -p ${DEV_DIR}${PREFIX}

# Copy development files
cp -a ${INSTALL_DIR}${PREFIX}/include ${DEV_DIR}${PREFIX}/ || true
mkdir -p ${DEV_DIR}${PREFIX}/lib
cp -a ${INSTALL_DIR}${PREFIX}/lib/*.a ${DEV_DIR}${PREFIX}/lib/ || true
cp -a ${INSTALL_DIR}${PREFIX}/lib/pkgconfig ${DEV_DIR}${PREFIX}/lib/ || true

cat > ${DEV_DIR}/DEBIAN/control << EOF
Package: zlib1g-dev-riscv32-cross
Version: ${ZLIB_VERSION}-0ubuntu1
Section: libdevel
Priority: optional
Architecture: all
Depends: zlib1g-riscv32-cross (= ${ZLIB_VERSION}-0ubuntu1), libc6-dev-riscv32-cross
Maintainer: ${MAINTAINER}
Description: compression library - development (for RISC-V 32-bit cross-compiling)
 zlib is a library implementing the deflate compression method found
 in gzip and PKZIP.  This package includes the development support
 files for RISC-V 32-bit.
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build ${DEV_DIR} build/zlib1g-dev-riscv32-cross_${ZLIB_VERSION}-0ubuntu1_all.deb
log_info "Created: zlib1g-dev-riscv32-cross_${ZLIB_VERSION}-0ubuntu1_all.deb"

log_info "zlib build complete!"
