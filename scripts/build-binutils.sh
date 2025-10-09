#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

BINUTILS_VERSION=2.42
PACKAGE_NAME=binutils-riscv32-cross
BUILD_DIR=$(pwd)/build/binutils
INSTALL_PREFIX=/usr

# Check if already built
if [ -f "build/.binutils-${BINUTILS_VERSION}.done" ]; then
    log_info "Binutils ${BINUTILS_VERSION} already built, skipping..."
    exit 0
fi

log_info "Building binutils ${BINUTILS_VERSION} for ${TARGET}"

# Get binutils source from Ubuntu (includes patches for cross-compilation)
if [ ! -d "binutils-${BINUTILS_VERSION}" ]; then
    log_info "Getting binutils source from Ubuntu..."
    # Use apt-get source to get Ubuntu's patched binutils
    apt-get source binutils
    # apt-get source extracts to binutils-<version>, find it
    BINUTILS_SRC_DIR=$(ls -d binutils-*/ 2>/dev/null | head -1 | sed 's:/$::')
    if [ -z "$BINUTILS_SRC_DIR" ]; then
        log_error "Failed to extract binutils source"
        exit 1
    fi
    # Rename to expected name if different
    if [ "$BINUTILS_SRC_DIR" != "binutils-${BINUTILS_VERSION}" ]; then
        log_info "Renaming $BINUTILS_SRC_DIR to binutils-${BINUTILS_VERSION}"
        mv "$BINUTILS_SRC_DIR" binutils-${BINUTILS_VERSION}
    fi
fi

# Create build directory
rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

# Configure binutils for riscv32
log_info "Configuring binutils..."
# Use native compiler to build cross-compilation tools
# Unset cross-compilation environment variables for configure
unset CC CXX AR RANLIB STRIP CFLAGS CXXFLAGS LDFLAGS
../../binutils-${BINUTILS_VERSION}/configure \
    --prefix=${INSTALL_PREFIX} \
    --target=${TARGET} \
    --with-sysroot=${PREFIX} \
    --disable-multilib \
    --disable-nls \
    --disable-werror \
    --enable-64-bit-bfd

# Build binutils
log_info "Building binutils (this may take a while)..."
make -j${JOBS}

# Install binutils
log_info "Installing binutils..."
sudo make install

# Mark as complete
cd ../..
touch build/.binutils-${BINUTILS_VERSION}.done

log_info "Binutils ${BINUTILS_VERSION} build complete!"
