#!/bin/bash
# Map OpenWrt platform names to compiler triples and OpenSSL target names.
#
# Usage:
#   source target-map.sh
#   resolve_target "aarch64_generic"
#   echo "$TARGET_HOST $OPENSSL_TARGET"
#
# After resolve_target, the following variables are exported:
#   TARGET_HOST        – GNU host triple for --host=
#   OPENSSL_TARGET     – OpenSSL ./Configure target
#   EXTRA_CFLAGS       – any target-specific CFLAGS
#   UPX_SKIP           – "yes" if UPX should be skipped for this target

set -euo pipefail

# Auto-detect TARGET_HOST from the SDK toolchain binaries.
# Call after setting TOOLCHAIN_DIR on PATH.
auto_detect_target_host() {
    local toolchain_dir="${1:?toolchain dir required}"
    local gcc_path
    gcc_path=$(find "$toolchain_dir/bin" -maxdepth 1 -name '*-gcc' ! -name '*-wrapper' 2>/dev/null | head -1)
    if [ -n "$gcc_path" ]; then
        basename "$gcc_path" | sed 's/-gcc$//'
    fi
}

resolve_target() {
    local platform="$1"
    TARGET_HOST=""
    OPENSSL_TARGET=""
    EXTRA_CFLAGS=""
    UPX_SKIP="no"

    case "$platform" in
        x86_64)
            TARGET_HOST="x86_64-openwrt-linux-musl"
            OPENSSL_TARGET="linux-x86_64"
            ;;
        aarch64_*)
            TARGET_HOST="aarch64-openwrt-linux-musl"
            OPENSSL_TARGET="linux-aarch64"
            ;;
        arm_*)
            TARGET_HOST="arm-openwrt-linux-muslgnueabi"
            OPENSSL_TARGET="linux-armv4"
            ;;
        i386_*)
            TARGET_HOST="i486-openwrt-linux-musl"
            OPENSSL_TARGET="linux-elf"
            ;;
        mips64el_*)
            TARGET_HOST="mips64el-openwrt-linux-musl"
            OPENSSL_TARGET="linux64-mips64"
            UPX_SKIP="yes"
            ;;
        mips64_*)
            TARGET_HOST="mips64-openwrt-linux-musl"
            OPENSSL_TARGET="linux64-mips64"
            UPX_SKIP="yes"
            ;;
        mipsel_*)
            TARGET_HOST="mipsel-openwrt-linux-musl"
            OPENSSL_TARGET="linux-mips32"
            ;;
        mips_*)
            TARGET_HOST="mips-openwrt-linux-musl"
            OPENSSL_TARGET="linux-mips32"
            ;;
        riscv64_*)
            TARGET_HOST="riscv64-openwrt-linux-musl"
            OPENSSL_TARGET="linux64-riscv64"
            UPX_SKIP="yes"
            ;;
        loongarch64_*)
            TARGET_HOST="loongarch64-openwrt-linux-musl"
            OPENSSL_TARGET="linux64-loongarch64"
            UPX_SKIP="yes"
            ;;
        *)
            echo "ERROR: Unknown platform '$platform'" >&2
            return 1
            ;;
    esac

    export TARGET_HOST OPENSSL_TARGET EXTRA_CFLAGS UPX_SKIP
}
