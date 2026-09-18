#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: build-gcc.sh --arch x86|arm [options]

Options:
  --arch NAME       Native container architecture: x86 (x86_64) or arm (aarch64)
  --os NAME         Output OS label (example: ubuntu, oraclelinux7, oraclelinux8, oraclelinux9)
  --ref REF         GCC git branch, tag, or commit (default: master)
  --jobs N          Parallel make jobs (default: nproc)
  --prefix DIR      Installation prefix inside the artifact (default: /opt/gcc)
  --output-dir DIR  Directory receiving the tar.xz artifact (default: /artifacts)
  --keep-source     Keep downloaded source trees after the build
  -h, --help        Show this help
EOF
}

ARCH=""
OS_LABEL="linux"
GCC_REF="${GCC_REF:-master}"
JOBS="${BUILD_JOBS:-$(nproc)}"
PREFIX="/opt/gcc"
OUTPUT_DIR="/artifacts"
KEEP_SOURCE=0

while (($#)); do
  case "$1" in
    --arch) ARCH="${2:?missing value for --arch}"; shift 2 ;;
    --os) OS_LABEL="${2:?missing value for --os}"; shift 2 ;;
    --ref) GCC_REF="${2:?missing value for --ref}"; shift 2 ;;
    --jobs) JOBS="${2:?missing value for --jobs}"; shift 2 ;;
    --prefix) PREFIX="${2:?missing value for --prefix}"; shift 2 ;;
    --output-dir) OUTPUT_DIR="${2:?missing value for --output-dir}"; shift 2 ;;
    --keep-source) KEEP_SOURCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$ARCH" in
  x86) ARCH_PATTERN='(x86_64|amd64)' ;;
  arm) ARCH_PATTERN='(aarch64|arm64)' ;;
  *) echo '--arch must be x86 or arm' >&2; exit 2 ;;
esac

# ========== 移除原来硬编码OS白名单校验，不再限制centos，支持oraclelinux7/8/9等任意标签 ==========
# case "$OS_LABEL" in
#   ubuntu|centos7|centos8|centos9|linux) ;;
#   *) echo '--os must be ubuntu, centos7, centos8, or centos9' >&2; exit 2 ;;
# esac

if ! [[ "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
  echo '--jobs must be a positive integer' >&2
  exit 2
fi

if [[ "$PREFIX" != /* ]]; then
  echo '--prefix must be an absolute path' >&2
  exit 2
fi

WORK_DIR="${WORK_DIR:-/workspace}"
SOURCE_DIR="$WORK_DIR/src"
BINUTILS_DIR="$SOURCE_DIR/binutils"
GCC_DIR="$SOURCE_DIR/gcc"
BUILD_BINUTILS="$WORK_DIR/build-binutils"
BUILD_GCC="$WORK_DIR/build-gcc"
BUILD_TRIPLET="$(gcc -dumpmachine)"
if [[ ! "$BUILD_TRIPLET" =~ ^${ARCH_PATTERN} ]]; then
  echo "Container architecture does not match --arch=$ARCH: gcc reports $BUILD_TRIPLET" >&2
  exit 1
fi
TARGET="$BUILD_TRIPLET"
DATE_TAG="$(date -u +%Y%m%d_%H%M%S)"
ARTIFACT_NAME="gcc-${OS_LABEL}-${ARCH}-${DATE_TAG}"

log() { printf '[gcc-build] %s\n' "$*"; }

clone_shallow() {
  local destination="$1"
  local ref="$2"
  shift 2
  local url
  rm -rf "$destination"
  for url in "$@"; do
    if git clone --depth=1 --branch "$ref" "$url" "$destination"; then
      return 0
    fi
    rm -rf "$destination"
  done
  echo "Unable to clone $destination at ref $ref" >&2
  exit 1
}

rm -rf "$SOURCE_DIR" "$BUILD_BINUTILS" "$BUILD_GCC" "$PREFIX"
mkdir -p "$SOURCE_DIR" "$OUTPUT_DIR"

log "Building GCC ref=$GCC_REF os=$OS_LABEL arch=$ARCH target=$TARGET jobs=$JOBS"
clone_shallow "$BINUTILS_DIR" master \
  "https://sourceware.org/git/binutils-gdb.git" \
  "https://gitlab.com/open-mirrors/binutils-gdb.git" \
  "https://github.com/bminor/binutils-gdb.git"
clone_shallow "$GCC_DIR" "$GCC_REF" \
  "https://github.com/gcc-mirror/gcc.git" \
  "https://gcc.gnu.org/git/gcc.git"

sed -i '/^development=/s/true/false/' "$BINUTILS_DIR/bfd/development.sh" || true

log 'Downloading GCC prerequisites'
(cd "$GCC_DIR" && ./contrib/download_prerequisites)

log 'Configuring and building binutils'
mkdir -p "$BUILD_BINUTILS"
(
  cd "$BUILD_BINUTILS"
  "$BINUTILS_DIR/configure" \
    --target="$TARGET" \
    --build="$BUILD_TRIPLET" \
    --host="$BUILD_TRIPLET" \
    --prefix="$PREFIX" \
    --disable-gdb \
    --disable-nls \
    --disable-werror \
    --enable-plugins \
    --enable-ld \
    --enable-gold \
    --with-pkgversion="indiff GCC build"
  make -j"$JOBS"
  make install
)

log 'Configuring and building GCC'
mkdir -p "$BUILD_GCC"
(
  cd "$BUILD_GCC"
  # binutils 是 native 构建（build=host=target）时安装的工具不带 target 前缀，
  # 例如 $PREFIX/bin/as 和 $PREFIX/bin/ld；cross 构建才会生成 $TARGET-as/$TARGET-ld。
  if [[ -x "$PREFIX/bin/$TARGET-as" ]]; then
    WITH_AS="$PREFIX/bin/$TARGET-as"
    WITH_LD="$PREFIX/bin/$TARGET-ld"
  else
    WITH_AS="$PREFIX/bin/as"
    WITH_LD="$PREFIX/bin/ld"
  fi
  "$GCC_DIR/configure" \
    --target="$TARGET" \
    --build="$BUILD_TRIPLET" \
    --host="$BUILD_TRIPLET" \
    --prefix="$PREFIX" \
    --with-gnu-as \
    --with-gnu-ld \
    --with-as="$WITH_AS" \
    --with-ld="$WITH_LD" \
    --disable-multilib \
    --disable-nls \
    --disable-werror \
    --enable-languages=c,c++ \
    --enable-threads=posix \
    --enable-__cxa_atexit \
    --enable-default-ssp \
    --enable-plugin \
    --with-pkgversion="indiff GCC build"
  # 注意：当前 GCC master 顶层 Makefile 中 configure-target-libgcc / configure-target-libstdc++-v3
  # 都不依赖 all-gcc，configure-target-libstdc++-v3 也不依赖 all-target-libgcc。
  # 若像旧写法一样在一条 make 命令中并行请求多个目标，会发生抢跑：
  #   - libgcc 在 xgcc 生成前 configure（xgcc: No such file）
  #   - libstdc++-v3 在 libgcc.a 生成前做链接测试（Link tests are not allowed after GCC_NO_EXECUTABLES）
  # 因此必须逐个目标串行执行。
  # 另外，GCC master 的 LINK_LIBATOMIC_SPEC 默认用 "-latomic_asneeded"，该 ldscript 由
  # all-target-libatomic 生成到 $BUILD_GCC/gcc/ 目录；不先构建 libatomic 的话，
  # libstdc++-v3 configure 的链接测试会报 "ld: cannot find -latomic_asneeded"。
  make -j"$JOBS" all-gcc
  make -j"$JOBS" all-target-libgcc
  make -j"$JOBS" all-target-libatomic
  make -j"$JOBS" all-target-libstdc++-v3
  make install-gcc install-target-libgcc install-target-libatomic install-target-libstdc++-v3
)

log 'Writing build metadata and archive'
mkdir -p "$PREFIX/share/gcc-build"
cat > "$PREFIX/share/gcc-build/build-info.txt" <<EOF
gcc_ref=$GCC_REF
os=$OS_LABEL
arch=$ARCH
target=$TARGET
build_triplet=$BUILD_TRIPLET
build_date_utc=$(date -u +%FT%TZ)
EOF

mkdir -p "$OUTPUT_DIR"
tar -C "$(dirname "$PREFIX")" -cJf "$OUTPUT_DIR/$ARTIFACT_NAME.tar.xz" "$(basename "$PREFIX")"
sha256sum "$OUTPUT_DIR/$ARTIFACT_NAME.tar.xz" > "$OUTPUT_DIR/$ARTIFACT_NAME.tar.xz.sha256"
log "Artifact: $OUTPUT_DIR/$ARTIFACT_NAME.tar.xz"

if ((KEEP_SOURCE == 0)); then
  rm -rf "$SOURCE_DIR" "$BUILD_BINUTILS" "$BUILD_GCC"
fi
