#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# mbedtls build uses the riscv32 toolchain from common.sh
# CC, AR, RANLIB, CFLAGS, etc. are already set by common.sh

MBEDTLS_VERSION=2.28.8
PACKAGE_NAME=libmbedtls-riscv32-cross
BUILD_DIR=$(pwd)/build/mbedtls
INSTALL_DIR=$(pwd)/build/${PACKAGE_NAME}

log_info "Building mbedtls for ${TARGET}"

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

# Create libmbedcrypto package
log_info "Creating libmbedcrypto7-riscv32-cross package..."
cd ../..
CRYPTO_DIR=$(pwd)/build/libmbedcrypto7-riscv32-cross
mkdir -p ${CRYPTO_DIR}/DEBIAN
mkdir -p ${CRYPTO_DIR}${PREFIX}/lib

cp -a ${INSTALL_DIR}${PREFIX}/lib/libmbedcrypto.so* ${CRYPTO_DIR}${PREFIX}/lib/ || true

cat > ${CRYPTO_DIR}/DEBIAN/control << EOF
Package: libmbedcrypto7-riscv32-cross
Version: ${MBEDTLS_VERSION}-0ubuntu1
Section: libs
Priority: optional
Architecture: all
Maintainer: ${MAINTAINER}
Description: lightweight crypto library - runtime (for RISC-V 32-bit)
 mbed TLS crypto library for cryptographic operations.
 .
 This package contains the shared crypto library for RISC-V 32-bit.
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build ${CRYPTO_DIR} build/libmbedcrypto7-riscv32-cross_${MBEDTLS_VERSION}-0ubuntu1_all.deb
log_info "Created: libmbedcrypto7-riscv32-cross_${MBEDTLS_VERSION}-0ubuntu1_all.deb"

# Create libmbedx509 package
log_info "Creating libmbedx509-1-riscv32-cross package..."
X509_DIR=$(pwd)/build/libmbedx509-1-riscv32-cross
mkdir -p ${X509_DIR}/DEBIAN
mkdir -p ${X509_DIR}${PREFIX}/lib

cp -a ${INSTALL_DIR}${PREFIX}/lib/libmbedx509.so* ${X509_DIR}${PREFIX}/lib/ || true

cat > ${X509_DIR}/DEBIAN/control << EOF
Package: libmbedx509-1-riscv32-cross
Version: ${MBEDTLS_VERSION}-0ubuntu1
Section: libs
Priority: optional
Architecture: all
Depends: libmbedcrypto7-riscv32-cross (= ${MBEDTLS_VERSION}-0ubuntu1)
Maintainer: ${MAINTAINER}
Description: lightweight X.509 certificate library - runtime (for RISC-V 32-bit)
 mbed TLS X.509 certificate handling library.
 .
 This package contains the shared X.509 library for RISC-V 32-bit.
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build ${X509_DIR} build/libmbedx509-1-riscv32-cross_${MBEDTLS_VERSION}-0ubuntu1_all.deb
log_info "Created: libmbedx509-1-riscv32-cross_${MBEDTLS_VERSION}-0ubuntu1_all.deb"

# Create libmbedtls package
log_info "Creating libmbedtls14-riscv32-cross package..."
TLS_DIR=$(pwd)/build/libmbedtls14-riscv32-cross
mkdir -p ${TLS_DIR}/DEBIAN
mkdir -p ${TLS_DIR}${PREFIX}/lib

cp -a ${INSTALL_DIR}${PREFIX}/lib/libmbedtls.so* ${TLS_DIR}${PREFIX}/lib/ || true

cat > ${TLS_DIR}/DEBIAN/control << EOF
Package: libmbedtls14-riscv32-cross
Version: ${MBEDTLS_VERSION}-0ubuntu1
Section: libs
Priority: optional
Architecture: all
Depends: libmbedcrypto7-riscv32-cross (= ${MBEDTLS_VERSION}-0ubuntu1), libmbedx509-1-riscv32-cross (= ${MBEDTLS_VERSION}-0ubuntu1)
Maintainer: ${MAINTAINER}
Description: lightweight SSL/TLS library - runtime (for RISC-V 32-bit)
 mbed TLS TLS/SSL protocol implementation library.
 .
 This package contains the shared TLS library for RISC-V 32-bit.
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build ${TLS_DIR} build/libmbedtls14-riscv32-cross_${MBEDTLS_VERSION}-0ubuntu1_all.deb
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
Depends: libmbedtls14-riscv32-cross (= ${MBEDTLS_VERSION}-0ubuntu1), libmbedcrypto7-riscv32-cross (= ${MBEDTLS_VERSION}-0ubuntu1), libmbedx509-1-riscv32-cross (= ${MBEDTLS_VERSION}-0ubuntu1), libc6-dev-riscv32-cross
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
