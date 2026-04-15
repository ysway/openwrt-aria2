#!/bin/bash
# Generate a package feed index from collected .ipk files.
#
# Usage:
#   bash gen_feed.sh <artifacts_dir> <feed_output_dir>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ARTIFACTS_DIR="${1:?Usage: gen_feed.sh <artifacts_dir> <feed_output_dir>}"
FEED_DIR="${2:?Feed output directory required}"

ensure_dir "$FEED_DIR"

log_info "Generating feed index from $ARTIFACTS_DIR"

# Copy all .ipk files to feed directory
find "$ARTIFACTS_DIR" -name '*.ipk' -exec cp {} "$FEED_DIR/" \;

# Generate Packages index
cd "$FEED_DIR"
IPK_COUNT=0
PACKAGES_FILE="$FEED_DIR/Packages"
> "$PACKAGES_FILE"

for ipk in *.ipk; do
    [ -f "$ipk" ] || continue
    IPK_COUNT=$((IPK_COUNT + 1))

    # Extract control info
    TMPDIR=$(mktemp -d)
    cd "$TMPDIR"
    ar x "$FEED_DIR/$ipk" control.tar.gz 2>/dev/null || true
    if [ -f control.tar.gz ]; then
        tar xzf control.tar.gz ./control 2>/dev/null || true
    fi

    if [ -f control ]; then
        cat control >> "$PACKAGES_FILE"
    fi
    rm -rf "$TMPDIR"
    cd "$FEED_DIR"

    SIZE=$(stat -c%s "$ipk" 2>/dev/null || stat -f%z "$ipk")
    MD5=$(md5sum "$ipk" | awk '{print $1}')
    SHA256=$(sha256sum "$ipk" | awk '{print $1}')

    cat >> "$PACKAGES_FILE" <<EOF
Filename: $ipk
Size: $SIZE
MD5Sum: $MD5
SHA256sum: $SHA256

EOF
done

# Compress Packages
gzip -k "$PACKAGES_FILE" 2>/dev/null || gzip -c "$PACKAGES_FILE" > "${PACKAGES_FILE}.gz"

# Copy index.html template if available
TEMPLATE="$SCRIPT_DIR/../feed_template/index.html"
if [ -f "$TEMPLATE" ]; then
    cp "$TEMPLATE" "$FEED_DIR/index.html"
fi

log_info "Feed generated: $IPK_COUNT packages in $FEED_DIR"
