# RISC-V 32-bit Cross-Compilation Packages for Ubuntu

This repository provides cross-compilation packages for RISC-V 32-bit (rv32imac with ILP32 ABI) on Ubuntu 24.04. These packages enable you to build and test 32-bit RISC-V applications using QEMU user emulation, similar to how `crossbuild-essential-armhf` works for ARM.

## Problem Statement

While Ubuntu provides excellent support for RISC-V 64-bit cross-compilation through packages like `gcc-riscv64-linux-gnu`, there's no official support for RISC-V 32-bit. When trying to compile for 32-bit RISC-V using flags like `-march=rv32imac -mabi=ilp32`, you'll encounter errors:

```bash
$ riscv64-linux-gnu-gcc -march=rv32imac -mabi=ilp32 hello.c -o hello
fatal error: gnu/stubs-ilp32.h: No such file or directory
```

This happens because the standard libraries (glibc, zlib, etc.) are only available for 64-bit RISC-V.

## Solution

This repository builds and packages the following libraries for RISC-V 32-bit:

### Core Libraries
- **linux-libc-dev-riscv32-cross** - Linux kernel headers
- **libc6-riscv32-cross** - GNU C Library runtime
- **libc6-dev-riscv32-cross** - GNU C Library development files
- **libc6-dbg-riscv32-cross** - GNU C Library debug symbols
- **gcc-14-base-riscv32-cross** - GCC base package
- **libgcc-s1-riscv32-cross** - GCC support library

### Additional Libraries
- **libcrypt1-riscv32-cross** - Password/crypt library runtime
- **libcrypt-dev-riscv32-cross** - Password/crypt library development files
- **libunistring5-riscv32-cross** - Unicode string library
- **libidn2-0-riscv32-cross** - Internationalized Domain Names library
- **zlib1g-riscv32-cross** - zlib compression library runtime
- **zlib1g-dev-riscv32-cross** - zlib development files
- **libmbedcrypto7-riscv32-cross** - mbedTLS crypto library
- **libmbedx509-1-riscv32-cross** - mbedTLS X.509 library
- **libmbedtls14-riscv32-cross** - mbedTLS TLS/SSL library
- **libmbedtls-dev-riscv32-cross** - mbedTLS development files

All packages are built using GitHub Actions and can be installed alongside existing riscv64 packages.

## Installation

### Option 1: Download Pre-built Packages

Download all packages from the [Releases](https://github.com/pguyot/crossbuild-essential-riscv32/releases) page. Each release includes all 16 .deb packages.

```bash
# Download all packages from the latest release
# Visit https://github.com/pguyot/crossbuild-essential-riscv32/releases/latest
# and download all .deb files, or use the GitHub CLI:
gh release download --repo pguyot/crossbuild-essential-riscv32 --pattern "*.deb"

# Install all packages (install in order to satisfy dependencies)
sudo dpkg -i *-linux-libc-dev*.deb
sudo dpkg -i libc6-riscv32-cross*.deb libc6-dev-riscv32-cross*.deb libc6-dbg-riscv32-cross*.deb
sudo dpkg -i gcc-14-base*.deb libgcc-s1*.deb
sudo dpkg -i libcrypt1*.deb libcrypt-dev*.deb
sudo dpkg -i libunistring5*.deb
sudo dpkg -i libidn2-0*.deb
sudo dpkg -i zlib1g*.deb
sudo dpkg -i libmbed*.deb
```

### Option 2: Build Locally

```bash
# Install dependencies
sudo apt-get update
sudo apt-get install -y \
  gcc-riscv64-linux-gnu \
  g++-riscv64-linux-gnu \
  binutils-riscv64-linux-gnu \
  build-essential \
  cmake \
  wget \
  gawk \
  bison \
  flex \
  texinfo \
  python3 \
  libgmp-dev \
  libmpfr-dev \
  libmpc-dev \
  libisl-dev

# Clone and build
git clone https://github.com/pguyot/crossbuild-essential-riscv32.git
cd crossbuild-essential-riscv32
chmod +x scripts/*.sh
bash scripts/build-all.sh

# Install
sudo dpkg -i build/*.deb
```

## Prerequisites

Before using these packages, ensure you have the RISC-V 64-bit toolchain installed:

```bash
sudo apt-get install gcc-riscv64-linux-gnu qemu-user qemu-user-binfmt
```

## Usage

After installing the packages, you can compile and run RISC-V 32-bit programs:

### Basic Example

```c
// hello.c
#include <stdio.h>

int main() {
    printf("hello, world\n");
    return 0;
}
```

Compile for RISC-V 32-bit:

```bash
riscv64-linux-gnu-gcc -march=rv32imac -mabi=ilp32 hello.c -o hello_riscv32
```

Run with QEMU:

```bash
qemu-riscv32 -L /usr/riscv32-linux-gnu ./hello_riscv32
```

### Using Libraries

Example with zlib:

```c
#include <stdio.h>
#include <zlib.h>

int main() {
    printf("zlib version: %s\n", zlibVersion());
    return 0;
}
```

Compile:

```bash
riscv64-linux-gnu-gcc -march=rv32imac -mabi=ilp32 \
  -I/usr/riscv32-linux-gnu/include \
  -L/usr/riscv32-linux-gnu/lib \
  example.c -lz -o example_riscv32
```

Run:

```bash
qemu-riscv32 -L /usr/riscv32-linux-gnu ./example_riscv32
```

## Package Details

All packages install to `/usr/riscv32-linux-gnu/` to avoid conflicts with existing riscv64 packages.

### Library Versions

- **linux**: 6.8
- **glibc**: 2.39
- **gcc**: 14.2.0
- **libxcrypt**: 4.4.36
- **libunistring**: 1.1
- **libidn2**: 2.3.7
- **zlib**: 1.3.1
- **mbedtls**: 2.28.8

### Target Architecture

- **Architecture**: RISC-V 32-bit
- **ISA**: rv32imac (RV32I base + M extension + A extension + C extension)
- **ABI**: ILP32 (32-bit integer, 32-bit long, 32-bit pointer)

## Building Additional Packages

You can use the build scripts as templates to create packages for other libraries. The general structure is:

1. Cross-compile the library with:
   - `CC=riscv64-linux-gnu-gcc`
   - `CFLAGS="-march=rv32imac -mabi=ilp32"`
   - `--prefix=/usr/riscv32-linux-gnu`

2. Package the results into .deb files with proper dependencies

See `scripts/build-zlib.sh` for a simple example.

## GitHub Actions

This repository includes a GitHub Actions workflow that automatically builds all packages on:

- Push to main/master branch
- Pull requests
- Manual trigger (workflow_dispatch)
- Release creation

The workflow produces artifacts that can be downloaded and installed directly.

## Troubleshooting

### Compilation fails with "cannot find -lc"

Make sure you've installed the runtime package:
```bash
sudo dpkg -i libc6-riscv32-cross_*.deb
```

### QEMU fails with "Could not open '/lib/ld-linux-riscv32-ilp32.so'"

Use the `-L` flag to specify the library path:
```bash
qemu-riscv32 -L /usr/riscv32-linux-gnu ./your-program
```

### Missing library error

Ensure you've installed both runtime and development packages for the library you need.

## Contributing

Contributions are welcome! If you'd like to add support for additional libraries:

1. Fork this repository
2. Create a new build script in `scripts/`
3. Update `scripts/build-all.sh` to include your library
4. Test the build locally
5. Submit a pull request

## License

The build scripts in this repository are released under the MIT License. The packaged software (glibc, zlib, mbedtls) retains its original licenses.

## Acknowledgments

- Inspired by Ubuntu's `crossbuild-essential-armhf` packages
- Built on the excellent work of the RISC-V toolchain maintainers
- Thanks to the glibc, zlib, and mbedTLS projects

## See Also

- [RISC-V GNU Toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain)
- [QEMU RISC-V](https://www.qemu.org/docs/master/system/target-riscv.html)
- [Ubuntu RISC-V Wiki](https://wiki.ubuntu.com/RISC-V)
