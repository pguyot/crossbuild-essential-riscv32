#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

TOOLCHAIN_VERSION="2025.09.28"
TOOLCHAIN_URL="https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/${TOOLCHAIN_VERSION}/riscv32-glibc-ubuntu-24.04-gcc-nightly-${TOOLCHAIN_VERSION}-nightly.tar.xz"
TOOLCHAIN_DIR="/opt/riscv32"
TOOLCHAIN_ARCHIVE="/tmp/riscv32-toolchain.tar.xz"

log_info "Setting up official RISC-V 32-bit toolchain"

# Check if already installed
if [ -d "${TOOLCHAIN_DIR}" ] && [ -f "${TOOLCHAIN_DIR}/bin/riscv32-unknown-linux-gnu-gcc" ]; then
    log_info "Toolchain already installed at ${TOOLCHAIN_DIR}"
else
    # Download toolchain if not already present
    if [ ! -f "${TOOLCHAIN_ARCHIVE}" ]; then
        log_info "Downloading official RISC-V 32-bit toolchain (~600MB)..."
        wget -q --show-progress -O "${TOOLCHAIN_ARCHIVE}" "${TOOLCHAIN_URL}"
    else
        log_info "Using cached toolchain archive"
    fi

    # Extract toolchain
    log_info "Extracting toolchain to ${TOOLCHAIN_DIR}..."
    sudo mkdir -p ${TOOLCHAIN_DIR}
    sudo tar -xf ${TOOLCHAIN_ARCHIVE} -C ${TOOLCHAIN_DIR} --strip-components=1

    log_info "Toolchain extracted successfully"
fi

# Create Ubuntu-style symlinks (riscv32-linux-gnu-* -> riscv32-unknown-linux-gnu-*)
log_info "Creating Ubuntu-style symlinks..."
cd ${TOOLCHAIN_DIR}/bin
for tool in riscv32-unknown-linux-gnu-*; do
    ubuntu_name=$(echo $tool | sed 's/unknown-linux-gnu/linux-gnu/')
    if [ ! -e "$ubuntu_name" ]; then
        sudo ln -sf "$tool" "$ubuntu_name"
    fi
done

# Copy toolchain libraries to standard cross-compilation location
log_info "Setting up cross-compilation sysroot at /usr/riscv32-linux-gnu..."
sudo mkdir -p /usr/riscv32-linux-gnu
sudo cp -rn ${TOOLCHAIN_DIR}/sysroot/* /usr/riscv32-linux-gnu/ || true

# Verify installation
${TOOLCHAIN_DIR}/bin/riscv32-linux-gnu-gcc --version | head -1

log_info "Toolchain setup complete!"
log_info "Toolchain installed at: ${TOOLCHAIN_DIR}"
log_info "Sysroot copied to: /usr/riscv32-linux-gnu"
log_info "Add ${TOOLCHAIN_DIR}/bin to PATH to use it"
