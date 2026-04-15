#!/bin/bash
# Build an .ipk package for aria2-static.
#
# This creates a minimal .ipk (ar archive with control.tar.gz and data.tar.gz)
# suitable for opkg installation on OpenWrt.
#
# Usage:
#   bash build_ipk.sh <platform> <binary_path> <output_dir>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/versions.sh"

PLATFORM="${1:?Usage: build_ipk.sh <platform> <binary_path> <output_dir>}"
BINARY="${2:?Binary path required}"
OUTPUT_DIR="${3:?Output directory required}"

if [ ! -f "$BINARY" ]; then
    log_fatal "Binary not found: $BINARY"
fi

ARIA2_VERSION="$(get_aria2_version)"
PKG_NAME="aria2-static"
PKG_VERSION="${ARIA2_VERSION}-1"
PKG_ARCH="$PLATFORM"
WORKDIR="$(mktemp -d)"

trap 'rm -rf "$WORKDIR"' EXIT

# ── data.tar.gz ─────────────────────────────────────────────────────────────
DATA_DIR="$WORKDIR/data"
mkdir -p "$DATA_DIR/usr/bin"
mkdir -p "$DATA_DIR/etc/init.d"
mkdir -p "$DATA_DIR/etc/config"
mkdir -p "$DATA_DIR/usr/share/doc/$PKG_NAME"

cp "$BINARY" "$DATA_DIR/usr/bin/aria2c"
chmod 755 "$DATA_DIR/usr/bin/aria2c"

# Install init script and config if available
PACKAGE_FILES="$SCRIPT_DIR/../package/aria2-static/files"
if [ -f "$PACKAGE_FILES/aria2.init" ]; then
    cp "$PACKAGE_FILES/aria2.init" "$DATA_DIR/etc/init.d/aria2"
    chmod 755 "$DATA_DIR/etc/init.d/aria2"
fi
if [ -f "$PACKAGE_FILES/aria2.conf" ]; then
    cp "$PACKAGE_FILES/aria2.conf" "$DATA_DIR/etc/config/aria2"
fi

# BUILDINFO
if [ -f "$OUTPUT_DIR/BUILDINFO" ]; then
    cp "$OUTPUT_DIR/BUILDINFO" "$DATA_DIR/usr/share/doc/$PKG_NAME/BUILDINFO"
fi

cd "$DATA_DIR"
tar czf "$WORKDIR/data.tar.gz" .

# ── control.tar.gz ──────────────────────────────────────────────────────────
CTRL_DIR="$WORKDIR/control"
mkdir -p "$CTRL_DIR"

INSTALLED_SIZE=$(du -sk "$DATA_DIR" | awk '{print $1}')

cat > "$CTRL_DIR/control" <<EOF
Package: $PKG_NAME
Version: $PKG_VERSION
Architecture: $PKG_ARCH
Maintainer: openwrt-aria2
Description: aria2 download utility (statically linked)
 A lightweight multi-protocol & multi-source download utility with
 BitTorrent, Metalink, and HTTP/HTTPS/FTP/SFTP support. This package
 ships a statically linked binary with OpenSSL, libssh2, c-ares,
 expat, sqlite3, and zlib embedded.
Installed-Size: $INSTALLED_SIZE
Section: net
Priority: optional
EOF

# conffiles
cat > "$CTRL_DIR/conffiles" <<EOF
/etc/config/aria2
EOF

cd "$CTRL_DIR"
tar czf "$WORKDIR/control.tar.gz" .

# ── Assemble .ipk ──────────────────────────────────────────────────────────
echo "2.0" > "$WORKDIR/debian-binary"

ensure_dir "$OUTPUT_DIR"
IPK_FILE="$OUTPUT_DIR/${PKG_NAME}_${PKG_VERSION}_${PKG_ARCH}.ipk"

cd "$WORKDIR"
ar r "$IPK_FILE" debian-binary control.tar.gz data.tar.gz 2>/dev/null

log_info "Built: $IPK_FILE"
echo "IPK_FILE=$IPK_FILE"
