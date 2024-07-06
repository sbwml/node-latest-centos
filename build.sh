#!/bin/bash

node_version="$1"

# Setting up the environment
echo "::group::  Setting up the environment"
yum makecache
yum install -y devtoolset-12-gcc devtoolset-12-gcc-c++ devtoolset-12-make wget curl patch openssl-devel
bash -c "$(curl -sS https://us.cooluc.com/python3/install.sh)"
echo "::endgroup::"

# Download Source
echo "::group::  Download node-v"$node_version".tar.xz"
wget https://nodejs.org/dist/v"$node_version"/node-v"$node_version".tar.xz
tar -Jxf node-v"$node_version".tar.xz
echo "::endgroup::"

# Build Node
source /etc/profile
source /opt/rh/devtoolset-12/enable
cd node-v"$node_version"
sed -i 's/define HAVE_SYS_RANDOM_H 1/undef HAVE_SYS_RANDOM_H/g' deps/cares/config/linux/ares_config.h
sed -i 's/define HAVE_GETRANDOM 1/undef HAVE_GETRANDOM/g' deps/cares/config/linux/ares_config.h
echo "::group::  Configure node-v"$node_version""
./configure --prefix=../node-v"$node_version"-linux-x$(getconf LONG_BIT)
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
tar Jcvf tar/node-v"$node_version"-linux-x$(getconf LONG_BIT).tar.xz node-v"$node_version"-linux-x$(getconf LONG_BIT)
tar zcvf tar/node-v"$node_version"-linux-x$(getconf LONG_BIT).tar.gz node-v"$node_version"-linux-x$(getconf LONG_BIT)
sha256sum node-v*.tar.* > sha256sum.txt
