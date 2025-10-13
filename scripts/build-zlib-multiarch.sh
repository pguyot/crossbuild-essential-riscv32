#!/bin/bash
# Build zlib1g and zlib1g-dev for riscv32 with multilib support

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# zlib version (match Ubuntu 24.04)
ZLIB_VERSION="1.3.1"
ZLIB_PKG_VERSION="1:${ZLIB_VERSION}.dfsg-3.1ubuntu2.1"
# Safe version for filenames (dpkg handles epoch internally)
ZLIB_FILE_VERSION="${ZLIB_VERSION}.dfsg-3.1ubuntu2.1"

log_info "Building zlib ${ZLIB_VERSION} for ${ARCH} with multilib support"

# Download and extract zlib source
cd "$(dirname "${SCRIPT_DIR}")"
if [ ! -d "zlib-${ZLIB_VERSION}" ]; then
    log_info "Downloading zlib source..."
    wget -q https://www.zlib.net/zlib-${ZLIB_VERSION}.tar.gz
    tar xzf zlib-${ZLIB_VERSION}.tar.gz
    rm zlib-${ZLIB_VERSION}.tar.gz
fi

# Create main installation directory
INSTALL_DIR=$(pwd)/build/zlib-install
rm -rf ${INSTALL_DIR}
mkdir -p ${INSTALL_DIR}

# Define multilib variants: march, mabi, libdir_suffix
MULTILIB_VARIANTS=(
    "rv32imac:ilp32::ilp32"
    "rv32imafc:ilp32f::ilp32f"
    "rv32gc:ilp32d::"
)

# Build each multilib variant
for variant in "${MULTILIB_VARIANTS[@]}"; do
    IFS=':' read -r march mabi suffix libdir <<< "$variant"

    log_info "Building zlib for ${march}/${mabi}..."

    cd zlib-${ZLIB_VERSION}

    # Clean previous build
    make distclean 2>/dev/null || true

    # Configure for cross-compilation
    # Use minimal CFLAGS for configure to avoid "too harsh" error
    CC=${CC} AR=${AR} RANLIB=${RANLIB} \
    CFLAGS="-march=${march} -mabi=${mabi} -O2" \
    ./configure --prefix=/usr

    log_info "Building zlib for ${march}/${mabi}..."
    make -j${JOBS}

    # Install to variant-specific directory
    VARIANT_INSTALL=$(pwd)/../build/zlib-install-${march}-${mabi}
    rm -rf ${VARIANT_INSTALL}
    mkdir -p ${VARIANT_INSTALL}
    make install DESTDIR=${VARIANT_INSTALL}

    # Copy to main install dir with proper multilib path
    if [ -z "$suffix" ]; then
        # Default variant (rv32gc/ilp32d) goes to base lib directory
        mkdir -p ${INSTALL_DIR}/usr/lib
        cp -a ${VARIANT_INSTALL}/usr/lib/*.so* ${INSTALL_DIR}/usr/lib/
        cp -a ${VARIANT_INSTALL}/usr/lib/*.a ${INSTALL_DIR}/usr/lib/
    else
        # Other variants go to multilib subdirectories
        mkdir -p ${INSTALL_DIR}/usr/lib/${libdir}
        cp -a ${VARIANT_INSTALL}/usr/lib/*.so* ${INSTALL_DIR}/usr/lib/${libdir}/
        cp -a ${VARIANT_INSTALL}/usr/lib/*.a ${INSTALL_DIR}/usr/lib/${libdir}/
    fi

    # Copy headers and pkgconfig from first variant only
    if [ "$march" = "rv32imac" ]; then
        mkdir -p ${INSTALL_DIR}/usr/include
        mkdir -p ${INSTALL_DIR}/usr/lib/pkgconfig
        cp -a ${VARIANT_INSTALL}/usr/include/*.h ${INSTALL_DIR}/usr/include/
        cp -a ${VARIANT_INSTALL}/usr/lib/pkgconfig ${INSTALL_DIR}/usr/lib/
    fi

    cd ..
    log_info "Completed build for ${march}/${mabi}"
done

cd "$(dirname "${SCRIPT_DIR}")"

# Create zlib1g package (runtime) with all multilib variants
log_info "Creating zlib1g:${ARCH} package..."
RUNTIME_DIR=build/zlib1g_${ARCH}
rm -rf ${RUNTIME_DIR}
mkdir -p ${RUNTIME_DIR}/DEBIAN
mkdir -p ${RUNTIME_DIR}/usr/lib/${TARGET}

# Copy all runtime libraries (all multilib variants)
cp -a ${INSTALL_DIR}/usr/lib/*.so.* ${RUNTIME_DIR}/usr/lib/${TARGET}/ 2>/dev/null || true
# Copy multilib variant libraries
if [ -d ${INSTALL_DIR}/usr/lib/ilp32 ]; then
    mkdir -p ${RUNTIME_DIR}/usr/lib/${TARGET}/ilp32
    cp -a ${INSTALL_DIR}/usr/lib/ilp32/*.so.* ${RUNTIME_DIR}/usr/lib/${TARGET}/ilp32/ 2>/dev/null || true
fi
if [ -d ${INSTALL_DIR}/usr/lib/ilp32f ]; then
    mkdir -p ${RUNTIME_DIR}/usr/lib/${TARGET}/ilp32f
    cp -a ${INSTALL_DIR}/usr/lib/ilp32f/*.so.* ${RUNTIME_DIR}/usr/lib/${TARGET}/ilp32f/ 2>/dev/null || true
fi

# Create control file
cat > ${RUNTIME_DIR}/DEBIAN/control << EOF
Package: zlib1g
Architecture: ${ARCH}
Version: ${ZLIB_PKG_VERSION}
Multi-Arch: same
Section: libs
Priority: optional
Maintainer: ${MAINTAINER}
Description: compression library - runtime (${ARCH} cross-compile)
 zlib is a library implementing the deflate compression method found
 in gzip and PKZIP.  This package includes the shared library for ${ARCH}.
 .
 This package includes multilib variants:
  - rv32imac/ilp32 (soft-float)
  - rv32imafc/ilp32f (single-precision FP)
  - rv32gc/ilp32d (double-precision FP, default)
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build --root-owner-group ${RUNTIME_DIR} build/zlib1g_${ZLIB_FILE_VERSION}_${ARCH}.deb
log_info "Created: zlib1g_${ZLIB_FILE_VERSION}_${ARCH}.deb"

# Create zlib1g-dev package (development) with all multilib variants
log_info "Creating zlib1g-dev:${ARCH} package..."
DEV_DIR=build/zlib1g-dev_${ARCH}
rm -rf ${DEV_DIR}
mkdir -p ${DEV_DIR}/DEBIAN
mkdir -p ${DEV_DIR}/usr/lib/${TARGET}
mkdir -p ${DEV_DIR}/usr/include/${TARGET}

# Copy development files (all multilib variants)
cp -a ${INSTALL_DIR}/usr/lib/libz.so ${DEV_DIR}/usr/lib/${TARGET}/ 2>/dev/null || true
cp -a ${INSTALL_DIR}/usr/lib/libz.a ${DEV_DIR}/usr/lib/${TARGET}/ 2>/dev/null || true
# Copy multilib variant static libraries and symlinks
if [ -d ${INSTALL_DIR}/usr/lib/ilp32 ]; then
    mkdir -p ${DEV_DIR}/usr/lib/${TARGET}/ilp32
    cp -a ${INSTALL_DIR}/usr/lib/ilp32/libz.so ${DEV_DIR}/usr/lib/${TARGET}/ilp32/ 2>/dev/null || true
    cp -a ${INSTALL_DIR}/usr/lib/ilp32/libz.a ${DEV_DIR}/usr/lib/${TARGET}/ilp32/ 2>/dev/null || true
fi
if [ -d ${INSTALL_DIR}/usr/lib/ilp32f ]; then
    mkdir -p ${DEV_DIR}/usr/lib/${TARGET}/ilp32f
    cp -a ${INSTALL_DIR}/usr/lib/ilp32f/libz.so ${DEV_DIR}/usr/lib/${TARGET}/ilp32f/ 2>/dev/null || true
    cp -a ${INSTALL_DIR}/usr/lib/ilp32f/libz.a ${DEV_DIR}/usr/lib/${TARGET}/ilp32f/ 2>/dev/null || true
fi

# Copy headers and pkgconfig
cp -a ${INSTALL_DIR}/usr/lib/pkgconfig ${DEV_DIR}/usr/lib/${TARGET}/
cp -a ${INSTALL_DIR}/usr/include/*.h ${DEV_DIR}/usr/include/${TARGET}/

# Fix pkg-config file
sed -i "s|prefix=/usr|prefix=/usr/${TARGET}|g" ${DEV_DIR}/usr/lib/${TARGET}/pkgconfig/zlib.pc

# Create control file
cat > ${DEV_DIR}/DEBIAN/control << EOF
Package: zlib1g-dev
Architecture: ${ARCH}
Version: ${ZLIB_PKG_VERSION}
Multi-Arch: same
Section: libdevel
Priority: optional
Provides: libz-dev
Depends: zlib1g (= ${ZLIB_PKG_VERSION})
Maintainer: ${MAINTAINER}
Description: compression library - development (${ARCH} cross-compile)
 zlib is a library implementing the deflate compression method found
 in gzip and PKZIP.  This package includes development support files for ${ARCH}.
 .
 This package includes multilib variants:
  - rv32imac/ilp32 (soft-float)
  - rv32imafc/ilp32f (single-precision FP)
  - rv32gc/ilp32d (double-precision FP, default)
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build --root-owner-group ${DEV_DIR} build/zlib1g-dev_${ZLIB_FILE_VERSION}_${ARCH}.deb
log_info "Created: zlib1g-dev_${ZLIB_FILE_VERSION}_${ARCH}.deb"

log_info "zlib build complete!"
