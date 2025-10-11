#!/bin/bash
set -euo pipefail

# Common configuration for all build scripts
export ARCH=riscv32
export TARGET=riscv32-linux-gnu
export MARCH=rv32gc
export MABI=ilp32d
export JOBS=$(nproc)

# Toolchain configuration - use official riscv32 toolchain
# The toolchain should be set up with scripts/setup-toolchain.sh first
export CC=riscv32-linux-gnu-gcc
export CXX=riscv32-linux-gnu-g++
export AR=riscv32-linux-gnu-ar
export RANLIB=riscv32-linux-gnu-ranlib
export STRIP=riscv32-linux-gnu-strip

# Common flags for 32-bit RISC-V
export CFLAGS="-march=${MARCH} -mabi=${MABI} -O2 -fno-semantic-interposition"
export CXXFLAGS="-march=${MARCH} -mabi=${MABI} -O2 -fno-semantic-interposition"
export LDFLAGS="-march=${MARCH} -mabi=${MABI}"

# Installation prefix
export PREFIX=/usr/${TARGET}
export SYSROOT=${PREFIX}

# Package metadata
export MAINTAINER="Paul Guyot <pguyot@kallisys.net>"
export UBUNTU_VERSION="24.04"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Create directory structure
create_package_structure() {
    local package_name=$1
    local package_dir="build/${package_name}"

    mkdir -p "${package_dir}/DEBIAN"
    mkdir -p "${package_dir}${PREFIX}"

    echo "${package_dir}"
}

# Create .deb package
create_deb_package() {
    local package_dir=$1
    local package_name=$2
    local version=$3
    local description=$4
    local depends=$5

    cat > "${package_dir}/DEBIAN/control" << EOF
Package: ${package_name}
Version: ${version}
Section: libs
Priority: optional
Architecture: all
Maintainer: ${MAINTAINER}
Description: ${description}
${depends:+Depends: ${depends}}
EOF

    dpkg-deb --build "${package_dir}" "build/${package_name}_${version}_all.deb"
    log_info "Created package: build/${package_name}_${version}_all.deb"
}
