#!/bin/bash
# Dependency versions — sourced from aria2-builder upstream
# Keep in sync with aria2-builder/release.yml

ZLIB_VERSION="1.3.1"
EXPAT_VERSION="2.5.0"
SQLITE_VERSION="3430100"
CARES_VERSION="1.19.1"
LIBSSH2_VERSION="1.11.0"
OPENSSL_VERSION="3.4.4"

# aria2 source is inside the submodule; version is extracted at build time
# from aria2-builder/configure.ac

# Download URLs
ZLIB_URL="https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz"
EXPAT_URL="https://github.com/libexpat/libexpat/releases/download/R_$(echo $EXPAT_VERSION | tr . _)/expat-${EXPAT_VERSION}.tar.bz2"
SQLITE_URL="https://www.sqlite.org/2023/sqlite-autoconf-${SQLITE_VERSION}.tar.gz"
CARES_URL="https://github.com/c-ares/c-ares/releases/download/cares-$(echo $CARES_VERSION | tr . _)/c-ares-${CARES_VERSION}.tar.gz"
LIBSSH2_URL="https://github.com/libssh2/libssh2/releases/download/libssh2-${LIBSSH2_VERSION}/libssh2-${LIBSSH2_VERSION}.tar.bz2"
OPENSSL_URL="https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz"
