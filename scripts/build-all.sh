#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "Starting RISC-V 32-bit cross-compilation packages build"
log_info "Target: ${TARGET}, MARCH: ${MARCH}, MABI: ${MABI}"

# Create build directory
mkdir -p build

# Build packages in order (glibc must be first)
log_info "===== Building glibc ====="
bash "${SCRIPT_DIR}/build-glibc.sh"

log_info "===== Building zlib ====="
bash "${SCRIPT_DIR}/build-zlib.sh"

log_info "===== Building mbedtls ====="
bash "${SCRIPT_DIR}/build-mbedtls.sh"

# List all generated packages
log_info "===== Build Summary ====="
log_info "Generated packages:"
ls -lh build/*.deb | awk '{print "  - " $9 " (" $5 ")"}'

log_info "All packages built successfully!"
log_info "Install with: sudo dpkg -i build/*.deb"
