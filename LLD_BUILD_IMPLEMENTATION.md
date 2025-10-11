# LLD Build Workflow Implementation

This document describes the implementation of the LLD (LLVM Linker) build workflow using CentOS 7 Docker.

## Overview

The workflow has been enhanced to support building LLD compiler with CentOS 7 in a Docker container. The implementation includes:

1. **Dockerfile** - Defines the CentOS 7 build environment
2. **centos7.sh** - Script for installing dependencies and configuring the environment
3. **Workflow job** - GitHub Actions job for building and publishing LLD

## Files Created

### 1. `Dockerfile`
- Base image: CentOS 7
- Copies and executes the centos7.sh script
- Sets up working directory and default shell

### 2. `centos7.sh`
- Configures YUM repositories (finds fastest mirror)
- Installs all required development tools and dependencies:
  - Development tools group
  - mpfr-devel, gmp-devel, libmpc-devel, zlib-devel
  - glibc-devel (32 and 64 bit)
  - binutils-devel, g++, texinfo, bison, flex
  - cmake, clang, ninja-build, lld, bzip2
  - And many more...
- Installs devtoolset-10 for newer GCC version
- Sets timezone to Asia/Shanghai

## Workflow Changes

### New Job: `build-lld-centos7`
This job:
1. **Builds Docker Image**
   - Uses Docker Buildx for better caching
   - Generates cache key based on Dockerfile and centos7.sh content
   - Pushes to GitHub Container Registry (ghcr.io)
   - Uses layer caching to avoid rebuilding unchanged layers

2. **Builds LLD**
   - Runs `build-lld.sh -a x86` inside the Docker container
   - Uses devtoolset-10 for compilation

3. **Packages LLD**
   - Creates a compressed archive of the built LLD
   - Names it: `lld-indiff-centos7-x86_64-YYYYMMDD_HHMM.xz`

4. **Uploads Artifacts**
   - Uploads the LLD package as a GitHub Actions artifact

### Updated Job: `publish-release`
- Now depends on `build-lld-centos7` job
- Downloads both GCC and LLD artifacts
- Creates release with both packages
- Updates release notes to include separate download links for GCC and LLD

## Cache Strategy

The Docker image uses a smart caching strategy:
- Cache key is generated from the SHA256 hash of Dockerfile and centos7.sh
- If either file changes, the cache key changes and Docker image is rebuilt
- If files are unchanged, the workflow pulls the cached image from registry
- Uses Docker layer caching (`cache-from` and `cache-to` parameters)

## Usage

The workflow runs automatically on:
- Push to main branch
- Daily schedule (midnight)
- Manual dispatch

To manually trigger:
1. Go to Actions tab in GitHub
2. Select "GCC+LLD Build" workflow
3. Click "Run workflow"

## Docker Image Location

The built Docker image is available at:
```
ghcr.io/indiff/gcc-build-centos7:latest
```

## Release Artifacts

When the workflow completes, it creates a GitHub release with:
- GCC compiler package (from build-in-centos7 job)
- LLD linker package (from build-lld-centos7 job)

Both packages are available for download with proxy and direct download options.
