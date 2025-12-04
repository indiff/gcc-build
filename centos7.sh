#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# CentOS 7 dependency installation and configuration script
set -xe
export gcc_indiff_centos7_url="https://github.com/indiff/gcc-build/releases/download/20251203_1308_16.0.0/gcc-indiff-centos7-16.0.0-x86_64-20251203_1005.xz"
echo 'LANG=zh_CN.UTF-8' >> /etc/environment
echo 'LANGUAGE=zh_CN.UTF-8' >> /etc/environment
echo 'LC_ALL=zh_CN.UTF-8' >> /etc/environment
echo 'LC_CTYPE=zh_CN.UTF-8' >> /etc/environment

# Define mirror list for CentOS 7.9.2009
MIRRORS=(
    "http://mirror.rackspace.com/centos-vault/7.9.2009"
    "https://mirror.nsc.liu.se/centos-store/7.9.2009"
    "https://linuxsoft.cern.ch/centos-vault/7.9.2009"
    "https://archive.kernel.org/centos-vault/7.9.2009"
    "https://vault.centos.org/7.9.2009"
)

# Initialize variables
FASTEST_MIRROR=""
FASTEST_TIME=99999

echo "Testing mirror response times..."

# Test each mirror's response time
for MIRROR in "${MIRRORS[@]}"; do
    echo -n "Testing $MIRROR ... "
    TIME=$(curl -o /dev/null -s -w "%{time_total}\n" "$MIRROR" || echo "99999")
    echo "$TIME seconds"
    
    if (( $(echo "$TIME < $FASTEST_TIME" | bc -l) )); then
        FASTEST_TIME=$TIME
        FASTEST_MIRROR=$MIRROR
    fi
done

echo "-----------------------------------"
echo "Fastest mirror: $FASTEST_MIRROR"
echo "Response time: $FASTEST_TIME seconds"

# Configure YUM repositories
echo "[base]" > /etc/yum.repos.d/CentOS-Base.repo
echo "name=CentOS-Base" >> /etc/yum.repos.d/CentOS-Base.repo
echo "baseurl=${FASTEST_MIRROR}/os/\$basearch/" >> /etc/yum.repos.d/CentOS-Base.repo
echo "gpgcheck=0" >> /etc/yum.repos.d/CentOS-Base.repo

echo "[updates]" >> /etc/yum.repos.d/CentOS-Base.repo
echo "name=CentOS-updates" >> /etc/yum.repos.d/CentOS-Base.repo
echo "baseurl=${FASTEST_MIRROR}/updates/\$basearch/" >> /etc/yum.repos.d/CentOS-Base.repo
echo "gpgcheck=0" >> /etc/yum.repos.d/CentOS-Base.repo

echo "[extras]" >> /etc/yum.repos.d/CentOS-Base.repo
echo "name=CentOS-extras" >> /etc/yum.repos.d/CentOS-Base.repo
echo "baseurl=${FASTEST_MIRROR}/extras/\$basearch/" >> /etc/yum.repos.d/CentOS-Base.repo
echo "gpgcheck=0" >> /etc/yum.repos.d/CentOS-Base.repo

echo "[centosplus]" >> /etc/yum.repos.d/CentOS-Base.repo
echo "name=CentOS-centosplus" >> /etc/yum.repos.d/CentOS-Base.repo
echo "baseurl=${FASTEST_MIRROR}/centosplus/\$basearch/" >> /etc/yum.repos.d/CentOS-Base.repo
echo "gpgcheck=0" >> /etc/yum.repos.d/CentOS-Base.repo

yum clean all
yum makecache
yum install -y https://dl.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm

# Set timezone
yum -y install tzdata
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone

# Update system
yum update -y

# Install development tools and dependencies
yum groupinstall -y "Development tools"
yum install -y \
    mpfr-devel \
    gmp-devel \
    libmpc-devel \
    zlib-devel \
    glibc-devel.i686 \
    glibc-devel \
    binutils-devel \
    texinfo \
    bison \
    flex \
    cmake \
    which \
    ninja-build \
    lld \
    bzip2 \
    wget \
    tar \
    git \
    tree \
    ncurses-devel \
    expat-devel \
    pkgconfig \
    gettext-devel \
    xz \
    xz-devel \
    zstd \
    pcre-devel \
    make \
    sed \
    autoconf \
    automake \
    libtool \
    curl \
    file \
    unzip \
    zip
yum clean all

# Install devtoolset-10 for newer GCC
# echo "[buildlogs-devtoolset-centos-x86_64]" > /etc/yum.repos.d/centos7-devtoolset-10.repo
# echo "name=devtoolset-10" >> /etc/yum.repos.d/centos7-devtoolset-10.repo
# echo "baseurl=https://buildlogs.cdn.centos.org/c7-devtoolset-10.x86_64" >> /etc/yum.repos.d/centos7-devtoolset-10.repo
# echo "gpgcheck=0" >> /etc/yum.repos.d/centos7-devtoolset-10.repo
# echo "enabled=1" >> /etc/yum.repos.d/centos7-devtoolset-10.repo

echo "[buildlogs-devtoolset9-centos-x86_64]" > /etc/yum.repos.d/centos7-devtoolset-10.repo
echo "name=devtoolset-9" >> /etc/yum.repos.d/centos7-devtoolset-10.repo
echo "baseurl=https://buildlogs.cdn.centos.org/c7-devtoolset-9.x86_64" >> /etc/yum.repos.d/centos7-devtoolset-10.repo
echo "gpgcheck=0" >> /etc/yum.repos.d/centos7-devtoolset-10.repo
echo "enabled=1" >> /etc/yum.repos.d/centos7-devtoolset-10.repo

yum -y update
# devtoolset-10 
yum -y install devtoolset-9 --nogpgcheck
yum clean all

# Enable devtoolset-10
# source /opt/rh/devtoolset-10/enable
# echo "source /opt/rh/devtoolset-10/enable" >> /etc/bashrc

# install mygcc
mkdir /opt/mygcc
curl -sLo mygcc.zip "${gcc_indiff_centos7_url}"
curl -sLo lld-indiff.zip https://github.com/indiff/gcc-build/releases/download/20251203_1308_16.0.0/lld-indiff-centos7-x86_64-20251203_1307.xz
unzip mygcc.zip -d /opt/mygcc
unzip lld-indiff.zip -d /opt/mygcc
rm -f mygcc.zip
rm -f lld-indiff.zip

export LD_LIBRARY_PATH=""
LD_LIBRARY_PATH=/opt/mygcc/lib:/opt/mygcc/lib64:$LD_LIBRARY_PATH


rm -f /etc/yum.repos.d/centos7-llvm.repo
echo "[centos7-13-llvm]" > /etc/yum.repos.d/centos7-llvm.repo
echo "name=CentOS-7 - llvm rh" >> /etc/yum.repos.d/centos7-llvm.repo
echo "baseurl=https://buildlogs.cdn.centos.org/c7-llvm-toolset-13.0.x86_64/" >> /etc/yum.repos.d/centos7-llvm.repo
echo "gpgcheck=0" >> /etc/yum.repos.d/centos7-llvm.repo
echo "enabled=1" >> /etc/yum.repos.d/centos7-llvm.repo


yum -y install llvm-toolset-13.0
yum clean all
scl enable llvm-toolset-13.0 bash
source /opt/rh/llvm-toolset-13.0/enable
echo 'source /opt/rh/llvm-toolset-13.0/enable' >> /etc/bashrc


# install cmake v4.1.1
curl -sLo cmake3.tar.gz https://github.com/Kitware/CMake/releases/download/v4.1.1/cmake-4.1.1-linux-x86_64.tar.gz
tar -xzf cmake3.tar.gz
mv cmake-4.1.1-linux-x86_64 /opt/cmake
rm -f /usr/bin/cmake
ln -sf /opt/cmake/bin/cmake /usr/bin/cmake

# update git
yum -y remove git
yum -y install https://packages.endpointdev.com/rhel/7/os/x86_64/endpoint-repo.x86_64.rpm
yum -y install git

# build ninja 

git clone --filter=blob:none https://github.com/ninja-build/ninja.git --depth=1
cd ninja
cmake -Bbuild-cmake -DBUILD_TESTING=OFF -DCMAKE_EXE_LINKER_FLAGS="-static-libstdc++ -static-libgcc" -DCMAKE_BUILD_TYPE=release -DCMAKE_CXX_COMPILER=/opt/mygcc/bin/g++
cmake --build build-cmake
rm -f /usr/bin/ninja
cp build-cmake/ninja /usr/bin/ninja
cd ..
rm -rf ninja
# rm -rf /opt/mygcc

/usr/bin/ninja --version

# yum -y remove python36 python36-pip python36-devel python3 python3-pip python3-devel
# yum -y install yum-plugin-copr
# yum -y copr enable adrienverge/python37
# yum -y install python37 python37-devel python37-pip
python3 --version
          
git --version

# 创建符号链接
rm -f /usr/bin/clang
rm -f /usr/bin/clang++
ln -sf /opt/rh/llvm-toolset-13.0/root/bin/clang /usr/bin/clang
ln -sf /opt/rh/llvm-toolset-13.0/root/bin/clang++ /usr/bin/clang++
ln -sf /opt/rh/llvm-toolset-13.0/root/bin/llvm-config /usr/bin/llvm-config
# Verify installations
clang++ -v
clang -v
make -v
cmake --version || true
ninja --version || true

export PATH=/opt/rh/llvm-toolset-13.0/root/usr/bin:/opt/rh/llvm-toolset-13.0/root/usr/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/opt/rh/llvm-toolset-13.0/root/usr/lib64:/opt/mygcc/lib:/opt/mygcc/lib64:/opt/rh/devtoolset-9/root/usr/lib64:$LD_LIBRARY_PATH
git clone --filter=blob:none --depth 1 https://github.com/microsoft/vcpkg.git /opt/vcpkg
/opt/vcpkg/bootstrap-vcpkg.sh
export VCPKG_ROOT=/opt/vcpkg
export TRIPLET=x64-linux
export PATH=/opt/rh/llvm-toolset-13.0/root/usr/bin:/opt/rh/llvm-toolset-13.0/root/usr/sbin:/opt/mygcc/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
CC=clang CXX=clang++ $VCPKG_ROOT/vcpkg install \
            zlib \
            lz4 \
            zstd \
            --triplet $TRIPLET --clean-after-build
            
echo "CentOS 7 build environment setup completed successfully!"
