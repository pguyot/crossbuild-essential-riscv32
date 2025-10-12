#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# libxcrypt build configuration
# Note: CC, AR, RANLIB, etc. are set by common.sh

LIBXCRYPT_VERSION=4.4.36
PACKAGE_NAME=libcrypt1-riscv32-cross
BUILD_DIR=$(pwd)/build/libxcrypt
INSTALL_DIR=$(pwd)/build/${PACKAGE_NAME}

log_info "Building libxcrypt for ${TARGET}"

# Get libxcrypt source from Ubuntu
if [ ! -d "libxcrypt-${LIBXCRYPT_VERSION}" ]; then
    log_info "Getting libxcrypt source from Ubuntu..."
    apt-get source libxcrypt
    # Find the extracted directory
    LIBXCRYPT_SRC_DIR=$(ls -d libxcrypt*/ 2>/dev/null | head -1 | sed 's:/$::')
    if [ -z "$LIBXCRYPT_SRC_DIR" ]; then
        log_error "Failed to extract libxcrypt source"
        exit 1
    fi
    # Rename if necessary
    if [ "$LIBXCRYPT_SRC_DIR" != "libxcrypt-${LIBXCRYPT_VERSION}" ] && [ ! -d "libxcrypt-${LIBXCRYPT_VERSION}" ]; then
        log_info "Renaming $LIBXCRYPT_SRC_DIR to libxcrypt-${LIBXCRYPT_VERSION}"
        mv "$LIBXCRYPT_SRC_DIR" libxcrypt-${LIBXCRYPT_VERSION}
    fi

    # Check if we need to run autogen.sh
    cd libxcrypt-${LIBXCRYPT_VERSION}
    if [ ! -f configure ] && [ -f autogen.sh ]; then
        log_info "Running autogen.sh to generate configure script..."
        ./autogen.sh
    fi
    cd ..
fi

# Verify configure script exists
if [ ! -f "libxcrypt-${LIBXCRYPT_VERSION}/configure" ]; then
    log_error "Configure script not found in libxcrypt-${LIBXCRYPT_VERSION}/"
    exit 1
fi

# Create build directory
rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

# Configure and build libxcrypt
log_info "Configuring libxcrypt..."
# Add -Wno-error to work around GCC 15 stricter warnings
../../libxcrypt-${LIBXCRYPT_VERSION}/configure \
    --prefix=${PREFIX} \
    --host=${TARGET} \
    --build=x86_64-linux-gnu \
    CC="${CC}" \
    CFLAGS="${CFLAGS} -Wno-error" \
    --disable-static \
    --enable-shared \
    --enable-hashes=all \
    --enable-obsolete-api=glibc

log_info "Building libxcrypt..."
make -j${JOBS}

# Install to package directory
log_info "Installing libxcrypt to package directory..."
rm -rf ${INSTALL_DIR}
mkdir -p ${INSTALL_DIR}
make install DESTDIR=${INSTALL_DIR}

# Create runtime package (libcrypt1-riscv32-cross)
log_info "Creating libcrypt1-riscv32-cross package..."
RUNTIME_DIR=$(pwd)/../build/libcrypt1-riscv32-cross-runtime
mkdir -p ${RUNTIME_DIR}/DEBIAN
mkdir -p ${RUNTIME_DIR}${PREFIX}/lib

# Copy runtime libraries
cp -a ${INSTALL_DIR}${PREFIX}/lib/*.so* ${RUNTIME_DIR}${PREFIX}/lib/ || true

cat > ${RUNTIME_DIR}/DEBIAN/control << EOF
Package: libcrypt1-riscv32-cross
Version: ${LIBXCRYPT_VERSION}-0ubuntu1
Section: libs
Priority: optional
Architecture: all
Maintainer: ${MAINTAINER}
Description: libxcrypt shared library (for RISC-V 32-bit cross-compiling)
 libxcrypt is a modern library for one-way hashing of passwords.
 It supports a wide variety of both modern and historical hashing methods:
 yescrypt, gost-yescrypt, scrypt, bcrypt, sha512crypt, sha256crypt,
 md5crypt, SunMD5, sha1crypt, NT, bsdicrypt, bigcrypt, and descrypt.
 It provides the traditional Unix crypt and crypt_r interfaces, as well
 as a set of extended interfaces pioneered by Openwall Linux, crypt_rn,
 crypt_ra, crypt_gensalt, crypt_gensalt_rn, and crypt_gensalt_ra.
 .
 This package contains the shared library for RISC-V 32-bit.
 .
 This package is for cross-compiling.
EOF

cd ..
dpkg-deb --build ${RUNTIME_DIR} build/libcrypt1-riscv32-cross_${LIBXCRYPT_VERSION}-0ubuntu1_all.deb
log_info "Created: libcrypt1-riscv32-cross_${LIBXCRYPT_VERSION}-0ubuntu1_all.deb"

# Create development package (libcrypt-dev-riscv32-cross)
log_info "Creating libcrypt-dev-riscv32-cross package..."
DEV_DIR=$(pwd)/build/libcrypt-dev-riscv32-cross
mkdir -p ${DEV_DIR}/DEBIAN
mkdir -p ${DEV_DIR}${PREFIX}

# Copy development files
cp -a ${INSTALL_DIR}${PREFIX}/include ${DEV_DIR}${PREFIX}/ || true
mkdir -p ${DEV_DIR}${PREFIX}/lib
cp -a ${INSTALL_DIR}${PREFIX}/lib/pkgconfig ${DEV_DIR}${PREFIX}/lib/ || true
cp -a ${INSTALL_DIR}${PREFIX}/share ${DEV_DIR}${PREFIX}/ || true

cat > ${DEV_DIR}/DEBIAN/control << EOF
Package: libcrypt-dev-riscv32-cross
Version: ${LIBXCRYPT_VERSION}-0ubuntu1
Section: libdevel
Priority: optional
Architecture: all
Depends: libcrypt1-riscv32-cross (= ${LIBXCRYPT_VERSION}-0ubuntu1), libc6-dev-riscv32-cross
Maintainer: ${MAINTAINER}
Description: libxcrypt development files (for RISC-V 32-bit cross-compiling)
 libxcrypt is a modern library for one-way hashing of passwords.
 .
 This package contains the development files for RISC-V 32-bit.
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build ${DEV_DIR} build/libcrypt-dev-riscv32-cross_${LIBXCRYPT_VERSION}-0ubuntu1_all.deb
log_info "Created: libcrypt-dev-riscv32-cross_${LIBXCRYPT_VERSION}-0ubuntu1_all.deb"

log_info "libxcrypt build complete!"
