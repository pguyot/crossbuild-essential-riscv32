#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

GCC_VERSION=14.2.0
PACKAGE_NAME=gcc-riscv32-cross
BUILD_DIR=$(pwd)/build/gcc-riscv32
INSTALL_PREFIX=/usr

# Check if already built
if [ -f "build/.gcc-riscv32-${GCC_VERSION}.done" ]; then
    log_info "GCC ${GCC_VERSION} for riscv32 already built, skipping..."
    exit 0
fi

log_info "Building GCC ${GCC_VERSION} for ${TARGET}"

# Get GCC source from Ubuntu (includes patches for cross-compilation)
if [ ! -d "gcc-${GCC_VERSION}" ]; then
    log_info "Getting GCC source from Ubuntu..."
    # Use apt-get source to get Ubuntu's patched gcc
    apt-get source gcc-14
    # apt-get source extracts to gcc-14-<version>, find it
    GCC_SRC_DIR=$(ls -d gcc-14-*/ 2>/dev/null | head -1 | sed 's:/$::')
    if [ -z "$GCC_SRC_DIR" ]; then
        log_error "Failed to extract GCC source"
        exit 1
    fi
    # Rename to expected name if different
    if [ "$GCC_SRC_DIR" != "gcc-${GCC_VERSION}" ]; then
        log_info "Renaming $GCC_SRC_DIR to gcc-${GCC_VERSION}"
        mv "$GCC_SRC_DIR" gcc-${GCC_VERSION}
    fi

    # Extract tarball if this is Ubuntu's package format
    cd gcc-${GCC_VERSION}
    if [ -f "gcc-${GCC_VERSION}.tar.xz" ]; then
        log_info "Extracting gcc tarball from Ubuntu package..."
        tar xf gcc-${GCC_VERSION}.tar.xz
        # Move contents to src/ directory for consistency
        if [ -d "gcc-${GCC_VERSION}" ]; then
            mv gcc-${GCC_VERSION} src
        fi
    fi

    # Download prerequisites (only needed for upstream tarballs, not Ubuntu packages)
    if [ -f "src/contrib/download_prerequisites" ]; then
        log_info "Downloading GCC prerequisites..."
        cd src
        ./contrib/download_prerequisites
        cd ..
    elif [ -f "contrib/download_prerequisites" ]; then
        log_info "Downloading GCC prerequisites..."
        ./contrib/download_prerequisites
    else
        log_info "Skipping prerequisites (Ubuntu package already includes them)"
    fi
    cd ..
fi

# Create build directory
rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

# Configure GCC for riscv32
log_info "Configuring GCC..."
# Debug: show what's in the gcc directory
log_info "Listing gcc-${GCC_VERSION} contents:"
ls -la ../../gcc-${GCC_VERSION}/ | head -20 || true

# Detect gcc source structure - try multiple possible locations
GCC_CONFIGURE=""
for possible_dir in "../../gcc-${GCC_VERSION}/src" "../../gcc-${GCC_VERSION}"; do
    log_info "Checking for configure in $possible_dir"
    if [ -f "$possible_dir/configure" ]; then
        GCC_CONFIGURE="$possible_dir/configure"
        log_info "Found configure in $possible_dir"
        break
    fi
done

if [ -z "$GCC_CONFIGURE" ]; then
    log_error "Could not find GCC configure script"
    log_info "Directory structure:"
    find ../../gcc-${GCC_VERSION}/ -name configure -type f 2>/dev/null || true
    exit 1
fi

# Use native compiler to build cross-compilation tools
# Unset cross-compilation environment variables for configure
unset CC CXX AR RANLIB STRIP CFLAGS CXXFLAGS LDFLAGS
${GCC_CONFIGURE} \
    --prefix=${INSTALL_PREFIX} \
    --target=${TARGET} \
    --with-sysroot=${PREFIX} \
    --with-arch=${MARCH} \
    --with-abi=${MABI} \
    --enable-languages=c,c++ \
    --disable-multilib \
    --disable-nls \
    --disable-libssp \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libsanitizer \
    --disable-libvtv \
    --disable-libcilkrts \
    --disable-libmpx \
    --disable-libatomic \
    --disable-threads \
    --disable-shared \
    --enable-tls \
    --with-newlib \
    --without-headers \
    --with-gnu-as \
    --with-gnu-ld

# Build GCC stage 1 (without libc)
log_info "Building GCC stage 1 (this will take a while)..."
make -j${JOBS} all-gcc all-target-libgcc

# Install GCC stage 1
log_info "Installing GCC stage 1..."
sudo make install-gcc install-target-libgcc

# Mark as complete
cd ../..
touch build/.gcc-riscv32-${GCC_VERSION}.done

log_info "GCC ${GCC_VERSION} for riscv32 build complete!"
