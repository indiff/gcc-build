#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# CentOS 7 dependency installation and configuration script
set -xe

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
    g++ \
    texinfo \
    bison \
    flex \
    cmake \
    which \
    clang \
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
    zip \
    centos-release-scl 
yum clean all

# Install devtoolset-10 for newer GCC
echo "[buildlogs-devtoolset-10-centos-x86_64]" > /etc/yum.repos.d/centos7-devtoolset-10.repo
echo "name=devtoolset-10" >> /etc/yum.repos.d/centos7-devtoolset-10.repo
echo "baseurl=https://buildlogs.cdn.centos.org/c7-devtoolset-10.x86_64" >> /etc/yum.repos.d/centos7-devtoolset-10.repo
echo "gpgcheck=0" >> /etc/yum.repos.d/centos7-devtoolset-10.repo
echo "enabled=1" >> /etc/yum.repos.d/centos7-devtoolset-10.repo

yum -y update
yum -y install devtoolset-10 --nogpgcheck
yum clean all

# Enable devtoolset-10
source /opt/rh/devtoolset-10/enable
echo "source /opt/rh/devtoolset-10/enable" >> /etc/bashrc


rm -f /etc/yum.repos.d/centos7-llvm.repo
echo "[centos7-13-llvm]" > /etc/yum.repos.d/centos7-llvm.repo
echo "name=CentOS-7 - llvm rh" >> /etc/yum.repos.d/centos7-llvm.repo
echo "baseurl=https://buildlogs.cdn.centos.org/c7-llvm-toolset-7.0.x86_64/" >> /etc/yum.repos.d/centos7-llvm.repo
echo "gpgcheck=0" >> /etc/yum.repos.d/centos7-llvm.repo
echo "enabled=1" >> /etc/yum.repos.d/centos7-llvm.repo
yum -y install llvm-toolset-7.0
yum clean all

scl enable llvm-toolset-7.0 bash
source /opt/rh/llvm-toolset-13.0/enable
echo 'source /opt/rh/llvm-toolset-7.0/enable' >> /etc/bashrc


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


yum -y remove python36 python36-pip python36-devel python3 python3-pip python3-devel
yum -y install yum-plugin-copr
yum -y copr enable adrienverge/python37
yum -y install python37 python37-devel python37-pip
python3 --version
          
git --version
        
# Verify installations
clang -v
gcc -v
make -v
cmake --version || true
ninja --version || true

echo "CentOS 7 build environment setup completed successfully!"
