#!/bin/bash
# Build libc6-dev for riscv32

set -e

MABI=$1
MARCH=$2

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "Building libc6-dev for ${ARCH} (${MARCH};${MABI})"

# Define ABI-specific library path
LIB_DIR="${TARGET}-${MABI}"

# The toolchain should be installed at /opt/riscv32-{abi}
TOOLCHAIN_SYSROOT="/opt/riscv32-${MABI}/sysroot"
if [ ! -d "${TOOLCHAIN_SYSROOT}" ]; then
    log_error "Toolchain sysroot not found at ${TOOLCHAIN_SYSROOT}"
    log_error "Please install the riscv32-gnu-toolchain-${MABI} package first"
    exit 1
fi

# Use Ubuntu 24.04's glibc version
GLIBC_VERSION=2.39
log_info "Using glibc version: ${GLIBC_VERSION}"

# Package version
LIBC_PKG_VERSION="${GLIBC_VERSION}-0ubuntu1"

# Create libc6-dev package
log_info "Creating libc6-dev:${ARCH} package (${MARCH};${MABI})"
cd "$(dirname "${SCRIPT_DIR}")"

DEV_DIR=build/libc6-dev_${ARCH}_${MARCH}_${MABI}
rm -rf ${DEV_DIR}
mkdir -p ${DEV_DIR}/DEBIAN
mkdir -p ${DEV_DIR}/usr/lib/${LIB_DIR}
mkdir -p ${DEV_DIR}/usr/include/${LIB_DIR}

# Copy development headers from toolchain
log_info "Copying development headers..."
if [ -d "${TOOLCHAIN_SYSROOT}/usr/include" ]; then
    cp -a ${TOOLCHAIN_SYSROOT}/usr/include/* ${DEV_DIR}/usr/include/${LIB_DIR}/ 2>/dev/null || true
fi

# Copy static libraries and other development files
log_info "Copying static libraries..."
# Copy .a files (static libraries)
find ${TOOLCHAIN_SYSROOT}/lib -name "*.a" -exec cp {} ${DEV_DIR}/usr/lib/${LIB_DIR}/ \; 2>/dev/null || true
find ${TOOLCHAIN_SYSROOT}/usr/lib -name "*.a" -exec cp {} ${DEV_DIR}/usr/lib/${LIB_DIR}/ \; 2>/dev/null || true

# Copy .o files (object files needed for linking)
find ${TOOLCHAIN_SYSROOT}/lib -name "*.o" -exec cp {} ${DEV_DIR}/usr/lib/${LIB_DIR}/ \; 2>/dev/null || true
find ${TOOLCHAIN_SYSROOT}/usr/lib -name "*.o" -exec cp {} ${DEV_DIR}/usr/lib/${LIB_DIR}/ \; 2>/dev/null || true

# Copy linker scripts (.so files that are actually linker scripts, not binaries)
# These are needed for proper linking
find ${TOOLCHAIN_SYSROOT}/lib -name "*.so" -type f -exec sh -c 'file "$1" | grep -q "ASCII text" && cp "$1" {}' _ {} ${DEV_DIR}/usr/lib/${LIB_DIR}/ \; 2>/dev/null || true
find ${TOOLCHAIN_SYSROOT}/usr/lib -name "*.so" -type f -exec sh -c 'file "$1" | grep -q "ASCII text" && cp "$1" {}' _ {} ${DEV_DIR}/usr/lib/${LIB_DIR}/ \; 2>/dev/null || true

# Create control file with ABI-specific package name
PKG_NAME="libc6-dev-${MABI}"
cat > ${DEV_DIR}/DEBIAN/control << EOF
Package: ${PKG_NAME}
Architecture: ${ARCH}
Version: ${LIBC_PKG_VERSION}
Multi-Arch: same
Section: libdevel
Priority: optional
Provides: libc-dev
Maintainer: ${MAINTAINER}
Description: GNU C Library: development files (${ARCH} ${MARCH}-${MABI} cross-compile)
 This package contains the headers and static libraries for the GNU C Library
 for ${ARCH} (${MARCH};${MABI}).
 .
 This package includes headers and static libraries needed to compile programs
 that use the standard C library.
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build --root-owner-group ${DEV_DIR} build/${PKG_NAME}_${LIBC_PKG_VERSION}_${ARCH}.deb
log_info "Created: ${PKG_NAME}_${LIBC_PKG_VERSION}_${ARCH}.deb"

log_info "libc6-dev build complete!"
