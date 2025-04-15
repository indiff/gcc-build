#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0
# Author: Vaisakh Murali
set -e

echo "*****************************************"
echo "* Building Bare-Metal Bleeding Edge GCC *"
echo "*****************************************"

# Declare the number of jobs to run simultaneously
JOBS=$(nproc --all)

# TODO: Add more dynamic option handling
while getopts a: flag; do
  case "${flag}" in
    a) arch=${OPTARG} ;;
    *) echo "Invalid argument passed" && exit 1 ;;
  esac
done

# TODO: Better target handling
case "${arch}" in
  "arm") TARGET="arm-eabi" ;;
  "arm64") TARGET="aarch64-elf" ;;
  "arm64gnu") TARGET="aarch64-linux-gnu" ;;
  # "x86") TARGET="x86_64-elf" ;;
  "x86") TARGET="x86_64-linux-gnu" ;;
esac

export WORK_DIR="$PWD"
export PREFIX="$WORK_DIR/gcc-${arch}"
export PATH="$PREFIX/bin:/usr/bin/core_perl:$PATH"
export OPT_FLAGS="-flto -flto-compression-level=10 -O3 -pipe -ffunction-sections -fdata-sections"

echo "Cleaning up previously cloned repos..."
rm -rf "$WORK_DIR"/{binutils,build-binutils,build-gcc,gcc}

echo "||                                                                    ||"
echo "|| Building Bare Metal Toolchain for ${arch} with ${TARGET} as target ||"
echo "||                                                                    ||"

download_resources() {
  echo "Downloading Pre-requisites"
  echo "Cloning binutils"
  git clone git://sourceware.org/git/binutils-gdb.git -b master binutils --depth=1
  sed -i '/^development=/s/true/false/' binutils/bfd/development.sh
  echo "Cloned binutils!"
  echo "Cloning GCC"
  git clone git://gcc.gnu.org/git/gcc.git -b master gcc --depth=1
  cd "${WORK_DIR}"
  echo "Downloaded prerequisites!"
}

build_binutils() {
	  cd "${WORK_DIR}"
	  echo "Building Binutils"
	  mkdir build-binutils
	  cd build-binutils
	  env CFLAGS="$OPT_FLAGS" CXXFLAGS="$OPT_FLAGS" \
		../binutils/configure --target="$TARGET" --build="$TARGET" --host="$TARGET"  \
		--program-prefix= \
		--disable-docs \
		--disable-gdb \
		--disable-nls \
		--disable-werror \
		--enable-ld \
		--enable-gold \
		--enable-deterministic-archives=no \
		--enable-lto \
		--enable-compressed-debug-sections=none \
		--enable-generate-build-notes=no \
		--enable-threads=yes \
		--enable-relro=yes \
		--enable-plugins \
		--prefix="$PREFIX" \
		--with-bugurl=https://github.com/indiff/gcc-build \
		--with-sysroot=/  \
		--with-pkgversion="Indiff binutils"
	  
	  make -j"$JOBS"
	  make install -j"$JOBS"
	  cd ../
	  echo "Built Binutils, proceeding to next step...."
}

build_gcc() {
  cd "${WORK_DIR}"
  echo "Building GCC"
  cd gcc
  ./contrib/download_prerequisites
  echo "Bleeding Edge" > gcc/DEV-PHASE
  cd ../
  mkdir build-gcc
  cd build-gcc
  env CFLAGS="$OPT_FLAGS" CXXFLAGS="$OPT_FLAGS" \
    ../gcc/configure --target="$TARGET" \
    --with-bugurl=https://github.com/indiff/gcc-build \
    --disable-decimal-float \
    --disable-docs \
    --disable-gcov \
    --disable-libffi \
    --disable-libgomp \
    --disable-libmudflap \
    --disable-libquadmath \
    --disable-libstdcxx-pch \
    --disable-nls \
    --disable-shared \
	--disable-libunwind-exceptions \
	--enable-__cxa_atexit \
    --enable-bootstrap \
    --enable-multilib \
    --enable-gnu-unique-object \
    --enable-plugin  \
    --enable-gnu-indirect-function \
    --enable-initfini-array \
    --enable-default-ssp \
    --enable-languages=c,c++,fortran,lto \
    --enable-threads=posix \
	--enable-libstdcxx-backtrace \
	--enable-offload-targets=nvptx-none \
	--without-cuda-driver --enable-offload-defaulted \
	--with-tune=generic \
	--with-gcc-major-version-only \
	--with-arch_32=x86-64 \
    --prefix="$PREFIX" \
    --with-gnu-as \
    --with-gnu-ld \
    --with-headers="/usr/include" \
    --with-linker-hash-style=gnu \
    --with-newlib \
    --with-pkgversion="Indiff GCC"

  make all-gcc -j"$JOBS"
  make all-target-libgcc -j"$JOBS"
  make install-gcc -j"$JOBS"
  make install-target-libgcc -j"$JOBS"
  echo "Built GCC!"
}

download_resources
build_binutils
build_gcc
