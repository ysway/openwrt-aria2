#!/bin/bash
# Entrypoint script for building aria2 inside the OpenWrt SDK container.
#
# This script is executed via:
#   docker run --rm --user root \
#     -v "$(pwd)/repo:/work/repo:z" \
#     -v "$(pwd)/output:/work/output:z" \
#     -e OPENWRT_SDK_VERSION=... \
#     -e BUILD_VERSION=... \
#     ghcr.io/openwrt/sdk:<platform>-V<version> \
#     bash /work/repo/build_scripts/build_in_sdk.sh <platform>
#
# Expects:
#   /work/repo    - mounted repo with aria2-builder submodule
#   /work/output  - mounted output directory for artifacts
#   /builder      - SDK_HOME (pre-existing in the SDK container image)

set -euo pipefail

PLATFORM="${1:?Usage: build_in_sdk.sh <platform>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

log_info "=== Building aria2 for $PLATFORM ==="

# ── Install host build tools ───────────────────────────────────────────────
log_info "Installing host build tools..."
apt-get update -qq
apt-get install -y --no-install-recommends \
    autoconf automake autotools-dev autopoint libtool pkg-config \
    gettext curl file bzip2 xz-utils upx-ucl ca-certificates binutils

# ── Set up SDK toolchain ──────────────────────────────────────────────────
SDK_HOME="${SDK_HOME:-/builder}"
TOOLCHAIN_DIR=$(find "$SDK_HOME"/staging_dir -maxdepth 1 -name 'toolchain-*' -type d | head -1)
if [ -z "$TOOLCHAIN_DIR" ]; then
    log_fatal "Could not find SDK toolchain directory in $SDK_HOME/staging_dir/"
fi
export PATH="$TOOLCHAIN_DIR/bin:$PATH"
log_info "Toolchain: $TOOLCHAIN_DIR"

# ── Resolve target mapping ─────────────────────────────────────────────────
source "$SCRIPT_DIR/target-map.sh"
resolve_target "$PLATFORM"

# Auto-detect TARGET_HOST from SDK toolchain if possible
DETECTED_HOST=$(auto_detect_target_host "$TOOLCHAIN_DIR")
if [ -n "$DETECTED_HOST" ]; then
    if [ "$DETECTED_HOST" != "$TARGET_HOST" ]; then
        log_info "Auto-detected host triple: $DETECTED_HOST (overriding mapped: $TARGET_HOST)"
        TARGET_HOST="$DETECTED_HOST"
        export TARGET_HOST
    fi
fi
log_info "Target: HOST=$TARGET_HOST SSL=$OPENSSL_TARGET UPX_SKIP=$UPX_SKIP"

# ── Build static dependencies ──────────────────────────────────────────────
export PREFIX=/work/static-prefix
export BUILDDIR=/work/build
mkdir -p "$PREFIX" "$BUILDDIR"

log_info "Building static dependencies..."
bash "$SCRIPT_DIR/build_deps_static.sh"

# ── Build aria2 ────────────────────────────────────────────────────────────
log_info "Building aria2..."
bash "$SCRIPT_DIR/build_static_aria2.sh"

BINARY="$ARIA2_SRC/src/aria2c"

# ── Verify binary ──────────────────────────────────────────────────────────
log_info "Verifying binary..."
VERIFY_LOG="/tmp/verify.log"
bash "$SCRIPT_DIR/verify_binary.sh" "$BINARY" 2>&1 | tee "$VERIFY_LOG" || true

FULLY_STATIC=$(grep 'FULLY_STATIC=' "$VERIFY_LOG" | tail -1 | cut -d= -f2)
export FULLY_STATIC="${FULLY_STATIC:-unknown}"

# ── Compress with UPX ──────────────────────────────────────────────────────
log_info "UPX compression..."
UPX_OUTPUT=$(bash "$SCRIPT_DIR/pack_with_upx.sh" "$BINARY" 2>&1) || true
echo "$UPX_OUTPUT"
UPX_APPLIED=$(echo "$UPX_OUTPUT" | grep 'UPX_APPLIED=' | cut -d= -f2)
export UPX_APPLIED="${UPX_APPLIED:-no}"

# ── Collect artifacts ──────────────────────────────────────────────────────
OUTPUT_DIR="/work/output/$PLATFORM"
mkdir -p "$OUTPUT_DIR"

export OPENWRT_SDK_VERSION="${OPENWRT_SDK_VERSION:-unknown}"
export BUILD_VERSION="${BUILD_VERSION:-dev}"

log_info "Collecting artifacts..."
bash "$SCRIPT_DIR/collect_artifacts.sh" "$PLATFORM" "$BINARY" "$OUTPUT_DIR"

# ── Build .ipk package ────────────────────────────────────────────────────
log_info "Building .ipk package..."
bash "$SCRIPT_DIR/build_ipk.sh" "$PLATFORM" "$BINARY" "$OUTPUT_DIR"

# ── Build .apk package ────────────────────────────────────────────────────
log_info "Building .apk package..."
bash "$SCRIPT_DIR/build_apk.sh" "$PLATFORM" "$BINARY" "$OUTPUT_DIR"

log_info "=== Build complete for $PLATFORM ==="
ls -la "$OUTPUT_DIR/"
