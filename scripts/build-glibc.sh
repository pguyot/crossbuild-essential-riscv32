#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

GLIBC_VERSION=2.39
PACKAGE_NAME=libc6-riscv32-cross
BUILD_DIR=$(pwd)/build/glibc
INSTALL_DIR=$(pwd)/build/${PACKAGE_NAME}

log_info "Building glibc ${GLIBC_VERSION} for ${TARGET}"

# Download glibc source
if [ ! -f "glibc-${GLIBC_VERSION}.tar.gz" ]; then
    log_info "Downloading glibc ${GLIBC_VERSION}..."
    wget -q https://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.gz
fi

# Extract source
log_info "Extracting glibc source..."
rm -rf glibc-${GLIBC_VERSION}
tar xzf glibc-${GLIBC_VERSION}.tar.gz

# Create build directory
rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

# Configure glibc for riscv32
log_info "Configuring glibc..."
../../glibc-${GLIBC_VERSION}/configure \
    --prefix=${PREFIX} \
    --host=${TARGET} \
    --build=x86_64-linux-gnu \
    --target=${TARGET} \
    --with-headers=/usr/riscv64-linux-gnu/include \
    --enable-kernel=5.4.0 \
    --disable-werror \
    --disable-multilib \
    --disable-profile \
    --without-gd \
    --without-selinux \
    --disable-nscd \
    libc_cv_forced_unwind=yes \
    libc_cv_c_cleanup=yes \
    CC="${CC} -march=${MARCH} -mabi=${MABI}" \
    CXX="${CXX} -march=${MARCH} -mabi=${MABI}"

# Build glibc
log_info "Building glibc (this may take a while)..."
make -j${JOBS}

# Install to package directory
log_info "Installing glibc to package directory..."
mkdir -p ${INSTALL_DIR}${PREFIX}
make install DESTDIR=${INSTALL_DIR}

# Create runtime package (libc6-riscv32-cross)
log_info "Creating libc6-riscv32-cross package..."
RUNTIME_DIR=$(pwd)/build/libc6-riscv32-cross-runtime
mkdir -p ${RUNTIME_DIR}/DEBIAN
mkdir -p ${RUNTIME_DIR}${PREFIX}/lib

# Copy runtime libraries
cp -a ${INSTALL_DIR}${PREFIX}/lib/*.so* ${RUNTIME_DIR}${PREFIX}/lib/ || true
cp -a ${INSTALL_DIR}${PREFIX}/lib/ld-*.so* ${RUNTIME_DIR}${PREFIX}/lib/ || true

cat > ${RUNTIME_DIR}/DEBIAN/control << EOF
Package: libc6-riscv32-cross
Version: ${GLIBC_VERSION}-0ubuntu1
Section: libs
Priority: optional
Architecture: all
Maintainer: ${MAINTAINER}
Description: GNU C Library: Shared libraries (for RISC-V 32-bit cross-compiling)
 Contains the standard libraries that are used by nearly all programs on
 the system. This package includes shared versions of the standard C library
 and the standard math library, as well as many others for RISC-V 32-bit.
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build ${RUNTIME_DIR} build/libc6-riscv32-cross_${GLIBC_VERSION}-0ubuntu1_all.deb
log_info "Created: libc6-riscv32-cross_${GLIBC_VERSION}-0ubuntu1_all.deb"

# Create development package (libc6-dev-riscv32-cross)
log_info "Creating libc6-dev-riscv32-cross package..."
DEV_DIR=$(pwd)/build/libc6-dev-riscv32-cross
mkdir -p ${DEV_DIR}/DEBIAN
mkdir -p ${DEV_DIR}${PREFIX}

# Copy development files
cp -a ${INSTALL_DIR}${PREFIX}/include ${DEV_DIR}${PREFIX}/ || true
mkdir -p ${DEV_DIR}${PREFIX}/lib
cp -a ${INSTALL_DIR}${PREFIX}/lib/*.a ${DEV_DIR}${PREFIX}/lib/ || true
cp -a ${INSTALL_DIR}${PREFIX}/lib/*.o ${DEV_DIR}${PREFIX}/lib/ || true

cat > ${DEV_DIR}/DEBIAN/control << EOF
Package: libc6-dev-riscv32-cross
Version: ${GLIBC_VERSION}-0ubuntu1
Section: libdevel
Priority: optional
Architecture: all
Depends: libc6-riscv32-cross (= ${GLIBC_VERSION}-0ubuntu1)
Maintainer: ${MAINTAINER}
Description: GNU C Library: Development Libraries and Headers (for RISC-V 32-bit)
 Contains the symlinks, headers, and object files needed to compile
 and link programs which use the standard C library for RISC-V 32-bit.
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build ${DEV_DIR} build/libc6-dev-riscv32-cross_${GLIBC_VERSION}-0ubuntu1_all.deb
log_info "Created: libc6-dev-riscv32-cross_${GLIBC_VERSION}-0ubuntu1_all.deb"

log_info "glibc build complete!"
