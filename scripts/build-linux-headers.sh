#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

KERNEL_VERSION=6.8
PACKAGE_NAME=linux-libc-dev-riscv32-cross

log_info "Building linux-libc-dev ${KERNEL_VERSION} for ${TARGET}"

# Download kernel source
if [ ! -f "linux-${KERNEL_VERSION}.tar.xz" ]; then
    log_info "Downloading Linux kernel ${KERNEL_VERSION} headers..."
    wget -q https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz
fi

# Extract source
log_info "Extracting kernel source..."
rm -rf linux-${KERNEL_VERSION}
tar xf linux-${KERNEL_VERSION}.tar.xz

cd linux-${KERNEL_VERSION}

# Install headers for riscv32
log_info "Installing kernel headers..."
INSTALL_DIR=$(pwd)/../build/${PACKAGE_NAME}
rm -rf ${INSTALL_DIR}
mkdir -p ${INSTALL_DIR}${PREFIX}/include

# Make headers for RISC-V 32-bit
make ARCH=riscv headers_install INSTALL_HDR_PATH=${INSTALL_DIR}${PREFIX}

# Create package
log_info "Creating linux-libc-dev-riscv32-cross package..."
mkdir -p ${INSTALL_DIR}/DEBIAN

cat > ${INSTALL_DIR}/DEBIAN/control << EOF
Package: linux-libc-dev-riscv32-cross
Version: ${KERNEL_VERSION}.0-0ubuntu1
Section: devel
Priority: optional
Architecture: all
Maintainer: ${MAINTAINER}
Description: Linux Kernel Headers for development (for RISC-V 32-bit cross-compiling)
 This package provides headers from the Linux kernel. These headers
 are used by the installed headers for GNU glibc and other system
 libraries. They are NOT meant to be used to build third-party modules for
 your kernel. Use linux-headers-* packages for that.
 .
 This package is for cross-compiling to RISC-V 32-bit.
EOF

cd ..
dpkg-deb --build ${INSTALL_DIR} build/linux-libc-dev-riscv32-cross_${KERNEL_VERSION}.0-0ubuntu1_all.deb
log_info "Created: linux-libc-dev-riscv32-cross_${KERNEL_VERSION}.0-0ubuntu1_all.deb"

log_info "linux-libc-dev build complete!"
