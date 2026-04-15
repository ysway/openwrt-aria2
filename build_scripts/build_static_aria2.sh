#!/bin/bash
# Build aria2c as a static binary using the pre-built static dependencies.
#
# Expects:
#   - SDK toolchain on PATH
#   - TARGET_HOST set
#   - PREFIX set and populated by build_deps_static.sh
#   - ARIA2_SRC pointing to the aria2-builder submodule

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

if [ -z "${TARGET_HOST:-}" ]; then
    log_fatal "TARGET_HOST is not set; source target-map.sh and call resolve_target first"
fi

log_info "Building aria2 from $ARIA2_SRC for $TARGET_HOST"

cd "$ARIA2_SRC"

# Regenerate build system
autoreconf -i

./configure \
    --host="$TARGET_HOST" \
    --prefix=/usr \
    --disable-nls \
    --without-gnutls --with-openssl \
    --without-libxml2 --with-libexpat \
    --with-libcares --with-libz --with-sqlite3 --with-libssh2 \
    ARIA2_STATIC=yes \
    CXXFLAGS="-O2 ${EXTRA_CFLAGS:-}" \
    CFLAGS="-O2 ${EXTRA_CFLAGS:-}" \
    CPPFLAGS="-I$PREFIX/include" \
    LDFLAGS="-L$PREFIX/lib -static -static-libgcc -static-libstdc++" \
    PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

make -j"$NPROC"

# Strip the binary using the cross-strip from the toolchain
"${TARGET_HOST}-strip" src/aria2c 2>/dev/null || strip src/aria2c 2>/dev/null || true

log_info "aria2c built: $(file src/aria2c)"
