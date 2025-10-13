FROM centos/llvm-toolset-7-centos7:latest

LABEL maintainer="indiff"
LABEL description="CentOS 7 build environment for GCC and LLD compilation"

# Copy dependency installation script
COPY centos7.sh /tmp/centos7.sh

# Run the installation script
RUN chmod +x /tmp/centos7.sh && \
    /tmp/centos7.sh && \
    rm -f /tmp/centos7.sh

# Set working directory
WORKDIR /workspace

# Set default shell to bash with devtoolset-10 enabled
SHELL ["/bin/bash", "-c"]
CMD ["/bin/bash"]
