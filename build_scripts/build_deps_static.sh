#!/bin/bash
# Build all static dependencies inside the OpenWrt SDK container.
#
# Expects:
#   - SDK toolchain on PATH (CC, CXX, AR, RANLIB set or discoverable)
#   - TARGET_HOST, OPENSSL_TARGET, EXTRA_CFLAGS set (via target-map.sh)
#   - PREFIX set (via common.sh)
#   - versions.sh sourced
#
# Usage:
#   source build_scripts/common.sh
#   source build_scripts/versions.sh
#   source build_scripts/target-map.sh
#   resolve_target "$PLATFORM"
#   bash build_scripts/build_deps_static.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/versions.sh"

SRC_DIR="$BUILDDIR/src"
ensure_dir "$SRC_DIR" "$PREFIX"

COMMON_CFLAGS="-O2 ${EXTRA_CFLAGS:-}"

# ── Download all sources ────────────────────────────────────────────────────
log_info "Downloading dependency sources..."
download_source "$ZLIB_URL"    "$SRC_DIR/zlib-${ZLIB_VERSION}.tar.gz"
download_source "$EXPAT_URL"   "$SRC_DIR/expat-${EXPAT_VERSION}.tar.bz2"
download_source "$SQLITE_URL"  "$SRC_DIR/sqlite-autoconf-${SQLITE_VERSION}.tar.gz"
download_source "$CARES_URL"   "$SRC_DIR/c-ares-${CARES_VERSION}.tar.gz"
download_source "$LIBSSH2_URL" "$SRC_DIR/libssh2-${LIBSSH2_VERSION}.tar.bz2"
download_source "$OPENSSL_URL" "$SRC_DIR/openssl-${OPENSSL_VERSION}.tar.gz"

# ── zlib ────────────────────────────────────────────────────────────────────
log_info "Building zlib ${ZLIB_VERSION}"
cd "$BUILDDIR"
rm -rf "zlib-${ZLIB_VERSION}"
extract_source "$SRC_DIR/zlib-${ZLIB_VERSION}.tar.gz" "$BUILDDIR"
cd "zlib-${ZLIB_VERSION}"
CHOST="$TARGET_HOST" CFLAGS="$COMMON_CFLAGS" \
    ./configure --prefix="$PREFIX" --static
make -j"$NPROC"
make install

# ── expat ───────────────────────────────────────────────────────────────────
log_info "Building expat ${EXPAT_VERSION}"
cd "$BUILDDIR"
rm -rf "expat-${EXPAT_VERSION}"
extract_source "$SRC_DIR/expat-${EXPAT_VERSION}.tar.bz2" "$BUILDDIR"
cd "expat-${EXPAT_VERSION}"
./configure --host="$TARGET_HOST" --prefix="$PREFIX" \
    --disable-shared --enable-static \
    CFLAGS="$COMMON_CFLAGS"
make -j"$NPROC"
make install

# ── SQLite ──────────────────────────────────────────────────────────────────
log_info "Building SQLite ${SQLITE_VERSION}"
cd "$BUILDDIR"
rm -rf "sqlite-autoconf-${SQLITE_VERSION}"
extract_source "$SRC_DIR/sqlite-autoconf-${SQLITE_VERSION}.tar.gz" "$BUILDDIR"
cd "sqlite-autoconf-${SQLITE_VERSION}"
./configure --host="$TARGET_HOST" --prefix="$PREFIX" \
    --disable-shared --enable-static \
    CFLAGS="$COMMON_CFLAGS"
make -j"$NPROC"
make install

# ── c-ares ──────────────────────────────────────────────────────────────────
log_info "Building c-ares ${CARES_VERSION}"
cd "$BUILDDIR"
rm -rf "c-ares-${CARES_VERSION}"
extract_source "$SRC_DIR/c-ares-${CARES_VERSION}.tar.gz" "$BUILDDIR"
cd "c-ares-${CARES_VERSION}"
./configure --host="$TARGET_HOST" --prefix="$PREFIX" \
    --disable-shared --enable-static \
    CFLAGS="$COMMON_CFLAGS"
make -j"$NPROC"
make install

# ── OpenSSL ─────────────────────────────────────────────────────────────────
log_info "Building OpenSSL ${OPENSSL_VERSION}"
cd "$BUILDDIR"
rm -rf "openssl-${OPENSSL_VERSION}"
extract_source "$SRC_DIR/openssl-${OPENSSL_VERSION}.tar.gz" "$BUILDDIR"
cd "openssl-${OPENSSL_VERSION}"
./Configure "$OPENSSL_TARGET" no-shared no-module no-tests \
    --cross-compile-prefix="${TARGET_HOST}-" \
    --prefix="$PREFIX" --libdir=lib \
    -O2
make -j"$NPROC"
make install_sw

# ── libssh2 ────────────────────────────────────────────────────────────────
log_info "Building libssh2 ${LIBSSH2_VERSION}"
cd "$BUILDDIR"
rm -rf "libssh2-${LIBSSH2_VERSION}"
extract_source "$SRC_DIR/libssh2-${LIBSSH2_VERSION}.tar.bz2" "$BUILDDIR"
cd "libssh2-${LIBSSH2_VERSION}"
./configure --host="$TARGET_HOST" --prefix="$PREFIX" \
    --disable-shared --enable-static \
    --with-crypto=openssl --with-libssl-prefix="$PREFIX" \
    CPPFLAGS="-I$PREFIX/include" LDFLAGS="-L$PREFIX/lib" \
    CFLAGS="$COMMON_CFLAGS" \
    PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
make -j"$NPROC"
make install

log_info "All static dependencies built successfully in $PREFIX"
