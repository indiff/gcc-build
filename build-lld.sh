#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0
# Author: Vaisakh Murali
set -e

echo "***************************"
echo "* Building Integrated LLD *"
echo "***************************"

while getopts a: flag; do
  if [[ $flag == "a" ]]; then
    arch="$OPTARG"
    case "${OPTARG}" in
      "arm") ARCH_CLANG="ARM" && TARGET_CLANG="arm-linux-gnueabi" && TARGET_GCC="arm-eabi" ;;
      "arm64") ARCH_CLANG="AArch64" && TARGET_CLANG="aarch64-linux-gnu" && TARGET_GCC="aarch64-elf" ;;
      "x86") ARCH_CLANG="X86" && TARGET_CLANG="x86_64-linux-gnu" && TARGET_GCC="x86_64-elf" ;;
      *) echo "Invalid architecture passed: $OPTARG" && exit 1 ;;
    esac
  else
    echo "Invalid argument passed" && exit 1
  fi
done

# Let's keep this as is
export WORK_DIR="$(pwd)"
export PREFIX="${WORK_DIR}/gcc-${arch}"
export PATH="$PREFIX/bin:$PATH"

echo "Cleaning up previously cloned repos..."
rm -rf "${WORK_DIR}"/llvm-project

echo "Building Integrated lld for ${arch} with ${TARGET_CLANG} as target"

download_resources() {
  echo ">"
  echo "> Downloading LLVM for LLD"
  echo ">"
  cd "${WORK_DIR}"
  git clone --filter=blob:none https://github.com/llvm/llvm-project.git -b main "${WORK_DIR}/llvm-project" --depth=1
}

build_lld() {
  cd "${WORK_DIR}"
  echo ">"
  echo "> Building LLD"
  echo ">"
  # Use half of available cores
  NPROC_HALF=$(($(nproc --all) / 2))
  # Ensure at least 1 core is used
  NPROC_HALF=$((NPROC_HALF > 0 ? NPROC_HALF : 1))
  mkdir -p "${WORK_DIR}/llvm-project/build"
  cd "${WORK_DIR}/llvm-project/build"
  export INSTALL_LLD_DIR="${WORK_DIR}/gcc-${arch}"
  cmake -G "Ninja" \
    -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
    -DLLVM_ENABLE_PROJECTS="clang;lld;compiler-rt" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_LLD_DIR" \
    -DLLVM_DEFAULT_TARGET_TRIPLE="$TARGET_CLANG" \
    -DLLVM_TARGET_ARCH="X86" \
    -DLLVM_TARGETS_TO_BUILD=$ARCH_CLANG \
    -DCMAKE_CXX_COMPILER="$(which clang++)" \
    -DCMAKE_C_COMPILER="$(which clang)" \
    -DLLVM_OPTIMIZED_TABLEGEN=ON \
    -DLLVM_ENABLE_LIBXML2=OFF \
    -DLLVM_USE_LINKER=lld \
    -DLLVM_ENABLE_LTO=Full \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_BUILD_RUNTIME=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_ENABLE_MODULES=OFF \
    -DLLVM_ENABLE_BACKTRACES=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_PARALLEL_COMPILE_JOBS="$NPROC_HALF" \
    -DLLVM_PARALLEL_LINK_JOBS="$NPROC_HALF" \
    -DBUILD_SHARED_LIBS=OFF \
    -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
    -DCMAKE_C_FLAGS="-O3" \
    -DCMAKE_CXX_FLAGS="-O3" \
    -DLLVM_ENABLE_PIC=ON \
    -DLLVM_ENABLE_ZLIB=1 \
    -DZLIB_LIBRARY="/opt/vcpkg/installed/x64-linux/lib/libz.a" \
    -DZLIB_INCLUDE_DIR="/opt/vcpkg/installed/x64-linux/include" \
    "${WORK_DIR}"/llvm-project/llvm
  ninja -j$NPROC_HALF
  ninja -j$NPROC_HALF install
  # Create proper symlinks
  cd "${INSTALL_LLD_DIR}"/bin
  ln -s lld ${TARGET_GCC}-ld.lld
  cd "${WORK_DIR}"
}

download_resources
build_lld
