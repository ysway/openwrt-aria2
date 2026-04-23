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

EXTRA_LIBS_ARRAY=()
EXTRA_LIBS_STRING=""

if [ -n "${EXTRA_LIBS:-}" ]; then
    read -r -a extra_libs_raw <<< "$EXTRA_LIBS"
    mapfile -t EXTRA_LIBS_ARRAY < <(resolve_extra_libs "${TARGET_HOST}-gcc" "${extra_libs_raw[@]}")
    EXTRA_LIBS_STRING="${EXTRA_LIBS_ARRAY[*]}"
fi

resolve_target_binutils

find_config_helper() {
    local helper_name="${1:?helper name required}"
    local helper_path=""

    if [ -n "${STAGING_DIR:-}" ] && [ -d "$STAGING_DIR/host/share" ]; then
        helper_path=$(find "$STAGING_DIR/host/share" \( -path "*/automake-*/$helper_name" -o -path "*/misc/$helper_name" \) 2>/dev/null | sort | head -1)
    fi

    if [ -z "$helper_path" ]; then
        helper_path=$(find /usr/share \( -path "*/automake-*/$helper_name" -o -path "*/misc/$helper_name" \) 2>/dev/null | sort | head -1)
    fi

    printf '%s' "$helper_path"
}

refresh_config_helpers() {
    local config_sub config_guess dir
    config_sub=$(find_config_helper config.sub)
    config_guess=$(find_config_helper config.guess)

    for dir in "$ARIA2_SRC" "$ARIA2_SRC/deps/wslay"; do
        [ -d "$dir" ] || continue
        if [ -n "$config_sub" ] && [ -f "$dir/config.sub" ]; then
            cp "$config_sub" "$dir/config.sub"
        fi
        if [ -n "$config_guess" ] && [ -f "$dir/config.guess" ]; then
            cp "$config_guess" "$dir/config.guess"
        fi
    done
}

cd "$ARIA2_SRC"

# Regenerate build system
autoreconf -i
refresh_config_helpers

ARIA2_LIBS="-lgcc_eh${EXTRA_LIBS_STRING:+ $EXTRA_LIBS_STRING}"

AR="$TARGET_AR" RANLIB="$TARGET_RANLIB" NM="$TARGET_NM" \
./configure \
    --host="$TARGET_HOST" \
    --prefix=/usr \
    --disable-nls \
    --without-gnutls --with-openssl \
    --without-libxml2 --with-libexpat \
    --with-libcares --with-libz --with-sqlite3 --with-libssh2 \
    ARIA2_STATIC=yes \
    CXXFLAGS="-O2 -ffunction-sections -fdata-sections -fno-asynchronous-unwind-tables -flto=auto ${EXTRA_CFLAGS:-}" \
    CFLAGS="-O2 -ffunction-sections -fdata-sections -fno-asynchronous-unwind-tables -flto=auto ${EXTRA_CFLAGS:-}" \
    CPPFLAGS="-I$PREFIX/include" \
    LDFLAGS="-L$PREFIX/lib -static -static-libgcc -static-libstdc++ -Wl,--gc-sections -flto=auto" \
    LIBS="$ARIA2_LIBS" \
    PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

make -j"$NPROC"

# Strip the binary using the cross-strip from the toolchain
"${TARGET_HOST}-strip" src/aria2c 2>/dev/null || strip src/aria2c 2>/dev/null || true

log_info "aria2c built: $(file src/aria2c)"
