#!/bin/bash
# Build libc6-dbg for riscv32

set -e

MABI=$1
MARCH=$2

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "Building libc6-dbg for ${ARCH} (${MARCH};${MABI})"

# The toolchain should be installed at /opt/riscv32
TOOLCHAIN_SYSROOT="/opt/riscv32-${MABI}/sysroot"
if [ ! -d "${TOOLCHAIN_SYSROOT}" ]; then
    log_error "Toolchain sysroot not found at ${TOOLCHAIN_SYSROOT}"
    log_error "Please install the riscv32-gnu-toolchain-multilib package first"
    exit 1
fi

# Find glibc version from the toolchain
LIBC_SO=$(find ${TOOLCHAIN_SYSROOT} -name "libc.so.6" -type f | head -1)
if [ -z "${LIBC_SO}" ]; then
    log_error "Could not find libc.so.6 in toolchain sysroot"
    exit 1
fi

# Use Ubuntu 24.04's glibc version
GLIBC_VERSION=2.39
log_info "Using glibc version: ${GLIBC_VERSION}"

# Package version
LIBC_PKG_VERSION="${GLIBC_VERSION}-0ubuntu1"

# Create libc6-dbg package
log_info "Creating libc6-dbg:${ARCH} package (${MARCH};${MABI})"
cd "$(dirname "${SCRIPT_DIR}")"

# Define ABI-specific library path
LIB_DIR="${TARGET}-${MABI}"

DBG_DIR=build/libc6-dbg_${ARCH}_${MARCH}_${MABI}
rm -rf ${DBG_DIR}
mkdir -p ${DBG_DIR}/DEBIAN
mkdir -p ${DBG_DIR}/usr/lib/${LIB_DIR}

# Copy debug libraries from toolchain
if [ -d "${TOOLCHAIN_SYSROOT}/usr/lib/debug" ]; then
    mkdir -p ${DBG_DIR}/usr/lib/${LIB_DIR}/debug
    cp -a ${TOOLCHAIN_SYSROOT}/usr/lib/debug/* ${DBG_DIR}/usr/lib/${LIB_DIR}/debug/ 2>/dev/null || true
fi

# If no debug files found, extract static libraries as fallback
if [ ! -d "${DBG_DIR}/usr/lib/${LIB_DIR}/debug" ] || [ ! "$(ls -A ${DBG_DIR}/usr/lib/${LIB_DIR}/debug 2>/dev/null)" ]; then
    log_warn "No debug files found in toolchain, copying static libraries as fallback..."
    mkdir -p ${DBG_DIR}/usr/lib/${LIB_DIR}

    # Copy all static libraries from the sysroot
    find ${TOOLCHAIN_SYSROOT} -name "*.a" -exec cp {} ${DBG_DIR}/usr/lib/${LIB_DIR}/ \; 2>/dev/null || true
fi

# Create control file with ABI-specific package name
PKG_NAME="libc6-dbg-${MABI}"
cat > ${DBG_DIR}/DEBIAN/control << EOF
Package: ${PKG_NAME}
Architecture: ${ARCH}
Version: ${LIBC_PKG_VERSION}
Multi-Arch: same
Section: debug
Priority: extra
Provides: libc-dbg
Maintainer: ${MAINTAINER}
Description: GNU C Library: detached debugging symbols (${ARCH} ${MARCH}-${MABI} cross-compile)
 This package contains the detached debugging symbols for the GNU C Library
 for ${ARCH} (${MARCH};${MABI}).
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build --root-owner-group ${DBG_DIR} build/${PKG_NAME}_${LIBC_PKG_VERSION}_${ARCH}.deb
log_info "Created: ${PKG_NAME}_${LIBC_PKG_VERSION}_${ARCH}.deb"

log_info "libc6-dbg build complete!"
