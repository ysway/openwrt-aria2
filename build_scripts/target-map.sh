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
        aarch64_generic)
            TARGET_HOST="aarch64-openwrt-linux-musl"
            OPENSSL_TARGET="linux-aarch64"
            ;;
        arm_cortex-a7)
            TARGET_HOST="arm-openwrt-linux-muslgnueabi"
            OPENSSL_TARGET="linux-armv4"
            EXTRA_CFLAGS="-march=armv7-a -mcpu=cortex-a7 -mfloat-abi=soft"
            ;;
        arm_cortex-a9)
            TARGET_HOST="arm-openwrt-linux-muslgnueabi"
            OPENSSL_TARGET="linux-armv4"
            EXTRA_CFLAGS="-march=armv7-a -mcpu=cortex-a9 -mfloat-abi=soft"
            ;;
        i386_pentium4)
            TARGET_HOST="i486-openwrt-linux-musl"
            OPENSSL_TARGET="linux-elf"
            EXTRA_CFLAGS="-march=pentium4"
            ;;
        mips_24kc)
            TARGET_HOST="mips-openwrt-linux-musl"
            OPENSSL_TARGET="linux-mips32"
            ;;
        mipsel_24kc)
            TARGET_HOST="mipsel-openwrt-linux-musl"
            OPENSSL_TARGET="linux-mips32"
            ;;
        riscv64_generic)
            TARGET_HOST="riscv64-openwrt-linux-musl"
            OPENSSL_TARGET="linux64-riscv64"
            UPX_SKIP="yes"
            ;;
        loongarch64_generic)
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
