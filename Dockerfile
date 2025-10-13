FROM centos:7

LABEL maintainer="indiff"
LABEL description="CentOS 7 build environment for GCC and LLD compilation"

# Copy dependency installation script
COPY centos7.sh /tmp/centos7.sh

# Run the installation script
RUN chmod +x /tmp/centos7.sh && \
    /tmp/centos7.sh && \
    rm -f /tmp/centos7.sh


/opt/rh/llvm-toolset-13.0/enable
ENV PATH=/opt/rh/llvm-toolset-13.0/root/usr/bin:$PATH
ENV LD_LIBRARY_PATH=/opt/rh/llvm-toolset-13.0/root/usr/lib64:/opt/rh/devtoolset-9/root/usr/lib64:$LD_LIBRARY_PATH
ENV CC=/opt/rh/llvm-toolset-13.0/root/usr/bin/clang
ENV CXX=/opt/rh/llvm-toolset-13.0/root/usr/bin/clang++

# Set working directory
WORKDIR /workspace

# Set default shell to bash with devtoolset-10 enabled
SHELL ["/bin/bash", "-c"]
CMD ["/bin/bash"]
