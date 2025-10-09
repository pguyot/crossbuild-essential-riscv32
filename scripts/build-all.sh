#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "Starting RISC-V 32-bit cross-compilation packages build"
log_info "Target: ${TARGET}, MARCH: ${MARCH}, MABI: ${MABI}"

# Create build directory
mkdir -p build

# Build packages in dependency order, installing each before the next
log_info "===== Building linux-libc-dev (kernel headers) ====="
bash "${SCRIPT_DIR}/build-linux-headers.sh"
log_info "Installing linux-libc-dev-riscv32-cross..."
sudo dpkg -i build/linux-libc-dev-riscv32-cross_*.deb

log_info "===== Building glibc (libc6, libc6-dev, libc6-dbg) ====="
bash "${SCRIPT_DIR}/build-glibc.sh"
log_info "Installing libc6 packages..."
sudo dpkg -i build/libc6-riscv32-cross_*.deb build/libc6-dev-riscv32-cross_*.deb build/libc6-dbg-riscv32-cross_*.deb

log_info "===== Building GCC support (gcc-14-base, libgcc-s1) ====="
bash "${SCRIPT_DIR}/build-gcc-support.sh"
log_info "Installing GCC support packages..."
sudo dpkg -i build/gcc-14-base-riscv32-cross_*.deb build/libgcc-s1-riscv32-cross_*.deb

log_info "===== Building libxcrypt (libcrypt1, libcrypt-dev) ====="
bash "${SCRIPT_DIR}/build-libxcrypt.sh"
log_info "Installing libxcrypt packages..."
sudo dpkg -i build/libcrypt1-riscv32-cross_*.deb build/libcrypt-dev-riscv32-cross_*.deb

log_info "===== Building libunistring ====="
bash "${SCRIPT_DIR}/build-libunistring.sh"
log_info "Installing libunistring package..."
sudo dpkg -i build/libunistring5-riscv32-cross_*.deb

log_info "===== Building libidn2 ====="
bash "${SCRIPT_DIR}/build-libidn2.sh"
log_info "Installing libidn2 package..."
sudo dpkg -i build/libidn2-0-riscv32-cross_*.deb

log_info "===== Building zlib ====="
bash "${SCRIPT_DIR}/build-zlib.sh"
log_info "Installing zlib packages..."
sudo dpkg -i build/zlib1g-riscv32-cross_*.deb build/zlib1g-dev-riscv32-cross_*.deb

log_info "===== Building mbedtls (libmbedcrypto, libmbedx509, libmbedtls, dev) ====="
bash "${SCRIPT_DIR}/build-mbedtls.sh"
log_info "Installing mbedtls packages..."
sudo dpkg -i build/libmbedcrypto7-riscv32-cross_*.deb build/libmbedx509-1-riscv32-cross_*.deb build/libmbedtls14-riscv32-cross_*.deb build/libmbedtls-dev-riscv32-cross_*.deb

# List all generated packages
log_info "===== Build Summary ====="
log_info "Generated packages:"
ls -lh build/*.deb | awk '{print "  - " $9 " (" $5 ")"}'

log_info "All packages built successfully!"
log_info "Install with: sudo dpkg -i build/*.deb"
