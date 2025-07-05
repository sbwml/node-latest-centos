#!/bin/bash

node_version="$1"
major_version=${node_version%%.*}

# Setting up the environment
echo "::group::  Setting up the environment"
yum makecache
yum install -y devtoolset-12-gcc devtoolset-12-gcc-c++ devtoolset-12-make wget curl patch openssl-devel
bash -c "$(curl -sS https://us.cooluc.com/python3/install.sh)"
wget https://github.com/sbwml/redhat-llvm-project/releases/download/20.0.0/clang-20.0.0-x86_64-redhat-linux-gnu.tar.xz
tar xf clang-20.0.0-x86_64-redhat-linux-gnu.tar.xz
mv clang-20.0.0-x86_64-redhat-linux-gnu /opt/clang
rm -rf clang-20.0.0-x86_64-redhat-linux-gnu.tar.xz
echo "export PATH=\"/opt/clang/bin:\$PATH\"" >> /etc/profile
echo "::endgroup::"

# Download Source
echo "::group::  Download node-v"$node_version".tar.xz"
wget https://nodejs.org/dist/v"$node_version"/node-v"$node_version".tar.xz
tar -Jxf node-v"$node_version".tar.xz
rm -rf node-v"$node_version".tar.xz
echo "::endgroup::"

# Build Node
source /etc/profile
source /opt/rh/devtoolset-12/enable
cd node-v"$node_version"

# fix cares
sed -i 's/define HAVE_SYS_RANDOM_H 1/undef HAVE_SYS_RANDOM_H/g' deps/cares/config/linux/ares_config.h
sed -i 's/define HAVE_GETRANDOM 1/undef HAVE_GETRANDOM/g' deps/cares/config/linux/ares_config.h

if [ "$major_version" -ge "23" ]; then
    # v8: wasm: fix: define MFD_CLOEXEC for compatibility with old glibc
    cat <<'EOF' | cat - deps/v8/src/wasm/wasm-objects.cc > temp && mv temp deps/v8/src/wasm/wasm-objects.cc -f
#include <unistd.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <fcntl.h>

#ifndef MFD_CLOEXEC
#define MFD_CLOEXEC 0x0001
#endif

#ifndef MFD_ALLOW_SEALING
#define MFD_ALLOW_SEALING 0x0002
#endif

#ifndef HAVE_MEMFD_CREATE
#if defined(__x86_64__)
#define __NR_memfd_create 319
#elif defined(__i386__)
#define __NR_memfd_create 356
#elif defined(__arm__)
#define __NR_memfd_create 385
#elif defined(__aarch64__)
#define __NR_memfd_create 279
#else
#error "Platform not supported for memfd_create syscall numbers"
#endif

static inline int memfd_create(const char *name, unsigned int flags) {
    return syscall(__NR_memfd_create, name, flags);
}
#endif

EOF
fi

echo "::group::  Configure node-v"$node_version""
CC=clang CXX=clang++ ./configure --prefix=../node-v"$node_version"-linux-x$(getconf LONG_BIT)
echo "::endgroup::"
echo "::group::  make node-v"$node_version""
make -j$(($(nproc --all)+1))
echo "::endgroup::"
echo "::group::  make install"
make install
echo "::endgroup::"
cp -a ./{LICENSE,CHANGELOG.md,README.md} ../node-v"$node_version"-linux-x$(getconf LONG_BIT)/
strip ../node-v"$node_version"-linux-x$(getconf LONG_BIT)/bin/node

# Create Archive
cd ..
tar Jcf node-v"$node_version"-linux-x$(getconf LONG_BIT).tar.xz node-v"$node_version"-linux-x$(getconf LONG_BIT)
tar zcf node-v"$node_version"-linux-x$(getconf LONG_BIT).tar.gz node-v"$node_version"-linux-x$(getconf LONG_BIT)
sha256sum node-v*.tar.* > sha256sum.txt
