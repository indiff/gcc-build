git clone https://github.com/Microsoft/vcpkg.git --depth 1
cd vcpkg
export VCPKG_ROOT=$(pwd)
export PATH=$VCPKG_ROOT:$PATH
./bootstrap-vcpkg.sh
./vcpkg integrate install
./vcpkg install curl[openssl]
tree packages
cd $WORK_DIR

git clone https://github.com/git/git.git --depth 1
cd git
GIT_VERSION=$(cat GIT-VERSION-FILE | cut -d'=' -f2)
make configure
./configure --prefix=/opt/git
vdir=$WORK_DIR/vcpkg/installed/x64-linux
make -j"$JOBS" NO_EXPAT=1 NO_TCLTK=1 NO_GETTEXT=1 NO_PERL=1 CFLAGS="-I${vdir}/include/curl" \
    LDFLAGS="-L${vdir}/lib"  \
    NO_REGEX=NeedsStartEnd \
    NO_INSTALL_HARDLINKS=Yes \
    INSTALL_SYMLINKS=Yes \
    CURL_LIBCURL="${vdir}/lib/libcurl.a ${vdir}/lib/libssl.a ${vdir}/lib/libcrypto.a -static-libgcc" all install
# package git
cd /opt/git
# gname=/workspace/centos7-indiff-git-${{ env.GIT_VERSION }}-$(/bin/date -u '+%Y%m%d')
gname=/workspace/centos7-indiff-git-${GIT_VERSION}-$(/bin/date -u '+%Y%m%d')
zip -r -q -9 $gname.zip .
mv $gname.zip $gname.xz
ln -sf /opt/git/bin/git /usr/bin/git
git --version
cd $WORK_DIR