#!/bin/bash

set -e

# Builds a gcc-picolibc-ARM toolchain with blocksds
# Places the toolchain in the "./toolchain/" directory.
# It downloads any necessary sources and validates them.

GCC_VER="14.1.0"
BINUTILS_VER="2.44"
PICOLIBC_VER="1.8.10"
BLOCKSDS_VER="43b693bc622c8fea4a3b991ed9027ba006fc00e5"  # Ver 1.11.1

BINUTILS_URL="http://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VER}.tar.xz"
GCC_URL="http://ftp.gnu.org/gnu/gcc/gcc-${GCC_VER}/gcc-${GCC_VER}.tar.xz"
PICOLIBC_URL="https://github.com/picolibc/picolibc/releases/download/${PICOLIBC_VER}/picolibc-${PICOLIBC_VER}.tar.xz"
BLOCKSDS_URL="https://github.com/blocksds/sdk.git"

BINUTILS_SUM="ce2017e059d63e67ddb9240e9d4ec49c2893605035cd60e92ad53177f4377237"
GCC_SUM="e283c654987afe3de9d8080bc0bd79534b5ca0d681a73a11ff2b5d3767426840"
PICOLIBC_SUM="0ce5ee3bde81256633644d7b3bd25f5a6ccfd8b0590fd4ee543df2c3ede6e27e"


# Clean up and start from anew
rm -rf toolchain/ build/
mkdir -p download/
mkdir -p toolchain/
mkdir -p build/

TOOLCHAIN_PATH=`realpath toolchain`

# Setup env vars
export PATH="${TOOLCHAIN_PATH}/bin:${PATH}"

downfile() {
  # Download source files if they do not exist
  if [ ! -f "download/$1" ]; then
    wget -O "download/$1" "$2"
  fi
  if ! (printf '%s %s\n' "$3" "download/$1" | sha256sum --check); then
    echo "Checksum error"
    exit 1
  fi
}

checkgit() {
  # Checkout git repo at specific commit
  if [ ! -f "download/${1}.tar.xz" ]; then
    git clone "$2" "download/${1}"
    (cd "download/${1}" && git checkout "$3" && git submodule update --init --recursive)
    (cd "download/" && tar cfJ "${1}.tar.xz" "${1}" && rm -rf "${1}")
  fi
}

# Download and check files if needed
downfile "binutils-${BINUTILS_VER}.tar.xz" "$BINUTILS_URL" "$BINUTILS_SUM"
downfile "gcc-${GCC_VER}.tar.xz" "$GCC_URL" "$GCC_SUM"
downfile "picolibc-${PICOLIBC_VER}.tar.xz" "$PICOLIBC_URL" "$PICOLIBC_SUM"
checkgit "blocksds-${BLOCKSDS_VER}" "$BLOCKSDS_URL" "$BLOCKSDS_VER"

if [ "$#" -gt 0 ]; then
  if [ "$1" == "download" ]; then
    exit 0   # Only download!
  fi
fi

# Extract files in the build directory
(cd build && tar xf "../download/binutils-${BINUTILS_VER}.tar.xz")
(cd build && tar xf "../download/gcc-${GCC_VER}.tar.xz")
(cd build && tar xf "../download/picolibc-${PICOLIBC_VER}.tar.xz")
(cd build && tar xf "../download/blocksds-${BLOCKSDS_VER}.tar.xz")

# Apply any necessary patches
(cd build/gcc-${GCC_VER} && patch -p1 < ../../patches/gcc14-poison-system-directories.patch)

# Clear OS flags
unset CXXFLAGS
unset CFLAGS
unset LDFLAGS
# Ubuntu likes to override this :D TODO: Fix upsteam
unset V

# Configure and build binutils for ARM
(cd build/binutils-${BINUTILS_VER} && mkdir build)

pushd build/binutils-${BINUTILS_VER}/build
  ../configure --target=arm-none-eabi \
               --prefix="${TOOLCHAIN_PATH}" \
               --enable-interwork \
               --enable-multilib \
               --with-float=soft \
               --disable-gprof \
               --disable-nls \
               --disable-shared \
               --disable-sim \
               --disable-werror \
               --enable-ld-default \
               --enable-threads \
               --enable-lto \
               --enable-plugins 

  make -j$(nproc) all
  make install-strip
popd

# Do Gcc phase 1 now (just C, no libc support yet)
(cd build/gcc-${GCC_VER} && mkdir build-phase1)

pushd build/gcc-${GCC_VER}/build-phase1
  ../configure --target=arm-none-eabi \
               --prefix="${TOOLCHAIN_PATH}" \
               --enable-poison-system-directories \
               --enable-interwork \
               --enable-multilib \
               --without-headers \
               --enable-plugins \
               --disable-bootstrap \
               --disable-gcov \
               --disable-nls \
               --disable-shared \
               --disable-werror \
               --disable-libquadmath \
               --disable-libssp \
               --enable-languages=c \
               --disable-libunwind-exceptions \
               --disable-threads \
               --with-gnu-as \
               --with-gnu-ld

  make -j$(nproc) all
  make install-strip
popd

# We proceed to build picolibc with the current gcc1 phase1
(cd build/picolibc-${PICOLIBC_VER} && mkdir build)

pushd build/picolibc-${PICOLIBC_VER}/build

  meson setup \
          --cross-file=../../../patches/cross-thumb.txt \
          -Dmultilib=true \
          -Dpicocrt=false \
          -Dpicolib=false \
          -Dsemihost=false \
          -Dspecsdir=none \
          -Dtests=false \
          -Dfast-bufio=true \
          -Dio-long-long=true \
          -Dio-pos-args=true \
          -Dio-percent-b=true \
          -Dposix-console=true \
          -Dformat-default=double \
          -Dnewlib-nano-malloc=false \
          -Dprefix="${TOOLCHAIN_PATH}" \
          -Dlibdir=arm-none-eabi/lib \
          -Dincludedir=arm-none-eabi/include \
          ..

  ninja
  ninja install

  # Remove linkerscripts (provided by the SDK) and add spec file
  rm "${TOOLCHAIN_PATH}/arm-none-eabi/lib/"picolibc*.ld
  cp ../../../patches/picolibc.specs "${TOOLCHAIN_PATH}/arm-none-eabi/lib/"

popd


# Now proceed with gcc phase 2, that includes C++
(cd build/gcc-${GCC_VER} && mkdir build-phase2)

pushd build/gcc-${GCC_VER}/build-phase2
  ../configure --target=arm-none-eabi \
               --prefix="${TOOLCHAIN_PATH}" \
               --with-sysroot="${TOOLCHAIN_PATH}/arm-none-eabi" \
               --with-native-system-header-dir="/include" \
               --enable-poison-system-directories \
               --with-newlib \
               --enable-interwork \
               --enable-multilib \
               --enable-plugins \
               --disable-gcov \
               --disable-nls \
               --disable-shared \
               --disable-werror \
               --disable-libquadmath \
               --disable-libssp \
               --enable-languages=c,c++ \
               --disable-libunwind-exceptions \
               --disable-threads \
               --with-gnu-as \
               --with-gnu-ld

  make -j$(nproc) all
  make install-strip
popd

# Go ahead and install the actual SDK
pushd build/blocksds-${BLOCKSDS_VER}
  # Point to the toolchain
  export ARM_NONE_EABI_PATH=${TOOLCHAIN_PATH}/bin/

  BLOCKSDS=$PWD make -j`nproc`
  mkdir -p "${TOOLCHAIN_PATH}/blocksds"
  INSTALLDIR="${TOOLCHAIN_PATH}/blocksds" make install
popd


