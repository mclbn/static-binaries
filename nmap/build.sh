#!/bin/bash

set -e
set -o pipefail
set -x


NMAP_VERSION=7.94
OPENSSL_VERSION=1.1.1u


function build_openssl() {
    cd /build

    # Download
    curl -LO https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
    tar zxvf openssl-${OPENSSL_VERSION}.tar.gz
    cd openssl-${OPENSSL_VERSION}

    # Configure
    CC='/musl-cross-make/output/bin/x86_64-linux-musl-gcc -static' ./Configure no-shared linux-x86_64

    # Build
    make
    echo "** Finished building OpenSSL"
}

function build_nmap() {
    cd /build

    # Install Python
    DEBIAN_FRONTEND=noninteractive apt-get update --allow-releaseinfo-change
    DEBIAN_FRONTEND=noninteractive apt-get install -yy python3

    # Download
    curl -LO https://nmap.org/dist/nmap-${NMAP_VERSION}.tar.bz2
    tar xjvf nmap-${NMAP_VERSION}.tar.bz2
    cd nmap-${NMAP_VERSION}

    # Configure
    CC='/musl-cross-make/output/bin/x86_64-linux-musl-gcc -static -fPIC' \
        CXX='/musl-cross-make/output/bin/x86_64-linux-musl-g++ -static -static-libstdc++ -fPIC' \
        LD=/musl-cross-make/output/bin/x86_64-linux-musl-ld \
        LDFLAGS="-L/build/openssl-${OPENSSL_VERSION}"   \
        ./configure \
            --without-ndiff \
            --without-zenmap \
            --without-nmap-update \
            --with-pcap=linux \
            --with-openssl=/build/openssl-${OPENSSL_VERSION}

    # Don't build the libpcap.so file
    sed -i -e 's/shared\: /shared\: #/' libpcap/Makefile
    sed -i -e 's/shared\: /shared\: #/' libz/Makefile

    # Build
    make -j4
    /musl-cross-make/output/bin/x86_64-linux-musl-strip nmap ncat/ncat nping/nping
}

function doit() {

    # check if /output was mapped
    if [ ! -d /output ]; then
        echo "/output directory not found. Make sure you are running the container by mapping the output directory with '-v'"
        exit -1
    fi

    build_openssl
    build_nmap

    OUT_DIR=/output/`uname | tr 'A-Z' 'a-z'`/`uname -m`
    mkdir -p $OUT_DIR
    cp /build/nmap-${NMAP_VERSION}/nmap $OUT_DIR/
    cp /build/nmap-${NMAP_VERSION}/ncat/ncat $OUT_DIR/
    cp /build/nmap-${NMAP_VERSION}/nping/nping $OUT_DIR/
    echo "** Finished **"
}

doit
