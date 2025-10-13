#!/bin/bash
# Build libc6-dbg for riscv32 with Multi-Arch support

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "Building libc6-dbg for ${ARCH}"

# The toolchain should be installed at /opt/riscv
TOOLCHAIN_SYSROOT="/opt/riscv/sysroot"
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

# Get glibc version
GLIBC_VERSION=$(${TARGET}-gcc --version | grep -oP 'glibc \K[\d.]+' || echo "2.39")
log_info "Detected glibc version: ${GLIBC_VERSION}"

# Package version
LIBC_PKG_VERSION="${GLIBC_VERSION}-0ubuntu1"

# Create libc6-dbg package
log_info "Creating libc6-dbg:${ARCH} package..."
cd "$(dirname "${SCRIPT_DIR}")"

DBG_DIR=build/libc6-dbg_${ARCH}
rm -rf ${DBG_DIR}
mkdir -p ${DBG_DIR}/DEBIAN
mkdir -p ${DBG_DIR}/usr/lib/${TARGET}

# Copy debug libraries from toolchain
# In multilib toolchains, debug files are usually in lib/rv32gc/ilp32d/
for multilib_path in "" "rv32gc/ilp32d/" "rv32imac/ilp32/" "rv32imafc/ilp32f/"; do
    src_path="${TOOLCHAIN_SYSROOT}/lib/${multilib_path}"
    if [ -d "${src_path}" ]; then
        log_info "Checking ${src_path} for debug libraries..."
        # Copy .a files (static libraries with debug info)
        find "${src_path}" -name "*.a" -exec cp {} ${DBG_DIR}/usr/lib/${TARGET}/ \; 2>/dev/null || true
        # Copy any _g.so files (debug versions)
        find "${src_path}" -name "*_g.so*" -exec cp -a {} ${DBG_DIR}/usr/lib/${TARGET}/ \; 2>/dev/null || true
    fi
done

# Also check for debug directory
if [ -d "${TOOLCHAIN_SYSROOT}/usr/lib/debug" ]; then
    mkdir -p ${DBG_DIR}/usr/lib/debug
    cp -a ${TOOLCHAIN_SYSROOT}/usr/lib/debug/* ${DBG_DIR}/usr/lib/debug/ 2>/dev/null || true
fi

# If no debug files found, extract them from the shared libraries
if [ ! "$(ls -A ${DBG_DIR}/usr/lib/${TARGET}/ 2>/dev/null)" ]; then
    log_warn "No debug files found in toolchain, extracting from shared libraries..."
    mkdir -p ${DBG_DIR}/usr/lib/${TARGET}

    # Copy all static libraries
    find ${TOOLCHAIN_SYSROOT} -name "*.a" -exec cp {} ${DBG_DIR}/usr/lib/${TARGET}/ \; 2>/dev/null || true
fi

# Create control file
cat > ${DBG_DIR}/DEBIAN/control << EOF
Package: libc6-dbg
Architecture: ${ARCH}
Version: ${LIBC_PKG_VERSION}
Multi-Arch: same
Section: debug
Priority: extra
Provides: libc-dbg
Maintainer: ${MAINTAINER}
Description: GNU C Library: detached debugging symbols (${ARCH} cross-compile)
 This package contains the detached debugging symbols for the GNU C Library
 for ${ARCH}.
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build --root-owner-group ${DBG_DIR} build/libc6-dbg_${LIBC_PKG_VERSION}_${ARCH}.deb
log_info "Created: libc6-dbg_${LIBC_PKG_VERSION}_${ARCH}.deb"

log_info "libc6-dbg build complete!"
