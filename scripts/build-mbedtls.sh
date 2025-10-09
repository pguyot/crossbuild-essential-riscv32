#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

MBEDTLS_VERSION=2.28.8
PACKAGE_NAME=libmbedtls-riscv32-cross
BUILD_DIR=$(pwd)/build/mbedtls
INSTALL_DIR=$(pwd)/build/${PACKAGE_NAME}

log_info "Building mbedtls ${MBEDTLS_VERSION} for ${TARGET}"

# Download mbedtls source
if [ ! -f "mbedtls-${MBEDTLS_VERSION}.tar.gz" ]; then
    log_info "Downloading mbedtls ${MBEDTLS_VERSION}..."
    wget -q https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/v${MBEDTLS_VERSION}.tar.gz -O mbedtls-${MBEDTLS_VERSION}.tar.gz
fi

# Extract source
log_info "Extracting mbedtls source..."
rm -rf mbedtls-${MBEDTLS_VERSION}
tar xzf mbedtls-${MBEDTLS_VERSION}.tar.gz

# Create build directory
rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

# Configure mbedtls with CMake
log_info "Configuring mbedtls..."
cmake ../../mbedtls-${MBEDTLS_VERSION} \
    -DCMAKE_INSTALL_PREFIX=${PREFIX} \
    -DCMAKE_C_COMPILER=${CC} \
    -DCMAKE_CXX_COMPILER=${CXX} \
    -DCMAKE_C_FLAGS="${CFLAGS}" \
    -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=riscv32 \
    -DENABLE_TESTING=OFF \
    -DENABLE_PROGRAMS=OFF \
    -DUSE_SHARED_MBEDTLS_LIBRARY=ON \
    -DUSE_STATIC_MBEDTLS_LIBRARY=ON

log_info "Building mbedtls..."
make -j${JOBS}

# Install to package directory
log_info "Installing mbedtls to package directory..."
rm -rf ${INSTALL_DIR}
mkdir -p ${INSTALL_DIR}
make install DESTDIR=${INSTALL_DIR}

# Create runtime package (libmbedtls14-riscv32-cross)
log_info "Creating libmbedtls14-riscv32-cross package..."
RUNTIME_DIR=$(pwd)/../build/libmbedtls14-riscv32-cross
mkdir -p ${RUNTIME_DIR}/DEBIAN
mkdir -p ${RUNTIME_DIR}${PREFIX}/lib

# Copy runtime libraries
cp -a ${INSTALL_DIR}${PREFIX}/lib/*.so* ${RUNTIME_DIR}${PREFIX}/lib/ || true

cat > ${RUNTIME_DIR}/DEBIAN/control << EOF
Package: libmbedtls14-riscv32-cross
Version: ${MBEDTLS_VERSION}-0ubuntu1
Section: libs
Priority: optional
Architecture: all
Maintainer: ${MAINTAINER}
Description: lightweight crypto and SSL/TLS library - runtime (for RISC-V 32-bit)
 mbed TLS (formerly known as PolarSSL) makes it easy for developers to include
 cryptographic and SSL/TLS capabilities in their embedded products. It provides
 a modern, portable, easy to use and well documented C library.
 .
 This package contains the shared libraries for RISC-V 32-bit.
 .
 This package is for cross-compiling.
EOF

cd ..
dpkg-deb --build ${RUNTIME_DIR} build/libmbedtls14-riscv32-cross_${MBEDTLS_VERSION}-0ubuntu1_all.deb
log_info "Created: libmbedtls14-riscv32-cross_${MBEDTLS_VERSION}-0ubuntu1_all.deb"

# Create development package (libmbedtls-dev-riscv32-cross)
log_info "Creating libmbedtls-dev-riscv32-cross package..."
DEV_DIR=$(pwd)/build/libmbedtls-dev-riscv32-cross
mkdir -p ${DEV_DIR}/DEBIAN
mkdir -p ${DEV_DIR}${PREFIX}

# Copy development files
cp -a ${INSTALL_DIR}${PREFIX}/include ${DEV_DIR}${PREFIX}/ || true
mkdir -p ${DEV_DIR}${PREFIX}/lib
cp -a ${INSTALL_DIR}${PREFIX}/lib/*.a ${DEV_DIR}${PREFIX}/lib/ || true

cat > ${DEV_DIR}/DEBIAN/control << EOF
Package: libmbedtls-dev-riscv32-cross
Version: ${MBEDTLS_VERSION}-0ubuntu1
Section: libdevel
Priority: optional
Architecture: all
Depends: libmbedtls14-riscv32-cross (= ${MBEDTLS_VERSION}-0ubuntu1), libc6-dev-riscv32-cross
Maintainer: ${MAINTAINER}
Description: lightweight crypto and SSL/TLS library - development (for RISC-V 32-bit)
 mbed TLS (formerly known as PolarSSL) makes it easy for developers to include
 cryptographic and SSL/TLS capabilities in their embedded products.
 .
 This package contains the development files for RISC-V 32-bit.
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build ${DEV_DIR} build/libmbedtls-dev-riscv32-cross_${MBEDTLS_VERSION}-0ubuntu1_all.deb
log_info "Created: libmbedtls-dev-riscv32-cross_${MBEDTLS_VERSION}-0ubuntu1_all.deb"

log_info "mbedtls build complete!"
