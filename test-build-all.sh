#!/bin/bash
set -euo pipefail

# Test script to build all packages locally and catch errors

echo "=== Building linux headers ==="
bash scripts/build-linux-headers.sh 2>&1 | tee logs/linux-headers.log
sudo dpkg -i build/linux-libc-dev-riscv32-cross_*.deb

echo "=== Building binutils ==="
bash scripts/build-binutils.sh 2>&1 | tee logs/binutils.log

echo "=== Building GCC support ==="
bash scripts/build-gcc-support.sh 2>&1 | tee logs/gcc-support.log
sudo dpkg -i build/gcc-14-base-riscv32-cross_*.deb build/libgcc-s1-riscv32-cross_*.deb

echo "=== Building GCC stage 1 ==="
bash scripts/build-gcc-riscv32.sh 2>&1 | tee logs/gcc-riscv32.log

echo "=== Building glibc ==="
bash scripts/build-glibc.sh 2>&1 | tee logs/glibc.log
sudo dpkg -i build/libc6-riscv32-cross_*_all.deb build/libc6-dev-riscv32-cross_*_all.deb build/libc6-dbg-riscv32-cross_*_all.deb

echo "=== Building libxcrypt ==="
bash scripts/build-libxcrypt.sh 2>&1 | tee logs/libxcrypt.log
sudo dpkg -i build/libcrypt1-riscv32-cross_*.deb build/libcrypt-dev-riscv32-cross_*.deb

echo "=== Building libunistring ==="
bash scripts/build-libunistring.sh 2>&1 | tee logs/libunistring.log
sudo dpkg -i build/libunistring5-riscv32-cross_*.deb

echo "=== Building libidn2 ==="
bash scripts/build-libidn2.sh 2>&1 | tee logs/libidn2.log
sudo dpkg -i build/libidn2-0-riscv32-cross_*.deb

echo "=== Building zlib ==="
bash scripts/build-zlib.sh 2>&1 | tee logs/zlib.log
sudo dpkg -i build/zlib1g-riscv32-cross_*.deb build/zlib1g-dev-riscv32-cross_*.deb

echo "=== Building mbedtls ==="
bash scripts/build-mbedtls.sh 2>&1 | tee logs/mbedtls.log
sudo dpkg -i build/libmbedcrypto7-riscv32-cross_*.deb build/libmbedx509-1-riscv32-cross_*.deb build/libmbedtls14-riscv32-cross_*.deb build/libmbedtls-dev-riscv32-cross_*.deb

echo "=== All builds complete! ==="
ls -lh build/*.deb
