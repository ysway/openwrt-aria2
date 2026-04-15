#!/bin/sh
# Quick installer for aria2-static on OpenWrt
#
# Usage:
#   wget -O- https://raw.githubusercontent.com/OWNER/openwrt-aria2/master/install.sh | sh
#
# Or download and run:
#   sh install.sh

set -e

REPO="OWNER/openwrt-aria2"
FEED_URL="https://github.com/${REPO}/releases/latest/download"

# Detect architecture
detect_arch() {
    local arch
    arch=$(opkg print-architecture 2>/dev/null | awk '/arch/{print $2}' | grep -v 'all' | head -1)
    if [ -z "$arch" ]; then
        arch=$(uname -m)
        case "$arch" in
            x86_64)       arch="x86_64" ;;
            aarch64)      arch="aarch64_generic" ;;
            armv7*)       arch="arm_cortex-a7" ;;
            mips)         arch="mips_24kc" ;;
            mipsel)       arch="mipsel_24kc" ;;
            riscv64)      arch="riscv64_generic" ;;
            loongarch64)  arch="loongarch64_generic" ;;
            i?86)         arch="i386_pentium4" ;;
            *)
                echo "ERROR: Unsupported architecture: $arch" >&2
                exit 1
                ;;
        esac
    fi
    echo "$arch"
}

ARCH=$(detect_arch)
echo "Detected architecture: $ARCH"

# Try opkg install from feed first
if command -v opkg >/dev/null 2>&1; then
    echo "Attempting opkg install..."
    IPK_URL="${FEED_URL}/aria2-static_*_${ARCH}.ipk"
    TMPFILE=$(mktemp /tmp/aria2-static.XXXXXX.ipk)
    if wget -q -O "$TMPFILE" "${FEED_URL}/aria2c-${ARCH}" 2>/dev/null; then
        # Direct binary install fallback
        echo "Installing binary directly..."
        mv "$TMPFILE" /usr/bin/aria2c
        chmod 755 /usr/bin/aria2c
    else
        rm -f "$TMPFILE"
        echo "ERROR: Could not download aria2-static for $ARCH" >&2
        echo "Visit https://github.com/${REPO}/releases for manual download." >&2
        exit 1
    fi
fi

# Verify
if /usr/bin/aria2c --version >/dev/null 2>&1; then
    echo "aria2c installed successfully!"
    /usr/bin/aria2c --version | head -1
else
    echo "WARNING: aria2c installed but could not verify (may need reboot)"
fi
