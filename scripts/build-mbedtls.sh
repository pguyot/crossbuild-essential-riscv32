#!/bin/bash
set -euo pipefail

MABI=$1
MARCH=$2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# mbedtls build uses the riscv32 toolchain from common.sh
# CC, AR, RANLIB, CFLAGS, etc. are already set by common.sh

# Define ABI-specific library path
LIB_DIR="${TARGET}-${MABI}"

MBEDTLS_VERSION=2.28.8
PACKAGE_NAME=libmbedtls-${MABI}
BUILD_DIR=$(pwd)/build/mbedtls
INSTALL_DIR=$(pwd)/build/${PACKAGE_NAME}

log_info "Building mbedtls for ${ARCH} (${MARCH};${MABI})"

# Get mbedtls source from Ubuntu
if [ ! -d "mbedtls-${MBEDTLS_VERSION}" ]; then
    log_info "Getting mbedtls source from Ubuntu..."
    apt-get source mbedtls
    # Find the extracted directory
    MBEDTLS_SRC_DIR=$(ls -d mbedtls*/ 2>/dev/null | head -1 | sed 's:/$::')
    if [ -z "$MBEDTLS_SRC_DIR" ]; then
        log_error "Failed to extract mbedtls source"
        exit 1
    fi
    # Rename if necessary
    if [ "$MBEDTLS_SRC_DIR" != "mbedtls-${MBEDTLS_VERSION}" ] && [ ! -d "mbedtls-${MBEDTLS_VERSION}" ]; then
        log_info "Renaming $MBEDTLS_SRC_DIR to mbedtls-${MBEDTLS_VERSION}"
        mv "$MBEDTLS_SRC_DIR" mbedtls-${MBEDTLS_VERSION}
    fi
fi

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

# Create libmbedcrypto package with ABI-specific name
PKG_CRYPTO="libmbedcrypto7-${MABI}"
log_info "Creating ${PKG_CRYPTO} package..."
cd ../..
CRYPTO_DIR=$(pwd)/build/${PKG_CRYPTO}
mkdir -p ${CRYPTO_DIR}/DEBIAN
mkdir -p ${CRYPTO_DIR}/usr/lib/${LIB_DIR}

cp -a ${INSTALL_DIR}${PREFIX}/lib/libmbedcrypto.so* ${CRYPTO_DIR}/usr/lib/${LIB_DIR}/ || true

cat > ${CRYPTO_DIR}/DEBIAN/control << EOF
Package: ${PKG_CRYPTO}
Architecture: ${ARCH}
Version: ${MBEDTLS_VERSION}-0ubuntu1
Multi-Arch: same
Section: libs
Priority: optional
Maintainer: ${MAINTAINER}
Description: lightweight crypto library - runtime (${ARCH} ${MARCH}-${MABI} cross-compile)
 mbed TLS crypto library for cryptographic operations for RISC-V 32-bit (${MARCH};${MABI}).
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build ${CRYPTO_DIR} build/${PKG_CRYPTO}_${MBEDTLS_VERSION}-0ubuntu1_${ARCH}.deb
log_info "Created: ${PKG_CRYPTO}_${MBEDTLS_VERSION}-0ubuntu1_${ARCH}.deb"

# Create libmbedx509 package with ABI-specific name
PKG_X509="libmbedx509-1-${MABI}"
log_info "Creating ${PKG_X509} package..."
X509_DIR=$(pwd)/build/${PKG_X509}
mkdir -p ${X509_DIR}/DEBIAN
mkdir -p ${X509_DIR}/usr/lib/${LIB_DIR}

cp -a ${INSTALL_DIR}${PREFIX}/lib/libmbedx509.so* ${X509_DIR}/usr/lib/${LIB_DIR}/ || true

cat > ${X509_DIR}/DEBIAN/control << EOF
Package: ${PKG_X509}
Architecture: ${ARCH}
Version: ${MBEDTLS_VERSION}-0ubuntu1
Multi-Arch: same
Section: libs
Priority: optional
Depends: ${PKG_CRYPTO} (= ${MBEDTLS_VERSION}-0ubuntu1)
Maintainer: ${MAINTAINER}
Description: lightweight X.509 certificate library - runtime (${ARCH} ${MARCH}-${MABI} cross-compile)
 mbed TLS X.509 certificate handling library for RISC-V 32-bit (${MARCH};${MABI}).
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build ${X509_DIR} build/${PKG_X509}_${MBEDTLS_VERSION}-0ubuntu1_${ARCH}.deb
log_info "Created: ${PKG_X509}_${MBEDTLS_VERSION}-0ubuntu1_${ARCH}.deb"

# Create libmbedtls package with ABI-specific name
PKG_TLS="libmbedtls14-${MABI}"
log_info "Creating ${PKG_TLS} package..."
TLS_DIR=$(pwd)/build/${PKG_TLS}
mkdir -p ${TLS_DIR}/DEBIAN
mkdir -p ${TLS_DIR}/usr/lib/${LIB_DIR}

cp -a ${INSTALL_DIR}${PREFIX}/lib/libmbedtls.so* ${TLS_DIR}/usr/lib/${LIB_DIR}/ || true

cat > ${TLS_DIR}/DEBIAN/control << EOF
Package: ${PKG_TLS}
Architecture: ${ARCH}
Version: ${MBEDTLS_VERSION}-0ubuntu1
Multi-Arch: same
Section: libs
Priority: optional
Depends: ${PKG_CRYPTO} (= ${MBEDTLS_VERSION}-0ubuntu1), ${PKG_X509} (= ${MBEDTLS_VERSION}-0ubuntu1)
Maintainer: ${MAINTAINER}
Description: lightweight SSL/TLS library - runtime (${ARCH} ${MARCH}-${MABI} cross-compile)
 mbed TLS TLS/SSL protocol implementation library for RISC-V 32-bit (${MARCH};${MABI}).
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build ${TLS_DIR} build/${PKG_TLS}_${MBEDTLS_VERSION}-0ubuntu1_${ARCH}.deb
log_info "Created: ${PKG_TLS}_${MBEDTLS_VERSION}-0ubuntu1_${ARCH}.deb"

# Create development package with ABI-specific name
PKG_DEV="libmbedtls-dev-${MABI}"
log_info "Creating ${PKG_DEV} package..."
DEV_DIR=$(pwd)/build/${PKG_DEV}
mkdir -p ${DEV_DIR}/DEBIAN
mkdir -p ${DEV_DIR}/usr/lib/${LIB_DIR}
mkdir -p ${DEV_DIR}/usr/include/${LIB_DIR}

# Copy development files
cp -a ${INSTALL_DIR}${PREFIX}/include/* ${DEV_DIR}/usr/include/${LIB_DIR}/ || true
cp -a ${INSTALL_DIR}${PREFIX}/lib/*.a ${DEV_DIR}/usr/lib/${LIB_DIR}/ || true

cat > ${DEV_DIR}/DEBIAN/control << EOF
Package: ${PKG_DEV}
Architecture: ${ARCH}
Version: ${MBEDTLS_VERSION}-0ubuntu1
Multi-Arch: same
Section: libdevel
Priority: optional
Depends: ${PKG_TLS} (= ${MBEDTLS_VERSION}-0ubuntu1), ${PKG_CRYPTO} (= ${MBEDTLS_VERSION}-0ubuntu1), ${PKG_X509} (= ${MBEDTLS_VERSION}-0ubuntu1), libc6-dev-${MABI}
Maintainer: ${MAINTAINER}
Description: lightweight crypto and SSL/TLS library - development (${ARCH} ${MARCH}-${MABI} cross-compile)
 mbed TLS (formerly known as PolarSSL) makes it easy for developers to include
 cryptographic and SSL/TLS capabilities in their embedded products.
 .
 This package contains the development files for RISC-V 32-bit (${MARCH};${MABI}).
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build ${DEV_DIR} build/${PKG_DEV}_${MBEDTLS_VERSION}-0ubuntu1_${ARCH}.deb
log_info "Created: ${PKG_DEV}_${MBEDTLS_VERSION}-0ubuntu1_${ARCH}.deb"

log_info "mbedtls build complete!"
