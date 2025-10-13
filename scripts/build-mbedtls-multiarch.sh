#!/bin/bash
# Build mbedtls libraries for riscv32 with Multi-Arch support

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# mbedtls version (match Ubuntu 24.04)
MBEDTLS_VERSION="2.28.8"
MBEDTLS_PKG_VERSION="${MBEDTLS_VERSION}-1"
MBEDTLS_FILE_VERSION="${MBEDTLS_PKG_VERSION}"

log_info "Building mbedtls ${MBEDTLS_VERSION} for ${ARCH} with multilib support"

# Download and extract mbedtls source
cd "$(dirname "${SCRIPT_DIR}")"
if [ ! -d "mbedtls-${MBEDTLS_VERSION}" ]; then
    log_info "Downloading mbedtls source..."
    wget -q https://github.com/Mbed-TLS/mbedtls/archive/v${MBEDTLS_VERSION}.tar.gz -O mbedtls-${MBEDTLS_VERSION}.tar.gz
    tar xzf mbedtls-${MBEDTLS_VERSION}.tar.gz
    rm mbedtls-${MBEDTLS_VERSION}.tar.gz
fi

# Create main installation directory
INSTALL_DIR=$(pwd)/build/mbedtls-install
rm -rf ${INSTALL_DIR}
mkdir -p ${INSTALL_DIR}

# Define multilib variants: march, mabi, suffix, libdir
MULTILIB_VARIANTS=(
    "rv32imac:ilp32::ilp32"
    "rv32imafc:ilp32f::ilp32f"
    "rv32gc:ilp32d::"
)

# Build each multilib variant
for variant in "${MULTILIB_VARIANTS[@]}"; do
    IFS=':' read -r march mabi suffix libdir <<< "$variant"

    log_info "Building mbedtls for ${march}/${mabi}..."

    cd mbedtls-${MBEDTLS_VERSION}

    # Clean previous build
    rm -rf build-cross
    mkdir -p build-cross
    cd build-cross

    # Create toolchain file for CMake
    cat > toolchain.cmake << EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR riscv32)

set(CMAKE_C_COMPILER ${CC})
set(CMAKE_CXX_COMPILER ${CXX})
set(CMAKE_AR ${AR})
set(CMAKE_RANLIB ${RANLIB})

set(CMAKE_C_FLAGS "-march=${march} -mabi=${mabi} -O2 -fno-semantic-interposition -Wno-error")
set(CMAKE_CXX_FLAGS "-march=${march} -mabi=${mabi} -O2 -fno-semantic-interposition -Wno-error")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF

    cmake .. \
        -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DUSE_SHARED_MBEDTLS_LIBRARY=ON \
        -DUSE_STATIC_MBEDTLS_LIBRARY=ON \
        -DENABLE_TESTING=OFF \
        -DENABLE_PROGRAMS=OFF

    log_info "Building mbedtls for ${march}/${mabi}..."
    make -j${JOBS}

    # Install to variant-specific directory
    VARIANT_INSTALL=$(pwd)/../../build/mbedtls-install-${march}-${mabi}
    rm -rf ${VARIANT_INSTALL}
    mkdir -p ${VARIANT_INSTALL}
    make install DESTDIR=${VARIANT_INSTALL}

    # Copy to main install dir with proper multilib path
    if [ -z "$suffix" ]; then
        # Default variant (rv32gc/ilp32d) goes to base lib directory
        mkdir -p ${INSTALL_DIR}/usr/lib
        cp -a ${VARIANT_INSTALL}/usr/lib/*.so* ${INSTALL_DIR}/usr/lib/
        cp -a ${VARIANT_INSTALL}/usr/lib/*.a ${INSTALL_DIR}/usr/lib/
    else
        # Other variants go to multilib subdirectories
        mkdir -p ${INSTALL_DIR}/usr/lib/${libdir}
        cp -a ${VARIANT_INSTALL}/usr/lib/*.so* ${INSTALL_DIR}/usr/lib/${libdir}/
        cp -a ${VARIANT_INSTALL}/usr/lib/*.a ${INSTALL_DIR}/usr/lib/${libdir}/
    fi

    # Copy headers from first variant only
    if [ "$march" = "rv32imac" ]; then
        mkdir -p ${INSTALL_DIR}/usr/include
        cp -a ${VARIANT_INSTALL}/usr/include/mbedtls ${INSTALL_DIR}/usr/include/
        cp -a ${VARIANT_INSTALL}/usr/include/psa ${INSTALL_DIR}/usr/include/
    fi

    cd ../..
    log_info "Completed build for ${march}/${mabi}"
done

cd "$(dirname "${SCRIPT_DIR}")"

# Create libmbedcrypto7t64 package
log_info "Creating libmbedcrypto7t64:${ARCH} package..."
CRYPTO_DIR=build/libmbedcrypto7t64_${ARCH}
rm -rf ${CRYPTO_DIR}
mkdir -p ${CRYPTO_DIR}/DEBIAN
mkdir -p ${CRYPTO_DIR}/usr/lib/${TARGET}

# Copy all runtime libraries (all multilib variants)
cp -a ${INSTALL_DIR}/usr/lib/libmbedcrypto.so.* ${CRYPTO_DIR}/usr/lib/${TARGET}/ 2>/dev/null || true
# Copy multilib variant libraries
if [ -d ${INSTALL_DIR}/usr/lib/ilp32 ]; then
    mkdir -p ${CRYPTO_DIR}/usr/lib/${TARGET}/ilp32
    cp -a ${INSTALL_DIR}/usr/lib/ilp32/libmbedcrypto.so.* ${CRYPTO_DIR}/usr/lib/${TARGET}/ilp32/ 2>/dev/null || true
fi
if [ -d ${INSTALL_DIR}/usr/lib/ilp32f ]; then
    mkdir -p ${CRYPTO_DIR}/usr/lib/${TARGET}/ilp32f
    cp -a ${INSTALL_DIR}/usr/lib/ilp32f/libmbedcrypto.so.* ${CRYPTO_DIR}/usr/lib/${TARGET}/ilp32f/ 2>/dev/null || true
fi

cat > ${CRYPTO_DIR}/DEBIAN/control << EOF
Package: libmbedcrypto7t64
Architecture: ${ARCH}
Version: ${MBEDTLS_PKG_VERSION}
Multi-Arch: same
Section: libs
Priority: optional
Maintainer: ${MAINTAINER}
Description: lightweight crypto library - runtime (${ARCH} cross-compile)
 mbed TLS crypto library for cryptographic operations for ${ARCH}.
 .
 This package includes multilib variants:
  - rv32imac/ilp32 (soft-float)
  - rv32imafc/ilp32f (single-precision FP)
  - rv32gc/ilp32d (double-precision FP, default)
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build --root-owner-group ${CRYPTO_DIR} build/libmbedcrypto7t64_${MBEDTLS_FILE_VERSION}_${ARCH}.deb
log_info "Created: libmbedcrypto7t64_${MBEDTLS_FILE_VERSION}_${ARCH}.deb"

# Create libmbedx509-1t64 package
log_info "Creating libmbedx509-1t64:${ARCH} package..."
X509_DIR=build/libmbedx509-1t64_${ARCH}
rm -rf ${X509_DIR}
mkdir -p ${X509_DIR}/DEBIAN
mkdir -p ${X509_DIR}/usr/lib/${TARGET}

# Copy all runtime libraries (all multilib variants)
cp -a ${INSTALL_DIR}/usr/lib/libmbedx509.so.* ${X509_DIR}/usr/lib/${TARGET}/ 2>/dev/null || true
# Copy multilib variant libraries
if [ -d ${INSTALL_DIR}/usr/lib/ilp32 ]; then
    mkdir -p ${X509_DIR}/usr/lib/${TARGET}/ilp32
    cp -a ${INSTALL_DIR}/usr/lib/ilp32/libmbedx509.so.* ${X509_DIR}/usr/lib/${TARGET}/ilp32/ 2>/dev/null || true
fi
if [ -d ${INSTALL_DIR}/usr/lib/ilp32f ]; then
    mkdir -p ${X509_DIR}/usr/lib/${TARGET}/ilp32f
    cp -a ${INSTALL_DIR}/usr/lib/ilp32f/libmbedx509.so.* ${X509_DIR}/usr/lib/${TARGET}/ilp32f/ 2>/dev/null || true
fi

cat > ${X509_DIR}/DEBIAN/control << EOF
Package: libmbedx509-1t64
Architecture: ${ARCH}
Version: ${MBEDTLS_PKG_VERSION}
Multi-Arch: same
Section: libs
Priority: optional
Depends: libmbedcrypto7t64 (= ${MBEDTLS_PKG_VERSION})
Maintainer: ${MAINTAINER}
Description: lightweight X.509 library - runtime (${ARCH} cross-compile)
 mbed TLS X.509 certificate handling library for ${ARCH}.
 .
 This package includes multilib variants:
  - rv32imac/ilp32 (soft-float)
  - rv32imafc/ilp32f (single-precision FP)
  - rv32gc/ilp32d (double-precision FP, default)
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build --root-owner-group ${X509_DIR} build/libmbedx509-1t64_${MBEDTLS_FILE_VERSION}_${ARCH}.deb
log_info "Created: libmbedx509-1t64_${MBEDTLS_FILE_VERSION}_${ARCH}.deb"

# Create libmbedtls14t64 package
log_info "Creating libmbedtls14t64:${ARCH} package..."
TLS_DIR=build/libmbedtls14t64_${ARCH}
rm -rf ${TLS_DIR}
mkdir -p ${TLS_DIR}/DEBIAN
mkdir -p ${TLS_DIR}/usr/lib/${TARGET}

# Copy all runtime libraries (all multilib variants)
cp -a ${INSTALL_DIR}/usr/lib/libmbedtls.so.* ${TLS_DIR}/usr/lib/${TARGET}/ 2>/dev/null || true
# Copy multilib variant libraries
if [ -d ${INSTALL_DIR}/usr/lib/ilp32 ]; then
    mkdir -p ${TLS_DIR}/usr/lib/${TARGET}/ilp32
    cp -a ${INSTALL_DIR}/usr/lib/ilp32/libmbedtls.so.* ${TLS_DIR}/usr/lib/${TARGET}/ilp32/ 2>/dev/null || true
fi
if [ -d ${INSTALL_DIR}/usr/lib/ilp32f ]; then
    mkdir -p ${TLS_DIR}/usr/lib/${TARGET}/ilp32f
    cp -a ${INSTALL_DIR}/usr/lib/ilp32f/libmbedtls.so.* ${TLS_DIR}/usr/lib/${TARGET}/ilp32f/ 2>/dev/null || true
fi

cat > ${TLS_DIR}/DEBIAN/control << EOF
Package: libmbedtls14t64
Architecture: ${ARCH}
Version: ${MBEDTLS_PKG_VERSION}
Multi-Arch: same
Section: libs
Priority: optional
Depends: libmbedcrypto7t64 (= ${MBEDTLS_PKG_VERSION}), libmbedx509-1t64 (= ${MBEDTLS_PKG_VERSION})
Maintainer: ${MAINTAINER}
Description: lightweight SSL/TLS library - runtime (${ARCH} cross-compile)
 mbed TLS SSL/TLS library for ${ARCH}.
 .
 This package includes multilib variants:
  - rv32imac/ilp32 (soft-float)
  - rv32imafc/ilp32f (single-precision FP)
  - rv32gc/ilp32d (double-precision FP, default)
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build --root-owner-group ${TLS_DIR} build/libmbedtls14t64_${MBEDTLS_FILE_VERSION}_${ARCH}.deb
log_info "Created: libmbedtls14t64_${MBEDTLS_FILE_VERSION}_${ARCH}.deb"

# Create libmbedtls-dev package
log_info "Creating libmbedtls-dev:${ARCH} package..."
DEV_DIR=build/libmbedtls-dev_${ARCH}
rm -rf ${DEV_DIR}
mkdir -p ${DEV_DIR}/DEBIAN
mkdir -p ${DEV_DIR}/usr/lib/${TARGET}
mkdir -p ${DEV_DIR}/usr/include/${TARGET}

# Copy development files (all multilib variants)
cp -a ${INSTALL_DIR}/usr/lib/libmbedcrypto.so ${DEV_DIR}/usr/lib/${TARGET}/ 2>/dev/null || true
cp -a ${INSTALL_DIR}/usr/lib/libmbedx509.so ${DEV_DIR}/usr/lib/${TARGET}/ 2>/dev/null || true
cp -a ${INSTALL_DIR}/usr/lib/libmbedtls.so ${DEV_DIR}/usr/lib/${TARGET}/ 2>/dev/null || true
cp -a ${INSTALL_DIR}/usr/lib/*.a ${DEV_DIR}/usr/lib/${TARGET}/ 2>/dev/null || true
# Copy multilib variant static libraries and symlinks
if [ -d ${INSTALL_DIR}/usr/lib/ilp32 ]; then
    mkdir -p ${DEV_DIR}/usr/lib/${TARGET}/ilp32
    cp -a ${INSTALL_DIR}/usr/lib/ilp32/libmbedcrypto.so ${DEV_DIR}/usr/lib/${TARGET}/ilp32/ 2>/dev/null || true
    cp -a ${INSTALL_DIR}/usr/lib/ilp32/libmbedx509.so ${DEV_DIR}/usr/lib/${TARGET}/ilp32/ 2>/dev/null || true
    cp -a ${INSTALL_DIR}/usr/lib/ilp32/libmbedtls.so ${DEV_DIR}/usr/lib/${TARGET}/ilp32/ 2>/dev/null || true
    cp -a ${INSTALL_DIR}/usr/lib/ilp32/*.a ${DEV_DIR}/usr/lib/${TARGET}/ilp32/ 2>/dev/null || true
fi
if [ -d ${INSTALL_DIR}/usr/lib/ilp32f ]; then
    mkdir -p ${DEV_DIR}/usr/lib/${TARGET}/ilp32f
    cp -a ${INSTALL_DIR}/usr/lib/ilp32f/libmbedcrypto.so ${DEV_DIR}/usr/lib/${TARGET}/ilp32f/ 2>/dev/null || true
    cp -a ${INSTALL_DIR}/usr/lib/ilp32f/libmbedx509.so ${DEV_DIR}/usr/lib/${TARGET}/ilp32f/ 2>/dev/null || true
    cp -a ${INSTALL_DIR}/usr/lib/ilp32f/libmbedtls.so ${DEV_DIR}/usr/lib/${TARGET}/ilp32f/ 2>/dev/null || true
    cp -a ${INSTALL_DIR}/usr/lib/ilp32f/*.a ${DEV_DIR}/usr/lib/${TARGET}/ilp32f/ 2>/dev/null || true
fi

# Copy headers
cp -a ${INSTALL_DIR}/usr/include/mbedtls ${DEV_DIR}/usr/include/${TARGET}/
cp -a ${INSTALL_DIR}/usr/include/psa ${DEV_DIR}/usr/include/${TARGET}/

cat > ${DEV_DIR}/DEBIAN/control << EOF
Package: libmbedtls-dev
Architecture: ${ARCH}
Version: ${MBEDTLS_PKG_VERSION}
Multi-Arch: same
Section: libdevel
Priority: optional
Depends: libmbedcrypto7t64 (= ${MBEDTLS_PKG_VERSION}), libmbedtls14t64 (= ${MBEDTLS_PKG_VERSION}), libmbedx509-1t64 (= ${MBEDTLS_PKG_VERSION})
Maintainer: ${MAINTAINER}
Description: lightweight SSL/TLS library - development files (${ARCH} cross-compile)
 mbed TLS development files for ${ARCH}.
 .
 This package includes multilib variants:
  - rv32imac/ilp32 (soft-float)
  - rv32imafc/ilp32f (single-precision FP)
  - rv32gc/ilp32d (double-precision FP, default)
 .
 This package is for cross-compiling.
Homepage: https://www.trustedfirmware.org/projects/mbed-tls/
EOF

dpkg-deb --build --root-owner-group ${DEV_DIR} build/libmbedtls-dev_${MBEDTLS_FILE_VERSION}_${ARCH}.deb
log_info "Created: libmbedtls-dev_${MBEDTLS_FILE_VERSION}_${ARCH}.deb"

log_info "mbedtls build complete!"
