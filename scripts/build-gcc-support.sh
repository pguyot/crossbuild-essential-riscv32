#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

GCC_VERSION=14.2.0
PACKAGE_VERSION=14.2.0-4ubuntu2

log_info "Creating GCC support packages for ${TARGET}"

# For rv32, we need to create a minimal libgcc.a for glibc to link against during build
# The glibc build process requires libgcc.a (static), but the riscv64 toolchain only has 64-bit version

# Create a minimal 32-bit libgcc.a with stub functions
log_info "Creating minimal 32-bit libgcc.a..."
LIBGCC_BUILD_DIR=$(pwd)/build/libgcc-build
mkdir -p ${LIBGCC_BUILD_DIR}

# Create a stub file with weak symbols for common libgcc functions
cat > ${LIBGCC_BUILD_DIR}/libgcc_stub.c << 'EOF'
/* Minimal libgcc stub for 32-bit RISC-V glibc build
 * These are weak symbols that allow glibc to build without full libgcc
 */

// Integer division functions (shouldn't be needed with M extension, but just in case)
long long __attribute__((weak)) __divdi3(long long a, long long b) { return a / b; }
unsigned long long __attribute__((weak)) __udivdi3(unsigned long long a, unsigned long long b) { return a / b; }
long long __attribute__((weak)) __moddi3(long long a, long long b) { return a % b; }
unsigned long long __attribute__((weak)) __umoddi3(unsigned long long a, unsigned long long b) { return a % b; }

// Bit shift operations (64-bit)
long long __attribute__((weak)) __ashldi3(long long a, int b) { return a << b; }
long long __attribute__((weak)) __ashrdi3(long long a, int b) { return a >> b; }
unsigned long long __attribute__((weak)) __lshrdi3(unsigned long long a, int b) { return a >> b; }

// Count leading zeros
int __attribute__((weak)) __clzsi2(unsigned int x) { return __builtin_clz(x); }
int __attribute__((weak)) __clzdi2(unsigned long long x) { return __builtin_clzll(x); }

// Count trailing zeros
int __attribute__((weak)) __ctzsi2(unsigned int x) { return __builtin_ctz(x); }
int __attribute__((weak)) __ctzdi2(unsigned long long x) { return __builtin_ctzll(x); }

// Find first set bit (returns one plus the index of the least significant 1-bit, or 0 if zero)
int __attribute__((weak)) __ffssi2(unsigned int x) { return __builtin_ffs(x); }
int __attribute__((weak)) __ffsdi2(unsigned long long x) { return __builtin_ffsll(x); }

// Population count (count number of set bits)
int __attribute__((weak)) __popcountsi2(unsigned int x) { return __builtin_popcount(x); }
int __attribute__((weak)) __popcountdi2(unsigned long long x) { return __builtin_popcountll(x); }

// Byte swap functions
unsigned int __attribute__((weak)) __bswapsi2(unsigned int x) {
    return ((x & 0xff000000) >> 24) |
           ((x & 0x00ff0000) >>  8) |
           ((x & 0x0000ff00) <<  8) |
           ((x & 0x000000ff) << 24);
}

unsigned long long __attribute__((weak)) __bswapdi2(unsigned long long x) {
    return ((x & 0xff00000000000000ULL) >> 56) |
           ((x & 0x00ff000000000000ULL) >> 40) |
           ((x & 0x0000ff0000000000ULL) >> 24) |
           ((x & 0x000000ff00000000ULL) >>  8) |
           ((x & 0x00000000ff000000ULL) <<  8) |
           ((x & 0x0000000000ff0000ULL) << 24) |
           ((x & 0x000000000000ff00ULL) << 40) |
           ((x & 0x00000000000000ffULL) << 56);
}

// Soft-float emulation functions (needed when hardware FPU is not available)
float __attribute__((weak)) __floatsisf(int x) { return (float)x; }
float __attribute__((weak)) __floatunsisf(unsigned int x) { return (float)x; }
double __attribute__((weak)) __floatsidf(int x) { return (double)x; }
double __attribute__((weak)) __floatunsidf(unsigned int x) { return (double)x; }
int __attribute__((weak)) __fixsfsi(float x) { return (int)x; }
unsigned int __attribute__((weak)) __fixunssfsi(float x) { return (unsigned int)x; }
int __attribute__((weak)) __fixdfsi(double x) { return (int)x; }
unsigned int __attribute__((weak)) __fixunsdfsi(double x) { return (unsigned int)x; }

float __attribute__((weak)) __addsf3(float a, float b) { return a + b; }
float __attribute__((weak)) __subsf3(float a, float b) { return a - b; }
float __attribute__((weak)) __mulsf3(float a, float b) { return a * b; }
float __attribute__((weak)) __divsf3(float a, float b) { return a / b; }

double __attribute__((weak)) __adddf3(double a, double b) { return a + b; }
double __attribute__((weak)) __subdf3(double a, double b) { return a - b; }
double __attribute__((weak)) __muldf3(double a, double b) { return a * b; }
double __attribute__((weak)) __divdf3(double a, double b) { return a / b; }

// Float comparison functions
int __attribute__((weak)) __eqsf2(float a, float b) { return !(a == b); }
int __attribute__((weak)) __nesf2(float a, float b) { return a != b; }
int __attribute__((weak)) __ltsf2(float a, float b) { return a < b ? -1 : (a == b ? 0 : 1); }
int __attribute__((weak)) __lesf2(float a, float b) { return a <= b ? -1 : (a == b ? 0 : 1); }
int __attribute__((weak)) __gtsf2(float a, float b) { return a > b ? 1 : (a == b ? 0 : -1); }
int __attribute__((weak)) __gesf2(float a, float b) { return a >= b ? 1 : (a == b ? 0 : -1); }

int __attribute__((weak)) __eqdf2(double a, double b) { return !(a == b); }
int __attribute__((weak)) __nedf2(double a, double b) { return a != b; }
int __attribute__((weak)) __ltdf2(double a, double b) { return a < b ? -1 : (a == b ? 0 : 1); }
int __attribute__((weak)) __ledf2(double a, double b) { return a <= b ? -1 : (a == b ? 0 : 1); }
int __attribute__((weak)) __gtdf2(double a, double b) { return a > b ? 1 : (a == b ? 0 : -1); }
int __attribute__((weak)) __gedf2(double a, double b) { return a >= b ? 1 : (a == b ? 0 : -1); }

// Type conversions
float __attribute__((weak)) __extendsfdf2(float x) { return (double)x; }
double __attribute__((weak)) __truncdfsf2(double x) { return (float)x; }

// Unordered comparisons (for NaN handling)
int __attribute__((weak)) __unordsf2(float a, float b) {
    return __builtin_isnan(a) || __builtin_isnan(b);
}
int __attribute__((weak)) __unorddf2(double a, double b) {
    return __builtin_isnan(a) || __builtin_isnan(b);
}

// Quad-precision (long double / __float128) support
// On RISC-V, long double is 128-bit (IEEE binary128)
typedef long double quad_t;

quad_t __attribute__((weak)) __floatditf(long long x) { return (quad_t)x; }
quad_t __attribute__((weak)) __floatsitf(int x) { return (quad_t)x; }
quad_t __attribute__((weak)) __floatunditf(unsigned long long x) { return (quad_t)x; }
quad_t __attribute__((weak)) __floatunsitf(unsigned int x) { return (quad_t)x; }

quad_t __attribute__((weak)) __addtf3(quad_t a, quad_t b) { return a + b; }
quad_t __attribute__((weak)) __subtf3(quad_t a, quad_t b) { return a - b; }
quad_t __attribute__((weak)) __multf3(quad_t a, quad_t b) { return a * b; }
quad_t __attribute__((weak)) __divtf3(quad_t a, quad_t b) { return a / b; }

double __attribute__((weak)) __trunctfdf2(quad_t x) { return (double)x; }
float __attribute__((weak)) __trunctfsf2(quad_t x) { return (float)x; }
quad_t __attribute__((weak)) __extenddftf2(double x) { return (quad_t)x; }
quad_t __attribute__((weak)) __extendsftf2(float x) { return (quad_t)x; }

int __attribute__((weak)) __eqtf2(quad_t a, quad_t b) { return !(a == b); }
int __attribute__((weak)) __netf2(quad_t a, quad_t b) { return a != b; }
int __attribute__((weak)) __lttf2(quad_t a, quad_t b) { return a < b ? -1 : (a == b ? 0 : 1); }
int __attribute__((weak)) __letf2(quad_t a, quad_t b) { return a <= b ? -1 : (a == b ? 0 : 1); }
int __attribute__((weak)) __gttf2(quad_t a, quad_t b) { return a > b ? 1 : (a == b ? 0 : -1); }
int __attribute__((weak)) __getf2(quad_t a, quad_t b) { return a >= b ? 1 : (a == b ? 0 : -1); }
int __attribute__((weak)) __unordtf2(quad_t a, quad_t b) {
    return __builtin_isnan(a) || __builtin_isnan(b);
}

long long __attribute__((weak)) __fixtfdi(quad_t x) { return (long long)x; }
int __attribute__((weak)) __fixtfsi(quad_t x) { return (int)x; }
unsigned long long __attribute__((weak)) __fixunstfdi(quad_t x) { return (unsigned long long)x; }
unsigned int __attribute__((weak)) __fixunstfsi(quad_t x) { return (unsigned int)x; }

// These might be needed for some operations
void __attribute__((weak)) __clear_cache(char *beg, char *end) { }
EOF

# Compile the stub
${CC} -march=${MARCH} -mabi=${MABI} -c ${LIBGCC_BUILD_DIR}/libgcc_stub.c -o ${LIBGCC_BUILD_DIR}/libgcc_stub.o

# Create the static library
riscv64-linux-gnu-ar rcs ${LIBGCC_BUILD_DIR}/libgcc.a ${LIBGCC_BUILD_DIR}/libgcc_stub.o

# Install it where gcc will find it
# Since gcc doesn't have multilib for rv32, we need to replace the default libgcc.a
LIBGCC_INSTALL_DIR=/usr/lib/gcc-cross/riscv64-linux-gnu/13
if [ -f ${LIBGCC_INSTALL_DIR}/libgcc.a ]; then
    sudo mv ${LIBGCC_INSTALL_DIR}/libgcc.a ${LIBGCC_INSTALL_DIR}/libgcc.a.64bit.bak
    log_info "Backed up 64-bit libgcc.a to libgcc.a.64bit.bak"
fi
sudo cp ${LIBGCC_BUILD_DIR}/libgcc.a ${LIBGCC_INSTALL_DIR}/

log_info "Installed minimal 32-bit libgcc.a to ${LIBGCC_INSTALL_DIR}"

# Find the existing libgcc_s.so.1 from the riscv64 toolchain for the shared library package
LIBGCC_PATH=$(${CC} -march=${MARCH} -mabi=${MABI} -print-file-name=libgcc_s.so.1)
if [ ! -f "$LIBGCC_PATH" ]; then
    log_error "Could not find libgcc_s.so.1"
    exit 1
fi

log_info "Found libgcc_s.so.1 at: $LIBGCC_PATH"

# Create gcc-14-base package (just base files, no binaries)
log_info "Creating gcc-14-base-riscv32-cross package..."
BASE_DIR=$(pwd)/build/gcc-14-base-riscv32-cross
mkdir -p ${BASE_DIR}/DEBIAN
mkdir -p ${BASE_DIR}/usr/share/doc/gcc-14-base-riscv32-cross

cat > ${BASE_DIR}/usr/share/doc/gcc-14-base-riscv32-cross/README << EOF
GCC Base Package for RISC-V 32-bit Cross-Compilation
=====================================================

This package provides base files for using GCC with RISC-V 32-bit targets.

The actual compiler used is riscv64-linux-gnu-gcc with the following flags:
  -march=rv32imc
  -mabi=ilp32

This allows cross-compilation to 32-bit RISC-V targets using the existing
64-bit RISC-V toolchain.
EOF

cat > ${BASE_DIR}/DEBIAN/control << EOF
Package: gcc-14-base-riscv32-cross
Version: ${PACKAGE_VERSION}
Section: devel
Priority: optional
Architecture: all
Maintainer: ${MAINTAINER}
Description: GCC base package (for RISC-V 32-bit cross-compiling)
 This package contains base files for the GNU Compiler Collection for
 RISC-V 32-bit cross-compilation.
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build ${BASE_DIR} build/gcc-14-base-riscv32-cross_${PACKAGE_VERSION}_all.deb
log_info "Created: gcc-14-base-riscv32-cross_${PACKAGE_VERSION}_all.deb"

# Create libgcc-s1 package
log_info "Creating libgcc-s1-riscv32-cross package..."
LIBGCC_DIR=$(pwd)/build/libgcc-s1-riscv32-cross
mkdir -p ${LIBGCC_DIR}/DEBIAN
mkdir -p ${LIBGCC_DIR}${PREFIX}/lib

# Copy the libgcc_s.so.1 from the toolchain
# Note: We're using the one that gets selected with rv32 flags
cp -a "$LIBGCC_PATH" ${LIBGCC_DIR}${PREFIX}/lib/
# Also create the symlink
(cd ${LIBGCC_DIR}${PREFIX}/lib && ln -sf libgcc_s.so.1 libgcc_s.so)

cat > ${LIBGCC_DIR}/DEBIAN/control << EOF
Package: libgcc-s1-riscv32-cross
Version: ${PACKAGE_VERSION}
Section: libs
Priority: optional
Architecture: all
Depends: gcc-14-base-riscv32-cross (= ${PACKAGE_VERSION})
Maintainer: ${MAINTAINER}
Description: GCC support library (for RISC-V 32-bit cross-compiling)
 Shared version of the support library, a library of internal subroutines
 that GCC uses to overcome shortcomings of particular machines, or
 special needs for some languages.
 .
 This package contains the library for RISC-V 32-bit.
 .
 This package is for cross-compiling.
EOF

dpkg-deb --build ${LIBGCC_DIR} build/libgcc-s1-riscv32-cross_${PACKAGE_VERSION}_all.deb
log_info "Created: libgcc-s1-riscv32-cross_${PACKAGE_VERSION}_all.deb"

log_info "GCC support packages build complete!"
