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


  # helper: free memory and drop caches safely (ignore failures under set -e)
free_memory_and_cache() {
    echo ">"
    echo "> Freeing memory and dropping caches..."
    echo ">"
    sync || true
    if [ -w /proc/sys/vm/drop_caches ]; then
      echo 3 > /proc/sys/vm/drop_caches || true
    else
      # try sudo without password; ignore errors
      sh -c 'echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null || true
    fi
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
  export LD_LIBRARY_PATH=/opt/mygcc/lib:/opt/mygcc/lib64:$LD_LIBRARY_PATH
  export PATH=/opt/mygcc/bin:$PATH
  
  # 使用 LLVM 的 libc++
  #   -DLLVM_PARALLEL_COMPILE_JOBS="$NPROC_HALF" \
  # -DLLVM_PARALLEL_LINK_JOBS="$NPROC_HALF" \
  # clang use follow, gcc no
  # -DLLVM_ENABLE_LTO=Full \

  
  # -DCMAKE_CXX_COMPILER="$(which clang++)" \
  # -DCMAKE_C_COMPILER="$(which clang)" \
  # clang
  # -DLLVM_ENABLE_RUNTIMES="compiler-rt;libcxx;libcxxabi;
  # -DLLVM_ENABLE_PROJECTS="clang;lld;compiler-rt" \
  #     -DLLVM_USE_LINKER=gold \
  cmake -G "Ninja" \
    -DLLVM_ENABLE_PROJECTS="lld" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_LLD_DIR" \
    -DLLVM_DEFAULT_TARGET_TRIPLE="$TARGET_CLANG" \
    -DLLVM_TARGET_ARCH="X86" \
    -DLLVM_TARGETS_TO_BUILD=$ARCH_CLANG \
    -DLLVM_ENABLE_LIBCXX=ON \
    -DCMAKE_CXX_COMPILER="/opt/mygcc/bin/g++" \
    -DCMAKE_C_COMPILER="/opt/mygcc/bin/gcc" \
    -DLLVM_OPTIMIZED_TABLEGEN=ON \
    -DLLVM_ENABLE_LIBXML2=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_BUILD_RUNTIME=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_BUILD_TESTS=OFF \
    -DLLVM_BUILD_DOCS=OFF \
    -DLLVM_BUILD_EXAMPLES=OFF \
    -DLLVM_ENABLE_MODULES=OFF \
    -DLLVM_ENABLE_BACKTRACES=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
    -DLLVM_USE_LINKER=gold \
    -DCMAKE_LINKER=/opt/mygcc/bin/ld.gold \
    -DLLVM_PARALLEL_LINK_JOBS=2 \
    -DCMAKE_EXE_LINKER_FLAGS="\
    -Wl,--as-needed \
    -Wl,--gc-sections \
    -Wl,--no-keep-memory " \
    -DCMAKE_SHARED_LINKER_FLAGS="\
    -Wl,--as-needed \
    -Wl,--gc-sections \
    -Wl,--no-keep-memory " \
    -DCMAKE_MODULE_LINKER_FLAGS="\
    -Wl,--as-needed \
    -Wl,--no-keep-memory " \
    -DCMAKE_C_FLAGS="-O3 -DNDEBUG" \
    -DCMAKE_CXX_FLAGS="-O3 -DNDEBUG" \
    -DLLVM_ENABLE_PIC=ON \
    -DLLVM_ENABLE_ZLIB=1 \
    -DZLIB_LIBRARY="/opt/vcpkg/installed/x64-linux/lib/libz.a" \
    -DZLIB_INCLUDE_DIR="/opt/vcpkg/installed/x64-linux/include" \
    "${WORK_DIR}"/llvm-project/llvm
  # 这里会消耗茫茫多内存，所以尝试先开启多进程编译，失败之后降级到单进程  
  # ninja -j$(nproc --all) || ninja -j$NPROC_HALF || ninja || echo "failed"

   # 这里会消耗茫茫多内存，所以尝试先开启多进程编译，失败之后降级到单进程
  # 按需求：降级一次 -> 释放一次内存和缓存 -> 再降级一次
  if ! ninja -j"$(nproc --all)"; then
    echo "> First attempt failed. Retrying with $NPROC_HALF jobs..."
    if ! ninja -j"$NPROC_HALF"; then
      free_memory_and_cache
      echo "> Second attempt failed. Retrying with 1 job..."
      ninja -j"$NPROC_HALF" || ninja -j1 || echo "failed"
    fi
  fi
  
  ninja -j$NPROC_HALF install
  # Create proper symlinks
  cd "${INSTALL_LLD_DIR}"/bin
  ln -s lld ${TARGET_GCC}-ld.lld
  cd "${WORK_DIR}"
}

download_resources
build_lld
