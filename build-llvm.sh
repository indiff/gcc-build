#/bin/bash


git clone --filter=blob:none https://github.com/indiff/bash-shell.git --depth=1
cd bash-shell/LLVM&Clang Installer/20.1/


env CC=/opt/gcc-indiff/bin/gcc CXX=/opt/gcc-indiff/bin/g++ installer-bootstrap.sh -p /workspace/gcc-x86
