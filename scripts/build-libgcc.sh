#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

GCC_VERSION=13.3.0
BUILD_DIR=$(pwd)/build/gcc
INSTALL_DIR=$(pwd)/build/libgcc-riscv32

log_info "Building libgcc for ${TARGET}"

# Get GCC source
if [ ! -d "gcc-${GCC_VERSION}" ]; then
    log_info "Downloading GCC source..."
    wget -q https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz
    tar xf gcc-${GCC_VERSION}.tar.xz
fi

# Create build directory
rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

# Configure GCC to build only libgcc
log_info "Configuring GCC for libgcc..."
../../gcc-${GCC_VERSION}/configure \
    --prefix=${PREFIX} \
    --target=${TARGET} \
    --host=x86_64-linux-gnu \
    --build=x86_64-linux-gnu \
    --with-arch=${MARCH} \
    --with-abi=${MABI} \
    --enable-languages=c \
    --disable-shared \
    --disable-threads \
    --disable-libssp \
    --disable-libgomp \
    --disable-libmudflap \
    --disable-libquadmath \
    --disable-decimal-float \
    --disable-nls \
    --disable-multilib \
    --with-newlib \
    --without-headers

# Build only libgcc
log_info "Building libgcc..."
make -j${JOBS} all-target-libgcc

# Install libgcc
log_info "Installing libgcc..."
make install-target-libgcc DESTDIR=${INSTALL_DIR}

# Copy to the gcc lib directory so glibc can find it
log_info "Copying libgcc to compiler directory..."
sudo mkdir -p /usr/lib/gcc-cross/riscv64-linux-gnu/13/rv32imac/ilp32
sudo cp -v ${INSTALL_DIR}${PREFIX}/lib/gcc/${TARGET}/${GCC_VERSION}/libgcc.a \
    /usr/lib/gcc-cross/riscv64-linux-gnu/13/rv32imac/ilp32/

log_info "libgcc build complete!"
