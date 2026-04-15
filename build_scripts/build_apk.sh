#!/bin/bash
# Build an .apk package for aria2-static (OpenWrt 24+ APK format).
#
# This is a Phase 3 placeholder. OpenWrt's APK packaging uses a different
# archive format. For now, this script warns and exits cleanly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

log_warn "APK packaging is not yet implemented (Phase 3)"
echo "APK_FILE="
exit 0
